//! Feasibility spike — embedded browser on Windows (Phase 4, decision 0001).
//!
//! One window, three child webviews:
//! - `chrome`: the app's own toolbar (trusted, IPC allowed by capability);
//! - `page`: the visited site (untrusted, no capability, http(s) only);
//! - `overlay`: transparent layer for the floating button and format sheet.
//!
//! Media detection never relies on the page: the native WebView2 network
//! events and a script result pulled by Rust are the only inputs.
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::collections::BTreeMap;
use std::sync::Mutex;
use std::time::Duration;

use serde::Serialize;
use tauri::webview::{NewWindowResponse, WebviewBuilder};
use tauri::window::WindowBuilder;
use tauri::{
    AppHandle, Emitter, LogicalPosition, LogicalSize, Manager, Url, Webview, WebviewUrl,
    WindowEvent,
};

const TOOLBAR: f64 = 48.0;
const FAB_W: f64 = 320.0;
const FAB_H: f64 = 100.0;
const MAX_ITEMS: usize = 50;
const HOME: &str = "https://commons.wikimedia.org/wiki/File:Big_Buck_Bunny_4K.webm";

#[derive(Clone, Serialize)]
struct Detected {
    kind: &'static str,
    mime: String,
    host: String,
    /// Last path segment only: full URLs stay in Rust.
    name: String,
    via: &'static str,
}

#[derive(Clone, Serialize)]
struct Snapshot {
    count: usize,
    items: Vec<Detected>,
}

#[derive(Default)]
struct Spike {
    found: Mutex<BTreeMap<String, Detected>>,
    sheet: Mutex<bool>,
}

fn webview(app: &AppHandle, label: &str) -> Result<Webview, String> {
    app.get_webview(label)
        .ok_or_else(|| format!("{label} webview missing"))
}

fn layout(app: &AppHandle) {
    let Some(window) = app.get_window("main") else {
        return;
    };
    let (Ok(size), Ok(scale)) = (window.inner_size(), window.scale_factor()) else {
        return;
    };
    let (w, h) = (
        f64::from(size.width) / scale,
        f64::from(size.height) / scale,
    );
    let page_h = (h - TOOLBAR).max(0.0);
    let sheet = *app.state::<Spike>().sheet.lock().unwrap();
    let place = |label: &str, x: f64, y: f64, w: f64, h: f64| {
        if let Some(v) = app.get_webview(label) {
            let _ = v.set_position(LogicalPosition::new(x, y));
            let _ = v.set_size(LogicalSize::new(w, h));
        }
    };
    place("chrome", 0.0, 0.0, w, TOOLBAR);
    place("page", 0.0, TOOLBAR, w, page_h);
    if sheet {
        place("overlay", 0.0, TOOLBAR, w, page_h);
    } else {
        place(
            "overlay",
            (w - FAB_W).max(0.0),
            (h - FAB_H).max(TOOLBAR),
            FAB_W,
            FAB_H,
        );
    }
}

fn current(app: &AppHandle) -> Snapshot {
    let state = app.state::<Spike>();
    let found = state.found.lock().unwrap();
    Snapshot {
        count: found.len(),
        items: found.values().cloned().collect(),
    }
}

fn publish(app: &AppHandle) {
    let snap = current(app);
    let sheet = *app.state::<Spike>().sheet.lock().unwrap();
    if let Ok(overlay) = webview(app, "overlay") {
        let _ = if snap.count == 0 && !sheet {
            overlay.hide()
        } else {
            overlay.show()
        };
    }
    for label in ["chrome", "overlay"] {
        let _ = app.emit_to(label, "detections", snap.clone());
    }
}

/// Classifies a response or element source as downloadable media.
fn classify(mime: &str, uri: &str) -> Option<&'static str> {
    let m = mime
        .split(';')
        .next()
        .unwrap_or("")
        .trim()
        .to_ascii_lowercase();
    let path = Url::parse(uri)
        .map(|u| u.path().to_ascii_lowercase())
        .unwrap_or_default();
    // Stream segments are parts of a manifest, not media on their own.
    if m == "video/mp2t"
        || m == "video/iso.segment"
        || path.ends_with(".ts")
        || path.ends_with(".m4s")
    {
        return None;
    }
    if matches!(
        m.as_str(),
        "application/vnd.apple.mpegurl" | "application/x-mpegurl" | "audio/mpegurl"
    ) || path.ends_with(".m3u8")
    {
        return Some("hls");
    }
    if m == "application/dash+xml" || path.ends_with(".mpd") {
        return Some("dash");
    }
    if m.starts_with("video/") {
        return Some("video");
    }
    if m.starts_with("audio/") {
        return Some("audio");
    }
    const EXT: [(&str, &str); 9] = [
        (".mp4", "video"),
        (".webm", "video"),
        (".mkv", "video"),
        (".mov", "video"),
        (".mp3", "audio"),
        (".m4a", "audio"),
        (".ogg", "audio"),
        (".opus", "audio"),
        (".flac", "audio"),
    ];
    EXT.iter()
        .find(|(ext, _)| path.ends_with(ext))
        .map(|(_, k)| *k)
}

fn record(app: &AppHandle, uri: &str, kind: &'static str, mime: &str, via: &'static str) {
    let Ok(url) = Url::parse(uri) else { return };
    if !matches!(url.scheme(), "http" | "https") {
        return;
    }
    let host = url.host_str().unwrap_or_default().to_owned();
    // Range requests and cache-busting queries hit the same resource.
    let key = format!("{host}{}", url.path());
    let name = url
        .path_segments()
        .and_then(|mut s| s.next_back())
        .unwrap_or_default()
        .to_owned();
    {
        let state = app.state::<Spike>();
        let mut found = state.found.lock().unwrap();
        if found.contains_key(&key) || found.len() >= MAX_ITEMS {
            return;
        }
        found.insert(
            key,
            Detected {
                kind,
                mime: mime.to_owned(),
                host,
                name,
                via,
            },
        );
    }
    publish(app);
}

fn reset(app: &AppHandle) {
    app.state::<Spike>().found.lock().unwrap().clear();
    publish(app);
}

fn shortcut(app: &AppHandle, name: &'static str) {
    match name {
        "Ctrl+L" => {
            if let Ok(chrome) = webview(app, "chrome") {
                let _ = chrome.set_focus();
            }
            let _ = app.emit_to("chrome", "focus-address", ());
        }
        "Ctrl+Shift+S" => {
            let _ = set_sheet(app, true);
        }
        "F5" => {
            let _ = page_nav(app, "reload");
        }
        _ => {}
    }
    let _ = app.emit_to("chrome", "shortcut", name);
}

fn parse_user_url(input: &str) -> Result<Url, String> {
    let t = input.trim();
    let candidate = if t.contains("://") {
        t.to_owned()
    } else {
        format!("https://{t}")
    };
    let url = Url::parse(&candidate).map_err(|_| "invalid address".to_owned())?;
    match url.scheme() {
        "http" | "https" => Ok(url),
        _ => Err("only http(s) pages can be opened".into()),
    }
}

fn set_sheet(app: &AppHandle, open: bool) -> Result<(), String> {
    *app.state::<Spike>().sheet.lock().unwrap() = open;
    layout(app);
    publish(app);
    let _ = app.emit_to("overlay", "sheet", open);
    let target = if open { "overlay" } else { "page" };
    webview(app, target)?.set_focus().map_err(|e| e.to_string())
}

#[cfg(windows)]
fn page_nav(app: &AppHandle, action: &str) -> Result<(), String> {
    let action = action.to_owned();
    webview(app, "page")?
        .with_webview(move |pw| unsafe {
            if let Ok(core) = pw.controller().CoreWebView2() {
                let _ = match action.as_str() {
                    "back" => core.GoBack(),
                    "forward" => core.GoForward(),
                    _ => core.Reload(),
                };
            }
        })
        .map_err(|e| e.to_string())
}

#[tauri::command]
fn navigate(app: AppHandle, url: String) -> Result<String, String> {
    let url = parse_user_url(&url)?;
    webview(&app, "page")?
        .navigate(url.clone())
        .map_err(|e| e.to_string())?;
    Ok(url.to_string())
}

#[tauri::command]
fn nav(app: AppHandle, action: String) -> Result<(), String> {
    match action.as_str() {
        "back" | "forward" | "reload" => page_nav(&app, &action),
        _ => Err("unknown action".into()),
    }
}

#[tauri::command]
fn open_sheet(app: AppHandle) -> Result<(), String> {
    set_sheet(&app, true)
}

#[tauri::command]
fn close_sheet(app: AppHandle) -> Result<(), String> {
    set_sheet(&app, false)
}

#[tauri::command]
fn snapshot(app: AppHandle) -> Snapshot {
    current(&app)
}

/// Collects <video>/<audio> sources. Runs in the page, so its answer is only
/// a hint about the page's own media; it is parsed and filtered in Rust.
const DOM_SCAN: &str = r#"(() => {
  const out = [];
  for (const el of document.querySelectorAll('video, audio, video source, audio source')) {
    const src = el.currentSrc || el.src;
    if (typeof src === 'string' && src) out.push([el.tagName.toLowerCase(), src.slice(0, 2048)]);
    if (out.length >= 50) break;
  }
  return out;
})()"#;

#[cfg(windows)]
fn scan_dom(app: &AppHandle) {
    use webview2_com::ExecuteScriptCompletedHandler;
    use windows::core::HSTRING;
    let Ok(page) = webview(app, "page") else {
        return;
    };
    let app = app.clone();
    let _ = page.with_webview(move |pw| unsafe {
        let Ok(core) = pw.controller().CoreWebView2() else {
            return;
        };
        let handler = ExecuteScriptCompletedHandler::create(Box::new(move |result, json| {
            result?;
            let Ok(items) = serde_json::from_str::<Vec<(String, String)>>(&json) else {
                return Ok(());
            };
            for (tag, src) in items {
                if src.starts_with("blob:") {
                    // Media Source Extensions: only the page URL can be analysed (yt-dlp).
                    let _ = app.emit_to("chrome", "mse", ());
                    continue;
                }
                let kind = classify("", &src).unwrap_or(if tag.starts_with("audio") {
                    "audio"
                } else {
                    "video"
                });
                record(&app, &src, kind, "", "dom");
            }
            Ok(())
        }));
        let _ = core.ExecuteScript(&HSTRING::from(DOM_SCAN), &handler);
    });
}

#[cfg(windows)]
unsafe fn take(p: windows::core::PWSTR) -> String {
    webview2_com::CoTaskMemPWSTR::from(p).to_string()
}

#[cfg(windows)]
fn install_page_hooks(page: &Webview, app: AppHandle) -> tauri::Result<()> {
    page.with_webview(move |pw| unsafe {
        use webview2_com::Microsoft::Web::WebView2::Win32::*;
        use webview2_com::*;
        use windows::Win32::UI::Input::KeyboardAndMouse::{GetKeyState, VK_CONTROL, VK_SHIFT};
        use windows::core::{Interface, PWSTR, w};

        let controller = pw.controller();
        let Ok(core) = controller.CoreWebView2() else {
            return;
        };
        let mut token = 0i64;

        // 1. Network: every response the page receives, including media
        //    fetched by players. Only the content type and URL are read.
        if let Ok(core2) = core.cast::<ICoreWebView2_2>() {
            let app = app.clone();
            let handler =
                WebResourceResponseReceivedEventHandler::create(Box::new(move |_, args| {
                    let Some(args) = args else { return Ok(()) };
                    let mut uri = PWSTR::null();
                    args.Request()?.Uri(&mut uri)?;
                    let uri = take(uri);
                    let response = args.Response()?;
                    let mut status = 0;
                    response.StatusCode(&mut status)?;
                    let mut ct = PWSTR::null();
                    let mime = match response.Headers()?.GetHeader(w!("Content-Type"), &mut ct) {
                        Ok(()) => take(ct),
                        Err(_) => String::new(),
                    };
                    if (200..300).contains(&status) {
                        if let Some(kind) = classify(&mime, &uri) {
                            record(&app, &uri, kind, &mime, "network");
                        }
                    }
                    Ok(())
                }));
            let _ = core2.add_WebResourceResponseReceived(&handler, &mut token);
        }

        // 2. Top-level navigation: reset detections and update the address bar.
        {
            let app = app.clone();
            let handler = NavigationStartingEventHandler::create(Box::new(move |_, args| {
                if let Some(args) = args {
                    let mut uri = PWSTR::null();
                    args.Uri(&mut uri)?;
                    let _ = app.emit_to("chrome", "address", take(uri));
                }
                reset(&app);
                Ok(())
            }));
            let _ = core.add_NavigationStarting(&handler, &mut token);
        }
        {
            let app = app.clone();
            let handler = NavigationCompletedEventHandler::create(Box::new(move |_, _| {
                scan_dom(&app);
                let _ = app.emit_to("chrome", "loaded", ());
                Ok(())
            }));
            let _ = core.add_NavigationCompleted(&handler, &mut token);
        }

        // 3. App shortcuts while the page has keyboard focus.
        {
            let app = app.clone();
            let handler = AcceleratorKeyPressedEventHandler::create(Box::new(move |_, args| {
                let Some(args) = args else { return Ok(()) };
                let mut kind = COREWEBVIEW2_KEY_EVENT_KIND::default();
                args.KeyEventKind(&mut kind)?;
                if kind != COREWEBVIEW2_KEY_EVENT_KIND_KEY_DOWN {
                    return Ok(());
                }
                let mut vk = 0u32;
                args.VirtualKey(&mut vk)?;
                let ctrl = GetKeyState(i32::from(VK_CONTROL.0)) < 0;
                let shift = GetKeyState(i32::from(VK_SHIFT.0)) < 0;
                let name = match (ctrl, shift, vk) {
                    (true, false, 0x4C) => "Ctrl+L",
                    (true, false, 0x54) => "Ctrl+T",
                    (true, false, 0x57) => "Ctrl+W",
                    (true, false, 0x48) => "Ctrl+H",
                    (true, false, 0x44) => "Ctrl+D",
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

fn build(app: &AppHandle) -> tauri::Result<()> {
    let window = WindowBuilder::new(app, "main")
        .title("Miarina Media — browser spike")
        .inner_size(1280.0, 760.0)
        .min_inner_size(800.0, 500.0)
        .build()?;
    let size = LogicalSize::new(1280.0, 760.0);

    window.add_child(
        WebviewBuilder::new("chrome", WebviewUrl::App("chrome.html".into())),
        LogicalPosition::new(0.0, 0.0),
        LogicalSize::new(size.width, TOOLBAR),
    )?;

    let nav_app = app.clone();
    let page = window.add_child(
        WebviewBuilder::new(
            "page",
            WebviewUrl::External(HOME.parse().expect("home url")),
        )
        // Only web pages: no file:, app or custom schemes.
        .on_navigation(|url| {
            matches!(url.scheme(), "http" | "https") || url.as_str() == "about:blank"
        })
        // Popups open in the same tab (tabs are out of the spike scope).
        .on_new_window(move |url, _| {
            if matches!(url.scheme(), "http" | "https") {
                if let Some(page) = nav_app.get_webview("page") {
                    let _ = page.navigate(url);
                }
            }
            NewWindowResponse::Deny
        })
        // Browser-native downloads are refused; the app engine owns downloads.
        .on_download(|webview, _| {
            let _ = webview
                .app_handle()
                .emit_to("chrome", "download-blocked", ());
            false
        }),
        LogicalPosition::new(0.0, TOOLBAR),
        LogicalSize::new(size.width, size.height - TOOLBAR),
    )?;
    install_page_hooks(&page, app.clone())?;

    let overlay = window.add_child(
        WebviewBuilder::new("overlay", WebviewUrl::App("overlay.html".into())).transparent(true),
        LogicalPosition::new(size.width - FAB_W, size.height - FAB_H),
        LogicalSize::new(FAB_W, FAB_H),
    )?;
    overlay.hide()?;

    let handle = app.clone();
    window.on_window_event(move |event| {
        if matches!(
            event,
            WindowEvent::Resized(_) | WindowEvent::ScaleFactorChanged { .. }
        ) {
            layout(&handle);
        }
    });

    // Players often attach their sources late: rescan while the app runs.
    let handle = app.clone();
    std::thread::spawn(move || {
        loop {
            std::thread::sleep(Duration::from_secs(3));
            scan_dom(&handle);
        }
    });
    Ok(())
}

fn main() {
    tauri::Builder::default()
        .manage(Spike::default())
        .invoke_handler(tauri::generate_handler![
            navigate,
            nav,
            open_sheet,
            close_sheet,
            snapshot
        ])
        .setup(|app| {
            build(app.handle())?;
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("browser spike failed");
}
