import { useCallback, useEffect, useState } from 'react';
import { Button, IconButton } from '../../components/Button';
import { EmptyState } from '../../components/Feedback';
import { Icon } from '../../components/Icon';
import { formatClock } from '../../hooks/usePlaybackClock';
import { useMediaQuery } from '../../hooks/useMediaQuery';
import { backend } from '../../services/backend';
import { setFullscreen } from '../../services/window';
import type { MediaRecord } from '../../services/types';
import { formatBytes } from '../../stores/downloads';
import { useLibrary } from '../../stores/library';
import { useUi } from '../../stores/ui';
import { durationLabel, folderOf, formatLabel, qualityLabel } from '../library/format';
import { MediaThumb } from '../library/MediaThumb';
import { ThumbBackdrop, VideoBackdrop } from './Backdrop';
import { SeekBar } from './SeekBar';
import { formatRate, nextRate } from './playbackRate';
import { usePlayback } from './usePlayback';

export default function PlayerScreen() {
  const item = useUi((s) => s.nowPlaying);
  const go = useUi((s) => s.go);
  if (!item) {
    return (
      <div className="grid flex-1 place-items-center p-10">
        <EmptyState
          icon="play_circle"
          title="Nothing is playing"
          action={
            <Button
              variant="primary"
              size="sm"
              className="h-9 text-[13px]"
              onClick={() => go('library')}
            >
              Open library
            </Button>
          }
        >
          Choose a video or a song in your library.
        </EmptyState>
      </div>
    );
  }
  return <Player key={item.id} item={item} />;
}

function Player({ item }: { item: MediaRecord }) {
  const { attachMedia, ...p } = usePlayback(item);
  const [videoEl, setVideoEl] = useState<HTMLVideoElement | null>(null);
  // Stable: a new ref callback each render would detach and re-attach the
  // element every time (and loop through the state update).
  const attachVideo = useCallback(
    (el: HTMLVideoElement | null) => {
      attachMedia(el);
      setVideoEl(el);
    },
    [attachMedia],
  );
  const play = useUi((s) => s.play);
  const pushToast = useUi((s) => s.pushToast);
  const items = useLibrary((s) => s.items);
  const [subtitles, setSubtitles] = useState(false);
  const [fullscreen, setFs] = useState(false);
  const wide = useMediaQuery('(min-width: 1280px)');
  const [panelOpen, setPanelOpen] = useState(false);
  const showPanel = !fullscreen && (wide || panelOpen);
  const pipSupported = typeof document !== 'undefined' && document.pictureInPictureEnabled === true;

  const index = items.findIndex((m) => m.id === item.id);
  const upNext = items.filter((m) => m.id !== item.id && m.kind === item.kind).slice(0, 5);

  const toggleFullscreen = (on = !fullscreen) => {
    setFs(on);
    void setFullscreen(on);
  };

  const openExternal = () =>
    backend
      .libraryOpenExternal(item.id)
      .catch((e: unknown) =>
        pushToast({ tone: 'error', message: e instanceof Error ? e.message : String(e) }),
      );

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement;
      if (['INPUT', 'TEXTAREA', 'SELECT'].includes(target.tagName) || useUi.getState().confirm)
        return;
      const slider = target.getAttribute('role') === 'slider';
      if (e.key === ' ' && !slider && target.tagName !== 'BUTTON') {
        e.preventDefault();
        p.toggle();
      } else if (e.key === 'ArrowLeft' && !slider) p.skip(-10);
      else if (e.key === 'ArrowRight' && !slider) p.skip(10);
      else if (e.key.toLowerCase() === 'f' && !e.ctrlKey) toggleFullscreen();
      else if (e.key === 'Escape' && fullscreen) toggleFullscreen(false);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  });

  const isVideo = item.kind === 'video';

  return (
    <div className="flex min-h-0 flex-1">
      <div className="flex min-w-0 flex-1 flex-col bg-player text-[#F5F7FA]">
        <div className="relative grid min-h-0 flex-1 place-items-center overflow-hidden bg-[#0B1218]">
          {/* Bars around the picture: blurred current frame, or blurred cover. */}
          {isVideo ? <VideoBackdrop video={videoEl} /> : <ThumbBackdrop path={item.thumbnail} />}
          {p.src && isVideo && (
            <video
              ref={attachVideo}
              src={p.src}
              preload="metadata"
              onClick={p.toggle}
              onDoubleClick={() => toggleFullscreen()}
              className="absolute inset-0 h-full w-full object-contain"
            >
              {subtitles && null}
            </video>
          )}
          {p.src && !isVideo && <audio ref={attachMedia} src={p.src} preload="metadata" />}
          {!isVideo &&
            (item.thumbnail ? (
              <MediaThumb
                media={item}
                className="relative aspect-square h-[min(55%,320px)] rounded-[20px] shadow-menu"
              />
            ) : (
              <div className="relative grid aspect-square h-[min(55%,320px)] place-items-center rounded-[20px] bg-[#182530]">
                <Icon name="music_note" size={64} className="text-[#8FB3D9]" />
              </div>
            ))}
          {!p.src && isVideo && (
            <span className="font-mono text-[12px] font-medium text-[#64748B]">
              video surface · preview
            </span>
          )}
          <div className="pointer-events-none absolute left-5 top-4 flex flex-col gap-0.5 drop-shadow">
            <span className="text-[15px] font-bold">{item.title}</span>
            <span className="text-[12px] text-[#94A3B8]">
              {[item.sourceHost, qualityLabel(item), item.path.split('.').pop()?.toUpperCase()]
                .filter(Boolean)
                .join(' · ')}
            </span>
          </div>
          {p.error && (
            <div
              role="alert"
              className="absolute inset-x-0 bottom-6 mx-auto flex w-fit max-w-[90%] items-center gap-3 rounded-lg border border-[#2F4558] bg-[#1F2F3B] px-4 py-3 text-[13px]"
            >
              <Icon name="error" fill className="text-[#F07070]" />
              <span>This format cannot be played here ({formatLabel(item)}).</span>
              <button type="button" onClick={openExternal} className="font-bold text-accent">
                Open with system player
              </button>
            </div>
          )}
        </div>
        <div className="flex flex-col gap-2.5 border-t border-[#1B2935] bg-player-chrome px-5 pb-3.5 pt-3 [--mm-border:36_53_69] [--mm-faint-icon:58_77_94]">
          <SeekBar time={p.time} duration={p.duration} buffered={p.buffered} onSeek={p.seek} />
          <div className="flex items-center gap-1 [&_button]:text-[#F5F7FA] [&_button:hover]:bg-[#182530]">
            <IconButton
              icon="skip_previous"
              label="Previous"
              fill
              iconSize={22}
              disabled={index <= 0}
              onClick={() => items[index - 1] && play(items[index - 1]!)}
            />
            <IconButton
              icon="replay_10"
              label="Back 10 seconds"
              iconSize={22}
              onClick={() => p.skip(-10)}
            />
            <button
              type="button"
              title="Play/Pause (Space)"
              aria-label={p.playing ? 'Pause' : 'Play'}
              onClick={p.toggle}
              className="mx-1 grid h-11 w-11 place-items-center rounded-full bg-accent !text-accent-ink hover:!bg-accent-hover"
            >
              <Icon name={p.playing ? 'pause' : 'play_arrow'} size={26} fill />
            </button>
            <IconButton
              icon="forward_10"
              label="Forward 10 seconds"
              iconSize={22}
              onClick={() => p.skip(10)}
            />
            <IconButton
              icon="skip_next"
              label="Next"
              fill
              iconSize={22}
              disabled={index < 0 || index >= items.length - 1}
              onClick={() => items[index + 1] && play(items[index + 1]!)}
            />
            <div className="ml-2.5 flex items-center gap-2">
              <button
                type="button"
                aria-label={p.volume === 0 ? 'Unmute' : 'Mute'}
                onClick={() => p.setVolume(p.volume === 0 ? 0.8 : 0)}
                className="grid place-items-center !bg-transparent"
              >
                <Icon
                  name={p.volume === 0 ? 'volume_off' : 'volume_up'}
                  className="text-[#94A3B8]"
                />
              </button>
              <div
                role="slider"
                tabIndex={0}
                aria-label="Volume"
                aria-valuemin={0}
                aria-valuemax={100}
                aria-valuenow={Math.round(p.volume * 100)}
                onClick={(e) => {
                  const r = e.currentTarget.getBoundingClientRect();
                  p.setVolume((e.clientX - r.left) / r.width);
                }}
                onKeyDown={(e) => {
                  if (e.key === 'ArrowUp' || e.key === 'ArrowRight') p.setVolume(p.volume + 0.1);
                  if (e.key === 'ArrowDown' || e.key === 'ArrowLeft') p.setVolume(p.volume - 0.1);
                  e.stopPropagation();
                }}
                className="flex h-3.5 w-20 cursor-pointer items-center"
              >
                <div className="h-1 w-full rounded-full bg-[#243545]">
                  <div
                    className="h-full rounded-full bg-[#F5F7FA]"
                    style={{ width: `${p.volume * 100}%` }}
                  />
                </div>
              </div>
            </div>
            <span className="ml-3.5 font-mono text-[12.5px] font-medium text-[#94A3B8] tabular">
              <span className="text-[#F5F7FA]">{formatClock(p.time)}</span> /{' '}
              {durationLabel(p.duration)}
            </span>
            <span className="flex-1" />
            <button
              type="button"
              aria-label={`Playback speed ${p.rate}×`}
              onClick={() => p.setRate(nextRate(p.rate))}
              className="h-[30px] rounded-sm border border-[#2A3D4E] px-2.5 font-mono text-[12px] font-semibold"
            >
              {formatRate(p.rate)}
            </button>
            <IconButton
              icon="closed_caption"
              label="Subtitles (no subtitle track in this file)"
              aria-pressed={subtitles}
              disabled
              onClick={() => setSubtitles((s) => !s)}
            />
            <IconButton
              icon="picture_in_picture_alt"
              label={
                pipSupported && isVideo
                  ? 'Picture in picture'
                  : 'Picture in picture (not available here)'
              }
              disabled={!pipSupported || !isVideo || !p.src}
              onClick={() => {
                const video = document.querySelector('video');
                void video?.requestPictureInPicture?.().catch(() => {});
              }}
            />
            {!wide && !fullscreen && (
              <IconButton
                icon="view_sidebar"
                label="File details and up next"
                aria-pressed={panelOpen}
                onClick={() => setPanelOpen((o) => !o)}
              />
            )}
            <IconButton
              icon={fullscreen ? 'fullscreen_exit' : 'fullscreen'}
              label={fullscreen ? 'Exit fullscreen (Esc)' : 'Fullscreen (F)'}
              onClick={() => toggleFullscreen()}
            />
          </div>
        </div>
      </div>

      {showPanel && (
        <aside
          aria-label="File details"
          className="flex w-[300px] shrink-0 flex-col overflow-auto border-l border-divider"
        >
          <div className="flex flex-col gap-2.5 border-b border-divider p-[18px]">
            <span className="text-overline font-bold uppercase tracking-[0.06em] text-muted">
              File
            </span>
            <dl className="m-0 grid grid-cols-[90px_1fr] gap-y-2 text-[12.5px]">
              <dt className="text-muted">Format</dt>
              <dd className="m-0">{formatLabel(item)}</dd>
              {item.width && item.height && (
                <>
                  <dt className="text-muted">Resolution</dt>
                  <dd className="m-0">
                    {item.width} × {item.height}
                  </dd>
                </>
              )}
              <dt className="text-muted">Size</dt>
              <dd className="m-0">{formatBytes(item.sizeBytes)}</dd>
              <dt className="text-muted">Location</dt>
              <dd className="m-0 break-all font-mono text-[11.5px]" title={item.path}>
                {folderOf(item.path)}
              </dd>
            </dl>
          </div>
          <div className="flex flex-col gap-1 px-2.5 py-[18px]">
            <span className="px-2 pb-2 text-overline font-bold uppercase tracking-[0.06em] text-muted">
              Up next
            </span>
            {upNext.length === 0 && (
              <p className="m-0 px-2 text-[12.5px] text-muted">Nothing else yet.</p>
            )}
            {upNext.map((u) => (
              <button
                key={u.id}
                type="button"
                onClick={() => play(u)}
                className="flex gap-2.5 rounded-sm p-2 text-left hover:bg-surface"
              >
                <MediaThumb media={u} className="h-[45px] w-20 rounded-xs" />
                <span className="flex min-w-0 flex-col gap-0.5">
                  <span className="truncate text-[12.5px] font-semibold">{u.title}</span>
                  <span className="text-[11.5px] text-muted">
                    {durationLabel(u.durationSecs)} · {qualityLabel(u)}
                  </span>
                </span>
              </button>
            ))}
          </div>
        </aside>
      )}
    </div>
  );
}
