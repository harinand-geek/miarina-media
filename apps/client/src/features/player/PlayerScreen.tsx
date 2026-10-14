import { useEffect, useState } from 'react';
import { Button, IconButton } from '../../components/Button';
import { EmptyState, Thumbnail } from '../../components/Feedback';
import { Icon } from '../../components/Icon';
import { LIBRARY } from '../../dev/fixtures';
import { formatClock, usePlaybackClock } from '../../hooks/usePlaybackClock';
import { useMediaQuery } from '../../hooks/useMediaQuery';
import { setFullscreen } from '../../services/window';
import type { LibraryItem } from '../../services/types';
import { useUi } from '../../stores/ui';
import { SeekBar } from './SeekBar';
import { formatRate, nextRate } from './playbackRate';

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

function Player({ item }: { item: LibraryItem }) {
  const { time, playing, toggle, seek, skip } = usePlaybackClock(
    item.durationSec,
    Math.floor(item.durationSec * 0.34),
  );
  const play = useUi((s) => s.play);
  const [rate, setRate] = useState(1);
  const [volume, setVolume] = useState(0.7);
  const [subtitles, setSubtitles] = useState(false);
  const [fullscreen, setFs] = useState(false);
  const wide = useMediaQuery('(min-width: 1280px)');
  const [panelOpen, setPanelOpen] = useState(false);
  const showPanel = !fullscreen && (wide || panelOpen);

  const upNext = LIBRARY.filter((m) => m.kind === 'video' && m.id !== item.id).slice(0, 5);
  const index = LIBRARY.findIndex((m) => m.id === item.id);

  const toggleFullscreen = (on = !fullscreen) => {
    setFs(on);
    void setFullscreen(on);
  };

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement;
      if (['INPUT', 'TEXTAREA', 'SELECT'].includes(target.tagName) || useUi.getState().confirm)
        return;
      if (
        e.key === ' ' &&
        target.getAttribute('role') !== 'slider' &&
        target.tagName !== 'BUTTON'
      ) {
        e.preventDefault();
        toggle();
      } else if (e.key === 'ArrowLeft' && target.getAttribute('role') !== 'slider') skip(-10);
      else if (e.key === 'ArrowRight' && target.getAttribute('role') !== 'slider') skip(10);
      else if (e.key.toLowerCase() === 'f' && !e.ctrlKey) toggleFullscreen();
      else if (e.key === 'Escape' && fullscreen) toggleFullscreen(false);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  });

  return (
    <div className="flex min-h-0 flex-1">
      <div className="flex min-w-0 flex-1 flex-col bg-player text-[#F5F7FA]">
        <div className="relative grid min-h-0 flex-1 place-items-center bg-[repeating-linear-gradient(135deg,#0E161D_0_10px,#0B1218_10px_20px)]">
          <span className="font-mono text-[12px] font-medium text-[#64748B]">
            video surface · 16:9
          </span>
          <div className="absolute left-5 top-4 flex flex-col gap-0.5">
            <span className="text-[15px] font-bold">{item.title}</span>
            <span className="text-[12px] text-[#94A3B8]">
              {item.source} · {item.quality} · MP4
            </span>
          </div>
          {subtitles && (
            <span className="absolute bottom-6 rounded-xs bg-[rgb(0_0_0/0.6)] px-2 py-1 text-[15px]">
              [Subtitles preview]
            </span>
          )}
        </div>
        <div className="flex flex-col gap-2.5 border-t border-[#1B2935] bg-player-chrome px-5 pb-3.5 pt-3 [--mm-border:36_53_69] [--mm-faint-icon:58_77_94]">
          <SeekBar
            time={time}
            duration={item.durationSec}
            buffered={time + item.durationSec * 0.18}
            onSeek={seek}
          />
          <div className="flex items-center gap-1 [&_button]:text-[#F5F7FA] [&_button:hover]:bg-[#182530]">
            <IconButton
              icon="skip_previous"
              label="Previous"
              fill
              iconSize={22}
              disabled={index <= 0}
              onClick={() => play(LIBRARY[index - 1] ?? item)}
            />
            <IconButton
              icon="replay_10"
              label="Back 10 seconds"
              iconSize={22}
              onClick={() => skip(-10)}
            />
            <button
              type="button"
              title="Play/Pause (Space)"
              aria-label={playing ? 'Pause' : 'Play'}
              onClick={toggle}
              className="mx-1 grid h-11 w-11 place-items-center rounded-full bg-accent !text-accent-ink hover:!bg-accent-hover"
            >
              <Icon name={playing ? 'pause' : 'play_arrow'} size={26} fill />
            </button>
            <IconButton
              icon="forward_10"
              label="Forward 10 seconds"
              iconSize={22}
              onClick={() => skip(10)}
            />
            <IconButton
              icon="skip_next"
              label="Next"
              fill
              iconSize={22}
              disabled={index >= LIBRARY.length - 1}
              onClick={() => play(LIBRARY[index + 1] ?? item)}
            />
            <div className="ml-2.5 flex items-center gap-2">
              <Icon name={volume === 0 ? 'volume_off' : 'volume_up'} className="text-[#94A3B8]" />
              <div
                role="slider"
                tabIndex={0}
                aria-label="Volume"
                aria-valuemin={0}
                aria-valuemax={100}
                aria-valuenow={Math.round(volume * 100)}
                onClick={(e) => {
                  const r = e.currentTarget.getBoundingClientRect();
                  setVolume(Math.min(1, Math.max(0, (e.clientX - r.left) / r.width)));
                }}
                onKeyDown={(e) => {
                  if (e.key === 'ArrowUp' || e.key === 'ArrowRight')
                    setVolume((v) => Math.min(1, v + 0.1));
                  if (e.key === 'ArrowDown' || e.key === 'ArrowLeft')
                    setVolume((v) => Math.max(0, v - 0.1));
                  e.stopPropagation();
                }}
                className="flex h-3.5 w-20 cursor-pointer items-center"
              >
                <div className="h-1 w-full rounded-full bg-[#243545]">
                  <div
                    className="h-full rounded-full bg-[#F5F7FA]"
                    style={{ width: `${volume * 100}%` }}
                  />
                </div>
              </div>
            </div>
            <span className="ml-3.5 font-mono text-[12.5px] font-medium text-[#94A3B8] tabular">
              <span className="text-[#F5F7FA]">{formatClock(time)}</span> / {item.duration}
            </span>
            <span className="flex-1" />
            <button
              type="button"
              aria-label={`Playback speed ${rate}×`}
              onClick={() => setRate(nextRate(rate))}
              className="h-[30px] rounded-sm border border-[#2A3D4E] px-2.5 font-mono text-[12px] font-semibold"
            >
              {formatRate(rate)}
            </button>
            <IconButton
              icon="closed_caption"
              label="Subtitles"
              aria-pressed={subtitles}
              fill={subtitles}
              onClick={() => setSubtitles((s) => !s)}
            />
            <IconButton
              icon="picture_in_picture_alt"
              label="Picture in picture (not available yet)"
              disabled
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
              <dd className="m-0">MP4 · H.264 · AAC</dd>
              <dt className="text-muted">Resolution</dt>
              <dd className="m-0">1920 × 800</dd>
              <dt className="text-muted">Size</dt>
              <dd className="m-0">{item.size}</dd>
              <dt className="text-muted">Location</dt>
              <dd className="m-0 break-all font-mono text-[11.5px]">…\Videos\Miarina</dd>
            </dl>
          </div>
          <div className="flex flex-col gap-1 px-2.5 py-[18px]">
            <span className="px-2 pb-2 text-overline font-bold uppercase tracking-[0.06em] text-muted">
              Up next
            </span>
            {upNext.map((u) => (
              <button
                key={u.id}
                type="button"
                onClick={() => play(u)}
                className="flex gap-2.5 rounded-sm p-2 text-left hover:bg-surface"
              >
                <Thumbnail className="h-[45px] w-20 rounded-xs" />
                <span className="flex min-w-0 flex-col gap-0.5">
                  <span className="truncate text-[12.5px] font-semibold">{u.title}</span>
                  <span className="text-[11.5px] text-muted">
                    {u.duration} · {u.quality}
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
