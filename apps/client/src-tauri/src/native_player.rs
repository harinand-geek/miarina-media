//! Windows video player engine (decision 0005, lot L05): libVLC 3, shipped
//! in `tools/libvlc/` and loaded at run time (nothing linked at build time).
//! Without it the WebView2 `<video>` element stays the engine.
//!
//! - One worker thread owns libVLC: every call goes through it (stopping a
//!   file can take seconds, never on the interface thread).
//! - The picture goes into one child window of the main window, created
//!   hidden at start and always given to libVLC, so libVLC never opens a
//!   window of its own. The interface reports where the picture goes
//!   (`native_player_frame`); clicks on it come back as events.
//! - State, position and tracks are sent as events (a few per second).
//!
//! Commands take a library id, never a path from the page.

use serde::Serialize;
use tauri::{AppHandle, State};

use crate::commands::{CmdResult, CommandError};
use crate::state::AppState;

pub const STATE_EVENT: &str = "native-player://state";
pub const TRACKS_EVENT: &str = "native-player://tracks";
pub const CLICK_EVENT: &str = "native-player://click";

#[derive(Debug, Clone, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct NativeStatus {
    pub available: bool,
    pub version: Option<String>,
    /// Why it is not available (missing runtime, load failure).
    pub reason: Option<String>,
}

#[derive(Debug, Clone, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct Track {
    pub id: i32,
    pub name: String,
}

#[derive(Debug, Clone, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct StateEvent {
    pub instance: u32,
    /// loading | playing | paused | ended | error | idle
    pub state: &'static str,
    pub position: f64,
    pub duration: f64,
    /// read | unsupported (WIN-02: access vs format).
    pub error: Option<&'static str>,
}

#[derive(Debug, Clone, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct TracksEvent {
    pub instance: u32,
    pub audio: Vec<Track>,
    pub subtitles: Vec<Track>,
    pub audio_id: i32,
    pub subtitle_id: i32,
    /// Subtitle delay in milliseconds.
    pub subtitle_delay: i64,
}

fn unavailable() -> CommandError {
    CommandError::new(
        "player_unavailable",
        "The built-in video engine is not available",
    )
}

#[cfg(windows)]
pub use imp::NativePlayer;

#[cfg(not(windows))]
#[derive(Default)]
pub struct NativePlayer;

#[cfg(not(windows))]
impl NativePlayer {
    pub fn new(_dir: Option<std::path::PathBuf>) -> Self {
        Self
    }
}

// ---------------------------------------------------------------- commands

#[tauri::command]
pub async fn native_player_status(
    app: AppHandle,
    player: State<'_, NativePlayer>,
) -> CmdResult<NativeStatus> {
    #[cfg(windows)]
    return Ok(player.status(&app));
    #[cfg(not(windows))]
    {
        let _ = (app, player);
        Ok(NativeStatus {
            available: false,
            version: None,
            reason: Some("Windows only".into()),
        })
    }
}

/// Opens a library entry. `instance` tags the events of this file.
#[tauri::command]
pub async fn native_player_open(
    app: AppHandle,
    state: State<'_, AppState>,
    player: State<'_, NativePlayer>,
    id: i64,
    start_secs: f64,
    autoplay: bool,
    instance: u32,
) -> CmdResult<()> {
    let path = std::path::PathBuf::from(state.storage().media(id)?.path);
    #[cfg(windows)]
    return player.send(
        &app,
        imp::Cmd::Open {
            path,
            start: if start_secs.is_finite() {
                start_secs.max(0.0)
            } else {
                0.0
            },
            autoplay,
            instance,
        },
    );
    #[cfg(not(windows))]
    {
        let _ = (app, player, path, start_secs, autoplay, instance);
        Err(unavailable())
    }
}

/// play | pause | stop | seek (secs) | rate | audioTrack (id) | subtitle (id,
/// -1: off) | subtitleDelay (ms).
#[tauri::command]
pub async fn native_player_control(
    app: AppHandle,
    player: State<'_, NativePlayer>,
    action: String,
    value: Option<f64>,
) -> CmdResult<()> {
    let v = value.filter(|v| v.is_finite()).unwrap_or(0.0);
    #[cfg(windows)]
    {
        use imp::Cmd;
        let cmd = match action.as_str() {
            "play" => Cmd::Play,
            "pause" => Cmd::Pause,
            "stop" => Cmd::Stop,
            "seek" => Cmd::Seek(v.max(0.0)),
            "rate" => Cmd::Rate(v.clamp(0.25, 3.0) as f32),
            "audioTrack" => Cmd::AudioTrack(v as i32),
            "subtitle" => Cmd::Subtitle(v as i32),
            "subtitleDelay" => Cmd::SubtitleDelay((v.clamp(-60_000.0, 60_000.0)) as i64),
            _ => return Err(CommandError::new("invalid_action", "Unknown player action")),
        };
        player.send(&app, cmd)
    }
    #[cfg(not(windows))]
    {
        let _ = (app, player, action, v);
        Err(unavailable())
    }
}

#[tauri::command]
pub async fn native_player_volume(
    app: AppHandle,
    player: State<'_, NativePlayer>,
    volume: f64,
    muted: bool,
) -> CmdResult<()> {
    let volume = if volume.is_finite() {
        volume.clamp(0.0, 1.0)
    } else {
        1.0
    };
    #[cfg(windows)]
    return player.send(&app, imp::Cmd::Volume(volume, muted));
    #[cfg(not(windows))]
    {
        let _ = (app, player, volume, muted);
        Err(unavailable())
    }
}

/// Adds a subtitle file picked in the system dialog. `false` if canceled.
#[tauri::command]
pub async fn native_player_add_subtitle(
    app: AppHandle,
    player: State<'_, NativePlayer>,
) -> CmdResult<bool> {
    #[cfg(windows)]
    {
        use tauri_plugin_dialog::DialogExt;
        let dialog = app.clone();
        let picked = tauri::async_runtime::spawn_blocking(move || {
            dialog
                .dialog()
                .file()
                .add_filter("Subtitles", &["srt", "vtt", "ass", "ssa", "sub"])
                .blocking_pick_file()
        })
        .await
        .map_err(|e| CommandError::new("dialog_failed", e.to_string()))?;
        let Some(file) = picked else { return Ok(false) };
        let path = file
            .into_path()
            .map_err(|e| CommandError::new("invalid_file", e.to_string()))?;
        player.send(&app, imp::Cmd::AddSubtitle(path))?;
        Ok(true)
    }
    #[cfg(not(windows))]
    {
        let _ = (app, player);
        Err(unavailable())
    }
}

/// Equalizer gains in dB at 60, 230, 910, 3.6k, 7k and 14k Hz (Windows v2
/// design), or `None` to turn it off. Files are never modified.
#[tauri::command]
pub async fn native_player_equalizer(
    app: AppHandle,
    player: State<'_, NativePlayer>,
    gains: Option<Vec<f64>>,
) -> CmdResult<()> {
    let gains = match gains {
        None => None,
        Some(g) if g.len() == 6 && g.iter().all(|v| v.is_finite()) => {
            let mut out = [0f32; 6];
            for (o, v) in out.iter_mut().zip(g) {
                *o = v.clamp(-12.0, 12.0) as f32;
            }
            Some(out)
        }
        Some(_) => return Err(CommandError::new("invalid_equalizer", "Six gains expected")),
    };
    #[cfg(windows)]
    return player.send(&app, imp::Cmd::Equalizer(gains));
    #[cfg(not(windows))]
    {
        let _ = (app, player, gains);
        Err(unavailable())
    }
}

/// Places the picture (logical px of the main window), or hides it.
#[tauri::command]
#[allow(clippy::too_many_arguments)]
pub async fn native_player_frame(
    app: AppHandle,
    player: State<'_, NativePlayer>,
    x: f64,
    y: f64,
    width: f64,
    height: f64,
    visible: bool,
) -> CmdResult<()> {
    if ![x, y, width, height]
        .iter()
        .all(|v| v.is_finite() && v.abs() < 100_000.0)
    {
        return Err(CommandError::new("invalid_frame", "Invalid video area"));
    }
    #[cfg(windows)]
    {
        player.frame(&app, (x, y, width, height), visible);
        Ok(())
    }
    #[cfg(not(windows))]
    {
        let _ = (app, player, visible);
        Err(unavailable())
    }
}

#[cfg(windows)]
mod imp {
    use std::ffi::{CStr, CString, c_char, c_int, c_uint, c_void};
    use std::path::{Path, PathBuf};
    use std::sync::atomic::{AtomicIsize, Ordering};
    use std::sync::mpsc::{self, RecvTimeoutError};
    use std::sync::{Mutex, OnceLock};
    use std::time::{Duration, Instant};

    use tauri::{AppHandle, Emitter, Manager};
    use windows::Win32::Foundation::{HMODULE, HWND, LPARAM, LRESULT, WPARAM};
    use windows::Win32::Graphics::Gdi::{BLACK_BRUSH, GetStockObject, HBRUSH};
    use windows::Win32::System::LibraryLoader::{
        GetModuleHandleW, GetProcAddress, LOAD_WITH_ALTERED_SEARCH_PATH, LoadLibraryExW,
    };
    use windows::Win32::UI::WindowsAndMessaging::{
        CS_DBLCLKS, CreateWindowExW, DefWindowProcW, HWND_TOP, RegisterClassW, SW_HIDE,
        SWP_NOACTIVATE, SWP_SHOWWINDOW, SetWindowPos, ShowWindow, WINDOW_EX_STYLE,
        WM_LBUTTONDBLCLK, WM_LBUTTONUP, WNDCLASSW, WS_CHILD, WS_CLIPCHILDREN, WS_CLIPSIBLINGS,
    };
    use windows::core::{HSTRING, PCSTR, PCWSTR, w};

    use super::{
        CLICK_EVENT, NativeStatus, STATE_EVENT, StateEvent, TRACKS_EVENT, Track, TracksEvent,
    };
    use crate::commands::CommandError;

    type Inst = *mut c_void;
    type Media = *mut c_void;
    type Player = *mut c_void;

    #[repr(C)]
    struct TrackDescription {
        id: c_int,
        name: *const c_char,
        next: *mut TrackDescription,
    }

    /// The libVLC 3 functions used, resolved at run time.
    struct Vlc {
        new: unsafe extern "C" fn(c_int, *const *const c_char) -> Inst,
        version: unsafe extern "C" fn() -> *const c_char,
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
        audio_tracks: unsafe extern "C" fn(Player) -> *mut TrackDescription,
        audio_set_track: unsafe extern "C" fn(Player, c_int) -> c_int,
        audio_get_track: unsafe extern "C" fn(Player) -> c_int,
        audio_set_volume: unsafe extern "C" fn(Player, c_int) -> c_int,
        audio_set_mute: unsafe extern "C" fn(Player, c_int),
        spu_tracks: unsafe extern "C" fn(Player) -> *mut TrackDescription,
        spu_set: unsafe extern "C" fn(Player, c_int) -> c_int,
        spu_get: unsafe extern "C" fn(Player) -> c_int,
        spu_set_delay: unsafe extern "C" fn(Player, i64) -> c_int,
        tracks_release: unsafe extern "C" fn(*mut TrackDescription),
        add_slave: unsafe extern "C" fn(Player, c_int, *const c_char, bool) -> c_int,
        mouse_input: unsafe extern "C" fn(Player, c_uint),
        key_input: unsafe extern "C" fn(Player, c_uint),
        eq_new: unsafe extern "C" fn() -> *mut c_void,
        eq_release: unsafe extern "C" fn(*mut c_void),
        eq_set_amp: unsafe extern "C" fn(*mut c_void, f32, c_uint) -> c_int,
        eq_band_count: unsafe extern "C" fn() -> c_uint,
        eq_band_frequency: unsafe extern "C" fn(c_uint) -> f32,
        set_equalizer: unsafe extern "C" fn(Player, *mut c_void) -> c_int,
    }

    unsafe fn sym<T>(lib: HMODULE, name: &str) -> Result<T, String> {
        let cname = CString::new(name).map_err(|e| e.to_string())?;
        let f = unsafe { GetProcAddress(lib, PCSTR(cname.as_ptr() as *const u8)) }
            .ok_or_else(|| format!("libVLC: missing {name}"))?;
        // SAFETY: `T` is the documented libVLC 3 signature of `name`.
        Ok(unsafe { std::mem::transmute_copy(&f) })
    }

    impl Vlc {
        fn load(dir: &Path) -> Result<Self, String> {
            let dll = HSTRING::from(dir.join("libvlc.dll").as_os_str());
            // Full path + altered search path: libvlccore.dll is taken from
            // the same folder, never from an installed VLC.
            let lib = unsafe { LoadLibraryExW(&dll, None, LOAD_WITH_ALTERED_SEARCH_PATH) }
                .map_err(|e| format!("libVLC could not be loaded: {e}"))?;
            unsafe {
                Ok(Self {
                    new: sym(lib, "libvlc_new")?,
                    version: sym(lib, "libvlc_get_version")?,
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
                    audio_tracks: sym(lib, "libvlc_audio_get_track_description")?,
                    audio_set_track: sym(lib, "libvlc_audio_set_track")?,
                    audio_get_track: sym(lib, "libvlc_audio_get_track")?,
                    audio_set_volume: sym(lib, "libvlc_audio_set_volume")?,
                    audio_set_mute: sym(lib, "libvlc_audio_set_mute")?,
                    spu_tracks: sym(lib, "libvlc_video_get_spu_description")?,
                    spu_set: sym(lib, "libvlc_video_set_spu")?,
                    spu_get: sym(lib, "libvlc_video_get_spu")?,
                    spu_set_delay: sym(lib, "libvlc_video_set_spu_delay")?,
                    tracks_release: sym(lib, "libvlc_track_description_list_release")?,
                    add_slave: sym(lib, "libvlc_media_player_add_slave")?,
                    mouse_input: sym(lib, "libvlc_video_set_mouse_input")?,
                    key_input: sym(lib, "libvlc_video_set_key_input")?,
                    eq_new: sym(lib, "libvlc_audio_equalizer_new")?,
                    eq_release: sym(lib, "libvlc_audio_equalizer_release")?,
                    eq_set_amp: sym(lib, "libvlc_audio_equalizer_set_amp_at_index")?,
                    eq_band_count: sym(lib, "libvlc_audio_equalizer_get_band_count")?,
                    eq_band_frequency: sym(lib, "libvlc_audio_equalizer_get_band_frequency")?,
                    set_equalizer: sym(lib, "libvlc_media_player_set_equalizer")?,
                })
            }
        }

        fn tracks(&self, list: *mut TrackDescription) -> Vec<Track> {
            let mut out = Vec::new();
            let mut node = list;
            while !node.is_null() && out.len() < 64 {
                let t = unsafe { &*node };
                let name = if t.name.is_null() {
                    String::new()
                } else {
                    unsafe { CStr::from_ptr(t.name) }
                        .to_string_lossy()
                        .chars()
                        .take(120)
                        .collect()
                };
                out.push(Track { id: t.id, name });
                node = t.next;
            }
            if !list.is_null() {
                unsafe { (self.tracks_release)(list) };
            }
            out
        }
    }

    pub enum Cmd {
        Open {
            path: PathBuf,
            start: f64,
            autoplay: bool,
            instance: u32,
        },
        Play,
        Pause,
        Stop,
        Seek(f64),
        Rate(f32),
        Volume(f64, bool),
        AudioTrack(i32),
        Subtitle(i32),
        SubtitleDelay(i64),
        AddSubtitle(PathBuf),
        /// Gains in dB at `EQ_BANDS`, or `None` for no equalizer.
        Equalizer(Option<[f32; 6]>),
    }

    /// Bands of the Windows v2 equalizer (Hz); libVLC's own bands get gains
    /// interpolated between them on a log scale.
    pub const EQ_BANDS: [f32; 6] = [60.0, 230.0, 910.0, 3600.0, 7000.0, 14000.0];

    pub(super) fn gain_at(freq: f32, gains: &[f32; 6]) -> f32 {
        let x = freq.max(1.0).log10();
        let xs = EQ_BANDS.map(|f| f.log10());
        if x <= xs[0] {
            return gains[0];
        }
        for i in 0..5 {
            if x <= xs[i + 1] {
                let t = (x - xs[i]) / (xs[i + 1] - xs[i]);
                return gains[i] + t * (gains[i + 1] - gains[i]);
            }
        }
        gains[5]
    }

    /// Gives the equalizer (or none) to a player; libVLC copies it.
    fn apply_equalizer(vlc: &Vlc, mp: Player, gains: Option<&[f32; 6]>) {
        unsafe {
            let Some(gains) = gains else {
                (vlc.set_equalizer)(mp, std::ptr::null_mut());
                return;
            };
            let eq = (vlc.eq_new)();
            if eq.is_null() {
                return;
            }
            for band in 0..(vlc.eq_band_count)() {
                let gain = gain_at((vlc.eq_band_frequency)(band), gains).clamp(-20.0, 20.0);
                (vlc.eq_set_amp)(eq, gain, band);
            }
            (vlc.set_equalizer)(mp, eq);
            (vlc.eq_release)(eq);
        }
    }

    /// The picture's window (isize: HWND is not Send).
    static VIDEO_HWND: AtomicIsize = AtomicIsize::new(0);
    static APP: OnceLock<AppHandle> = OnceLock::new();

    /// The worker's command channel and libVLC version, or why it is off.
    type Started = Result<(mpsc::Sender<Cmd>, String), String>;

    pub struct NativePlayer {
        dir: Option<PathBuf>,
        /// Started on first use; `Err` keeps the reason it is unavailable.
        worker: Mutex<Option<Started>>,
    }

    impl NativePlayer {
        pub fn new(dir: Option<PathBuf>) -> Self {
            Self {
                dir: dir.map(|d| plain_path(&d)),
                worker: Mutex::new(None),
            }
        }

        fn started(&self, app: &AppHandle) -> Started {
            let mut worker = self.worker.lock().unwrap_or_else(|e| e.into_inner());
            if let Some(w) = worker.as_ref() {
                return w.clone();
            }
            let result = self.start(app);
            *worker = Some(result.clone());
            result
        }

        fn start(&self, app: &AppHandle) -> Started {
            let dir = self
                .dir
                .clone()
                .ok_or_else(|| "libVLC is not shipped with this build".to_owned())?;
            let _ = APP.set(app.clone());
            let hwnd = create_video_window(app)?;
            VIDEO_HWND.store(hwnd, Ordering::SeqCst);
            let (tx, rx) = mpsc::channel();
            let (ready_tx, ready_rx) = mpsc::channel();
            let app = app.clone();
            std::thread::Builder::new()
                .name("libvlc".into())
                .spawn(move || worker(app, dir, hwnd, rx, ready_tx))
                .map_err(|e| e.to_string())?;
            let version = ready_rx
                .recv_timeout(Duration::from_secs(20))
                .map_err(|_| "libVLC did not start in time".to_owned())??;
            Ok((tx, version))
        }

        pub fn status(&self, app: &AppHandle) -> NativeStatus {
            match self.started(app) {
                Ok((_, version)) => NativeStatus {
                    available: true,
                    version: Some(version),
                    reason: None,
                },
                Err(reason) => NativeStatus {
                    available: false,
                    version: None,
                    reason: Some(reason),
                },
            }
        }

        pub fn send(&self, app: &AppHandle, cmd: Cmd) -> Result<(), CommandError> {
            let (tx, _) = self.started(app).map_err(|_| super::unavailable())?;
            tx.send(cmd).map_err(|_| super::unavailable())
        }

        pub fn frame(&self, app: &AppHandle, rect: (f64, f64, f64, f64), visible: bool) {
            let hwnd = VIDEO_HWND.load(Ordering::SeqCst);
            if hwnd == 0 {
                return;
            }
            let scale = app
                .get_window("main")
                .and_then(|w| w.scale_factor().ok())
                .unwrap_or(1.0);
            let shown = visible && rect.2 >= 1.0 && rect.3 >= 1.0;
            let px = (
                (rect.0 * scale).round() as i32,
                (rect.1 * scale).round() as i32,
                (rect.2 * scale).round().max(1.0) as i32,
                (rect.3 * scale).round().max(1.0) as i32,
            );
            let _ = app.run_on_main_thread(move || unsafe {
                let h = HWND(hwnd as *mut c_void);
                if shown {
                    let _ = SetWindowPos(
                        h,
                        Some(HWND_TOP),
                        px.0,
                        px.1,
                        px.2,
                        px.3,
                        SWP_SHOWWINDOW | SWP_NOACTIVATE,
                    );
                } else {
                    let _ = ShowWindow(h, SW_HIDE);
                }
            });
        }
    }

    unsafe extern "system" fn video_proc(h: HWND, m: u32, w: WPARAM, l: LPARAM) -> LRESULT {
        // Clicks on the picture go to the interface (play / pause, full
        // screen); keyboard focus stays with it.
        let event = match m {
            WM_LBUTTONUP => Some("click"),
            WM_LBUTTONDBLCLK => Some("dblclick"),
            _ => None,
        };
        if let (Some(event), Some(app)) = (event, APP.get()) {
            let _ = app.emit_to("main", CLICK_EVENT, event);
            if let Some(ui) = app.get_webview("main") {
                let _ = ui.set_focus();
            }
            return LRESULT(0);
        }
        unsafe { DefWindowProcW(h, m, w, l) }
    }

    /// Creates the picture's child window, hidden (main thread).
    fn create_video_window(app: &AppHandle) -> Result<isize, String> {
        let parent = app
            .get_window("main")
            .and_then(|w| w.hwnd().ok())
            .map(|h| h.0 as isize)
            .ok_or_else(|| "no main window".to_owned())?;
        let (tx, rx) = mpsc::channel();
        app.run_on_main_thread(move || {
            let hwnd = unsafe {
                let instance = GetModuleHandleW(None).unwrap_or_default();
                let class = WNDCLASSW {
                    style: CS_DBLCLKS,
                    lpfnWndProc: Some(video_proc),
                    hInstance: instance.into(),
                    lpszClassName: w!("MiarinaVideo"),
                    hbrBackground: HBRUSH(GetStockObject(BLACK_BRUSH).0),
                    ..Default::default()
                };
                RegisterClassW(&class);
                CreateWindowExW(
                    WINDOW_EX_STYLE(0),
                    w!("MiarinaVideo"),
                    PCWSTR::null(),
                    WS_CHILD | WS_CLIPSIBLINGS | WS_CLIPCHILDREN,
                    0,
                    0,
                    1,
                    1,
                    Some(HWND(parent as *mut c_void)),
                    None,
                    Some(instance.into()),
                    None,
                )
                .map(|h| h.0 as isize)
                .unwrap_or(0)
            };
            let _ = tx.send(hwnd);
        })
        .map_err(|e| e.to_string())?;
        match rx.recv_timeout(Duration::from_secs(5)) {
            Ok(h) if h != 0 => Ok(h),
            _ => Err("the video window could not be created".into()),
        }
    }

    struct Current {
        mp: Player,
        instance: u32,
        /// Seek once playing (libVLC opens asynchronously).
        start: Option<f64>,
        /// Pause once playing (load without autoplay).
        hold: bool,
        last: Option<StateEvent>,
        tracks: Option<TracksEvent>,
        started: Instant,
        delay: i64,
        /// Volume, mute and rate last given to this file.
        applied: Option<(f64, bool, f32)>,
        /// Equalizer version last given to this file.
        eq_applied: u64,
    }

    fn state_name(s: c_int) -> &'static str {
        match s {
            3 => "playing",
            4 => "paused",
            6 => "ended",
            7 => "error",
            5 => "idle",
            _ => "loading",
        }
    }

    fn worker(
        app: AppHandle,
        dir: PathBuf,
        hwnd: isize,
        rx: mpsc::Receiver<Cmd>,
        ready: mpsc::Sender<Result<String, String>>,
    ) {
        // SAFETY: read by libVLC in this process only.
        unsafe { std::env::set_var("VLC_PLUGIN_PATH", dir.join("plugins")) };
        let vlc = match Vlc::load(&dir) {
            Ok(v) => v,
            Err(e) => {
                let _ = ready.send(Err(e));
                return;
            }
        };
        let args: Vec<CString> = [
            "--no-video-title-show",
            "--no-osd",
            "--no-snapshot-preview",
            "--quiet",
            "--no-stats",
        ]
        .iter()
        .map(|a| CString::new(*a).unwrap_or_default())
        .collect();
        let argv: Vec<*const c_char> = args.iter().map(|a| a.as_ptr()).collect();
        let inst = unsafe { (vlc.new)(argv.len() as c_int, argv.as_ptr()) };
        if inst.is_null() {
            let _ = ready.send(Err("libVLC could not start".into()));
            return;
        }
        let version = unsafe { CStr::from_ptr((vlc.version)()) }
            .to_string_lossy()
            .into_owned();
        let _ = ready.send(Ok(version));

        let mut current: Option<Current> = None;
        let mut volume = (1.0f64, false);
        let mut rate = 1.0f32;
        let mut equalizer: Option<[f32; 6]> = None;
        // Starts at 1 so that a new file always gets the current setting.
        let mut eq_version = 1u64;
        let emit_state = |app: &AppHandle, e: &StateEvent| {
            let _ = app.emit_to("main", STATE_EVENT, e.clone());
        };
        let release = |vlc: &Vlc, c: Current| unsafe {
            (vlc.stop)(c.mp);
            (vlc.player_release)(c.mp);
        };

        loop {
            match rx.recv_timeout(Duration::from_millis(250)) {
                Ok(cmd) => match cmd {
                    Cmd::Open {
                        path,
                        start,
                        autoplay,
                        instance,
                    } => {
                        if let Some(c) = current.take() {
                            release(&vlc, c);
                        }
                        // WIN-02: an unreadable file is not a format problem.
                        if let Err(e) = std::fs::File::open(&path) {
                            let _ = e;
                            emit_state(
                                &app,
                                &StateEvent {
                                    instance,
                                    state: "error",
                                    position: 0.0,
                                    duration: 0.0,
                                    error: Some("read"),
                                },
                            );
                            continue;
                        }
                        let cpath =
                            CString::new(path.to_string_lossy().as_bytes()).unwrap_or_default();
                        let media = unsafe { (vlc.media_new_path)(inst, cpath.as_ptr()) };
                        if media.is_null() {
                            emit_state(
                                &app,
                                &StateEvent {
                                    instance,
                                    state: "error",
                                    position: 0.0,
                                    duration: 0.0,
                                    error: Some("unsupported"),
                                },
                            );
                            continue;
                        }
                        let mp = unsafe { (vlc.player_new)(media) };
                        unsafe {
                            (vlc.media_release)(media);
                            (vlc.set_hwnd)(mp, hwnd as *mut c_void);
                            (vlc.mouse_input)(mp, 0);
                            (vlc.key_input)(mp, 0);
                            (vlc.play)(mp);
                        }
                        current = Some(Current {
                            mp,
                            instance,
                            start: (start > 0.0).then_some(start),
                            hold: !autoplay,
                            last: None,
                            tracks: None,
                            started: Instant::now(),
                            delay: 0,
                            applied: None,
                            eq_applied: 0,
                        });
                    }
                    Cmd::Stop => {
                        if let Some(c) = current.take() {
                            let instance = c.instance;
                            release(&vlc, c);
                            emit_state(
                                &app,
                                &StateEvent {
                                    instance,
                                    state: "idle",
                                    position: 0.0,
                                    duration: 0.0,
                                    error: None,
                                },
                            );
                        }
                    }
                    Cmd::Volume(v, muted) => volume = (v, muted),
                    Cmd::Equalizer(gains) => {
                        equalizer = gains;
                        eq_version += 1;
                    }
                    Cmd::Rate(r) => rate = r,
                    other => {
                        if let Some(c) = current.as_mut() {
                            apply(&vlc, c, other);
                        }
                    }
                },
                Err(RecvTimeoutError::Timeout) => {}
                Err(RecvTimeoutError::Disconnected) => break,
            }

            let Some(c) = current.as_mut() else {
                continue;
            };
            let s = unsafe { (vlc.get_state)(c.mp) };
            if s == 3 || s == 4 {
                // Settings that apply to every file, sent when they change.
                let wanted = (volume.0, volume.1, rate);
                if c.applied != Some(wanted) {
                    unsafe {
                        (vlc.audio_set_volume)(c.mp, (volume.0 * 100.0).round() as c_int);
                        (vlc.audio_set_mute)(c.mp, volume.1 as c_int);
                        (vlc.set_rate)(c.mp, rate);
                    }
                    c.applied = Some(wanted);
                }
                if c.eq_applied != eq_version {
                    apply_equalizer(&vlc, c.mp, equalizer.as_ref());
                    c.eq_applied = eq_version;
                }
            }
            if s == 3 {
                if let Some(start) = c.start.take() {
                    unsafe { (vlc.set_time)(c.mp, (start * 1000.0) as i64) };
                }
                if c.hold {
                    c.hold = false;
                    unsafe { (vlc.set_pause)(c.mp, 1) };
                }
            }
            let shown = if c.hold && s == 3 { 4 } else { s };
            let event = StateEvent {
                instance: c.instance,
                state: state_name(shown),
                position: unsafe { (vlc.get_time)(c.mp) }.max(0) as f64 / 1000.0,
                duration: unsafe { (vlc.get_length)(c.mp) }.max(0) as f64 / 1000.0,
                error: (s == 7).then_some("unsupported"),
            };
            if c.last.as_ref() != Some(&event) {
                emit_state(&app, &event);
                c.last = Some(event);
            }
            // Tracks appear once the file is open; subtitles can be added.
            if s == 3 || s == 4 || c.started.elapsed() > Duration::from_secs(1) {
                let tracks = TracksEvent {
                    instance: c.instance,
                    audio: vlc.tracks(unsafe { (vlc.audio_tracks)(c.mp) }),
                    subtitles: vlc.tracks(unsafe { (vlc.spu_tracks)(c.mp) }),
                    audio_id: unsafe { (vlc.audio_get_track)(c.mp) },
                    subtitle_id: unsafe { (vlc.spu_get)(c.mp) },
                    subtitle_delay: c.delay,
                };
                if c.tracks.as_ref() != Some(&tracks) {
                    let _ = app.emit_to("main", TRACKS_EVENT, tracks.clone());
                    c.tracks = Some(tracks);
                }
            }
        }
        if let Some(c) = current.take() {
            release(&vlc, c);
        }
    }

    fn apply(vlc: &Vlc, c: &mut Current, cmd: Cmd) {
        unsafe {
            match cmd {
                Cmd::Play => {
                    c.hold = false;
                    if (vlc.get_state)(c.mp) == 6 {
                        // Played to the end: start again.
                        (vlc.stop)(c.mp);
                        (vlc.play)(c.mp);
                    } else {
                        (vlc.set_pause)(c.mp, 0);
                    }
                }
                Cmd::Pause => (vlc.set_pause)(c.mp, 1),
                Cmd::Seek(secs) => {
                    if (vlc.get_state)(c.mp) == 3 || (vlc.get_state)(c.mp) == 4 {
                        (vlc.set_time)(c.mp, (secs * 1000.0) as i64);
                    } else {
                        c.start = Some(secs);
                    }
                }
                Cmd::AudioTrack(id) => {
                    (vlc.audio_set_track)(c.mp, id);
                }
                Cmd::Subtitle(id) => {
                    (vlc.spu_set)(c.mp, id);
                }
                Cmd::SubtitleDelay(ms) => {
                    c.delay = ms;
                    (vlc.spu_set_delay)(c.mp, ms * 1000);
                }
                Cmd::AddSubtitle(path) => {
                    let uri = file_uri(&path);
                    let c_uri = CString::new(uri).unwrap_or_default();
                    (vlc.add_slave)(c.mp, 0, c_uri.as_ptr(), true);
                }
                Cmd::Open { .. }
                | Cmd::Stop
                | Cmd::Volume(..)
                | Cmd::Rate(_)
                | Cmd::Equalizer(_) => {}
            }
        }
    }

    /// libVLC finds no module through an extended-length path (the
    /// `\\?\C:\…` form Tauri gives resource folders): `libvlc_new` fails.
    pub(super) fn plain_path(path: &Path) -> PathBuf {
        let text = path.to_string_lossy();
        if let Some(rest) = text.strip_prefix(r"\\?\UNC\") {
            PathBuf::from(format!(r"\\{rest}"))
        } else if let Some(rest) = text.strip_prefix(r"\\?\") {
            PathBuf::from(rest)
        } else {
            path.to_path_buf()
        }
    }

    /// `C:\a b\été.srt` → `file:///C:/a%20b/%C3%A9t%C3%A9.srt`.
    pub(super) fn file_uri(path: &Path) -> String {
        let text = path.to_string_lossy().replace('\\', "/");
        let mut out = String::from("file:///");
        for b in text.trim_start_matches('/').bytes() {
            if b.is_ascii_alphanumeric() || b"/-._~:".contains(&b) {
                out.push(b as char);
            } else {
                out.push_str(&format!("%{b:02X}"));
            }
        }
        out
    }

    #[cfg(test)]
    mod tests {
        use super::*;

        #[test]
        fn subtitle_paths_become_file_uris() {
            assert_eq!(
                file_uri(Path::new("C:\\a b\\été.srt")),
                "file:///C:/a%20b/%C3%A9t%C3%A9.srt"
            );
            assert_eq!(
                plain_path(Path::new(r"\\?\C:\app\tools\libvlc")),
                PathBuf::from(r"C:\app\tools\libvlc")
            );
            assert_eq!(
                plain_path(Path::new(r"\\?\UNC\server\share\libvlc")),
                PathBuf::from(r"\\server\share\libvlc")
            );
            assert_eq!(plain_path(Path::new(r"C:\x")), PathBuf::from(r"C:\x"));
            let gains = [6.0, 4.0, 0.0, -1.0, 0.0, 2.0];
            assert_eq!(gain_at(30.0, &gains), 6.0);
            assert_eq!(gain_at(230.0, &gains), 4.0);
            assert_eq!(gain_at(16_000.0, &gains), 2.0);
            let mid = gain_at(117.5, &gains);
            assert!(mid < 6.0 && mid > 4.0, "{mid}");
            assert_eq!(state_name(3), "playing");
            assert_eq!(state_name(1), "loading");
            assert_eq!(state_name(7), "error");
        }
    }
}
