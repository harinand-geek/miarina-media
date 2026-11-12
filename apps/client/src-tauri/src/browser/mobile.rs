//! Android: a native WebView (`BrowserPlugin.kt`) placed over the page area
//! of the React browser screen (designs M1/M3). The interface polls
//! `browser_state` while the browser is shown; observations from the page
//! are classified in `page_state`. Commands keep the desktop names so one
//! handler list serves every platform; `browser_open`, `browser_sheet`,
//! `browser_fab_size` and `browser_show_in_app` belong to the desktop window.

use std::sync::Mutex;

use serde::Serialize;
use serde::de::DeserializeOwned;
use tauri::{AppHandle, Manager, State};

use super::page_state::{
    PageSnapshot, PageState, Poll, valid_fab_label, valid_rect, valid_snapshot,
};
use crate::commands::CommandError;

#[derive(Default)]
pub struct BrowserState(Mutex<PageState>);

#[cfg(target_os = "android")]
pub struct BrowserPage(tauri::plugin::PluginHandle<tauri::Wry>);

#[cfg(target_os = "android")]
pub fn init() -> tauri::plugin::TauriPlugin<tauri::Wry> {
    tauri::plugin::Builder::new("browser-page")
        .setup(|app, api| {
            let handle = api.register_android_plugin("org.miarina.media", "BrowserPlugin")?;
            app.manage(BrowserPage(handle));
            Ok(())
        })
        .build()
}

fn unavailable() -> CommandError {
    CommandError::new(
        "browser_unavailable",
        "The built-in browser is not available on this platform yet",
    )
}

async fn call<T: DeserializeOwned>(
    app: &AppHandle,
    command: &str,
    payload: impl Serialize,
) -> Result<T, CommandError> {
    #[cfg(target_os = "android")]
    {
        let Some(page) = app.try_state::<BrowserPage>() else {
            return Err(unavailable());
        };
        page.0
            .run_mobile_plugin_async(command, payload)
            .await
            .map_err(|e| CommandError::new("browser", e.to_string()))
    }
    #[cfg(not(target_os = "android"))]
    {
        let _ = (app, command, payload);
        Err(unavailable())
    }
}

#[tauri::command]
pub async fn browser_open(_app: AppHandle, _url: Option<String>) -> Result<(), CommandError> {
    Err(unavailable())
}

/// Opens what was typed in the address bar (a web address, or a search).
#[tauri::command]
pub async fn browser_navigate(app: AppHandle, address: String) -> Result<String, CommandError> {
    let url = super::address::resolve_address(&address)?;
    #[derive(Serialize)]
    struct Load<'a> {
        url: &'a str,
    }
    call::<serde_json::Value>(&app, "load", Load { url: url.as_str() }).await?;
    Ok(url.to_string())
}

/// Back, forward, reload, stop, or home (start page).
#[tauri::command]
pub async fn browser_nav(app: AppHandle, action: String) -> Result<(), CommandError> {
    if !matches!(
        action.as_str(),
        "back" | "forward" | "reload" | "stop" | "home"
    ) {
        return Err(CommandError::new(
            "invalid_action",
            "Unknown browser action",
        ));
    }
    #[derive(Serialize)]
    struct Action<'a> {
        action: &'a str,
    }
    call::<serde_json::Value>(&app, "action", Action { action: &action })
        .await
        .map(drop)
}

/// Current page, detected media and floating button gesture.
#[tauri::command]
pub async fn browser_state(
    app: AppHandle,
    state: State<'_, BrowserState>,
) -> Result<PageSnapshot, CommandError> {
    let poll: Poll = call(&app, "poll", ()).await?;
    Ok(state
        .0
        .lock()
        .unwrap_or_else(|e| e.into_inner())
        .apply(poll))
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct Frame<'a> {
    x: f64,
    y: f64,
    width: f64,
    height: f64,
    visible: bool,
    fab: Option<&'a str>,
    snapshot: bool,
}

#[derive(serde::Deserialize)]
struct Framed {
    snapshot: Option<String>,
}

/// Places the page over the screen's page area (CSS pixels), with the
/// floating button label, or hides it. With `snapshot`, returns a picture
/// of the page taken before hiding it (shown under the app's sheets).
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
    if !valid_rect([x, y, width, height]) {
        return Err(CommandError::new("invalid_frame", "Invalid page area"));
    }
    let fab = fab.filter(|label| valid_fab_label(label));
    let framed: Framed = call(
        &app,
        "frame",
        Frame {
            x,
            y,
            width,
            height,
            visible,
            fab: fab.as_deref(),
            snapshot,
        },
    )
    .await?;
    Ok(framed.snapshot.filter(|s| valid_snapshot(s)))
}

#[tauri::command]
pub async fn browser_sheet(_app: AppHandle, _open: bool) -> Result<(), CommandError> {
    Err(unavailable())
}

#[tauri::command]
pub fn browser_fab_size(_width: f64, _height: f64) {}

#[tauri::command]
pub fn browser_show_in_app(_screen: String) -> Result<(), CommandError> {
    Err(unavailable())
}

/// Android keeps one page for now (tabs grid: phase 2).
#[tauri::command]
pub async fn browser_tab_new(
    _kind: Option<String>,
    _address: Option<String>,
) -> Result<u32, CommandError> {
    Err(unavailable())
}

#[tauri::command]
pub async fn browser_tab_close(_id: u32) -> Result<(), CommandError> {
    Err(unavailable())
}

#[tauri::command]
pub async fn browser_tab_select(_id: Option<u32>, _step: Option<i32>) -> Result<(), CommandError> {
    Err(unavailable())
}
