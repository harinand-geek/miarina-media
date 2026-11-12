import { useEffect, useRef, useState } from 'react';
import { Button, IconButton } from '../../components/Button';
import { EmptyState } from '../../components/Feedback';
import { Icon } from '../../components/Icon';
import { formatClock } from '../../hooks/usePlaybackClock';
import { useMediaQuery } from '../../hooks/useMediaQuery';
import { useT } from '../../i18n';
import { backend } from '../../services/backend';
import { setFullscreen } from '../../services/window';
import type { MediaRecord } from '../../services/types';
import { formatBytes } from '../../stores/downloads';
import { isActive, usePlayer, type PlayerError } from '../../stores/player';
import { useSettings } from '../../stores/settings';
import { useUi } from '../../stores/ui';
import { openLibrary } from '../../app/navigation';
import { durationLabel, folderOf, formatLabel, qualityLabel } from '../library/format';
import { MediaThumb } from '../library/MediaThumb';
import NowPlayingScreen from './NowPlayingScreen';
import { PlayButton, VolumeControl } from './parts';
import { formatRate, nextRate } from './playbackRate';
import { SeekBar } from './SeekBar';
import { TracksPanel } from './TracksPanel';

/** Video player (Windows v2 screen 7). Audio plays on "Now playing". */
export default function PlayerScreen() {
  const t = useT();
  const media = usePlayer((s) => s.media);
  if (!media) {
    return (
      <div className="grid flex-1 place-items-center p-10">
        <EmptyState
          icon="play_circle"
          title={t('nothingPlaying')}
          action={
            <Button
              variant="primary"
              size="sm"
              className="h-9 text-[13px]"
              onClick={() => openLibrary('videos')}
            >
              {t('openLibrary')}
            </Button>
          }
        >
          {t('nothingPlayingBody')}
        </EmptyState>
      </div>
    );
  }
  if (media.kind !== 'video') return <NowPlayingScreen />;
  return <VideoPlayer item={media} />;
}

const errorKey = (error: PlayerError | null) =>
  error?.kind === 'unsupported'
    ? 'errUnsupported'
    : error?.kind === 'read'
      ? 'errRead'
      : error?.kind === 'decode'
        ? 'errDecode'
        : 'errOther';

function VideoPlayer({ item }: { item: MediaRecord }) {
  const t = useT();
  const position = usePlayer((s) => s.position);
  const duration = usePlayer((s) => s.duration);
  const buffered = usePlayer((s) => s.buffered);
  const playing = usePlayer((s) => isActive(s.state));
  const error = usePlayer((s) =>
    s.state === 'error' ? (s.error ?? { kind: 'unknown' as const }) : null,
  );
  const rate = usePlayer((s) => s.rate);
  const queue = usePlayer((s) => s.queue);
  const index = usePlayer((s) => s.index);
  const { toggle, seek, skip, setRate, retry, setSurface, playAt, previous, next } =
    usePlayer.getState();
  const pushToast = useUi((s) => s.pushToast);
  const fullscreen = useUi((s) => s.playerFullscreen);
  const mounted = useRef(true);
  const changingFullscreen = useRef(false);
  const wide = useMediaQuery('(min-width: 1280px)');
  const [panelOpen, setPanelOpen] = useState(false);
  const [tracksOpen, setTracksOpen] = useState(false);
  const nativeVideo = usePlayer((s) => s.nativeVideo);
  const hasTracks = usePlayer((s) => !!s.tracks);
  const lang = useSettings((s) => s.lang);
  const showPanel = (tracksOpen && hasTracks) || (!fullscreen && (wide || panelOpen));
  const pipSupported =
    !nativeVideo && typeof document !== 'undefined' && document.pictureInPictureEnabled === true;
  const hasFile = nativeVideo || !!backend.mediaUrl(item.path);
  const upNext = queue.slice(index + 1, index + 6);

  const toggleFullscreen = async (on = !fullscreen) => {
    if (changingFullscreen.current) return;
    changingFullscreen.current = true;
    try {
      await setFullscreen(on);
      if (mounted.current) useUi.setState({ playerFullscreen: on });
      else if (on) await setFullscreen(false);
    } catch {
      pushToast({ tone: 'error', message: t('fullscreenFailed') });
    } finally {
      changingFullscreen.current = false;
    }
  };

  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
      setSurface(null);
      if (useUi.getState().playerFullscreen) {
        useUi.setState({ playerFullscreen: false });
        void setFullscreen(false).catch(() => {});
      }
    };
  }, [setSurface]);

  // Native picture (libVLC): clicks on it arrive as events.
  const toggleFullscreenRef = useRef(toggleFullscreen);
  useEffect(() => {
    toggleFullscreenRef.current = toggleFullscreen;
  });
  useEffect(() => {
    if (!nativeVideo) return;
    return backend.onNativePlayerClick((kind) => {
      if (kind === 'dblclick') void toggleFullscreenRef.current();
      else usePlayer.getState().toggle();
    });
  }, [nativeVideo]);

  const openExternal = () =>
    backend
      .libraryOpenExternal(item.id)
      .catch((e: unknown) =>
        pushToast({ tone: 'error', message: e instanceof Error ? e.message : String(e) }),
      );

  // F / Escape (Space and ←/→ are global player shortcuts).
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement;
      if (['INPUT', 'TEXTAREA', 'SELECT'].includes(target.tagName) || useUi.getState().confirm)
        return;
      if (e.key.toLowerCase() === 'f' && !e.ctrlKey && !e.metaKey && !e.altKey) toggleFullscreen();
      else if (e.key === 'Escape' && fullscreen) toggleFullscreen(false);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  });

  const tech = [formatLabel(item), qualityLabel(item), item.sourceHost].filter(Boolean).join(' · ');

  return (
    <div className="flex min-h-0 flex-1">
      <div className="flex min-w-0 flex-1 flex-col text-[#F5F7FA]">
        {/* A native picture (libVLC) covers what is drawn under it: the
            title stays above the picture instead of over it. */}
        {nativeVideo && (
          <div className="flex h-12 shrink-0 items-center gap-3 bg-[#0B1117] px-5">
            {!fullscreen && (
              <IconButton
                icon="arrow_back"
                label={t('back')}
                iconSize={22}
                onClick={() => openLibrary('videos')}
                className="!text-[#F5F7FA] hover:!bg-white/10"
              />
            )}
            <span className="truncate text-[15px] font-bold">{item.title}</span>
            <span className="truncate font-mono text-[11.5px] text-[#94A3B8]">{tech}</span>
          </div>
        )}
        {/* Transparent stage: the engine's picture (PlayerHost) sits under it. */}
        <div className="relative min-h-0 flex-1 overflow-hidden">
          <div
            ref={setSurface}
            data-testid="video-surface"
            onClick={toggle}
            onDoubleClick={() => toggleFullscreen()}
            className="absolute inset-0"
          />
          {!hasFile && (
            <span className="pointer-events-none absolute inset-0 grid place-items-center font-mono text-[12px] font-medium text-[#3A4D5E]">
              {t('videoPreview')}
            </span>
          )}
          <div
            hidden={nativeVideo}
            className="absolute inset-x-0 top-0 flex h-16 items-center gap-3 bg-gradient-to-b from-black/60 to-transparent px-5"
          >
            {!fullscreen && (
              <IconButton
                icon="arrow_back"
                label={t('back')}
                iconSize={22}
                onClick={() => openLibrary('videos')}
                className="!text-[#F5F7FA] hover:!bg-white/10"
              />
            )}
            <span className="truncate text-[15px] font-bold drop-shadow">{item.title}</span>
            <span className="truncate font-mono text-[11.5px] text-[#94A3B8]">{tech}</span>
          </div>
          {error && (
            <div
              role="alert"
              className="absolute inset-x-0 bottom-6 mx-auto flex w-fit max-w-[90%] items-center gap-3 rounded-lg border border-[#2F4558] bg-[#1F2F3B] px-4 py-3 text-[13px]"
            >
              <Icon name="error" fill className="text-[#F07070]" />
              <span>{t(errorKey(error), { format: formatLabel(item) })}</span>
              <button type="button" onClick={retry} className="font-bold text-accent">
                {t('retry')}
              </button>
              <button type="button" onClick={openExternal} className="font-bold text-accent">
                {t('openExternal')}
              </button>
            </div>
          )}
        </div>
        <div className="flex flex-col gap-2 border-t border-[#1B2935] bg-[#0B1117] px-5 pb-3.5 pt-2.5 [--mm-border:36_53_69] [--mm-faint-icon:58_77_94]">
          <div className="flex items-center gap-3 font-mono text-[12px] text-[#94A3B8] tabular">
            <span>{formatClock(position)}</span>
            <div className="flex-1">
              <SeekBar
                time={position}
                duration={duration}
                buffered={buffered}
                onSeek={seek}
                tone="coral"
                hitHeight={16}
                label={t('seek')}
              />
            </div>
            <span>{durationLabel(duration)}</span>
          </div>
          <div className="flex items-center gap-1 [&_button:disabled]:opacity-40 [&_button:not(.bg-coral)]:text-[#F5F7FA] [&_button:not(.bg-coral):enabled:hover]:bg-[#243545]">
            <PlayButton
              size={44}
              iconSize={28}
              playing={playing}
              onClick={toggle}
              t={t}
              className="mr-1.5"
            />
            <IconButton
              icon="skip_previous"
              label={t('previous')}
              fill
              size={40}
              iconSize={22}
              onClick={previous}
            />
            <IconButton
              icon="replay_10"
              label={t('back10')}
              size={40}
              iconSize={22}
              onClick={() => skip(-10)}
            />
            <IconButton
              icon="forward_10"
              label={t('forward10')}
              size={40}
              iconSize={22}
              onClick={() => skip(10)}
            />
            <IconButton
              icon="skip_next"
              label={t('next')}
              fill
              size={40}
              iconSize={22}
              disabled={index + 1 >= queue.length}
              onClick={next}
            />
            <VolumeControl t={t} width={90} dark />
            <span className="flex-1" />
            <IconButton
              icon="closed_caption"
              label={hasTracks ? t('tracksButton') : t('tracksUnavailable')}
              aria-pressed={hasTracks ? tracksOpen : undefined}
              size={40}
              iconSize={22}
              disabled={!hasTracks}
              onClick={() => setTracksOpen((o) => !o)}
            />
            <button
              type="button"
              aria-label={t('speedButton', { rate: formatRate(rate) })}
              onClick={() => setRate(nextRate(rate))}
              className="flex h-10 min-w-10 items-center gap-1.5 rounded-sm px-2 font-mono text-[12.5px] font-semibold"
            >
              <Icon name="speed" size={22} />
              {formatRate(rate)}
            </button>
            <IconButton
              icon="picture_in_picture_alt"
              label={pipSupported && hasFile ? t('pip') : t('pipUnavailable')}
              size={40}
              iconSize={22}
              disabled={!pipSupported || !hasFile}
              onClick={() => {
                const video = document.querySelector<HTMLVideoElement>(
                  '[data-testid="player-engine"]',
                );
                void video?.requestPictureInPicture?.().catch(() => {});
              }}
            />
            {!wide && !fullscreen && (
              <IconButton
                icon="view_sidebar"
                label={t('detailsPanel')}
                aria-pressed={panelOpen}
                size={40}
                iconSize={22}
                onClick={() => setPanelOpen((o) => !o)}
              />
            )}
            <IconButton
              icon={fullscreen ? 'fullscreen_exit' : 'fullscreen'}
              label={fullscreen ? t('exitFullscreen') : t('fullscreen')}
              size={40}
              iconSize={22}
              onClick={() => toggleFullscreen()}
            />
          </div>
        </div>
      </div>

      {showPanel && (
        <aside
          aria-label={t('detailsPanel')}
          className="flex w-[300px] shrink-0 flex-col overflow-auto border-l border-divider bg-bg"
        >
          <TracksPanel lang={lang} />
          <div className="flex flex-col gap-2.5 border-b border-divider p-[18px]">
            <span className="text-overline font-bold uppercase tracking-[0.06em] text-muted">
              {t('file')}
            </span>
            <dl className="m-0 grid grid-cols-[90px_1fr] gap-y-2 text-[12.5px]">
              <dt className="text-muted">{t('format')}</dt>
              <dd className="m-0">{formatLabel(item)}</dd>
              {item.width && item.height && (
                <>
                  <dt className="text-muted">{t('resolution')}</dt>
                  <dd className="m-0">
                    {item.width} × {item.height}
                  </dd>
                </>
              )}
              <dt className="text-muted">{t('size')}</dt>
              <dd className="m-0">{formatBytes(item.sizeBytes)}</dd>
              <dt className="text-muted">{t('location')}</dt>
              <dd className="m-0 break-all font-mono text-[11.5px]" title={item.path}>
                {folderOf(item.path)}
              </dd>
            </dl>
          </div>
          <div className="flex flex-col gap-1 px-2.5 py-[18px]">
            <span className="px-2 pb-2 text-overline font-bold uppercase tracking-[0.06em] text-muted">
              {t('upNext')}
            </span>
            {upNext.length === 0 && (
              <p className="m-0 px-2 text-[12.5px] text-muted">{t('queueEmpty')}</p>
            )}
            {upNext.map((u, i) => (
              <button
                key={u.id}
                type="button"
                onClick={() => playAt(index + 1 + i)}
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
