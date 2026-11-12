//! WIN-SPIKE (lot L04): libVLC inside the Tauri window — a measured
//! prototype, not a product feature. Compiled only with the `libvlc-spike`
//! feature and run only when `MIARINA_LIBVLC_SPIKE` names a folder holding
//! `libvlc.dll`, `libvlccore.dll` and `plugins/`.
//!
//! It loads libVLC dynamically (nothing is linked at build time), creates a
//! child HWND in the main window, plays every file of `MIARINA_SPIKE_CORPUS`
//! and writes measurements to `MIARINA_SPIKE_OUT` (JSON). A transparent
//! child webview is placed over the video to check that HTML controls can
//! be drawn above it. See `docs/decisions/0005-windows-player-engine.md`.

use std::ffi::{CStr, CString, c_char, c_int, c_uint, c_void};
use std::path::{Path, PathBuf};
use std::sync::mpsc;
use std::time::{Duration, Instant};

use serde_json::{Value, json};
use tauri::webview::WebviewBuilder;
use tauri::{AppHandle, LogicalPosition, LogicalSize, Manager, WebviewUrl};
use windows::Win32::Foundation::{FILETIME, HWND, LPARAM, LRESULT, RECT, WPARAM};
use windows::Win32::Graphics::Gdi::{BLACK_BRUSH, GetStockObject, HBRUSH};
use windows::Win32::System::LibraryLoader::{
    GetModuleHandleW, GetProcAddress, LOAD_WITH_ALTERED_SEARCH_PATH, LoadLibraryExW,
};
use windows::Win32::System::ProcessStatus::{GetProcessMemoryInfo, PROCESS_MEMORY_COUNTERS};
use windows::Win32::System::Threading::{GetCurrentProcess, GetProcessTimes};
use windows::Win32::UI::WindowsAndMessaging::{
    CreateWindowExW, DefWindowProcW, DestroyWindow, EnumChildWindows, GetClassNameW, GetClientRect,
    GetParent, GetWindowRect, HWND_TOP, RegisterClassW, SWP_SHOWWINDOW, SetWindowPos,
    WINDOW_EX_STYLE, WNDCLASSW, WS_CHILD, WS_CLIPCHILDREN, WS_CLIPSIBLINGS, WS_VISIBLE,
};
use windows::core::BOOL;
use windows::core::{HSTRING, PCSTR, PCWSTR, w};

type Inst = *mut c_void;
type Media = *mut c_void;
type Player = *mut c_void;

#[repr(C)]
struct TrackDescription {
    id: c_int,
    name: *const c_char,
    next: *mut TrackDescription,
}

/// The libVLC 3 functions the prototype uses, resolved at run time.
struct Vlc {
    new: unsafe extern "C" fn(c_int, *const *const c_char) -> Inst,
    release: unsafe extern "C" fn(Inst),
    version: unsafe extern "C" fn() -> *const c_char,
    errmsg: unsafe extern "C" fn() -> *const c_char,
    media_new_path: unsafe extern "C" fn(Inst, *const c_char) -> Media,
    media_release: unsafe extern "C" fn(Media),
    player_new: unsafe extern "C" fn(Media) -> Player,
    player_release: unsafe extern "C" fn(Player),
    set_hwnd: unsafe extern "C" fn(Player, *mut c_void),
    play: unsafe extern "C" fn(Player) -> c_int,
    stop: unsafe extern "C" fn(Player),
    set_pause: unsafe extern "C" fn(Player, c_int),
    get_time: unsafe extern "C" fn(Player) -> i64,
    set_time: unsafe extern "C" fn(Player, i64),
    get_length: unsafe extern "C" fn(Player) -> i64,
    get_state: unsafe extern "C" fn(Player) -> c_int,
    set_rate: unsafe extern "C" fn(Player, f32) -> c_int,
    get_rate: unsafe extern "C" fn(Player) -> f32,
    video_size: unsafe extern "C" fn(Player, c_uint, *mut c_uint, *mut c_uint) -> c_int,
    audio_tracks: unsafe extern "C" fn(Player) -> *mut TrackDescription,
    audio_set_track: unsafe extern "C" fn(Player, c_int) -> c_int,
    audio_get_track: unsafe extern "C" fn(Player) -> c_int,
    spu_tracks: unsafe extern "C" fn(Player) -> *mut TrackDescription,
    spu_set: unsafe extern "C" fn(Player, c_int) -> c_int,
    spu_get: unsafe extern "C" fn(Player) -> c_int,
    tracks_release: unsafe extern "C" fn(*mut TrackDescription),
    add_slave: unsafe extern "C" fn(Player, c_int, *const c_char, bool) -> c_int,
    mouse_input: unsafe extern "C" fn(Player, c_uint),
    key_input: unsafe extern "C" fn(Player, c_uint),
}

unsafe fn sym<T>(lib: windows::Win32::Foundation::HMODULE, name: &str) -> Result<T, String> {
    let cname = CString::new(name).map_err(|e| e.to_string())?;
    let f = unsafe { GetProcAddress(lib, PCSTR(cname.as_ptr() as *const u8)) }
        .ok_or_else(|| format!("missing {name}"))?;
    Ok(unsafe { std::mem::transmute_copy(&f) })
}

impl Vlc {
    fn load(dir: &Path) -> Result<Self, String> {
        let dll = HSTRING::from(dir.join("libvlc.dll").as_os_str());
        let lib = unsafe { LoadLibraryExW(&dll, None, LOAD_WITH_ALTERED_SEARCH_PATH) }
            .map_err(|e| format!("LoadLibrary: {e}"))?;
        unsafe {
            Ok(Self {
                new: sym(lib, "libvlc_new")?,
                release: sym(lib, "libvlc_release")?,
                version: sym(lib, "libvlc_get_version")?,
                errmsg: sym(lib, "libvlc_errmsg")?,
                media_new_path: sym(lib, "libvlc_media_new_path")?,
                media_release: sym(lib, "libvlc_media_release")?,
                player_new: sym(lib, "libvlc_media_player_new_from_media")?,
                player_release: sym(lib, "libvlc_media_player_release")?,
                set_hwnd: sym(lib, "libvlc_media_player_set_hwnd")?,
                play: sym(lib, "libvlc_media_player_play")?,
                stop: sym(lib, "libvlc_media_player_stop")?,
                set_pause: sym(lib, "libvlc_media_player_set_pause")?,
                get_time: sym(lib, "libvlc_media_player_get_time")?,
                set_time: sym(lib, "libvlc_media_player_set_time")?,
                get_length: sym(lib, "libvlc_media_player_get_length")?,
                get_state: sym(lib, "libvlc_media_player_get_state")?,
                set_rate: sym(lib, "libvlc_media_player_set_rate")?,
                get_rate: sym(lib, "libvlc_media_player_get_rate")?,
                video_size: sym(lib, "libvlc_video_get_size")?,
                audio_tracks: sym(lib, "libvlc_audio_get_track_description")?,
                audio_set_track: sym(lib, "libvlc_audio_set_track")?,
                audio_get_track: sym(lib, "libvlc_audio_get_track")?,
                spu_tracks: sym(lib, "libvlc_video_get_spu_description")?,
                spu_set: sym(lib, "libvlc_video_set_spu")?,
                spu_get: sym(lib, "libvlc_video_get_spu")?,
                tracks_release: sym(lib, "libvlc_track_description_list_release")?,
                add_slave: sym(lib, "libvlc_media_player_add_slave")?,
                mouse_input: sym(lib, "libvlc_video_set_mouse_input")?,
                key_input: sym(lib, "libvlc_video_set_key_input")?,
            })
        }
    }

    fn tracks(&self, list: *mut TrackDescription) -> Vec<(i32, String)> {
        let mut out = Vec::new();
        let mut node = list;
        while !node.is_null() {
            let t = unsafe { &*node };
            let name = if t.name.is_null() {
                String::new()
            } else {
                unsafe { CStr::from_ptr(t.name) }
                    .to_string_lossy()
                    .into_owned()
            };
            out.push((t.id, name));
            node = t.next;
        }
        if !list.is_null() {
            unsafe { (self.tracks_release)(list) };
        }
        out
    }
}

const STATES: [&str; 8] = [
    "nothing",
    "opening",
    "buffering",
    "playing",
    "paused",
    "stopped",
    "ended",
    "error",
];

fn state_name(s: c_int) -> &'static str {
    STATES.get(s as usize).copied().unwrap_or("?")
}

/// (working set MB, CPU seconds of the whole process).
fn process_usage() -> (f64, f64) {
    unsafe {
        let process = GetCurrentProcess();
        let mut mem = PROCESS_MEMORY_COUNTERS {
            cb: std::mem::size_of::<PROCESS_MEMORY_COUNTERS>() as u32,
            ..Default::default()
        };
        let _ = GetProcessMemoryInfo(process, &mut mem, mem.cb);
        let (mut c, mut e, mut k, mut u) = (
            FILETIME::default(),
            FILETIME::default(),
            FILETIME::default(),
            FILETIME::default(),
        );
        let _ = GetProcessTimes(process, &mut c, &mut e, &mut k, &mut u);
        let ft =
            |f: FILETIME| ((f.dwHighDateTime as u64) << 32 | f.dwLowDateTime as u64) as f64 / 1e7;
        (mem.WorkingSetSize as f64 / 1048576.0, ft(k) + ft(u))
    }
}

unsafe extern "system" fn video_proc(h: HWND, m: u32, w: WPARAM, l: LPARAM) -> LRESULT {
    unsafe { DefWindowProcW(h, m, w, l) }
}

/// Runs `f` on the main (window) thread and waits for its result.
fn on_main<R: Send + 'static>(app: &AppHandle, f: impl FnOnce() -> R + Send + 'static) -> R {
    let (tx, rx) = mpsc::channel();
    app.run_on_main_thread(move || {
        let _ = tx.send(f());
    })
    .expect("main thread");
    rx.recv().expect("main thread result")
}

fn main_hwnd(app: &AppHandle) -> isize {
    app.get_window("main")
        .and_then(|w| w.hwnd().ok())
        .map(|h| h.0 as isize)
        .unwrap_or(0)
}

/// Creates the video child window (main thread); returns it as isize.
fn create_video_window(parent: isize, rect: (i32, i32, i32, i32)) -> isize {
    unsafe {
        let instance = GetModuleHandleW(None).unwrap_or_default();
        let class = WNDCLASSW {
            lpfnWndProc: Some(video_proc),
            hInstance: instance.into(),
            lpszClassName: w!("MiarinaVideoSpike"),
            hbrBackground: HBRUSH(GetStockObject(BLACK_BRUSH).0),
            ..Default::default()
        };
        RegisterClassW(&class);
        let (x, y, cw, ch) = rect;
        CreateWindowExW(
            WINDOW_EX_STYLE(0),
            w!("MiarinaVideoSpike"),
            PCWSTR::null(),
            WS_CHILD | WS_VISIBLE | WS_CLIPSIBLINGS | WS_CLIPCHILDREN,
            x,
            y,
            cw,
            ch,
            Some(HWND(parent as *mut c_void)),
            None,
            Some(instance.into()),
            None,
        )
        .map(|h| h.0 as isize)
        .unwrap_or(0)
    }
}

unsafe extern "system" fn collect(h: HWND, l: LPARAM) -> BOOL {
    let list = unsafe { &mut *(l.0 as *mut Vec<isize>) };
    list.push(h.0 as isize);
    BOOL(1)
}

/// The overlay webview's host window: a direct WRY_WEBVIEW child of the
/// main window that is not full height.
fn overlay_window(parent: isize, client_height: i32) -> Option<isize> {
    let mut all: Vec<isize> = Vec::new();
    unsafe {
        let _ = EnumChildWindows(
            Some(HWND(parent as *mut c_void)),
            Some(collect),
            LPARAM(&mut all as *mut Vec<isize> as isize),
        );
    }
    all.into_iter().find(|h| unsafe {
        let hwnd = HWND(*h as *mut c_void);
        let mut name = [0u16; 64];
        let n = GetClassNameW(hwnd, &mut name);
        let mut r = RECT::default();
        let _ = GetWindowRect(hwnd, &mut r);
        GetParent(hwnd).is_ok_and(|p| p.0 as isize == parent)
            && String::from_utf16_lossy(&name[..n as usize]) == "WRY_WEBVIEW"
            && (r.bottom - r.top) < client_height / 2
    })
}

/// Places the video window; just below `above` (the HTML overlay) when
/// given, so HTML controls stay visible over the picture.
fn place(hwnd: isize, rect: (i32, i32, i32, i32), above: Option<isize>) {
    unsafe {
        let _ = SetWindowPos(
            HWND(hwnd as *mut c_void),
            Some(above.map_or(HWND_TOP, |h| HWND(h as *mut c_void))),
            rect.0,
            rect.1,
            rect.2,
            rect.3,
            SWP_SHOWWINDOW,
        );
    }
}

fn client(parent: isize) -> (i32, i32) {
    let mut r = RECT::default();
    unsafe {
        let _ = GetClientRect(HWND(parent as *mut c_void), &mut r);
    }
    (r.right - r.left, r.bottom - r.top)
}

fn wait_for(timeout: Duration, mut done: impl FnMut() -> bool) -> Option<u128> {
    let start = Instant::now();
    while start.elapsed() < timeout {
        if done() {
            return Some(start.elapsed().as_millis());
        }
        std::thread::sleep(Duration::from_millis(20));
    }
    None
}

struct Session {
    vlc: Vlc,
    inst: Inst,
}

impl Session {
    /// Plays one file in `hwnd` and measures it; leaves nothing behind.
    fn play_file(
        &self,
        hwnd: isize,
        file: &Path,
        external_sub: Option<&Path>,
        deep: bool,
    ) -> Value {
        let v = &self.vlc;
        let path = CString::new(file.to_string_lossy().as_bytes()).unwrap_or_default();
        let opened = Instant::now();
        let media = unsafe { (v.media_new_path)(self.inst, path.as_ptr()) };
        if media.is_null() {
            return json!({ "file": file.file_name().map(|f| f.to_string_lossy().into_owned()), "error": "media_new_path" });
        }
        let mp = unsafe { (v.player_new)(media) };
        unsafe {
            (v.media_release)(media);
            (v.set_hwnd)(mp, hwnd as *mut c_void);
            // Clicks and keys go to the app, not to libVLC.
            (v.mouse_input)(mp, 0);
            (v.key_input)(mp, 0);
            (v.play)(mp);
        }
        let to_playing = wait_for(Duration::from_secs(6), || {
            let s = unsafe { (v.get_state)(mp) };
            s == 3 || s >= 6
        });
        let (mut w, mut h) = (0u32, 0u32);
        let to_frame = wait_for(Duration::from_secs(6), || unsafe {
            (v.video_size)(mp, 0, &mut w, &mut h) == 0 && w > 0
        });
        let (mem_playing, cpu0) = process_usage();
        std::thread::sleep(Duration::from_millis(2500));
        let (_, cpu1) = process_usage();
        let late_time = if file.to_string_lossy().contains("4k") {
            std::thread::sleep(Duration::from_millis(4000));
            Some(unsafe { (v.get_time)(mp) })
        } else {
            None
        };
        let mut out = json!({
            "file": file.file_name().map(|f| f.to_string_lossy().into_owned()),
            "state": state_name(unsafe { (v.get_state)(mp) }),
            "ms_to_playing": to_playing,
            "ms_to_first_size": to_frame,
            "ms_total_open": opened.elapsed().as_millis() as u64 - 2500,
            "video": [w, h],
            "length_ms": unsafe { (v.get_length)(mp) },
            "time_after_2_5s_ms": unsafe { (v.get_time)(mp) },
            "time_after_6_5s_ms": late_time,
            "cpu_percent_one_core": ((cpu1 - cpu0) / 2.5 * 100.0).round(),
            "working_set_mb": mem_playing.round(),
            "audio_tracks": v.tracks(unsafe { (v.audio_tracks)(mp) }),
            "spu_tracks": v.tracks(unsafe { (v.spu_tracks)(mp) }),
        });
        if deep {
            // Seek, track switch, external subtitle, rate bounds, pause.
            let length = unsafe { (v.get_length)(mp) };
            unsafe { (v.set_time)(mp, length / 2) };
            std::thread::sleep(Duration::from_millis(800));
            out["time_after_seek_half_ms"] = json!(unsafe { (v.get_time)(mp) });
            let audio: Vec<(i32, String)> = v.tracks(unsafe { (v.audio_tracks)(mp) });
            if let Some((id, _)) = audio.iter().rev().find(|(id, _)| *id >= 0) {
                let before = unsafe { (v.get_time)(mp) };
                unsafe { (v.audio_set_track)(mp, *id) };
                std::thread::sleep(Duration::from_millis(600));
                out["audio_switched_to"] = json!(unsafe { (v.audio_get_track)(mp) });
                out["time_kept_after_audio_switch_ms"] =
                    json!([before, unsafe { (v.get_time)(mp) }]);
            }
            if let Some(sub) = external_sub {
                let uri = format!(
                    "file:///{}",
                    sub.to_string_lossy().replace('\\', "/").replace(' ', "%20")
                );
                let c = CString::new(uri).unwrap_or_default();
                let added = unsafe { (v.add_slave)(mp, 0, c.as_ptr(), true) };
                std::thread::sleep(Duration::from_millis(800));
                out["external_sub_added"] = json!(added == 0);
                out["spu_after_external"] = json!(v.tracks(unsafe { (v.spu_tracks)(mp) }));
                out["spu_selected"] = json!(unsafe { (v.spu_get)(mp) });
                unsafe { (v.spu_set)(mp, -1) };
                std::thread::sleep(Duration::from_millis(200));
                out["spu_after_disable"] = json!(unsafe { (v.spu_get)(mp) });
            }
            let rates: Vec<Value> = [0.25f32, 3.0, 4.0]
                .iter()
                .map(|r| {
                    let ok = unsafe { (v.set_rate)(mp, *r) } == 0;
                    std::thread::sleep(Duration::from_millis(150));
                    json!([r, ok, unsafe { (v.get_rate)(mp) }])
                })
                .collect();
            unsafe { (v.set_rate)(mp, 1.0) };
            out["rates_requested_ok_effective"] = json!(rates);
            unsafe { (v.set_pause)(mp, 1) };
            std::thread::sleep(Duration::from_millis(300));
            out["state_after_pause"] = json!(state_name(unsafe { (v.get_state)(mp) }));
        }
        let stopping = Instant::now();
        unsafe {
            (v.stop)(mp);
            (v.player_release)(mp);
        }
        out["ms_stop_release"] = json!(stopping.elapsed().as_millis() as u64);
        out
    }
}

/// Starts the scripted prototype if the environment asks for it.
pub fn maybe_start(app: &AppHandle) {
    let Ok(dir) = std::env::var("MIARINA_LIBVLC_SPIKE") else {
        return;
    };
    let corpus = PathBuf::from(std::env::var("MIARINA_SPIKE_CORPUS").unwrap_or_default());
    let out =
        PathBuf::from(std::env::var("MIARINA_SPIKE_OUT").unwrap_or_else(|_| "spike.json".into()));
    let app = app.clone();
    std::thread::spawn(move || {
        // Let the main window and its webview settle.
        std::thread::sleep(Duration::from_secs(4));
        let report = run(&app, Path::new(&dir), &corpus);
        let _ = std::fs::write(&out, serde_json::to_vec_pretty(&report).unwrap_or_default());
    });
}

fn run(app: &AppHandle, dir: &Path, corpus: &Path) -> Value {
    let mut report = json!({});
    let (mem0, _) = process_usage();
    report["working_set_mb_before"] = json!(mem0.round());
    // SAFETY: the process environment is only read by libVLC afterwards.
    unsafe { std::env::set_var("VLC_PLUGIN_PATH", dir.join("plugins")) };
    let t = Instant::now();
    let vlc = match Vlc::load(dir) {
        Ok(v) => v,
        Err(e) => {
            report["error"] = json!(e);
            return report;
        }
    };
    report["ms_load_dll"] = json!(t.elapsed().as_millis() as u64);
    let hw = std::env::var("MIARINA_SPIKE_HW").unwrap_or_else(|_| "any".into());
    let args: Vec<CString> = [
        "--no-video-title-show",
        "--no-osd",
        "--no-snapshot-preview",
        "--quiet",
        &format!("--avcodec-hw={hw}"),
    ]
    .iter()
    .map(|a| CString::new(*a).unwrap_or_default())
    .collect();
    let argv: Vec<*const c_char> = args.iter().map(|a| a.as_ptr()).collect();
    let t = Instant::now();
    let inst = unsafe { (vlc.new)(argv.len() as c_int, argv.as_ptr()) };
    report["ms_libvlc_new"] = json!(t.elapsed().as_millis() as u64);
    report["hw_decoding"] = json!(hw);
    if inst.is_null() {
        let msg = unsafe { (vlc.errmsg)() };
        report["error"] = json!(if msg.is_null() {
            "libvlc_new failed".to_owned()
        } else {
            unsafe { CStr::from_ptr(msg) }
                .to_string_lossy()
                .into_owned()
        });
        return report;
    }
    report["version"] = json!(unsafe { CStr::from_ptr((vlc.version)()) }.to_string_lossy());
    let (mem1, _) = process_usage();
    report["working_set_mb_after_new"] = json!(mem1.round());

    // Video area: right of the sidebar, below the header (physical px).
    let parent = main_hwnd(app);
    let (cw, ch) = on_main(app, move || client(parent));
    let scale = app
        .get_window("main")
        .and_then(|w| w.scale_factor().ok())
        .unwrap_or(1.0);
    report["client_px"] = json!([cw, ch]);
    report["scale_factor"] = json!(scale);
    let rect = (
        (260.0 * scale) as i32,
        (110.0 * scale) as i32,
        cw - (290.0 * scale) as i32,
        ch - (200.0 * scale) as i32,
    );
    let hwnd = on_main(app, move || create_video_window(parent, rect));
    report["video_hwnd_created"] = json!(hwnd != 0);

    // HTML controls above the video: a transparent child webview on top.
    // Created from this thread: creating a webview on the main thread
    // would wait for the main thread itself.
    let overlay_ok = {
        let app = app.clone();
        (move || {
            let Some(window) = app.get_window("main") else {
                return false;
            };
            let Ok(url) = "about:blank".parse() else {
                return false;
            };
            window
                .add_child(
                    WebviewBuilder::new("spike-overlay", WebviewUrl::External(url))
                        .transparent(true),
                    LogicalPosition::new(
                        rect.0 as f64 / scale,
                        (rect.1 + rect.3) as f64 / scale - 90.0,
                    ),
                    LogicalSize::new(rect.2 as f64 / scale, 84.0),
                )
                .is_ok()
        })()
    };
    std::thread::sleep(Duration::from_millis(800));
    if let Some(view) = app.get_webview("spike-overlay") {
        let _ = view.eval(
            "document.documentElement.style.background='transparent';             document.body.style.cssText='margin:0;background:transparent';             document.body.innerHTML=\"<div style='position:fixed;left:16px;right:16px;bottom:16px;height:52px;border-radius:26px;background:rgba(53,201,189,.9);color:#062320;font:700 16px sans-serif;display:flex;align-items:center;justify-content:center'>Commandes HTML au-dessus de la vidéo</div>\";",
        );
    }
    report["overlay_webview"] = json!(overlay_ok);

    // Second approach: a transparent top-level window owned by the main
    // window. DWM composes top-level windows, so its transparent pixels
    // show the video below (child webviews only show the main webview).
    let osd = {
        let origin = app
            .get_window("main")
            .and_then(|w| w.inner_position().ok())
            .map(|p| (p.x, p.y))
            .unwrap_or((0, 0));
        let builder = tauri::WebviewWindowBuilder::new(
            app,
            "spike-osd",
            WebviewUrl::External("about:blank".parse().expect("about:blank")),
        )
        .owner_raw(HWND(parent as *mut c_void))
        .transparent(true)
        .decorations(false)
        .shadow(false)
        .skip_taskbar(true)
        .focused(false)
        .resizable(false)
        .position(
            (origin.0 + rect.0) as f64 / scale,
            (origin.1 + rect.1) as f64 / scale + 16.0,
        )
        .inner_size(rect.2 as f64 / scale, 72.0);
        builder.build().is_ok()
    };
    std::thread::sleep(Duration::from_millis(800));
    if let Some(view) = app.get_webview_window("spike-osd") {
        let _ = view.eval(
            "document.documentElement.style.background='transparent';             document.body.style.cssText='margin:0;background:transparent';             document.body.innerHTML=\"<div style='margin:8px 16px;height:52px;border-radius:26px;background:rgba(255,107,74,.85);color:#fff;font:700 16px sans-serif;display:flex;align-items:center;justify-content:center'>Fenêtre transparente possédée (DWM)</div>\";",
        );
    }
    report["owned_transparent_window"] = json!(osd);
    let over = on_main(app, move || overlay_window(parent, ch));
    report["overlay_window_found"] = json!(over.is_some());
    on_main(app, move || place(hwnd, rect, over));

    let session = Session { vlc, inst };
    let mut files: Vec<PathBuf> = std::fs::read_dir(corpus)
        .map(|d| {
            d.flatten()
                .map(|e| e.path())
                .filter(|p| {
                    p.extension().is_some_and(|e| {
                        ["mkv", "mp4", "webm", "avi"].contains(&e.to_string_lossy().as_ref())
                    })
                })
                .collect()
        })
        .unwrap_or_default();
    files.sort();
    // The 4K file last: the first file also pays libVLC's cold start.
    files.sort_by_key(|f| f.to_string_lossy().contains("4k"));
    if let Ok(d) = std::fs::read_dir(corpus.join("dossier avec espaces")) {
        files.extend(d.flatten().map(|e| e.path()));
    }
    let mut results = Vec::new();
    for file in &files {
        let name = file
            .file_name()
            .map(|f| f.to_string_lossy().into_owned())
            .unwrap_or_default();
        let deep = name == "mkv multipistes.mkv";
        let sub = deep.then(|| corpus.join("mkv multipistes.srt"));
        results.push(session.play_file(hwnd, file, sub.as_deref(), deep));
        if deep {
            // Resizing and "full window" while a file plays.
            let big = (0, 0, cw, ch);
            let started = Instant::now();
            on_main(app, move || place(hwnd, big, over));
            on_main(app, move || place(hwnd, rect, over));
            report["ms_two_resizes"] = json!(started.elapsed().as_millis() as u64);
            // Picture of the window with the video and the overlay.
            let ready = corpus.join("SNAPSHOT_NOW");
            let _ = std::fs::write(&ready, b"");
            let mid = Path::new(file);
            let replay = session.play_file_for_snapshot(hwnd, mid, &corpus.join("SNAPSHOT_DONE"));
            let _ = std::fs::remove_file(&ready);
            report["snapshot_replay"] = replay;
        }
    }
    report["files"] = json!(results);

    // Leak check: the same short file opened and released 10 times.
    if let Some(small) = files.iter().find(|f| f.ends_with("vp9.webm")) {
        let (before, _) = process_usage();
        let t = Instant::now();
        for _ in 0..10 {
            let _ = session.open_release(hwnd, small);
        }
        let (after, _) = process_usage();
        report["ten_open_release"] = json!({
            "ms": t.elapsed().as_millis() as u64,
            "working_set_mb_before": before.round(),
            "working_set_mb_after": after.round(),
        });
    }

    unsafe { (session.vlc.release)(session.inst) };
    on_main(app, move || unsafe {
        let _ = DestroyWindow(HWND(hwnd as *mut c_void));
    });
    if let Some(view) = app.get_webview("spike-overlay") {
        let _ = view.close();
    }
    if let Some(osd) = app.get_webview_window("spike-osd") {
        let _ = osd.destroy();
    }
    let (mem2, _) = process_usage();
    report["working_set_mb_after_release"] = json!(mem2.round());
    report["done"] = json!(true);
    report
}

impl Session {
    /// Plays a file until `done_flag` appears (an outside capture is taken).
    fn play_file_for_snapshot(&self, hwnd: isize, file: &Path, done_flag: &Path) -> Value {
        let v = &self.vlc;
        let path = CString::new(file.to_string_lossy().as_bytes()).unwrap_or_default();
        let media = unsafe { (v.media_new_path)(self.inst, path.as_ptr()) };
        let mp = unsafe { (v.player_new)(media) };
        unsafe {
            (v.media_release)(media);
            (v.set_hwnd)(mp, hwnd as *mut c_void);
            (v.mouse_input)(mp, 0);
            (v.key_input)(mp, 0);
            (v.play)(mp);
        }
        let waited = wait_for(Duration::from_secs(60), || done_flag.exists());
        let _ = std::fs::remove_file(done_flag);
        unsafe {
            (v.stop)(mp);
            (v.player_release)(mp);
        }
        json!({ "waited_ms": waited })
    }

    fn open_release(&self, hwnd: isize, file: &Path) -> bool {
        let v = &self.vlc;
        let path = CString::new(file.to_string_lossy().as_bytes()).unwrap_or_default();
        let media = unsafe { (v.media_new_path)(self.inst, path.as_ptr()) };
        if media.is_null() {
            return false;
        }
        let mp = unsafe { (v.player_new)(media) };
        unsafe {
            (v.media_release)(media);
            (v.set_hwnd)(mp, hwnd as *mut c_void);
            (v.play)(mp);
        }
        let ok = wait_for(Duration::from_secs(5), || unsafe { (v.get_state)(mp) } == 3).is_some();
        unsafe {
            (v.stop)(mp);
            (v.player_release)(mp);
        }
        ok
    }
}
