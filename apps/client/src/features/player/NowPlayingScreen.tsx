import { useState, type DragEvent, type KeyboardEvent } from 'react';
import { Button, IconButton } from '../../components/Button';
import { EmptyState } from '../../components/Feedback';
import { Icon } from '../../components/Icon';
import { formatClock } from '../../hooks/usePlaybackClock';
import { useT, type Translate } from '../../i18n';
import { isActive, usePlayer, type SleepTimer } from '../../stores/player';
import { useUi } from '../../stores/ui';
import { openLibrary } from '../../app/navigation';
import { durationLabel } from '../library/format';
import { MediaThumb } from '../library/MediaThumb';
import { mediaByline } from './byline';
import { PlayButton } from './parts';
import { PLAYBACK_RATES, formatRate } from './playbackRate';
import { equalizerLabel, useEqualizer } from './equalizer';
import { EqualizerSection } from './EqualizerSection';
import { SeekBar } from './SeekBar';

const SLEEP_CHOICES = ['off', 15, 30, 60, 'end'] as const;

const sleepLabel = (choice: 'off' | 'end' | number, t: Translate) =>
  choice === 'off'
    ? t('sleepOff')
    : choice === 'end'
      ? t('sleepEnd')
      : t('sleepMinutes', { n: choice });

const sleepChoice = (sleep: SleepTimer) => (sleep.mode === 'minutes' ? sleep.minutes : sleep.mode);

/** "En lecture" (Windows v2 screen 6): cover, transport, queue and sound. */
export default function NowPlayingScreen() {
  const t = useT();
  const media = usePlayer((s) => s.media);

  if (!media) {
    return (
      <div className="grid flex-1 place-items-center p-10">
        <EmptyState
          icon="graphic_eq"
          title={t('nothingPlaying')}
          action={
            <Button
              variant="primary"
              size="sm"
              className="h-9 text-[13px]"
              onClick={() => openLibrary('tracks')}
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

  return (
    <div className="flex min-h-0 flex-1">
      <Stage />
      <SidePanel />
    </div>
  );
}

function Stage() {
  const t = useT();
  const media = usePlayer((s) => s.media)!;
  const position = usePlayer((s) => s.position);
  const duration = usePlayer((s) => s.duration);
  const buffered = usePlayer((s) => s.buffered);
  const playing = usePlayer((s) => isActive(s.state));
  const failed = usePlayer((s) => s.state === 'error');
  const shuffle = usePlayer((s) => s.shuffle);
  const repeat = usePlayer((s) => s.repeat);
  const rate = usePlayer((s) => s.rate);
  const sleep = usePlayer((s) => s.sleep);
  // The equalizer chip follows its setting.
  useEqualizer((s) => s.enabled);
  useEqualizer((s) => s.preset);
  const { toggle, previous, next, seek, setShuffle, cycleRepeat, retry } = usePlayer.getState();
  const openSound = () => useUi.setState({ nowPanel: 'sound' });

  const repeatLabel =
    repeat === 'off' ? t('repeatOff') : repeat === 'all' ? t('repeatAll') : t('repeatOne');
  const chips = [
    { icon: 'speed', label: formatRate(rate) },
    { icon: 'equalizer', label: equalizerLabel(t) },
    {
      icon: 'bedtime',
      label: sleep.mode === 'off' ? t('timer') : sleepLabel(sleepChoice(sleep), t),
    },
  ];

  return (
    <div className="flex min-w-0 flex-1 flex-col items-center justify-center gap-7 overflow-auto px-12 py-8">
      <MediaThumb
        media={media}
        className="aspect-square w-[min(340px,40vh)] shrink-0 rounded-[14px] border border-line shadow-[0_24px_64px_rgba(0,0,0,0.3)]"
      />
      <div className="flex flex-col items-center gap-1.5 text-center">
        <h1 className="m-0 text-[26px] font-extrabold leading-8 tracking-[-0.02em]">
          {media.title}
        </h1>
        <span className="text-[14px] text-muted">{mediaByline(media, t)}</span>
      </div>
      {failed && (
        <div
          role="alert"
          className="flex items-center gap-3 rounded-md border border-overlay-border bg-surface2 px-4 py-2.5 text-[13px]"
        >
          <Icon name="error" fill className="text-danger" />
          <span>{t('errOther')}</span>
          <button type="button" onClick={retry} className="font-bold text-accent-strong">
            {t('retry')}
          </button>
        </div>
      )}
      <div className="flex w-[min(560px,100%)] flex-col gap-2">
        <SeekBar
          time={position}
          duration={duration}
          buffered={buffered}
          onSeek={seek}
          tone="coral"
          hitHeight={16}
          label={t('seek')}
        />
        <div className="flex justify-between font-mono text-[12px] text-muted tabular">
          <span>{formatClock(position)}</span>
          <span>{durationLabel(duration)}</span>
        </div>
      </div>
      <div className="flex items-center gap-3.5">
        <IconButton
          icon="shuffle"
          label={t('shuffle')}
          size={40}
          iconSize={22}
          aria-pressed={shuffle}
          onClick={() => setShuffle(!shuffle)}
          className={`!rounded-full ${shuffle ? '!text-coral-strong' : ''}`}
        />
        <IconButton
          icon="skip_previous"
          label={t('previous')}
          size={48}
          iconSize={30}
          fill
          tone="default"
          onClick={previous}
          className="!rounded-full"
        />
        <PlayButton size={68} iconSize={38} playing={playing} onClick={toggle} t={t} />
        <IconButton
          icon="skip_next"
          label={t('next')}
          size={48}
          iconSize={30}
          fill
          tone="default"
          onClick={next}
          className="!rounded-full"
        />
        <IconButton
          icon={repeat === 'one' ? 'repeat_one' : 'repeat'}
          label={repeatLabel}
          size={40}
          iconSize={22}
          aria-pressed={repeat !== 'off'}
          onClick={cycleRepeat}
          className={`!rounded-full ${repeat !== 'off' ? '!text-coral-strong' : ''}`}
        />
      </div>
      <div className="flex gap-2">
        {chips.map((c) => (
          <button
            key={c.icon}
            type="button"
            onClick={openSound}
            className="flex h-[30px] items-center gap-1.5 rounded-full border border-line bg-surface px-3 text-[12.5px] font-semibold text-muted hover:text-fg"
          >
            <Icon name={c.icon} size={16} />
            {c.label}
          </button>
        ))}
      </div>
    </div>
  );
}

function SidePanel() {
  const t = useT();
  const panel = useUi((s) => s.nowPanel);
  const tabs = [
    { id: 'queue' as const, label: t('queue') },
    { id: 'sound' as const, label: t('sound') },
  ];
  return (
    <aside className="flex w-[380px] shrink-0 flex-col border-l border-divider bg-sidebar">
      <div role="tablist" className="flex gap-6 border-b border-line px-5">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            type="button"
            role="tab"
            aria-selected={panel === tab.id}
            onClick={() => useUi.setState({ nowPanel: tab.id })}
            className={`-mb-px h-12 border-b-2 text-[13.5px] font-semibold ${
              panel === tab.id
                ? 'border-accent text-fg'
                : 'border-transparent text-muted hover:text-fg'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>
      {panel === 'queue' ? <QueuePanel /> : <SoundPanel />}
    </aside>
  );
}

function QueuePanel() {
  const t = useT();
  const queue = usePlayer((s) => s.queue);
  const index = usePlayer((s) => s.index);
  const playing = usePlayer((s) => isActive(s.state));
  const { playAt, removeAt, move, clearQueue } = usePlayer.getState();
  const pushToast = useUi((s) => s.pushToast);
  const [dragFrom, setDragFrom] = useState<number | null>(null);
  const [dropAt, setDropAt] = useState<number | null>(null);

  const onRowKey = (e: KeyboardEvent<HTMLLIElement>, i: number) => {
    if (e.altKey && (e.key === 'ArrowUp' || e.key === 'ArrowDown')) {
      e.preventDefault();
      const to = i + (e.key === 'ArrowUp' ? -1 : 1);
      move(i, to);
      // Keep focus on the moved row.
      requestAnimationFrame(() =>
        (document.querySelector(`[data-queue-row="${to}"]`) as HTMLElement | null)?.focus(),
      );
    } else if (e.key === 'Enter') {
      playAt(i);
    } else if (e.key === 'Delete') {
      removeAt(i);
    }
  };

  const onDrop = (e: DragEvent, i: number) => {
    e.preventDefault();
    if (dragFrom != null) move(dragFrom, i);
    setDragFrom(null);
    setDropAt(null);
  };

  return (
    <>
      <div className="flex-1 overflow-auto p-2.5">
        <span className="block px-2.5 py-2 text-[11px] font-bold uppercase tracking-[0.06em] text-faint">
          {t('upNext')}
        </span>
        {queue.length === 0 && (
          <p className="m-0 px-2.5 text-[12.5px] text-muted">{t('queueEmpty')}</p>
        )}
        <ol
          aria-label={t('queue')}
          title={t('dragHint')}
          className="m-0 flex list-none flex-col p-0"
        >
          {queue.map((m, i) => {
            const on = i === index;
            return (
              <li
                key={m.id}
                data-queue-row={i}
                tabIndex={0}
                draggable
                aria-current={on ? 'true' : undefined}
                onDragStart={() => setDragFrom(i)}
                onDragOver={(e) => {
                  e.preventDefault();
                  setDropAt(i);
                }}
                onDragEnd={() => {
                  setDragFrom(null);
                  setDropAt(null);
                }}
                onDrop={(e) => onDrop(e, i)}
                onDoubleClick={() => playAt(i)}
                onKeyDown={(e) => onRowKey(e, i)}
                className={`group flex h-[52px] cursor-pointer items-center gap-2.5 rounded-md px-2 hover:bg-surface ${
                  on ? 'bg-surface' : ''
                } ${dropAt === i && dragFrom !== i ? 'outline-2 outline-accent' : ''}`}
              >
                <Icon name="drag_indicator" size={18} className="cursor-grab text-faint" />
                <button
                  type="button"
                  tabIndex={-1}
                  onClick={() => playAt(i)}
                  className="flex min-w-0 flex-1 items-center gap-2.5 text-left"
                >
                  <MediaThumb
                    media={m}
                    className="grid h-9 w-9 shrink-0 place-items-center rounded-xs"
                  >
                    {on && playing && (
                      <span className="absolute inset-0 grid place-items-center bg-black/45">
                        <Icon name="equalizer" size={18} className="text-coral" />
                      </span>
                    )}
                  </MediaThumb>
                  <span className="flex min-w-0 flex-1 flex-col">
                    <span
                      className={`truncate text-[13px] font-bold ${on ? 'text-coral-strong' : ''}`}
                    >
                      {m.title}
                    </span>
                    <span className="truncate text-[12px] text-muted">{mediaByline(m, t)}</span>
                  </span>
                </button>
                <span className="font-mono text-[11.5px] text-muted">
                  {durationLabel(m.durationSecs)}
                </span>
                <IconButton
                  icon="close"
                  label={t('removeFromQueue')}
                  size={28}
                  iconSize={16}
                  tabIndex={-1}
                  onClick={() => removeAt(i)}
                  className="opacity-0 group-focus-within:opacity-100 group-hover:opacity-100"
                />
              </li>
            );
          })}
        </ol>
      </div>
      <div className="flex gap-2 border-t border-line px-5 py-3.5">
        <button
          type="button"
          disabled={queue.length === 0}
          onClick={() =>
            useUi.setState({
              playlistDialog: { kind: 'create', ids: queue.map((m) => m.id) },
            })
          }
          className="flex h-[34px] flex-1 items-center justify-center gap-2 rounded-sm border border-line-strong bg-surface2 text-[12.5px] font-semibold enabled:hover:bg-secondary-hover disabled:opacity-50"
        >
          <Icon name="playlist_add" size={17} />
          {t('saveAsPlaylist')}
        </button>
        <button
          type="button"
          disabled={queue.length <= 1}
          onClick={() => {
            clearQueue();
            pushToast({ tone: 'success', message: t('queueCleared') });
          }}
          className="h-[34px] rounded-sm border border-line-strong px-3 text-[12.5px] font-semibold text-muted hover:text-fg disabled:opacity-50"
        >
          {t('clearQueue')}
        </button>
      </div>
    </>
  );
}

function SoundPanel() {
  const t = useT();
  const media = usePlayer((s) => s.media);
  const rate = usePlayer((s) => s.rate);
  const sleep = usePlayer((s) => s.sleep);
  const { setRate, setSleep } = usePlayer.getState();
  const choice = sleepChoice(sleep);
  const note =
    sleep.mode === 'off'
      ? t('sleepNoteOff')
      : sleep.mode === 'end'
        ? t('sleepNoteEnd', { title: media?.title ?? '' })
        : t('sleepNoteMinutes', { n: sleep.minutes });

  return (
    <div className="flex flex-1 flex-col gap-[22px] overflow-auto p-5">
      <EqualizerSection />

      <section className="flex flex-col gap-2.5" aria-labelledby="speed-head">
        <span id="speed-head" className="text-[14px] font-bold">
          {t('speed')}
        </span>
        <div
          role="radiogroup"
          aria-labelledby="speed-head"
          className="flex rounded-[7px] border border-line bg-bg p-[3px]"
        >
          {PLAYBACK_RATES.map((r) => (
            <button
              key={r}
              type="button"
              role="radio"
              aria-checked={rate === r}
              onClick={() => setRate(r)}
              className={`h-7 flex-1 rounded-[5px] font-mono text-[12px] font-semibold ${
                rate === r ? 'bg-line-strong text-fg' : 'text-muted hover:text-fg'
              }`}
            >
              {`${r}×`}
            </button>
          ))}
        </div>
      </section>

      <section className="flex flex-col gap-2.5" aria-labelledby="sleep-head">
        <span id="sleep-head" className="text-[14px] font-bold">
          {t('sleep')}
        </span>
        <div role="radiogroup" aria-labelledby="sleep-head" className="flex flex-wrap gap-1.5">
          {SLEEP_CHOICES.map((c) => {
            const on = choice === c;
            return (
              <button
                key={String(c)}
                type="button"
                role="radio"
                aria-checked={on}
                onClick={() => setSleep(c)}
                className={`h-7 rounded-full border px-[11px] text-[12px] font-semibold transition-colors duration-150 ${
                  on
                    ? 'border-chip-border bg-accent-subtle text-chip-text'
                    : 'border-line-strong text-muted hover:text-fg'
                }`}
              >
                {sleepLabel(c, t)}
              </button>
            );
          })}
        </div>
        <span className="text-[12px] text-muted" aria-live="polite">
          {note}
        </span>
      </section>
    </div>
  );
}
