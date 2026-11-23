//! System media controls behind `api::system_media` (Windows SMTC).

pub use platform::{set_sink, update};

#[cfg(windows)]
mod platform {
    use std::cell::RefCell;
    use std::sync::Mutex;

    use anyhow::{Result, anyhow};
    use windows::Foundation::{TimeSpan, TypedEventHandler};
    use windows::Media::{
        MediaPlaybackStatus, MediaPlaybackType, SystemMediaTransportControls,
        SystemMediaTransportControlsButton, SystemMediaTransportControlsButtonPressedEventArgs,
        SystemMediaTransportControlsTimelineProperties,
    };
    use windows::Storage::Streams::{
        DataWriter, InMemoryRandomAccessStream, RandomAccessStreamReference,
    };
    use windows::Win32::System::WinRT::ISystemMediaTransportControlsInterop;
    use windows::core::{HSTRING, factory};

    use crate::api::system_media::SystemMediaState;
    use crate::frb_generated::StreamSink;

    /// Largest cover sent to the system (a bigger file is skipped).
    const ARTWORK_MAX: u64 = 4 * 1024 * 1024;
    /// Longest text shown.
    const TEXT_MAX: usize = 300;

    static SINK: Mutex<Option<StreamSink<String>>> = Mutex::new(None);

    thread_local! {
        // Created on first use for the app's window, on its thread.
        static CONTROLS: RefCell<Option<SystemMediaTransportControls>> = const { RefCell::new(None) };
        // What the display shows (title, artist, album, cover, kind).
        static SHOWN: RefCell<Option<String>> = const { RefCell::new(None) };
    }

    pub fn set_sink(sink: StreamSink<String>) {
        *SINK.lock().unwrap_or_else(|p| p.into_inner()) = Some(sink);
    }

    fn pressed(button: SystemMediaTransportControlsButton) {
        let name = match button {
            SystemMediaTransportControlsButton::Play => "play",
            SystemMediaTransportControlsButton::Pause => "pause",
            SystemMediaTransportControlsButton::Stop => "stop",
            SystemMediaTransportControlsButton::Next => "next",
            SystemMediaTransportControlsButton::Previous => "previous",
            _ => return,
        };
        if let Some(sink) = SINK.lock().unwrap_or_else(|p| p.into_inner()).as_ref() {
            let _ = sink.add(name.to_owned());
        }
    }

    fn create() -> Result<SystemMediaTransportControls> {
        let window =
            crate::win_window::flutter_window().ok_or_else(|| anyhow!("window not found"))?;
        let interop =
            factory::<SystemMediaTransportControls, ISystemMediaTransportControlsInterop>()?;
        let controls: SystemMediaTransportControls = unsafe { interop.GetForWindow(window)? };
        controls.ButtonPressed(&TypedEventHandler::<
            SystemMediaTransportControls,
            SystemMediaTransportControlsButtonPressedEventArgs,
        >::new(|_, args| {
            if let Some(args) = args.as_ref() {
                pressed(args.Button()?);
            }
            Ok(())
        }))?;
        controls.SetIsPlayEnabled(true)?;
        controls.SetIsPauseEnabled(true)?;
        controls.SetIsStopEnabled(true)?;
        Ok(controls)
    }

    fn controls() -> Result<SystemMediaTransportControls> {
        CONTROLS.with(|c| {
            if let Some(controls) = c.borrow().as_ref() {
                return Ok(controls.clone());
            }
            let controls = create()?;
            *c.borrow_mut() = Some(controls.clone());
            Ok(controls)
        })
    }

    fn text(value: &str) -> HSTRING {
        HSTRING::from(value.chars().take(TEXT_MAX).collect::<String>())
    }

    /// The cover as an in-memory stream (the file is read once, bounded).
    fn artwork(path: &str) -> Option<RandomAccessStreamReference> {
        let size = std::fs::metadata(path).ok()?.len();
        if size == 0 || size > ARTWORK_MAX {
            return None;
        }
        let bytes = std::fs::read(path).ok()?;
        let stream = InMemoryRandomAccessStream::new().ok()?;
        let writer = DataWriter::CreateDataWriter(&stream).ok()?;
        writer.WriteBytes(&bytes).ok()?;
        writer.StoreAsync().ok()?.join().ok()?;
        writer.DetachStream().ok()?;
        stream.Seek(0).ok()?;
        RandomAccessStreamReference::CreateFromStream(&stream).ok()
    }

    fn ticks(ms: u64) -> TimeSpan {
        TimeSpan {
            Duration: i64::try_from(ms).unwrap_or(i64::MAX / 10_000) * 10_000,
        }
    }

    pub fn update(s: SystemMediaState) -> Result<()> {
        let controls = controls()?;
        if !s.has_media {
            controls.SetPlaybackStatus(MediaPlaybackStatus::Closed)?;
            controls.SetIsEnabled(false)?;
            SHOWN.with(|v| *v.borrow_mut() = None);
            return Ok(());
        }
        controls.SetIsEnabled(true)?;
        controls.SetIsNextEnabled(s.can_next)?;
        controls.SetIsPreviousEnabled(s.can_previous)?;
        controls.SetPlaybackStatus(if s.playing {
            MediaPlaybackStatus::Playing
        } else {
            MediaPlaybackStatus::Paused
        })?;

        // The display changes only with the media (the cover is read once).
        let key = format!(
            "{}\u{1}{}\u{1}{}\u{1}{:?}\u{1}{}",
            s.title, s.artist, s.album, s.artwork, s.is_video
        );
        if SHOWN.with(|v| v.borrow().as_deref() != Some(key.as_str())) {
            let display = controls.DisplayUpdater()?;
            display.ClearAll()?;
            if s.is_video {
                display.SetType(MediaPlaybackType::Video)?;
                let video = display.VideoProperties()?;
                video.SetTitle(&text(&s.title))?;
                video.SetSubtitle(&text(&s.artist))?;
            } else {
                display.SetType(MediaPlaybackType::Music)?;
                let music = display.MusicProperties()?;
                music.SetTitle(&text(&s.title))?;
                music.SetArtist(&text(&s.artist))?;
                music.SetAlbumTitle(&text(&s.album))?;
            }
            if let Some(cover) = s.artwork.as_deref().and_then(artwork) {
                display.SetThumbnail(&cover)?;
            }
            display.Update()?;
            SHOWN.with(|v| *v.borrow_mut() = Some(key));
        }

        if s.duration_ms > 0 {
            let timeline = SystemMediaTransportControlsTimelineProperties::new()?;
            timeline.SetStartTime(ticks(0))?;
            timeline.SetMinSeekTime(ticks(0))?;
            timeline.SetEndTime(ticks(s.duration_ms))?;
            timeline.SetMaxSeekTime(ticks(s.duration_ms))?;
            timeline.SetPosition(ticks(s.position_ms.min(s.duration_ms)))?;
            controls.UpdateTimelineProperties(&timeline)?;
        }
        Ok(())
    }
}

#[cfg(not(windows))]
mod platform {
    use anyhow::Result;

    use crate::api::system_media::SystemMediaState;
    use crate::frb_generated::StreamSink;

    pub fn set_sink(_: StreamSink<String>) {}

    pub fn update(_: SystemMediaState) -> Result<()> {
        Ok(())
    }
}
