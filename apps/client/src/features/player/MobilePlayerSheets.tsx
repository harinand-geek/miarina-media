import { useEffect, useRef, useState, type PointerEvent } from 'react';
import { Icon } from '../../components/Icon';
import { BottomSheet } from '../../components/Overlay';
import { useNow } from '../downloads/useNow';
import { useT, type Translate } from '../../i18n';
import { backend } from '../../services/backend';
import type { MediaRecord } from '../../services/types';
import { MOBILE_RATES, useMobilePlayback } from '../../stores/mobilePlayback';
import { useSettings } from '../../stores/settings';
import { useUi } from '../../stores/ui';
import { durationLabel } from '../library/format';
import { MediaThumb } from '../library/MediaThumb';
import { mediaByline } from './byline';
import { rateLabel } from './playbackRate';

const ROW = 60;

const clock = (ms: number) => {
  const s = Math.max(0, Math.ceil(ms / 1000));
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
};

/** Android v2 screen 08: queue with drag to reorder (handle), remove, clear. */
export function QueueSheet({
  onClose,
  time,
  duration,
}: {
  onClose: () => void;
  time: number;
  duration: number;
}) {
  const t = useT();
  const { queue, shuffle, repeat, playAt, remove, move, clear, setShuffle, cycleRepeat } =
    useMobilePlayback();
  const currentId = useUi((s) => s.nowPlaying?.id);
  const at = queue.findIndex((m) => m.id === currentId);
  const left =
    Math.max(0, duration - time) +
    queue.slice(at + 1).reduce((sum, m) => sum + (m.durationSecs ?? 0), 0);
  const [drag, setDrag] = useState<{ from: number; to: number; startY: number } | null>(null);

  const onHandleDown = (e: PointerEvent<HTMLElement>, index: number) => {
    e.currentTarget.setPointerCapture(e.pointerId);
    setDrag({ from: index, to: index, startY: e.clientY });
  };
  const onHandleMove = (e: PointerEvent<HTMLElement>) => {
    if (!drag) return;
    const to = Math.min(queue.length - 1, Math.max(0, drag.from + Math.round((e.clientY - drag.startY) / ROW)));
    if (to !== drag.to) setDrag({ ...drag, to });
  };
  const onHandleUp = () => {
    if (drag && drag.to !== drag.from) move(drag.from, drag.to);
    setDrag(null);
  };

  return (
    <BottomSheet open onClose={onClose} label={t('queueTitle')} elevated>
      <div className="flex items-center gap-2 px-0 pt-1">
        <div className="flex flex-1 flex-col">
          <h2 className="m-0 text-[18px] font-extrabold">{t('queueTitle')}</h2>
          <span className="text-[12.5px] text-muted">
            {t('queueRemaining', {
              tracks: queue.length === 1 ? t('oneTrack') : t('tracksCount', { n: queue.length }),
              time: durationLabel(left),
            })}
          </span>
        </div>
        <button
          type="button"
          aria-label={t('shuffle')}
          aria-pressed={shuffle}
          onClick={() => setShuffle(!shuffle)}
          className={`grid h-10 w-10 place-items-center ${shuffle ? 'text-coral-strong' : 'text-muted'}`}
        >
          <Icon name="shuffle" size={24} />
        </button>
        <button
          type="button"
          aria-label={repeat === 'off' ? t('repeatOff') : repeat === 'all' ? t('repeatAll') : t('repeatOne')}
          aria-pressed={repeat !== 'off'}
          onClick={cycleRepeat}
          className={`grid h-10 w-10 place-items-center ${repeat !== 'off' ? 'text-coral-strong' : 'text-muted'}`}
        >
          <Icon name={repeat === 'one' ? 'repeat_one' : 'repeat'} size={24} />
        </button>
      </div>
      <ol aria-label={t('queueTitle')} className="-mx-2 m-0 flex list-none flex-col p-0">
        {queue.map((m, i) => {
          const on = m.id === currentId;
          const target = drag && drag.to === i && drag.from !== i;
          return (
            <li
              key={m.id}
              aria-current={on ? 'true' : undefined}
              className={`flex h-[60px] items-center gap-2.5 rounded-[10px] px-2 ${
                on ? 'bg-coral-subtle' : ''
              } ${target ? 'outline-2 outline-accent' : ''} ${drag?.from === i ? 'opacity-60' : ''}`}
            >
              <span
                role="button"
                tabIndex={0}
                aria-label={t('moveHandle', { title: m.title })}
                onPointerDown={(e) => onHandleDown(e, i)}
                onPointerMove={onHandleMove}
                onPointerUp={onHandleUp}
                onPointerCancel={() => setDrag(null)}
                onKeyDown={(e) => {
                  if (e.key === 'ArrowUp') move(i, i - 1);
                  else if (e.key === 'ArrowDown') move(i, i + 1);
                }}
                className="grid h-11 w-7 touch-none place-items-center text-faint"
              >
                <Icon name="drag_indicator" size={22} />
              </span>
              <button
                type="button"
                onClick={() => playAt(i)}
                className="flex min-w-0 flex-1 items-center gap-2.5 text-left"
              >
                <MediaThumb media={m} className="h-10 w-10 rounded-sm" />
                <span className="flex min-w-0 flex-1 flex-col gap-px">
                  <span className={`truncate text-[14px] font-bold ${on ? 'text-coral-strong' : ''}`}>
                    {m.title}
                  </span>
                  <span className="truncate text-[12px] text-muted">{mediaByline(m, t)}</span>
                </span>
              </button>
              {on ? (
                <Icon name="equalizer" size={20} className="mx-2.5 text-coral-strong" />
              ) : (
                <button
                  type="button"
                  aria-label={`${t('removeFromQueue')} : ${m.title}`}
                  onClick={() => remove(i)}
                  className="grid h-10 w-10 place-items-center text-muted"
                >
                  <Icon name="close" size={20} />
                </button>
              )}
            </li>
          );
        })}
      </ol>
      <div className="-mx-4 flex gap-2.5 border-t border-line-strong px-4 pt-3">
        <button
          type="button"
          disabled={queue.length === 0}
          onClick={() =>
            useUi.setState({ playlistDialog: { kind: 'create', ids: queue.map((m) => m.id) } })
          }
          className="flex h-12 flex-1 items-center justify-center gap-1.5 rounded-full border border-line-strong bg-surface text-[13.5px] font-semibold disabled:opacity-50"
        >
          <Icon name="playlist_add" size={20} />
          {t('saveAsPlaylist')}
        </button>
        <button
          type="button"
          disabled={queue.length <= 1}
          onClick={() => {
            clear();
            useUi.getState().pushToast({ tone: 'success', message: t('queueCleared') });
          }}
          className="flex h-12 items-center gap-1.5 rounded-full px-4 text-[13.5px] font-semibold text-muted disabled:opacity-50"
        >
          <Icon name="clear_all" size={20} />
          {t('clearShort')}
        </button>
      </div>
      <span className="text-center text-[11.5px] text-faint">{t('clearNote')}</span>
    </BottomSheet>
  );
}

const SLEEP_CHOICES = ['off', 15, 30, 60, 'end'] as const;

const sleepChipLabel = (c: (typeof SLEEP_CHOICES)[number], t: Translate) =>
  c === 'off' ? t('sleepOff') : c === 'end' ? t('sleepEnd') : t('sleepMinutes', { n: c });

/** Android v2 screen 09: equalizer (explained until native), speed, sleep timer. */
export function SoundSheet({ media, onClose }: { media: MediaRecord; onClose: () => void }) {
  const t = useT();
  const lang = useSettings((s) => s.lang);
  const { rate, sleep, setRate, setSleep } = useMobilePlayback();
  const now = useNow(sleep.mode === 'minutes' ? 1000 : null);
  const choice = sleep.mode === 'minutes' ? sleep.minutes : sleep.mode;

  return (
    <BottomSheet open onClose={onClose} label={t('sound')} elevated>
      <section aria-labelledby="m-eq" className="flex flex-col gap-2.5">
        <div className="flex items-center gap-3">
          <h2 id="m-eq" className="m-0 flex-1 text-[18px] font-extrabold">
            {t('eq')}
          </h2>
          <span className="rounded-xs border border-planned-border bg-planned-bg px-1.5 py-0.5 font-mono text-[10.5px] font-bold text-warn">
            {t('planned')}
          </span>
        </div>
        <p className="m-0 text-[13px] leading-[19px] text-muted">{t('eqUnavailable')}</p>
      </section>
      <div className="h-px bg-line-strong" />
      <section aria-labelledby="m-speed" className="flex flex-col gap-2.5">
        <h2 id="m-speed" className="m-0 text-[14px] font-bold">
          {t('speed')}
        </h2>
        <div
          role="radiogroup"
          aria-labelledby="m-speed"
          className="flex rounded-[20px] border border-line bg-bg p-[3px] font-mono text-[12.5px]"
        >
          {MOBILE_RATES.map((r) => (
            <button
              key={r}
              type="button"
              role="radio"
              aria-checked={rate === r}
              onClick={() => setRate(r)}
              className={`h-[34px] flex-1 rounded-[17px] ${rate === r ? 'bg-line-strong font-bold text-fg' : 'text-muted'}`}
            >
              {rateLabel(r, lang)}
            </button>
          ))}
        </div>
      </section>
      <section aria-labelledby="m-sleep" className="flex flex-col gap-2.5 pb-2">
        <h2 id="m-sleep" className="m-0 text-[14px] font-bold">
          {t('sleep')}
        </h2>
        <div role="radiogroup" aria-labelledby="m-sleep" className="flex flex-wrap gap-2">
          {SLEEP_CHOICES.map((c) => {
            const on = choice === c;
            return (
              <button
                key={String(c)}
                type="button"
                role="radio"
                aria-checked={on}
                onClick={() => setSleep(c)}
                className={`h-[34px] rounded-full border px-3 text-[12.5px] ${
                  on
                    ? 'border-coral-chip-border bg-coral-subtle font-bold text-coral-strong'
                    : 'border-line-strong font-semibold text-muted'
                }`}
              >
                {sleepChipLabel(c, t)}
              </button>
            );
          })}
        </div>
        {sleep.mode !== 'off' && (
          <span aria-live="polite" className="flex items-center gap-1.5 text-[12.5px] text-muted">
            <Icon name="bedtime" size={16} className="text-coral-strong" />
            {sleep.mode === 'end'
              ? t('sleepAtEnd', { title: media.title })
              : t('sleepIn', {
                  time: clock(Math.min(sleep.endsAt - now, sleep.minutes * 60_000)),
                })}
          </span>
        )}
      </section>
    </BottomSheet>
  );
}

/** Lyrics saved in the library (AND-15: local only, nothing fetched). */
export function LyricsSheet({ media, onClose }: { media: MediaRecord; onClose: () => void }) {
  const t = useT();
  const [lyrics, setLyrics] = useState<string | null | undefined>(undefined);
  const alive = useRef(true);
  useEffect(() => {
    alive.current = true;
    backend
      .libraryTags(media.id)
      .then((tags) => alive.current && setLyrics(tags.lyrics))
      .catch(() => alive.current && setLyrics(null));
    return () => {
      alive.current = false;
    };
  }, [media.id]);

  return (
    <BottomSheet open onClose={onClose} label={t('lyrics')} elevated>
      <h2 className="m-0 text-[18px] font-extrabold">{t('lyrics')}</h2>
      {lyrics === undefined ? (
        <div aria-busy="true" className="h-24" />
      ) : lyrics ? (
        <p className="m-0 whitespace-pre-wrap text-[15px] leading-6">{lyrics}</p>
      ) : (
        <p className="m-0 text-[13.5px] text-muted">{t('noLyrics')}</p>
      )}
    </BottomSheet>
  );
}
