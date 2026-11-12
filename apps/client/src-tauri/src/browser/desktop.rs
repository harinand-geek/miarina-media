//! Built-in browser on Windows (decision 0001), inside the main window. The
//! React browser screen draws the chrome (Windows v2 screen 8: tab strip,
//! toolbar) and reports where the page goes (`browser_frame`); child
//! webviews of the main window sit there:
//! - one `browser-page-<id>` per open tab: the visited site. Untrusted:
//!   remote origin, so no capability applies to it; http(s) only, popups
//!   become new tabs, no browser-native downloads;
//! - `browser-overlay`: floating download button and format sheet, drawn
//!   transparently above the page.
//!
//! Tabs (NAV-02) have a memory budget: at most `MAX_TABS` open and
//! `MAX_LIVE_PAGES` with a live webview; the least recently used background
//! tabs are put to sleep (webview closed, address kept) and reload when
//! selected. Open tabs are restored at the next start. Visited pages go to
//! the local history (NAV-03).
//!
//! Detection never depends on the page's cooperation: Rust reads WebView2
//! network events and pulls `<video>`/`<audio>` sources with a script whose
//! answer is filtered by `media_core::detect`.

use std::sync::Mutex;
use std::time::Duration;

use media_core::detect::{DetectedMedia, Detections};
use serde::{Deserialize, Serialize};
use tauri::webview::{NewWindowResponse, WebviewBuilder};
use tauri::{AppHandle, Emitter, LogicalPosition, LogicalSize, Manager, State, Url, WebviewUrl};

use super::page_state::valid_rect;
use crate::commands::CommandError;
use crate::state::AppState;

/// The app window and its own webview (the browser screen).
pub const MAIN: &str = "main";
const PAGE_PREFIX: &str = "browser-page-";
pub const OVERLAY: &str = "browser-overlay";
/// Browser state for the UI and overlay webviews.
pub const STATE_EVENT: &str = "browser://state";
/// Keyboard shortcuts pressed while the page had focus.
pub const SHORTCUT_EVENT: &str = "browser://shortcut";
/// Asks the main window to show a screen (e.g. Downloads).
pub const APP_NAVIGATE_EVENT: &str = "app://navigate";

/// Open tabs at most.
pub const MAX_TABS: usize = 12;
/// Tabs with a live webview at most (memory budget).
const MAX_LIVE_PAGES: usize = 4;
/// Open tabs, saved for the next start.
const KEY_TABS: &str = "browser.tabs";

/// Floating button: this far from the page's bottom right (Windows v2).
const FAB_INSET: f64 = 24.0;
const DEFAULT_FAB: (f64, f64) = (180.0, 52.0);
/// Players often attach their sources after the page has loaded.
const DOM_SCAN_INTERVAL: Duration = Duration::from_secs(3);

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum TabKind {
    /// No page yet: the start page.
    Start,
    Web,
    /// The internal history and favorites tab (miarina://history).
    History,
}

struct Tab {
    id: u32,
    kind: TabKind,
    /// Has a webview (false while asleep or never loaded).
    live: bool,
    url: String,
    title: String,
    loading: bool,
    can_go_back: bool,
    can_go_forward: bool,
    detections: Detections,
    /// Last time it was selected (least recently used goes to sleep).
    used: u64,
}

impl Tab {
    fn new(id: u32, kind: TabKind) -> Self {
        Self {
            id,
            kind,
            live: false,
            url: String::new(),
            title: String::new(),
            loading: false,
            can_go_back: false,
            can_go_forward: false,
            detections: Detections::default(),
            used: 0,
        }
    }

    fn reset_page(&mut self) {
        self.loading = false;
        self.can_go_back = false;
        self.can_go_forward = false;
        self.detections.clear();
    }
}

fn label(id: u32) -> String {
    format!("{PAGE_PREFIX}{id}")
}

#[derive(Default)]
pub struct BrowserState(Mutex<Inner>);

#[derive(Default)]
struct Inner {
    tabs: Vec<Tab>,
    active: u32,
    next_id: u32,
    tick: u64,
    /// Tabs were restored (once per run).
    ready: bool,
    sheet: bool,
    /// Size of the floating button reported by the overlay (logical px).
    fab: Option<(f64, f64)>,
    /// Page area of the browser screen (logical px of the main window), or
    /// `None` while the screen is not shown or something covers it.
    frame: Option<(f64, f64, f64, f64)>,
    /// Last saved tab list (avoids rewriting the same value).
    saved: Option<String>,
}

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct TabSummary {
    id: u32,
    kind: TabKind,
    title: String,
    url: String,
    media: usize,
    loading: bool,
    active: bool,
}

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct BrowserSnapshot {
    url: String,
    title: String,
    loading: bool,
    can_go_back: bool,
    can_go_forward: bool,
    start_page: bool,
    sheet: bool,
    media: Vec<DetectedMedia>,
    /// The page plays a stream (MSE): only the page URL can be analyzed.
    stream_player: bool,
    kind: TabKind,
    tabs: Vec<TabSummary>,
}

#[derive(Serialize, Deserialize)]
struct SavedTab {
    kind: TabKind,
    url: String,
    title: String,
}

#[derive(Serialize, Deserialize)]
struct SavedTabs {
    tabs: Vec<SavedTab>,
    active: usize,
}

impl Inner {
    fn active(&self) -> Option<&Tab> {
        self.tabs.iter().find(|t| t.id == self.active)
    }

    fn tab_mut(&mut self, id: u32) -> Option<&mut Tab> {
        self.tabs.iter_mut().find(|t| t.id == id)
    }

    fn add(&mut self, kind: TabKind) -> u32 {
        self.next_id += 1;
        let id = self.next_id;
        self.tabs.push(Tab::new(id, kind));
        id
    }

    fn snapshot(&self) -> BrowserSnapshot {
        let empty = Tab::new(0, TabKind::Start);
        let tab = self.active().unwrap_or(&empty);
        BrowserSnapshot {
            url: tab.url.clone(),
            title: tab.title.clone(),
            loading: tab.loading,
            can_go_back: tab.can_go_back,
            can_go_forward: tab.can_go_forward,
            start_page: tab.kind != TabKind::Web,
            sheet: self.sheet,
            media: tab.detections.items().to_vec(),
            stream_player: tab.detections.stream_player,
            kind: tab.kind,
            tabs: self
                .tabs
                .iter()
                .map(|t| TabSummary {
                    id: t.id,
                    kind: t.kind,
                    title: t.title.clone(),
                    url: t.url.clone(),
                    media: t.detections.items().len(),
                    loading: t.loading,
                    active: t.id == self.active,
                })
                .collect(),
        }
    }

    fn saved(&self) -> SavedTabs {
        SavedTabs {
            tabs: self
                .tabs
                .iter()
                .map(|t| SavedTab {
                    kind: t.kind,
                    url: if t.kind == TabKind::Web {
                        t.url.clone()
                    } else {
                        String::new()
                    },
                    title: t.title.chars().take(300).collect(),
                })
                .collect(),
            active: self
                .tabs
                .iter()
                .position(|t| t.id == self.active)
                .unwrap_or(0),
        }
    }
}

fn update<R>(app: &AppHandle, f: impl FnOnce(&mut Inner) -> R) -> R {
    let state = app.state::<BrowserState>();
    let mut inner = state.0.lock().unwrap_or_else(|e| e.into_inner());
    f(&mut inner)
}

/// Sends the state to the trusted webviews and re-lays out the window.
fn publish(app: &AppHandle) {
    let snapshot = update(app, |s| s.snapshot());
    for target in [MAIN, OVERLAY] {
        let _ = app.emit_to(target, STATE_EVENT, snapshot.clone());
    }
    layout(app);
}

/// Saves the open tabs when they changed (restored at the next start).
fn persist(app: &AppHandle) {
    let changed = update(app, |s| {
        let saved = s.saved();
        let json = serde_json::to_string(&saved).ok()?;
        if s.saved.as_deref() == Some(json.as_str()) {
            return None;
        }
        s.saved = Some(json);
        Some(saved)
    });
    if let Some(saved) = changed {
        let _ = app
            .state::<AppState>()
            .storage()
            .set_setting(KEY_TABS, &saved);
    }
}

/// Shows the selected tab's page over the browser screen's page area and
/// hides every other one.
fn layout(app: &AppHandle) {
    let (pages, shown, sheet, fab, has_media, frame) = update(app, |s| {
        let pages: Vec<u32> = s.tabs.iter().filter(|t| t.live).map(|t| t.id).collect();
        let shown = s
            .active()
            .filter(|t| t.kind == TabKind::Web && t.live)
            .map(|t| (t.id, !t.detections.is_empty()));
        (
            pages,
            shown,
            s.sheet,
            s.fab.unwrap_or(DEFAULT_FAB),
            shown.is_some_and(|(_, media)| media),
            s.frame,
        )
    });
    let place = |label: &str, x: f64, y: f64, width: f64, height: f64, visible: bool| {
        let Some(view) = app.get_webview(label) else {
            return;
        };
        if visible {
            let _ = view.set_position(LogicalPosition::new(x, y));
            let _ = view.set_size(LogicalSize::new(width.max(1.0), height.max(1.0)));
            let _ = view.show();
        } else {
            let _ = view.hide();
        }
    };
    let visible = frame.zip(shown.map(|(id, _)| id));
    for id in pages {
        if visible.is_none_or(|(_, shown)| shown != id) {
            place(&label(id), 0.0, 0.0, 0.0, 0.0, false);
        }
    }
    let Some(((x, y, w, h), id)) = visible else {
        place(OVERLAY, 0.0, 0.0, 0.0, 0.0, false);
        return;
    };
    place(&label(id), x, y, w, h, true);
    if sheet {
        place(OVERLAY, x, y, w, h, true);
    } else {
        // Sized to the button itself: the transparent area would otherwise
        // swallow clicks meant for the page (spike finding).
        let (fw, fh) = fab;
        let fx = (x + w - fw - FAB_INSET).max(x);
        let fy = (y + h - fh - FAB_INSET).max(y);
        place(OVERLAY, fx, fy, fw, fh, has_media);
    }
}

fn is_web(url: &Url) -> bool {
    matches!(url.scheme(), "http" | "https")
}

fn browser_failed(e: impl std::fmt::Display) -> CommandError {
    CommandError::new("browser_failed", e.to_string())
}

/// The selected tab's page webview.
fn page(app: &AppHandle) -> Result<tauri::Webview, CommandError> {
    let id = update(app, |s| s.active().filter(|t| t.live).map(|t| t.id));
    id.and_then(|id| app.get_webview(&label(id)))
        .ok_or_else(|| CommandError::new("browser_closed", "The browser is not open"))
}

/// Creates the webview of a tab (asleep or new), within the memory budget.
fn wake(app: &AppHandle, id: u32) -> Result<tauri::Webview, CommandError> {
    if let Some(view) = app.get_webview(&label(id)) {
        return Ok(view);
    }
    let window = app
        .get_window(MAIN)
        .ok_or_else(|| browser_failed("no main window"))?;
    let popup_app = app.clone();
    let view = window
        .add_child(
            WebviewBuilder::new(
                label(id),
                WebviewUrl::External("about:blank".parse().expect("about:blank")),
            )
            .on_navigation(|url| is_web(url) || url.as_str() == "about:blank")
            // Popups open in a new tab (web pages only); with every tab
            // already open, in the opener's tab rather than nowhere.
            .on_new_window(move |url, _| {
                if is_web(&url) {
                    let app = popup_app.clone();
                    tauri::async_runtime::spawn(async move {
                        if let Err(e) = open_tab(&app, TabKind::Web, Some(url.clone()))
                            && e.code == "too_many_tabs"
                        {
                            let _ = navigate_tab(&app, id, url);
                        }
                    });
                }
                NewWindowResponse::Deny
            })
            // The app's engine owns downloads: the WebView never writes files.
            .on_download(|_, _| false),
            LogicalPosition::new(0.0, 0.0),
            LogicalSize::new(1.0, 1.0),
        )
        .map_err(browser_failed)?;
    let _ = view.hide();
    #[cfg(windows)]
    hooks::install(&view, app.clone(), id).map_err(browser_failed)?;
    update(app, |s| {
        if let Some(tab) = s.tab_mut(id) {
            tab.live = true;
        }
    });
    sleep_extra(app);
    Ok(view)
}

/// Puts the least recently used background tabs to sleep beyond the budget.
fn sleep_extra(app: &AppHandle) {
    let asleep = update(app, |s| {
        let mut live: Vec<(u64, u32)> = s
            .tabs
            .iter()
            .filter(|t| t.live && t.id != s.active)
            .map(|t| (t.used, t.id))
            .collect();
        let budget = MAX_LIVE_PAGES.saturating_sub(1);
        if live.len() <= budget {
            return Vec::new();
        }
        live.sort_unstable();
        let extra: Vec<u32> = live[..live.len() - budget]
            .iter()
            .map(|(_, id)| *id)
            .collect();
        for id in &extra {
            if let Some(tab) = s.tab_mut(*id) {
                tab.live = false;
                tab.reset_page();
            }
        }
        extra
    });
    for id in asleep {
        if let Some(view) = app.get_webview(&label(id)) {
            let _ = view.close();
        }
    }
}

/// Loads `url` in a tab (which becomes a web tab).
fn navigate_tab(app: &AppHandle, id: u32, url: Url) -> Result<(), CommandError> {
    let view = wake(app, id)?;
    update(app, |s| {
        s.sheet = false;
        if let Some(tab) = s.tab_mut(id) {
            tab.kind = TabKind::Web;
            tab.url = url.to_string();
            tab.title.clear();
        }
    });
    publish(app);
    persist(app);
    view.navigate(url)
        .map_err(|e| CommandError::new("navigation_failed", e.to_string()))
}

/// Selects a tab; a web tab that was asleep reloads its address.
fn select(app: &AppHandle, id: u32) -> Result<(), CommandError> {
    let wake_url = update(app, |s| {
        s.tick += 1;
        let tick = s.tick;
        let tab = s.tab_mut(id)?;
        tab.used = tick;
        let asleep = (tab.kind == TabKind::Web && !tab.live).then(|| tab.url.clone());
        s.active = id;
        s.sheet = false;
        Some(asleep)
    })
    .ok_or_else(|| CommandError::new("invalid_tab", "This tab is closed"))?;
    if let Some(url) = wake_url {
        match Url::parse(&url).ok().filter(is_web) {
            Some(url) => navigate_tab(app, id, url)?,
            None => update(app, |s| {
                if let Some(tab) = s.tab_mut(id) {
                    tab.kind = TabKind::Start;
                }
            }),
        }
    }
    publish(app);
    persist(app);
    Ok(())
}

/// Opens a tab (selected) and returns its id.
fn open_tab(app: &AppHandle, kind: TabKind, url: Option<Url>) -> Result<u32, CommandError> {
    let id = update(app, |s| {
        (s.tabs.len() < MAX_TABS).then(|| s.add(if url.is_some() { TabKind::Web } else { kind }))
    })
    .ok_or_else(|| {
        CommandError::new(
            "too_many_tabs",
            format!("At most {MAX_TABS} tabs can be open"),
        )
    })?;
    select(app, id)?;
    if let Some(url) = url {
        navigate_tab(app, id, url)?;
    }
    Ok(id)
}

fn close_tab(app: &AppHandle, id: u32) -> Result<(), CommandError> {
    let next = update(app, |s| {
        let at = s.tabs.iter().position(|t| t.id == id)?;
        s.tabs.remove(at);
        if s.tabs.is_empty() {
            return Some(s.add(TabKind::Start));
        }
        if s.active != id {
            return Some(s.active);
        }
        // The tab on the right, else the one on the left.
        Some(s.tabs[at.min(s.tabs.len() - 1)].id)
    })
    .ok_or_else(|| CommandError::new("invalid_tab", "This tab is closed"))?;
    if let Some(view) = app.get_webview(&label(id)) {
        let _ = view.close();
    }
    select(app, next)
}

/// Restores the tabs of the last session and creates the overlay, once.
fn ensure_ready(app: &AppHandle) -> Result<(), CommandError> {
    // Commands run concurrently (placing the page and opening a search
    // arrive together): only one of them prepares the browser.
    static PREPARING: Mutex<()> = Mutex::new(());
    let _preparing = PREPARING.lock().unwrap_or_else(|e| e.into_inner());
    if update(app, |s| s.ready) {
        return Ok(());
    }
    let window = app
        .get_window(MAIN)
        .ok_or_else(|| browser_failed("no main window"))?;
    let overlay = window
        .add_child(
            WebviewBuilder::new(OVERLAY, WebviewUrl::App("browser-overlay.html".into()))
                .transparent(true),
            LogicalPosition::new(0.0, 0.0),
            LogicalSize::new(DEFAULT_FAB.0, DEFAULT_FAB.1),
        )
        .map_err(browser_failed)?;
    let _ = overlay.hide();

    let saved = app
        .state::<AppState>()
        .storage()
        .setting::<SavedTabs>(KEY_TABS)
        .ok()
        .flatten();
    let active = update(app, |s| {
        s.ready = true;
        let mut active = None;
        if let Some(saved) = &saved {
            for (i, tab) in saved.tabs.iter().take(MAX_TABS).enumerate() {
                let web = Url::parse(&tab.url).ok().filter(is_web);
                let kind = match (tab.kind, &web) {
                    (TabKind::Web, None) => TabKind::Start,
                    (kind, _) => kind,
                };
                let id = s.add(kind);
                if let Some(t) = s.tab_mut(id)
                    && let Some(url) = web.filter(|_| kind == TabKind::Web)
                {
                    t.url = url.to_string();
                    t.title = tab.title.chars().take(300).collect();
                }
                if i == saved.active {
                    active = Some(id);
                }
            }
        }
        if s.tabs.is_empty() {
            active = Some(s.add(TabKind::Start));
        }
        active.unwrap_or(s.tabs[0].id)
    });
    select(app, active)?;

    #[cfg(windows)]
    {
        let handle = app.clone();
        tauri::async_runtime::spawn(async move {
            let mut tick = tokio::time::interval(DOM_SCAN_INTERVAL);
            loop {
                tick.tick().await;
                if handle.get_webview(OVERLAY).is_none() {
                    break;
                }
                let minimized = handle
                    .get_window(MAIN)
                    .is_some_and(|w| w.is_minimized().unwrap_or(false));
                let idle = minimized
                    || update(&handle, |s| {
                        s.frame.is_none() || s.active().is_none_or(|t| t.kind != TabKind::Web)
                    });
                if !idle {
                    hooks::scan_page(&handle);
                }
            }
        });
    }
    Ok(())
}

fn active_id(app: &AppHandle) -> u32 {
    update(app, |s| s.active)
}

/// Selects the next (`1`) or previous (`-1`) tab, wrapping around.
fn cycle(app: &AppHandle, step: isize) -> Result<(), CommandError> {
    let next = update(app, |s| {
        let n = s.tabs.len() as isize;
        let at = s.tabs.iter().position(|t| t.id == s.active)? as isize;
        Some(s.tabs[((at + step).rem_euclid(n)) as usize].id)
    });
    match next {
        Some(id) => select(app, id),
        None => Ok(()),
    }
}

/// Selects the history tab, opening it if needed.
fn show_history(app: &AppHandle) -> Result<(), CommandError> {
    let existing = update(app, |s| {
        s.tabs
            .iter()
            .find(|t| t.kind == TabKind::History)
            .map(|t| t.id)
    });
    match existing {
        Some(id) => select(app, id),
        None => open_tab(app, TabKind::History, None).map(|_| ()),
    }
}

// ---------------------------------------------------------------- commands

/// Shows the browser screen of the main window, optionally on a page.
/// Async: creating webviews waits on the main thread.
#[tauri::command]
pub async fn browser_open(app: AppHandle, url: Option<String>) -> Result<(), CommandError> {
    ensure_ready(&app)?;
    let _ = app.emit_to(MAIN, APP_NAVIGATE_EVENT, "browser");
    if let Some(url) = url {
        navigate_tab(
            &app,
            active_id(&app),
            super::address::resolve_address(&url)?,
        )?;
    }
    Ok(())
}

/// Loads an address (or a search) in the selected tab.
#[tauri::command]
pub async fn browser_navigate(app: AppHandle, address: String) -> Result<String, CommandError> {
    ensure_ready(&app)?;
    let url = super::address::resolve_address(&address)?;
    navigate_tab(&app, active_id(&app), url.clone())?;
    Ok(url.to_string())
}

/// Back, forward, reload, stop, or home (start page).
#[tauri::command]
pub async fn browser_nav(app: AppHandle, action: String) -> Result<(), CommandError> {
    match action.as_str() {
        "home" => {
            let live = update(&app, |s| {
                s.sheet = false;
                let id = s.active;
                let tab = s.tab_mut(id)?;
                tab.kind = TabKind::Start;
                tab.url.clear();
                tab.title.clear();
                tab.reset_page();
                Some(tab.live)
            });
            if live == Some(true)
                && let Ok(page) = page(&app)
            {
                let _ = page.navigate("about:blank".parse().expect("about:blank"));
            }
            publish(&app);
            persist(&app);
            Ok(())
        }
        #[cfg(windows)]
        "back" | "forward" | "reload" | "stop" => hooks::page_action(&app, &action),
        _ => Err(CommandError::new(
            "invalid_action",
            "Unknown browser action",
        )),
    }
}

#[tauri::command]
pub fn browser_state(state: State<'_, BrowserState>) -> BrowserSnapshot {
    state.0.lock().unwrap_or_else(|e| e.into_inner()).snapshot()
}

/// Opens a tab: the start page, the history tab, or an address.
#[tauri::command]
pub async fn browser_tab_new(
    app: AppHandle,
    kind: Option<TabKind>,
    address: Option<String>,
) -> Result<u32, CommandError> {
    ensure_ready(&app)?;
    if kind == Some(TabKind::History) {
        show_history(&app)?;
        return Ok(active_id(&app));
    }
    let url = address
        .map(|a| super::address::resolve_address(&a))
        .transpose()?;
    open_tab(&app, TabKind::Start, url)
}

#[tauri::command]
pub async fn browser_tab_close(app: AppHandle, id: u32) -> Result<(), CommandError> {
    ensure_ready(&app)?;
    close_tab(&app, id)
}

/// Selects a tab by id, or the next / previous one (`step` 1 / -1).
#[tauri::command]
pub async fn browser_tab_select(
    app: AppHandle,
    id: Option<u32>,
    step: Option<i32>,
) -> Result<(), CommandError> {
    ensure_ready(&app)?;
    match (id, step) {
        (Some(id), _) => select(&app, id),
        (None, Some(step)) => cycle(&app, step.signum() as isize),
        (None, None) => Ok(()),
    }
}

/// Opens or closes the format sheet (the overlay then covers the page).
#[tauri::command]
pub async fn browser_sheet(app: AppHandle, open: bool) -> Result<(), CommandError> {
    update(&app, |s| {
        s.sheet = open && s.active().is_some_and(|t| t.kind == TabKind::Web)
    });
    publish(&app);
    let target = if open {
        app.get_webview(OVERLAY)
    } else {
        page(&app).ok()
    };
    if let Some(view) = target {
        let _ = view.set_focus();
    }
    Ok(())
}

/// The overlay reports the floating button's size so the transparent
/// webview covers nothing else.
#[tauri::command]
pub fn browser_fab_size(app: AppHandle, width: f64, height: f64) {
    let valid = |v: f64| v.is_finite() && (1.0..=600.0).contains(&v);
    if valid(width) && valid(height) {
        update(&app, |s| s.fab = Some((width.ceil(), height.ceil())));
        layout(&app);
    }
}

/// Places the page over the browser screen's page area (logical px of the
/// main window), or hides it while the screen is not shown or covered.
/// The floating button is the overlay webview's (`fab` is Android's) and no
/// picture of the page is taken here (`snapshot`).
#[tauri::command]
#[allow(clippy::too_many_arguments)]
pub async fn browser_frame(
    app: AppHandle,
    x: f64,
    y: f64,
    width: f64,
    height: f64,
    visible: bool,
    fab: Option<String>,
    snapshot: bool,
) -> Result<Option<String>, CommandError> {
    let _ = (fab, snapshot);
    if !valid_rect([x, y, width, height]) {
        return Err(CommandError::new("invalid_frame", "Invalid page area"));
    }
    ensure_ready(&app)?;
    let shown = visible && width >= 1.0 && height >= 1.0;
    update(&app, |s| {
        s.frame = shown.then_some((x, y, width, height));
        if !shown {
            s.sheet = false;
        }
    });
    layout(&app);
    Ok(None)
}

/// Brings the main window forward on a screen (e.g. Downloads).
#[tauri::command]
pub fn browser_show_in_app(app: AppHandle, screen: String) -> Result<(), CommandError> {
    if !matches!(screen.as_str(), "downloads" | "library" | "player") {
        return Err(CommandError::new("invalid_action", "Unknown screen"));
    }
    let _ = app.emit_to(MAIN, APP_NAVIGATE_EVENT, screen);
    Ok(())
}

// ------------------------------------------------------------ WebView2 hooks

#[cfg(windows)]
mod hooks {
    use tauri::{AppHandle, Emitter, Manager, Webview};
    use webview2_com::Microsoft::Web::WebView2::Win32::*;
    use webview2_com::{
        AcceleratorKeyPressedEventHandler, CoTaskMemPWSTR, DocumentTitleChangedEventHandler,
        ExecuteScriptCompletedHandler, NavigationCompletedEventHandler,
        NavigationStartingEventHandler, SourceChangedEventHandler,
        WebResourceResponseReceivedEventHandler,
    };
    use windows::Win32::UI::Input::KeyboardAndMouse::{GetKeyState, VK_CONTROL, VK_SHIFT};
    use windows::core::{HSTRING, Interface, PWSTR, w};

    use super::{CommandError, MAIN, SHORTCUT_EVENT, Tab, TabKind, persist, publish, update};
    use crate::state::AppState;

    /// Collects `<video>`/`<audio>` sources. It runs in the page, so its
    /// answer is a hint about the page's own media, filtered in Rust.
    const DOM_SCAN: &str = r#"(() => {
      const out = [];
      for (const el of document.querySelectorAll('video, audio, video source, audio source')) {
        const src = el.currentSrc || el.src;
        if (typeof src === 'string' && src) out.push([el.closest('audio') ? 'audio' : 'video', src.slice(0, 4096)]);
        if (out.length >= 50) break;
      }
      return out;
    })()"#;

    /// `bytes 0-1023/146515` → 146515 (`*` when unknown).
    fn range_total(value: &str) -> Option<u64> {
        value.rsplit('/').next()?.trim().parse().ok()
    }

    unsafe fn take(p: PWSTR) -> String {
        CoTaskMemPWSTR::from(p).to_string()
    }

    /// Changes one tab; nothing happens if it was closed meanwhile.
    fn update_tab<R>(app: &AppHandle, id: u32, f: impl FnOnce(&mut Tab) -> R) -> Option<R> {
        update(app, |s| s.tab_mut(id).map(f))
    }

    fn refresh_history(app: &AppHandle, id: u32, core: &ICoreWebView2) {
        let (mut back, mut forward) = (false.into(), false.into());
        unsafe {
            let _ = core.CanGoBack(&mut back);
            let _ = core.CanGoForward(&mut forward);
        }
        update_tab(app, id, |t| {
            t.can_go_back = back.as_bool();
            t.can_go_forward = forward.as_bool();
        });
    }

    fn is_web_address(url: &str) -> bool {
        url.starts_with("https://") || url.starts_with("http://")
    }

    pub fn page_action(app: &AppHandle, action: &str) -> Result<(), CommandError> {
        let action = action.to_owned();
        super::page(app)?
            .with_webview(move |view| unsafe {
                if let Ok(core) = view.controller().CoreWebView2() {
                    let _ = match action.as_str() {
                        "back" => core.GoBack(),
                        "forward" => core.GoForward(),
                        "stop" => core.Stop(),
                        _ => core.Reload(),
                    };
                }
            })
            .map_err(|e| CommandError::new("navigation_failed", e.to_string()))
    }

    /// Asks the selected tab's page for its `<video>`/`<audio>` sources.
    pub fn scan_page(app: &AppHandle) {
        let Ok(page) = super::page(app) else {
            return;
        };
        let id = super::active_id(app);
        let app = app.clone();
        let _ = page.with_webview(move |view| unsafe {
            let Ok(core) = view.controller().CoreWebView2() else {
                return;
            };
            let handler = ExecuteScriptCompletedHandler::create(Box::new(move |result, json| {
                result?;
                let Ok(items) = serde_json::from_str::<Vec<(String, String)>>(&json) else {
                    return Ok(());
                };
                let changed = update_tab(&app, id, |t| {
                    items.iter().take(50).fold(false, |acc, (tag, src)| {
                        t.detections.add_element(tag, src) | acc
                    })
                });
                if changed == Some(true) {
                    publish(&app);
                }
                Ok(())
            }));
            let _ = core.ExecuteScript(&HSTRING::from(DOM_SCAN), &handler);
        });
    }

    fn shortcut(app: &AppHandle, name: &'static str) {
        let app2 = app.clone();
        let run = move |f: fn(&AppHandle) -> Result<(), CommandError>| {
            tauri::async_runtime::spawn(async move {
                let _ = f(&app2);
            });
        };
        match name {
            "Ctrl+L" | "Ctrl+T" => {
                if name == "Ctrl+T" {
                    run(|app| super::open_tab(app, TabKind::Start, None).map(|_| ()));
                }
                if let Some(ui) = app.get_webview(MAIN) {
                    let _ = ui.set_focus();
                }
            }
            "Ctrl+W" => run(|app| super::close_tab(app, super::active_id(app))),
            "Ctrl+Tab" => run(|app| super::cycle(app, 1)),
            "Ctrl+Shift+Tab" => run(|app| super::cycle(app, -1)),
            "Ctrl+H" => run(super::show_history),
            "Ctrl+Shift+S" => {
                let app = app.clone();
                tauri::async_runtime::spawn(async move {
                    let _ = super::browser_sheet(app, true).await;
                });
            }
            "F5" => {
                let _ = page_action(app, "reload");
            }
            _ => {}
        }
        let _ = app.emit_to(MAIN, SHORTCUT_EVENT, name);
    }

    pub fn install(page: &Webview, app: AppHandle, id: u32) -> tauri::Result<()> {
        page.with_webview(move |view| unsafe {
            let controller = view.controller();
            let Ok(core) = controller.CoreWebView2() else {
                return;
            };
            let mut token = 0i64;

            // Network: content type, status and length of every response.
            if let Ok(core2) = core.cast::<ICoreWebView2_2>() {
                let app = app.clone();
                let handler =
                    WebResourceResponseReceivedEventHandler::create(Box::new(move |_, args| {
                        let Some(args) = args else { return Ok(()) };
                        let request = args.Request()?;
                        let mut uri = PWSTR::null();
                        request.Uri(&mut uri)?;
                        let uri = take(uri);
                        let fetch_dest = {
                            let mut value = PWSTR::null();
                            request
                                .Headers()?
                                .GetHeader(w!("Sec-Fetch-Dest"), &mut value)
                                .ok()
                                .map(|()| take(value))
                        };
                        let response = args.Response()?;
                        let mut status = 0;
                        response.StatusCode(&mut status)?;
                        let headers = response.Headers()?;
                        let header = |name: windows::core::PCWSTR| {
                            let mut value = PWSTR::null();
                            headers
                                .GetHeader(name, &mut value)
                                .ok()
                                .map(|()| take(value))
                        };
                        let content_type = header(w!("Content-Type")).unwrap_or_default();
                        let status = u16::try_from(status).unwrap_or(0);
                        // Whole resource size: a 206 carries it in Content-Range.
                        let total_size = if status == 206 {
                            header(w!("Content-Range")).and_then(|v| range_total(&v))
                        } else {
                            header(w!("Content-Length")).and_then(|v| v.trim().parse().ok())
                        };
                        let added = update_tab(&app, id, |t| {
                            t.detections.add_response(
                                &uri,
                                &content_type,
                                status,
                                total_size,
                                fetch_dest.as_deref(),
                            )
                        });
                        if added == Some(true) {
                            publish(&app);
                        }
                        Ok(())
                    }));
                let _ = core2.add_WebResourceResponseReceived(&handler, &mut token);
            }

            // A new document: fresh detections, address bar, loading state.
            {
                let app = app.clone();
                let handler = NavigationStartingEventHandler::create(Box::new(move |_, args| {
                    let Some(args) = args else { return Ok(()) };
                    let mut uri = PWSTR::null();
                    args.Uri(&mut uri)?;
                    let uri = take(uri);
                    // History moves too (Back to the start page's blank
                    // document, Forward to a page from it).
                    let start_page = uri == "about:blank";
                    update(&app, |s| {
                        if s.active == id {
                            s.sheet = false;
                        }
                        if let Some(t) = s.tab_mut(id) {
                            t.kind = if start_page {
                                TabKind::Start
                            } else {
                                TabKind::Web
                            };
                            t.url = if start_page { String::new() } else { uri };
                            t.loading = !start_page;
                            t.title.clear();
                            t.detections.clear();
                        }
                    });
                    publish(&app);
                    Ok(())
                }));
                let _ = core.add_NavigationStarting(&handler, &mut token);
            }
            {
                let app = app.clone();
                let handler =
                    NavigationCompletedEventHandler::create(Box::new(move |sender, args| {
                        let mut success = false.into();
                        if let Some(args) = args {
                            let _ = args.IsSuccess(&mut success);
                        }
                        let page = update_tab(&app, id, |t| {
                            t.loading = false;
                            (t.url.clone(), t.title.clone())
                        });
                        if let Some(core) = sender {
                            refresh_history(&app, id, &core);
                        }
                        // Local history (NAV-03): pages actually shown.
                        if let Some((url, title)) = page
                            && success.as_bool()
                            && is_web_address(&url)
                        {
                            let _ = app.state::<AppState>().storage().note_visit(&url, &title);
                        }
                        publish(&app);
                        persist(&app);
                        if super::active_id(&app) == id {
                            scan_page(&app);
                        }
                        Ok(())
                    }));
                let _ = core.add_NavigationCompleted(&handler, &mut token);
            }
            // Same-document navigations (single-page sites change the video
            // without loading a new document).
            {
                let app = app.clone();
                let handler = SourceChangedEventHandler::create(Box::new(move |sender, args| {
                    let Some(core) = sender else { return Ok(()) };
                    let mut uri = PWSTR::null();
                    core.Source(&mut uri)?;
                    let uri = take(uri);
                    let mut new_document = false.into();
                    if let Some(args) = args {
                        let _ = args.IsNewDocument(&mut new_document);
                    }
                    let moved = update_tab(&app, id, |t| {
                        let moved = t.url != uri && uri != "about:blank";
                        if moved {
                            t.url = uri.clone();
                            if !new_document.as_bool() {
                                t.detections.clear();
                            }
                        }
                        moved
                    });
                    refresh_history(&app, id, &core);
                    if moved == Some(true) {
                        if !new_document.as_bool() && is_web_address(&uri) {
                            let _ = app.state::<AppState>().storage().note_visit(&uri, "");
                        }
                        publish(&app);
                        persist(&app);
                    }
                    Ok(())
                }));
                let _ = core.add_SourceChanged(&handler, &mut token);
            }
            {
                let app = app.clone();
                let handler =
                    DocumentTitleChangedEventHandler::create(Box::new(move |sender, _| {
                        let Some(core) = sender else { return Ok(()) };
                        let mut title = PWSTR::null();
                        core.DocumentTitle(&mut title)?;
                        let title: String = take(title).chars().take(300).collect();
                        let url = update_tab(&app, id, |t| {
                            t.title = title.clone();
                            t.url.clone()
                        });
                        if let Some(url) = url.filter(|u| is_web_address(u)) {
                            let _ = app
                                .state::<AppState>()
                                .storage()
                                .set_visit_title(&url, &title);
                        }
                        publish(&app);
                        persist(&app);
                        Ok(())
                    }));
                let _ = core.add_DocumentTitleChanged(&handler, &mut token);
            }

            // App shortcuts keep working while the page has keyboard focus.
            {
                let app = app.clone();
                let handler =
                    AcceleratorKeyPressedEventHandler::create(Box::new(move |_, args| {
                        let Some(args) = args else { return Ok(()) };
                        let mut kind = COREWEBVIEW2_KEY_EVENT_KIND::default();
                        args.KeyEventKind(&mut kind)?;
                        if kind != COREWEBVIEW2_KEY_EVENT_KIND_KEY_DOWN {
                            return Ok(());
                        }
                        let mut key = 0u32;
                        args.VirtualKey(&mut key)?;
                        let ctrl = GetKeyState(i32::from(VK_CONTROL.0)) < 0;
                        let shift = GetKeyState(i32::from(VK_SHIFT.0)) < 0;
                        let name = match (ctrl, shift, key) {
                            (true, false, 0x4C) => "Ctrl+L",
                            (true, true, 0x53) => "Ctrl+Shift+S",
                            (true, false, 0x54) => "Ctrl+T",
                            (true, false, 0x57) => "Ctrl+W",
                            (true, false, 0x48) => "Ctrl+H",
                            (true, false, 0x09) => "Ctrl+Tab",
                            (true, true, 0x09) => "Ctrl+Shift+Tab",
                            (false, _, 0x74) => "F5",
                            _ => return Ok(()),
                        };
                        args.SetHandled(true)?;
                        shortcut(&app, name);
                        Ok(())
                    }));
                let _ = controller.add_AcceleratorKeyPressed(&handler, &mut token);
            }
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn saved_tabs_keep_web_addresses_only() {
        let mut s = Inner::default();
        let web = s.add(TabKind::Web);
        s.tab_mut(web).unwrap().url = "https://archive.org/details/x".into();
        let history = s.add(TabKind::History);
        s.tab_mut(history).unwrap().url = "ignored".into();
        s.active = history;
        let saved = s.saved();
        assert_eq!(saved.active, 1);
        assert_eq!(saved.tabs[0].url, "https://archive.org/details/x");
        assert_eq!(saved.tabs[1].url, "");
        assert_eq!(saved.tabs[1].kind, TabKind::History);
    }

    #[test]
    fn the_snapshot_describes_the_selected_tab_and_lists_all() {
        let mut s = Inner::default();
        let a = s.add(TabKind::Web);
        let b = s.add(TabKind::History);
        s.tab_mut(a).unwrap().title = "Commons".into();
        s.active = b;
        let snap = s.snapshot();
        assert!(snap.start_page, "no page shown for the history tab");
        assert_eq!(snap.kind, TabKind::History);
        assert_eq!(snap.tabs.len(), 2);
        assert!(snap.tabs[1].active && !snap.tabs[0].active);
        assert_eq!(snap.tabs[0].title, "Commons");
    }
}
