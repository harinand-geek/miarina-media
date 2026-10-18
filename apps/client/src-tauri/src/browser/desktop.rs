//! Built-in browser on Windows (decision 0001), inside the main window like
//! the Android browser (designs M1/M3 adapted, D2 sheet kept): the React
//! browser screen draws the chrome and reports where the page goes
//! (`browser_frame`); two child webviews of the main window sit there:
//! - `browser-page`: the visited site. Untrusted: remote origin, so no
//!   capability applies to it; http(s) only, no popups, no browser-native
//!   downloads;
//! - `browser-overlay`: floating download button and format sheet, drawn
//!   transparently above the page.
//!
//! Detection never depends on the page's cooperation: Rust reads WebView2
//! network events and pulls `<video>`/`<audio>` sources with a script whose
//! answer is filtered by `media_core::detect`.

use std::sync::Mutex;
use std::time::Duration;

use media_core::detect::{DetectedMedia, Detections};
use serde::Serialize;
use tauri::webview::{NewWindowResponse, WebviewBuilder};
use tauri::{AppHandle, Emitter, LogicalPosition, LogicalSize, Manager, State, Url, WebviewUrl};

use super::page_state::valid_rect;
use crate::commands::CommandError;

/// The app window and its own webview (the browser screen).
pub const MAIN: &str = "main";
pub const PAGE: &str = "browser-page";
pub const OVERLAY: &str = "browser-overlay";
/// Browser state for the UI and overlay webviews.
pub const STATE_EVENT: &str = "browser://state";
/// Keyboard shortcuts pressed while the page had focus.
pub const SHORTCUT_EVENT: &str = "browser://shortcut";
/// Asks the main window to show a screen (e.g. Downloads).
pub const APP_NAVIGATE_EVENT: &str = "app://navigate";

/// Floating button: centred, this far above the page bottom (design M1).
const FAB_INSET: f64 = 16.0;
const DEFAULT_FAB: (f64, f64) = (180.0, 52.0);
/// Players often attach their sources after the page has loaded.
const DOM_SCAN_INTERVAL: Duration = Duration::from_secs(3);

#[derive(Default)]
pub struct BrowserState(Mutex<Inner>);

#[derive(Default)]
struct Inner {
    detections: Detections,
    url: String,
    title: String,
    loading: bool,
    can_go_back: bool,
    can_go_forward: bool,
    /// No page yet: the browser screen shows its start page.
    start_page: bool,
    sheet: bool,
    /// Size of the floating button reported by the overlay (logical px).
    fab: Option<(f64, f64)>,
    /// Page area of the browser screen (logical px of the main window), or
    /// `None` while the screen is not shown or something covers it.
    frame: Option<(f64, f64, f64, f64)>,
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
}

impl Inner {
    fn snapshot(&self) -> BrowserSnapshot {
        BrowserSnapshot {
            url: self.url.clone(),
            title: self.title.clone(),
            loading: self.loading,
            can_go_back: self.can_go_back,
            can_go_forward: self.can_go_forward,
            start_page: self.start_page,
            sheet: self.sheet,
            media: self.detections.items().to_vec(),
            stream_player: self.detections.stream_player,
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
    for label in [MAIN, OVERLAY] {
        let _ = app.emit_to(label, STATE_EVENT, snapshot.clone());
    }
    layout(app);
}

/// Positions the page and overlay over the browser screen's page area.
fn layout(app: &AppHandle) {
    let (start_page, sheet, fab, has_media, frame) = update(app, |s| {
        (
            s.start_page,
            s.sheet,
            s.fab.unwrap_or(DEFAULT_FAB),
            !s.detections.is_empty(),
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
    let Some((x, y, w, h)) = frame.filter(|_| !start_page) else {
        place(PAGE, 0.0, 0.0, 0.0, 0.0, false);
        place(OVERLAY, 0.0, 0.0, 0.0, 0.0, false);
        return;
    };
    place(PAGE, x, y, w, h, true);
    if sheet {
        place(OVERLAY, x, y, w, h, true);
    } else {
        // Sized to the button itself: the transparent area would otherwise
        // swallow clicks meant for the page (spike finding).
        let (fw, fh) = fab;
        let fx = x + ((w - fw) / 2.0).max(0.0);
        let fy = (y + h - fh - FAB_INSET).max(y);
        place(OVERLAY, fx, fy, fw, fh, has_media);
    }
}

fn is_web(url: &Url) -> bool {
    matches!(url.scheme(), "http" | "https")
}

fn page(app: &AppHandle) -> Result<tauri::Webview, CommandError> {
    app.get_webview(PAGE)
        .ok_or_else(|| CommandError::new("browser_closed", "The browser is not open"))
}

fn navigate_page(app: &AppHandle, url: Url) -> Result<(), CommandError> {
    ensure_views(app).map_err(|e| CommandError::new("browser_failed", e.to_string()))?;
    update(app, |s| {
        s.start_page = false;
        s.sheet = false;
        s.url = url.to_string();
    });
    publish(app);
    page(app)?
        .navigate(url)
        .map_err(|e| CommandError::new("navigation_failed", e.to_string()))
}

/// Adds the page and overlay webviews to the main window, once.
fn ensure_views(app: &AppHandle) -> tauri::Result<()> {
    // Commands run concurrently (placing the page and opening a search
    // arrive together): only one of them creates the webviews.
    static CREATING: Mutex<()> = Mutex::new(());
    let _creating = CREATING.lock().unwrap_or_else(|e| e.into_inner());
    if app.get_webview(PAGE).is_some() {
        return Ok(());
    }
    let Some(window) = app.get_window(MAIN) else {
        return Ok(());
    };
    update(app, |s| {
        *s = Inner {
            start_page: true,
            ..Inner::default()
        }
    });

    let popup_app = app.clone();
    let page = window.add_child(
        WebviewBuilder::new(
            PAGE,
            WebviewUrl::External("about:blank".parse().expect("about:blank")),
        )
        .on_navigation(|url| is_web(url) || url.as_str() == "about:blank")
        // A single tab for now: popups open in place (only web pages).
        .on_new_window(move |url, _| {
            if is_web(&url) {
                let _ = navigate_page(&popup_app, url);
            }
            NewWindowResponse::Deny
        })
        // The app's engine owns downloads: the WebView never writes files.
        .on_download(|_, _| false),
        LogicalPosition::new(0.0, 0.0),
        LogicalSize::new(1.0, 1.0),
    )?;
    page.hide()?;
    #[cfg(windows)]
    hooks::install(&page, app.clone())?;

    let overlay = window.add_child(
        WebviewBuilder::new(OVERLAY, WebviewUrl::App("browser-overlay.html".into()))
            .transparent(true),
        LogicalPosition::new(0.0, 0.0),
        LogicalSize::new(DEFAULT_FAB.0, DEFAULT_FAB.1),
    )?;
    overlay.hide()?;

    #[cfg(windows)]
    {
        let handle = app.clone();
        tauri::async_runtime::spawn(async move {
            let mut tick = tokio::time::interval(DOM_SCAN_INTERVAL);
            loop {
                tick.tick().await;
                if handle.get_webview(PAGE).is_none() {
                    break;
                }
                let minimized = handle
                    .get_window(MAIN)
                    .is_some_and(|w| w.is_minimized().unwrap_or(false));
                let idle = minimized || update(&handle, |s| s.start_page || s.frame.is_none());
                if !idle {
                    hooks::scan_page(&handle);
                }
            }
        });
    }
    layout(app);
    Ok(())
}

// ---------------------------------------------------------------- commands

/// Shows the browser screen of the main window, optionally on a page.
/// Async: creating webviews waits on the main thread.
#[tauri::command]
pub async fn browser_open(app: AppHandle, url: Option<String>) -> Result<(), CommandError> {
    ensure_views(&app).map_err(|e| CommandError::new("browser_failed", e.to_string()))?;
    let _ = app.emit_to(MAIN, APP_NAVIGATE_EVENT, "browser");
    if let Some(url) = url {
        navigate_page(&app, super::address::resolve_address(&url)?)?;
    }
    Ok(())
}

#[tauri::command]
pub async fn browser_navigate(app: AppHandle, address: String) -> Result<String, CommandError> {
    let url = super::address::resolve_address(&address)?;
    navigate_page(&app, url.clone())?;
    Ok(url.to_string())
}

/// Back, forward, reload, stop, or home (start page).
#[tauri::command]
pub async fn browser_nav(app: AppHandle, action: String) -> Result<(), CommandError> {
    match action.as_str() {
        "home" => {
            update(&app, |s| {
                s.start_page = true;
                s.sheet = false;
                s.url.clear();
                s.title.clear();
                s.detections.clear();
            });
            if let Ok(page) = page(&app) {
                let _ = page.navigate("about:blank".parse().expect("about:blank"));
            }
            publish(&app);
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

/// Opens or closes the format sheet (the overlay then covers the page).
#[tauri::command]
pub async fn browser_sheet(app: AppHandle, open: bool) -> Result<(), CommandError> {
    update(&app, |s| s.sheet = open && !s.start_page);
    publish(&app);
    let target = if open { OVERLAY } else { PAGE };
    if let Some(view) = app.get_webview(target) {
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
    ensure_views(&app).map_err(|e| CommandError::new("browser_failed", e.to_string()))?;
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

    use super::{CommandError, MAIN, PAGE, SHORTCUT_EVENT, publish, update};

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

    fn refresh_history(app: &AppHandle, core: &ICoreWebView2) {
        let (mut back, mut forward) = (false.into(), false.into());
        unsafe {
            let _ = core.CanGoBack(&mut back);
            let _ = core.CanGoForward(&mut forward);
        }
        update(app, |s| {
            s.can_go_back = back.as_bool();
            s.can_go_forward = forward.as_bool();
        });
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

    pub fn scan_page(app: &AppHandle) {
        let Some(page) = app.get_webview(PAGE) else {
            return;
        };
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
                let changed = update(&app, |s| {
                    items.iter().take(50).fold(false, |acc, (tag, src)| {
                        s.detections.add_element(tag, src) | acc
                    })
                });
                if changed {
                    publish(&app);
                }
                Ok(())
            }));
            let _ = core.ExecuteScript(&HSTRING::from(DOM_SCAN), &handler);
        });
    }

    fn shortcut(app: &AppHandle, name: &'static str) {
        match name {
            "Ctrl+L" => {
                if let Some(ui) = app.get_webview(MAIN) {
                    let _ = ui.set_focus();
                }
            }
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

    pub fn install(page: &Webview, app: AppHandle) -> tauri::Result<()> {
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
                        if update(&app, |s| {
                            s.detections.add_response(
                                &uri,
                                &content_type,
                                status,
                                total_size,
                                fetch_dest.as_deref(),
                            )
                        }) {
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
                        s.start_page = start_page;
                        s.url = if start_page { String::new() } else { uri };
                        s.loading = !start_page;
                        s.title.clear();
                        s.sheet = false;
                        s.detections.clear();
                    });
                    publish(&app);
                    Ok(())
                }));
                let _ = core.add_NavigationStarting(&handler, &mut token);
            }
            {
                let app = app.clone();
                let handler =
                    NavigationCompletedEventHandler::create(Box::new(move |sender, _| {
                        update(&app, |s| s.loading = false);
                        if let Some(core) = sender {
                            refresh_history(&app, &core);
                        }
                        publish(&app);
                        scan_page(&app);
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
                    let changed = update(&app, |s| {
                        let moved = s.url != uri && uri != "about:blank";
                        if moved {
                            s.url = uri;
                            if !new_document.as_bool() {
                                s.detections.clear();
                            }
                        }
                        moved
                    });
                    refresh_history(&app, &core);
                    if changed {
                        publish(&app);
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
                        update(&app, |s| s.title = title);
                        publish(&app);
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
