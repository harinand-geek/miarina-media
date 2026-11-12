import { backend } from '../../services/backend';
import type { NativePlayerAction, NativePlayerStateEvent } from '../../services/types';
import {
  reportEnded,
  reportEngine,
  usePlayer,
  type EngineReport,
  type PlayerEngine,
} from '../../stores/player';

/** libVLC states → player store report (WIN-02: access vs format errors). */
export function reportOf(e: NativePlayerStateEvent): EngineReport | null {
  const base: EngineReport = { position: e.position };
  if (e.duration > 0) base.duration = e.duration;
  switch (e.state) {
    case 'loading':
      return { ...base, state: 'buffering' };
    case 'playing':
      return { ...base, state: 'playing', error: null };
    case 'paused':
      return { ...base, state: 'paused' };
    case 'error':
      return { state: 'error', error: { kind: e.error === 'read' ? 'read' : 'unsupported' } };
    default:
      return null;
  }
}

/**
 * The Windows engine (decision 0005): libVLC in Rust, the picture in a
 * native window over the video screen. Events of an older file are
 * dropped by instance, as with the WebView engine.
 */
export function createNativeEngine() {
  let instance = -1;
  const control = (action: NativePlayerAction, value?: number) =>
    void backend.nativePlayerControl(action, value).catch(() => {});

  const stopState = backend.onNativePlayerState((e) => {
    if (e.instance !== instance) return;
    if (e.state === 'ended') {
      reportEnded(instance);
      return;
    }
    const report = reportOf(e);
    if (report) reportEngine(instance, report);
  });
  const stopTracks = backend.onNativePlayerTracks((e) => {
    if (e.instance !== instance) return;
    usePlayer.setState({
      tracks: {
        // libVLC lists "Disable" (-1) among audio tracks: not a track.
        audio: e.audio.filter((t) => t.id >= 0),
        subtitles: e.subtitles.filter((t) => t.id >= 0),
        audioId: e.audioId,
        subtitleId: e.subtitleId,
        subtitleDelay: e.subtitleDelay,
      },
    });
  });

  const engine: PlayerEngine = {
    native: true,
    load: (media, inst, startAt, autoplay) => {
      instance = inst;
      usePlayer.setState({ tracks: null });
      backend
        .nativePlayerOpen(media.id, startAt, autoplay, inst)
        .catch(() => reportEngine(inst, { state: 'error', error: { kind: 'unknown' } }));
    },
    play: () => control('play'),
    pause: () => control('pause'),
    seek: (secs) => control('seek', secs),
    setVolume: (volume, muted) => void backend.nativePlayerVolume(volume, muted).catch(() => {}),
    setRate: (rate) => control('rate', rate),
    stop: () => {
      instance = -1;
      usePlayer.setState({ tracks: null });
      control('stop');
    },
    setAudioTrack: (id) => control('audioTrack', id),
    setSubtitle: (id) => control('subtitle', id),
    addSubtitle: () => backend.nativePlayerAddSubtitle().catch(() => false),
    setSubtitleDelay: (ms) => control('subtitleDelay', ms),
    setEqualizer: (gains) => void backend.nativePlayerEqualizer(gains).catch(() => {}),
  };

  return {
    engine,
    dispose: () => {
      stopState();
      stopTracks();
    },
  };
}
