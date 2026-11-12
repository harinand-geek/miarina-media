import { Icon } from '../../components/Icon';
import { useT } from '../../i18n';
import type { PlayerTrack } from '../../services/types';
import { usePlayer } from '../../stores/player';
import { useUi } from '../../stores/ui';

/** Subtitle delay step and bound (milliseconds). */
const DELAY_STEP = 100;
const DELAY_MAX = 60_000;

const delayLabel = (ms: number, lang: string) => {
  const secs = (ms / 1000).toLocaleString(lang === 'fr' ? 'fr-FR' : 'en-GB', {
    minimumFractionDigits: 1,
    maximumFractionDigits: 1,
    signDisplay: 'exceptZero',
  });
  return `${secs} s`;
};

/**
 * Audio tracks and subtitles of the playing file (WIN-05, WIN-06), in the
 * side panel: never over the picture, which is a native window.
 */
export function TracksPanel({ lang }: { lang: string }) {
  const t = useT();
  const tracks = usePlayer((s) => s.tracks);
  const { setAudioTrack, setSubtitle, addSubtitle, setSubtitleDelay } = usePlayer.getState();
  if (!tracks) return null;
  const name = (track: PlayerTrack, i: number) => track.name || t('trackUnnamed', { n: i + 1 });
  const delay = tracks.subtitleDelay;
  const shift = (ms: number) =>
    setSubtitleDelay(Math.max(-DELAY_MAX, Math.min(DELAY_MAX, delay + ms)));

  const pickSubtitle = async () => {
    if (await addSubtitle()) {
      useUi.getState().pushToast({ tone: 'success', message: t('subtitleAdded') });
    }
  };

  return (
    <section
      aria-label={t('tracksTitle')}
      className="flex flex-col gap-3 border-b border-divider p-[18px] text-[12.5px]"
    >
      <span className="text-overline font-bold uppercase tracking-[0.06em] text-muted">
        {t('tracksTitle')}
      </span>

      <div role="radiogroup" aria-label={t('audioTracks')} className="flex flex-col gap-0.5">
        <span className="pb-1 font-semibold text-muted">{t('audioTracks')}</span>
        {tracks.audio.length === 0 && <span className="text-muted">{t('noAudioTrack')}</span>}
        {tracks.audio.map((track, i) => (
          <Choice
            key={track.id}
            label={name(track, i)}
            checked={tracks.audioId === track.id}
            onSelect={() => setAudioTrack(track.id)}
          />
        ))}
      </div>

      <div role="radiogroup" aria-label={t('subtitles')} className="flex flex-col gap-0.5">
        <span className="pb-1 font-semibold text-muted">{t('subtitles')}</span>
        <Choice
          label={t('subtitlesOff')}
          checked={tracks.subtitleId < 0}
          onSelect={() => setSubtitle(-1)}
        />
        {tracks.subtitles.map((track, i) => (
          <Choice
            key={track.id}
            label={name(track, i)}
            checked={tracks.subtitleId === track.id}
            onSelect={() => setSubtitle(track.id)}
          />
        ))}
        <button
          type="button"
          onClick={() => void pickSubtitle()}
          className="mt-1 flex h-8 items-center gap-2 rounded-sm px-2 text-left font-semibold text-accent-strong hover:bg-surface"
        >
          <Icon name="add" size={18} />
          {t('addSubtitle')}
        </button>
      </div>

      <div className="flex items-center gap-1.5">
        <span className="flex-1 font-semibold text-muted">{t('subtitleDelay')}</span>
        <button
          type="button"
          aria-label={t('delayEarlier')}
          onClick={() => shift(-DELAY_STEP)}
          className="grid size-8 place-items-center rounded-sm hover:bg-surface"
        >
          <Icon name="remove" size={18} />
        </button>
        <span aria-live="polite" className="w-16 text-center font-mono tabular">
          {delayLabel(delay, lang)}
        </span>
        <button
          type="button"
          aria-label={t('delayLater')}
          onClick={() => shift(DELAY_STEP)}
          className="grid size-8 place-items-center rounded-sm hover:bg-surface"
        >
          <Icon name="add" size={18} />
        </button>
        <button
          type="button"
          aria-label={t('delayReset')}
          title={t('delayReset')}
          disabled={delay === 0}
          onClick={() => setSubtitleDelay(0)}
          className="grid size-8 place-items-center rounded-sm hover:bg-surface disabled:opacity-40"
        >
          <Icon name="restart_alt" size={18} />
        </button>
      </div>
    </section>
  );
}

function Choice({
  label,
  checked,
  onSelect,
}: {
  label: string;
  checked: boolean;
  onSelect: () => void;
}) {
  return (
    <button
      type="button"
      role="radio"
      aria-checked={checked}
      onClick={onSelect}
      className={`flex h-8 items-center gap-2 rounded-sm px-2 text-left hover:bg-surface ${
        checked ? 'font-semibold text-fg' : 'text-muted'
      }`}
    >
      <Icon
        name={checked ? 'radio_button_checked' : 'radio_button_unchecked'}
        size={18}
        className={checked ? 'text-accent-strong' : ''}
      />
      <span className="min-w-0 truncate">{label}</span>
    </button>
  );
}
