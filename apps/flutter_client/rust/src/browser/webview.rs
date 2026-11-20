//! WebView2 pages of the browser (Windows), behind `api::browser`. The tab
//! rules live in `state.rs`; this file creates, places and listens to the
//! pages, as the Tauri app's `browser/desktop.rs` does. The state lock is
//! never held while WebView2 is called: it may run its callbacks (which
//! take the lock) before returning.

use std::path::PathBuf;
use std::sync::{Arc, LazyLock, Mutex, MutexGuard};

use anyhow::{Result, anyhow};
use storage::Storage;

use super::address::{AddressError, is_web, resolve_address};
use super::favorites::{Favorite, KEY_FAVORITES, checked, toggle};
use super::state::{Inner, KEY_TABS, MAX_TABS, SavedTabs, TabKind};
use crate::api::browser::{BrowserEvent, BrowserFavorite, BrowserSnapshot, BrowserVisit};
use crate::frb_generated::StreamSink;

static STATE: LazyLock<Mutex<Inner>> = LazyLock::new(Default::default);
static SINK: Mutex<Option<StreamSink<BrowserEvent>>> = Mutex::new(None);
static STORAGE: Mutex<Option<Arc<Mutex<Storage>>>> = Mutex::new(None);
static PROFILE: Mutex<Option<PathBuf>> = Mutex::new(None);

fn lock<T>(m: &Mutex<T>) -> MutexGuard<'_, T> {
    m.lock().unwrap_or_else(|p| p.into_inner())
}

fn update<R>(f: impl FnOnce(&mut Inner) -> R) -> R {
    f(&mut lock(&STATE))
}

fn storage() -> Option<Arc<Mutex<Storage>>> {
    lock(&STORAGE).clone()
}

pub fn set_sink(sink: StreamSink<BrowserEvent>) {
    *lock(&SINK) = Some(sink);
}

fn emit(event: BrowserEvent) {
    if let Some(sink) = lock(&SINK).as_ref() {
        let _ = sink.add(event);
    }
}

pub fn snapshot() -> BrowserSnapshot {
    update(|s| s.snapshot())
}

fn publish() {
    emit(BrowserEvent {
        snapshot: Some(snapshot()),
        shortcut: None,
        open_tab: None,
        download: None,
    });
}

fn signal(shortcut: Option<String>, open_tab: Option<String>, download: Option<String>) {
    emit(BrowserEvent {
        snapshot: None,
        shortcut,
        open_tab,
        download,
    });
}

/// WebView2 could not start (runtime missing): the screen says so.
fn browser_failed() {
    signal(Some("unavailable".to_owned()), None, None);
}

/// Saves the open tabs when they changed.
fn persist() {
    let saved = update(|s| {
        let saved = s.saved();
        let json = serde_json::to_string(&saved).ok();
        if json.is_some() && json != s.saved {
            s.saved = json;
            Some(saved)
        } else {
            None
        }
    });
    if let (Some(saved), Some(db)) = (saved, storage()) {
        let _ = lock(&db).set_setting(KEY_TABS, &saved);
    }
}

fn note_visit(url: &str, title: &str) {
    if let Some(db) = storage() {
        let _ = lock(&db).note_visit(url, title);
    }
}

fn set_visit_title(url: &str, title: &str) {
    if let Some(db) = storage() {
        let _ = lock(&db).set_visit_title(url, title);
    }
}

/// Restores the tabs of the last run; pages load when shown.
pub fn init(data_dir: &str) -> Result<bool> {
    let first = lock(&STORAGE).is_none();
    if first {
        let shared = crate::api::indexer::shared()?;
        let saved: Option<SavedTabs> = lock(&shared.storage).setting(KEY_TABS).ok().flatten();
        update(|s| s.restore(saved));
        *lock(&STORAGE) = Some(shared.storage);
        *lock(&PROFILE) = Some(PathBuf::from(data_dir).join("browser"));
    }
    Ok(platform::on_window_thread())
}

pub fn show(frame: (i32, i32, i32, i32)) -> Result<()> {
    let (_, _, w, h) = frame;
    if w <= 0 || h <= 0 {
        hide();
        return Ok(());
    }
    update(|s| s.frame = Some(frame));
    let active = update(|s| s.active().map(|t| (t.id, t.kind)));
    if let Some((id, TabKind::Web)) = active {
        platform::wake(id)?;
    }
    platform::layout();
    Ok(())
}

pub fn hide() {
    update(|s| s.frame = None);
    platform::layout();
}

pub fn navigate(address: &str) -> Result<String> {
    let url = resolve_address(address).map_err(|e| {
        anyhow!(match e {
            AddressError::NotAWebAddress => "not_a_web_address",
            AddressError::Unsupported => "unsupported_address",
        })
    })?;
    let url = url.to_string();
    let id = update(|s| {
        let id = s.active;
        if let Some(t) = s.tab_mut(id) {
            t.kind = TabKind::Web;
            t.url = url.clone();
            t.title.clear();
            t.loading = true;
            t.detections.clear();
        }
        id
    });
    if !platform::wake(id)? {
        platform::navigate(id, &url)?;
    }
    platform::layout();
    publish();
    persist();
    Ok(url)
}

pub fn nav(action: &str) -> Result<()> {
    let id = update(|s| s.active);
    if action == "home" {
        // Back to the start page: the page is closed (memory).
        platform::close(id);
        update(|s| {
            if let Some(t) = s.tab_mut(id) {
                t.kind = TabKind::Start;
                t.url.clear();
                t.title.clear();
                t.live = false;
                t.reset_page();
            }
        });
        platform::layout();
        publish();
        persist();
        return Ok(());
    }
    platform::page_action(id, action);
    Ok(())
}

pub fn tab_new(url: Option<&str>) -> Result<()> {
    if update(|s| s.tabs.len()) >= MAX_TABS {
        return Err(anyhow!("too_many_tabs"));
    }
    update(|s| {
        let id = s.add(TabKind::Start);
        s.select(id);
    });
    if let Some(url) = url {
        navigate(url)?;
    } else {
        platform::layout();
        publish();
        persist();
    }
    Ok(())
}

pub fn tab_close(id: u32) -> Result<()> {
    platform::close(id);
    update(|s| s.remove(id));
    tab_select(update(|s| s.active))
}

pub fn tab_select(id: u32) -> Result<()> {
    let target = update(|s| {
        s.select(id);
        s.active().map(|t| (t.id, t.kind, s.frame.is_some()))
    });
    if let Some((id, TabKind::Web, true)) = target {
        platform::wake(id)?;
    }
    platform::layout();
    publish();
    persist();
    Ok(())
}

pub fn cycle(step: isize) -> Result<()> {
    match update(|s| s.neighbour(step)) {
        Some(id) => tab_select(id),
        None => Ok(()),
    }
}

/// Selects the history tab, opened if needed (one at most).
pub fn tab_history() -> Result<()> {
    let existing = update(|s| {
        s.tabs
            .iter()
            .find(|t| t.kind == TabKind::History)
            .map(|t| t.id)
    });
    if let Some(id) = existing {
        return tab_select(id);
    }
    if update(|s| s.tabs.len()) >= MAX_TABS {
        return Err(anyhow!("too_many_tabs"));
    }
    update(|s| {
        let id = s.add(TabKind::History);
        s.select(id);
    });
    platform::layout();
    publish();
    persist();
    Ok(())
}

fn db() -> Result<Arc<Mutex<Storage>>> {
    storage().ok_or_else(|| anyhow!("browser not initialized"))
}

fn favorites_of(db: &Storage) -> Vec<Favorite> {
    db.setting::<Vec<Favorite>>(KEY_FAVORITES)
        .ok()
        .flatten()
        .unwrap_or_default()
}

fn favorite_out(list: Vec<Favorite>) -> Vec<BrowserFavorite> {
    list.into_iter()
        .map(|f| BrowserFavorite {
            url: f.url,
            title: f.title,
        })
        .collect()
}

pub fn favorites() -> Result<Vec<BrowserFavorite>> {
    let db = db()?;
    Ok(favorite_out(favorites_of(&lock(&db))))
}

pub fn favorite_toggle(url: &str, title: &str) -> Result<Vec<BrowserFavorite>> {
    let favorite = checked(url, title).ok_or_else(|| anyhow!("invalid_favorite"))?;
    let db = db()?;
    let db = lock(&db);
    let mut list = favorites_of(&db);
    toggle(&mut list, favorite);
    db.set_setting(KEY_FAVORITES, &list)?;
    Ok(favorite_out(list))
}

/// Longest search accepted.
const QUERY_MAX: usize = 200;

pub fn history(query: &str, limit: u32) -> Result<Vec<BrowserVisit>> {
    let query: String = query.chars().take(QUERY_MAX).collect();
    let db = db()?;
    let visits = lock(&db).visits(&query, limit.min(storage::VISITS_PAGE_MAX))?;
    Ok(visits
        .into_iter()
        .map(|v| BrowserVisit {
            id: v.id,
            url: v.url,
            title: v.title,
            visited_at: v.visited_at,
        })
        .collect())
}

pub fn history_delete(id: i64) -> Result<()> {
    let db = db()?;
    Ok(lock(&db).delete_visit(id)?)
}

pub fn history_clear() -> Result<u32> {
    let db = db()?;
    Ok(lock(&db).clear_visits()? as u32)
}

pub fn scan() {
    let active = update(|s| s.active().map(|t| (t.id, t.kind, t.live)));
    if let Some((id, TabKind::Web, true)) = active {
        platform::scan(id);
    }
}

#[cfg(windows)]
mod platform {
    use std::cell::RefCell;
    use std::collections::HashMap;

    use anyhow::{Result, anyhow};
    use webview2_com::Microsoft::Web::WebView2::Win32::*;
    use webview2_com::{
        AcceleratorKeyPressedEventHandler, CoTaskMemPWSTR,
        CreateCoreWebView2ControllerCompletedHandler,
        CreateCoreWebView2EnvironmentCompletedHandler, DocumentTitleChangedEventHandler,
        DownloadStartingEventHandler, ExecuteScriptCompletedHandler,
        NavigationCompletedEventHandler, NavigationStartingEventHandler,
        NewWindowRequestedEventHandler, SourceChangedEventHandler,
        WebResourceResponseReceivedEventHandler,
    };
    use windows::Win32::Foundation::{HWND, LPARAM, RECT};
    use windows::Win32::System::Threading::{GetCurrentProcessId, GetCurrentThreadId};
    use windows::Win32::UI::Input::KeyboardAndMouse::{GetKeyState, VK_CONTROL, VK_SHIFT};
    use windows::Win32::UI::WindowsAndMessaging::{
        EnumWindows, GetClassNameW, GetWindowThreadProcessId,
    };
    use windows::core::{BOOL, HSTRING, Interface, PCWSTR, PWSTR, w};

    use super::super::state::{Tab, TabKind};
    use super::{
        PROFILE, is_web, lock, note_visit, persist, publish, set_visit_title, signal, update,
    };

    thread_local! {
        // WebView2 objects are apartment-bound: kept on the window's thread.
        static ENV: RefCell<Option<ICoreWebView2Environment>> = const { RefCell::new(None) };
        static PAGES: RefCell<HashMap<u32, ICoreWebView2Controller>> =
            RefCell::new(HashMap::new());
    }

    const FLUTTER_WINDOW_CLASS: &str = "FLUTTER_RUNNER_WIN32_WINDOW";

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

    fn flutter_window() -> Option<HWND> {
        unsafe extern "system" fn visit(hwnd: HWND, found: LPARAM) -> BOOL {
            let mut pid = 0;
            unsafe { GetWindowThreadProcessId(hwnd, Some(&mut pid)) };
            if pid != unsafe { GetCurrentProcessId() } {
                return true.into();
            }
            let mut class = [0u16; 64];
            let n = unsafe { GetClassNameW(hwnd, &mut class) } as usize;
            if String::from_utf16_lossy(&class[..n]) == FLUTTER_WINDOW_CLASS {
                unsafe { *(found.0 as *mut Option<HWND>) = Some(hwnd) };
                return false.into();
            }
            true.into()
        }
        let mut found: Option<HWND> = None;
        let _ = unsafe { EnumWindows(Some(visit), LPARAM(&mut found as *mut _ as isize)) };
        found
    }

    pub fn on_window_thread() -> bool {
        flutter_window()
            .is_some_and(|w| unsafe { GetWindowThreadProcessId(w, None) == GetCurrentThreadId() })
    }

    fn take(p: PWSTR) -> String {
        CoTaskMemPWSTR::from(p).to_string()
    }

    /// `bytes 0-1023/146515` â†’ 146515 (`*` when unknown).
    fn range_total(value: &str) -> Option<u64> {
        value.rsplit('/').next()?.trim().parse().ok()
    }

    fn update_tab<R>(id: u32, f: impl FnOnce(&mut Tab) -> R) -> Option<R> {
        update(|s| s.tab_mut(id).map(f))
    }

    type EnvWaiter = Box<dyn FnOnce(&ICoreWebView2Environment)>;

    thread_local! {
        // Callers waiting for the environment while it is being created.
        static ENV_WAITERS: RefCell<Option<Vec<EnvWaiter>>> = const { RefCell::new(None) };
        // Tabs whose page is being created.
        static PENDING: RefCell<std::collections::HashSet<u32>> =
            RefCell::new(std::collections::HashSet::new());
    }

    /// Runs `then` with the environment, created on first use. Never waits:
    /// creation completes through the window's own message loop (waiting
    /// here, inside a Flutter frame or not, would run Flutter re-entrantly).
    fn with_environment(then: EnvWaiter) -> Result<()> {
        if let Some(env) = ENV.with(|e| e.borrow().clone()) {
            then(&env);
            return Ok(());
        }
        let creating = ENV_WAITERS.with(|w| {
            let mut w = w.borrow_mut();
            let creating = w.is_some();
            w.get_or_insert_with(Vec::new).push(then);
            creating
        });
        if creating {
            return Ok(());
        }
        let profile = lock(&PROFILE)
            .clone()
            .ok_or_else(|| anyhow!("browser not initialized"))?;
        let data_dir = HSTRING::from(profile.as_os_str());
        let handler =
            CreateCoreWebView2EnvironmentCompletedHandler::create(Box::new(move |result, env| {
                let waiters = ENV_WAITERS
                    .with(|w| w.borrow_mut().take())
                    .unwrap_or_default();
                match (result, env) {
                    (Ok(()), Some(env)) => {
                        ENV.with(|e| *e.borrow_mut() = Some(env.clone()));
                        for waiter in waiters {
                            waiter(&env);
                        }
                    }
                    _ => {
                        // No WebView2 runtime: the tabs stay without a page.
                        PENDING.with(|p| p.borrow_mut().clear());
                        super::browser_failed();
                    }
                }
                Ok(())
            }));
        unsafe {
            CreateCoreWebView2EnvironmentWithOptions(PCWSTR::null(), &data_dir, None, &handler)?;
        }
        Ok(())
    }

    fn controller(id: u32) -> Option<ICoreWebView2Controller> {
        PAGES.with(|p| p.borrow().get(&id).cloned())
    }

    fn core(id: u32) -> Option<ICoreWebView2> {
        controller(id).and_then(|c| unsafe { c.CoreWebView2() }.ok())
    }

    /// Gives `id` a page if it has none; true when one is being created
    /// (it then opens the tab's address by itself). Returns at once.
    pub fn wake(id: u32) -> Result<bool> {
        if controller(id).is_some() {
            return Ok(false);
        }
        if !PENDING.with(|p| p.borrow_mut().insert(id)) {
            return Ok(true);
        }
        let parent = flutter_window().ok_or_else(|| anyhow!("window not found"))?;
        with_environment(Box::new(move |env| {
            let handler = CreateCoreWebView2ControllerCompletedHandler::create(Box::new(
                move |result, controller| {
                    let wanted = PENDING.with(|p| p.borrow_mut().remove(&id));
                    let Some(controller) = controller.filter(|_| result.is_ok()) else {
                        return Ok(());
                    };
                    // Closed while being created.
                    if !wanted || update(|s| s.tab_mut(id).is_none()) {
                        let _ = unsafe { controller.Close() };
                        return Ok(());
                    }
                    unsafe { controller.SetIsVisible(false)? };
                    if install(&controller, id).is_err() {
                        let _ = unsafe { controller.Close() };
                        return Ok(());
                    }
                    PAGES.with(|p| p.borrow_mut().insert(id, controller));
                    let url = update(|s| {
                        s.tab_mut(id).map(|t| {
                            t.live = true;
                            t.url.clone()
                        })
                    });
                    if let Some(url) = url.filter(|u| is_web(u)) {
                        let _ = navigate(id, &url);
                    }
                    sleep_extra();
                    layout();
                    publish();
                    Ok(())
                },
            ));
            let created = unsafe { env.CreateCoreWebView2Controller(parent, &handler) };
            if created.is_err() {
                PENDING.with(|p| p.borrow_mut().remove(&id));
            }
        }))?;
        Ok(true)
    }

    pub fn navigate(id: u32, url: &str) -> Result<()> {
        if let Some(core) = core(id) {
            unsafe { core.Navigate(&HSTRING::from(url))? };
        }
        Ok(())
    }

    pub fn close(id: u32) {
        if let Some(c) = PAGES.with(|p| p.borrow_mut().remove(&id)) {
            let _ = unsafe { c.Close() };
        }
    }

    /// Background pages beyond the memory budget are closed; their tab
    /// keeps its address and reloads when selected.
    fn sleep_extra() {
        for id in update(|s| s.to_sleep()) {
            close(id);
            update_tab(id, |t| {
                t.live = false;
                t.reset_page();
            });
        }
    }

    /// Only the selected web page is visible, where the screen left room.
    pub fn layout() {
        let (active, frame, web) = update(|s| {
            (
                s.active,
                s.frame,
                s.active().is_some_and(|t| t.kind == TabKind::Web),
            )
        });
        let pages: Vec<(u32, ICoreWebView2Controller)> =
            PAGES.with(|p| p.borrow().iter().map(|(k, v)| (*k, v.clone())).collect());
        for (id, c) in pages {
            let shown = id == active && web && frame.is_some();
            unsafe {
                if let (true, Some((x, y, w, h))) = (shown, frame) {
                    let _ = c.SetBounds(RECT {
                        left: x,
                        top: y,
                        right: x + w,
                        bottom: y + h,
                    });
                }
                let _ = c.SetIsVisible(shown);
            }
        }
    }

    pub fn page_action(id: u32, action: &str) {
        if let Some(core) = core(id) {
            let _ = unsafe {
                match action {
                    "back" => core.GoBack(),
                    "forward" => core.GoForward(),
                    "stop" => core.Stop(),
                    _ => core.Reload(),
                }
            };
        }
    }

    pub fn scan(id: u32) {
        let Some(core) = core(id) else { return };
        let handler = ExecuteScriptCompletedHandler::create(Box::new(move |result, json| {
            result?;
            let Ok(items) = serde_json::from_str::<Vec<(String, String)>>(&json) else {
                return Ok(());
            };
            let changed = update_tab(id, |t| {
                items.iter().take(50).fold(false, |acc, (tag, src)| {
                    t.detections.add_element(tag, src) | acc
                })
            });
            if changed == Some(true) {
                publish();
            }
            Ok(())
        }));
        let _ = unsafe { core.ExecuteScript(&HSTRING::from(DOM_SCAN), &handler) };
    }

    fn refresh_history(id: u32, core: &ICoreWebView2) {
        let (mut back, mut forward) = (BOOL::from(false), BOOL::from(false));
        unsafe {
            let _ = core.CanGoBack(&mut back);
            let _ = core.CanGoForward(&mut forward);
        }
        update_tab(id, |t| {
            t.can_go_back = back.as_bool();
            t.can_go_forward = forward.as_bool();
        });
    }

    fn install(controller: &ICoreWebView2Controller, id: u32) -> Result<()> {
        let core = unsafe { controller.CoreWebView2()? };
        let mut token = 0i64;
        unsafe {
            // Network: content type, status and length of every response.
            if let Ok(core2) = core.cast::<ICoreWebView2_2>() {
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
                        let header = |name: PCWSTR| {
                            let mut value = PWSTR::null();
                            headers
                                .GetHeader(name, &mut value)
                                .ok()
                                .map(|()| take(value))
                        };
                        let content_type = header(w!("Content-Type")).unwrap_or_default();
                        let status = u16::try_from(status).unwrap_or(0);
                        // Whole resource size: a 206 carries it in Content-Range.
                        let total = if status == 206 {
                            header(w!("Content-Range")).and_then(|v| range_total(&v))
                        } else {
                            header(w!("Content-Length")).and_then(|v| v.trim().parse().ok())
                        };
                        let added = update_tab(id, |t| {
                            t.detections.add_response(
                                &uri,
                                &content_type,
                                status,
                                total,
                                fetch_dest.as_deref(),
                            )
                        });
                        if added == Some(true) {
                            publish();
                        }
                        Ok(())
                    }));
                core2.add_WebResourceResponseReceived(&handler, &mut token)?;
            }

            // A new document: web pages only; fresh detections, address,
            // loading state.
            let handler = NavigationStartingEventHandler::create(Box::new(move |_, args| {
                let Some(args) = args else { return Ok(()) };
                let mut uri = PWSTR::null();
                args.Uri(&mut uri)?;
                let uri = take(uri);
                let blank = uri == "about:blank";
                if !blank && !is_web(&uri) {
                    args.SetCancel(true)?;
                    return Ok(());
                }
                update_tab(id, |t| {
                    t.kind = if blank { TabKind::Start } else { TabKind::Web };
                    t.url = if blank { String::new() } else { uri };
                    t.loading = !blank;
                    t.title.clear();
                    t.detections.clear();
                });
                publish();
                Ok(())
            }));
            core.add_NavigationStarting(&handler, &mut token)?;

            let handler = NavigationCompletedEventHandler::create(Box::new(move |sender, args| {
                let mut success = BOOL::from(false);
                if let Some(args) = args {
                    let _ = args.IsSuccess(&mut success);
                }
                let page = update_tab(id, |t| {
                    t.loading = false;
                    (t.url.clone(), t.title.clone())
                });
                if let Some(core) = sender {
                    refresh_history(id, &core);
                }
                // Local history (NAV-03): pages actually shown.
                if let Some((url, title)) = page
                    && success.as_bool()
                    && is_web(&url)
                {
                    note_visit(&url, &title);
                }
                publish();
                persist();
                if update(|s| s.active) == id {
                    scan(id);
                }
                Ok(())
            }));
            core.add_NavigationCompleted(&handler, &mut token)?;

            // Same-document navigations (single-page sites change the video
            // without loading a new document).
            let handler = SourceChangedEventHandler::create(Box::new(move |sender, args| {
                let Some(core) = sender else { return Ok(()) };
                let mut uri = PWSTR::null();
                core.Source(&mut uri)?;
                let uri = take(uri);
                let mut new_document = BOOL::from(false);
                if let Some(args) = args {
                    let _ = args.IsNewDocument(&mut new_document);
                }
                let moved = update_tab(id, |t| {
                    let moved = t.url != uri && uri != "about:blank";
                    if moved {
                        t.url = uri.clone();
                        if !new_document.as_bool() {
                            t.detections.clear();
                        }
                    }
                    moved
                });
                refresh_history(id, &core);
                if moved == Some(true) {
                    if !new_document.as_bool() && is_web(&uri) {
                        note_visit(&uri, "");
                    }
                    publish();
                    persist();
                }
                Ok(())
            }));
            core.add_SourceChanged(&handler, &mut token)?;

            let handler = DocumentTitleChangedEventHandler::create(Box::new(move |sender, _| {
                let Some(core) = sender else { return Ok(()) };
                let mut title = PWSTR::null();
                core.DocumentTitle(&mut title)?;
                let title: String = take(title).chars().take(300).collect();
                let url = update_tab(id, |t| {
                    t.title = title.clone();
                    t.url.clone()
                });
                if let Some(url) = url.filter(|u| is_web(u)) {
                    set_visit_title(&url, &title);
                }
                publish();
                persist();
                Ok(())
            }));
            core.add_DocumentTitleChanged(&handler, &mut token)?;

            // Popups become tabs (opened by the screen, outside this
            // callback).
            let handler = NewWindowRequestedEventHandler::create(Box::new(move |_, args| {
                let Some(args) = args else { return Ok(()) };
                let mut uri = PWSTR::null();
                args.Uri(&mut uri)?;
                let uri = take(uri);
                args.SetHandled(true)?;
                if is_web(&uri) {
                    signal(None, Some(uri), None);
                }
                Ok(())
            }));
            core.add_NewWindowRequested(&handler, &mut token)?;

            // The app's engine owns downloads: the page never writes files.
            // What it offered is handed to the analysis instead.
            if let Ok(core4) = core.cast::<ICoreWebView2_4>() {
                let handler = DownloadStartingEventHandler::create(Box::new(move |_, args| {
                    let Some(args) = args else { return Ok(()) };
                    args.SetCancel(true)?;
                    let mut uri = PWSTR::null();
                    args.DownloadOperation()?.Uri(&mut uri)?;
                    let uri = take(uri);
                    if is_web(&uri) {
                        signal(None, None, Some(uri));
                    }
                    Ok(())
                }));
                core4.add_DownloadStarting(&handler, &mut token)?;
            }

            // App shortcuts keep working while the page has the keyboard.
            let handler = AcceleratorKeyPressedEventHandler::create(Box::new(move |_, args| {
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
                    (true, false, 0x54) => "Ctrl+T",
                    (true, false, 0x57) => "Ctrl+W",
                    (true, false, 0x48) => "Ctrl+H",
                    (true, false, 0x09) => "Ctrl+Tab",
                    (true, true, 0x09) => "Ctrl+Shift+Tab",
                    (false, _, 0x74) => "F5",
                    _ => return Ok(()),
                };
                args.SetHandled(true)?;
                signal(Some(name.to_owned()), None, None);
                Ok(())
            }));
            controller.add_AcceleratorKeyPressed(&handler, &mut token)?;
        }
        Ok(())
    }
}

#[cfg(not(windows))]
mod platform {
    use anyhow::{Result, bail};

    pub fn on_window_thread() -> bool {
        false
    }
    pub fn wake(_: u32) -> Result<bool> {
        bail!("the built-in browser of this build is the Windows one")
    }
    pub fn navigate(_: u32, _: &str) -> Result<()> {
        Ok(())
    }
    pub fn close(_: u32) {}
    pub fn layout() {}
    pub fn page_action(_: u32, _: &str) {}
    pub fn scan(_: u32) {}
}
