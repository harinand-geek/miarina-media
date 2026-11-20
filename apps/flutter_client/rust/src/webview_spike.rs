//! Windows implementation of api::browser_spike (kept outside `api` so the
//! bridge generator does not expose it).

#[cfg(windows)]
mod platform {
    use std::cell::RefCell;
    use std::sync::{LazyLock, Mutex, mpsc};

    use anyhow::{Result, anyhow};
    use media_core::detect::Detections;
    use webview2_com::Microsoft::Web::WebView2::Win32::*;
    use webview2_com::{
        CoTaskMemPWSTR, CreateCoreWebView2ControllerCompletedHandler,
        CreateCoreWebView2EnvironmentCompletedHandler, WebResourceResponseReceivedEventHandler,
    };
    use windows::Win32::Foundation::{E_POINTER, HWND, LPARAM, RECT};
    use windows::Win32::System::Threading::{GetCurrentProcessId, GetCurrentThreadId};
    use windows::Win32::UI::WindowsAndMessaging::{
        EnumWindows, GetClassNameW, GetWindowThreadProcessId,
    };
    use windows::core::{BOOL, HSTRING, Interface, PCWSTR, PWSTR, w};

    use crate::api::browser_spike::{DetectedMediaItem, WebviewSpikeInfo};

    static DETECTIONS: LazyLock<Mutex<Detections>> =
        LazyLock::new(|| Mutex::new(Detections::default()));

    thread_local! {
        // WebView2 objects are apartment-bound: kept on the thread that made them.
        static CONTROLLER: RefCell<Option<ICoreWebView2Controller>> = const { RefCell::new(None) };
    }

    const FLUTTER_WINDOW_CLASS: &str = "FLUTTER_RUNNER_WIN32_WINDOW";

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

    fn take(p: PWSTR) -> String {
        CoTaskMemPWSTR::from(p).to_string()
    }

    pub fn open(url: &str, x: i32, y: i32, width: i32, height: i32) -> Result<WebviewSpikeInfo> {
        close();
        DETECTIONS.lock().map_err(|_| anyhow!("poisoned"))?.clear();
        let parent = flutter_window().ok_or_else(|| anyhow!("Flutter window not found"))?;
        let on_window_thread =
            unsafe { GetWindowThreadProcessId(parent, None) } == unsafe { GetCurrentThreadId() };

        let data_dir = HSTRING::from(
            std::env::temp_dir()
                .join("miarina-webview2-poc")
                .as_os_str(),
        );
        let (tx, rx) = mpsc::channel();
        CreateCoreWebView2EnvironmentCompletedHandler::wait_for_async_operation(
            Box::new(move |handler| unsafe {
                CreateCoreWebView2EnvironmentWithOptions(PCWSTR::null(), &data_dir, None, &handler)
                    .map_err(webview2_com::Error::WindowsError)
            }),
            Box::new(move |result, env| {
                result?;
                tx.send(env.ok_or_else(|| windows::core::Error::from(E_POINTER)))
                    .expect("send environment");
                Ok(())
            }),
        )?;
        let env = rx.recv()??;

        let (tx, rx) = mpsc::channel();
        CreateCoreWebView2ControllerCompletedHandler::wait_for_async_operation(
            Box::new(move |handler| unsafe {
                env.CreateCoreWebView2Controller(parent, &handler)
                    .map_err(webview2_com::Error::WindowsError)
            }),
            Box::new(move |result, controller| {
                result?;
                tx.send(controller.ok_or_else(|| windows::core::Error::from(E_POINTER)))
                    .expect("send controller");
                Ok(())
            }),
        )?;
        let controller = rx.recv()??;

        unsafe {
            controller.SetBounds(RECT {
                left: x,
                top: y,
                right: x + width,
                bottom: y + height,
            })?;
            controller.SetIsVisible(true)?;
            let core = controller.CoreWebView2()?;
            let core2 = core.cast::<ICoreWebView2_2>()?;
            let handler = WebResourceResponseReceivedEventHandler::create(Box::new(|_, args| {
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
                let total = header(w!("Content-Length")).and_then(|v| v.trim().parse().ok());
                if let Ok(mut d) = DETECTIONS.lock() {
                    d.add_response(
                        &uri,
                        &content_type,
                        u16::try_from(status).unwrap_or(0),
                        total,
                        fetch_dest.as_deref(),
                    );
                }
                Ok(())
            }));
            let mut token = 0i64;
            core2.add_WebResourceResponseReceived(&handler, &mut token)?;
            core.Navigate(&HSTRING::from(url))?;
        }
        CONTROLLER.with(|c| *c.borrow_mut() = Some(controller));
        Ok(WebviewSpikeInfo { on_window_thread })
    }

    pub fn detections() -> Vec<DetectedMediaItem> {
        let Ok(d) = DETECTIONS.lock() else {
            return Vec::new();
        };
        d.items()
            .iter()
            .map(|m| DetectedMediaItem {
                kind: format!("{:?}", m.kind).to_lowercase(),
                url: m.url.clone(),
                size_bytes: m.size_bytes,
            })
            .collect()
    }

    pub fn close() {
        CONTROLLER.with(|c| {
            if let Some(controller) = c.borrow_mut().take() {
                let _ = unsafe { controller.Close() };
            }
        });
    }
}

#[cfg(not(windows))]
mod platform {
    use crate::api::browser_spike::{DetectedMediaItem, WebviewSpikeInfo};
    use anyhow::{Result, bail};

    pub fn open(_: &str, _: i32, _: i32, _: i32, _: i32) -> Result<WebviewSpikeInfo> {
        bail!("the WebView2 spike only exists on Windows")
    }

    pub fn detections() -> Vec<DetectedMediaItem> {
        Vec::new()
    }

    pub fn close() {}
}

pub use platform::*;
