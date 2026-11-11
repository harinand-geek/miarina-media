import { useEffect, useId, useRef, useState, type KeyboardEvent } from 'react';
import { Button, IconButton } from '../../components/Button';
import { Icon } from '../../components/Icon';
import { useT, type MessageKey } from '../../i18n';
import { backend } from '../../services/backend';
import type { MediaRecord, MediaTags } from '../../services/types';
import { useLibrary } from '../../stores/library';
import { useUi } from '../../stores/ui';
import { MediaThumb } from './MediaThumb';
import { extensionOf, tagsFromFileName } from './tagNames';

/** Formats whose tags are written back into the file (mirror of `library::tags`). */
const WRITABLE = ['mp3', 'flac', 'm4a', 'ogg', 'opus', 'wav', 'aiff', 'aif'];

type TextKey = 'title' | 'artist' | 'album' | 'albumArtist' | 'genre' | 'comment';
type NumberKey = 'year' | 'trackNo' | 'discNo';
type Field = { key: TextKey | NumberKey; label: MessageKey; wide?: boolean };

const AUDIO_FIELDS: Field[] = [
  { key: 'title', label: 'fTitle', wide: true },
  { key: 'artist', label: 'fArtist' },
  { key: 'albumArtist', label: 'fAlbumArtist' },
  { key: 'album', label: 'fAlbum' },
  { key: 'year', label: 'fYear' },
  { key: 'genre', label: 'fGenre' },
  { key: 'trackNo', label: 'fTrack' },
  { key: 'discNo', label: 'fDisc' },
  { key: 'comment', label: 'fComment' },
];
const VIDEO_FIELDS: Field[] = [
  { key: 'title', label: 'fTitle', wide: true },
  { key: 'artist', label: 'fDirector' },
  { key: 'year', label: 'fYear' },
  { key: 'genre', label: 'fGenre' },
  { key: 'album', label: 'fSeries' },
  { key: 'comment', label: 'fLicense', wide: true },
];
const NUMBERS: NumberKey[] = ['year', 'trackNo', 'discNo'];

export type Draft = Record<TextKey | NumberKey | 'lyrics', string>;

const toDraft = (t: MediaTags): Draft => ({
  title: t.title ?? '',
  artist: t.artist ?? '',
  album: t.album ?? '',
  albumArtist: t.albumArtist ?? '',
  genre: t.genre ?? '',
  comment: t.comment ?? '',
  lyrics: t.lyrics ?? '',
  year: t.year?.toString() ?? '',
  trackNo: t.trackNo?.toString() ?? '',
  discNo: t.discNo?.toString() ?? '',
});

const text = (v: string) => (v.trim() ? v.trim() : null);
const int = (v: string) => (v.trim() && /^\d+$/.test(v.trim()) ? Number(v.trim()) : null);
const validNumber = (v: string) => !v.trim() || /^\d{1,4}$/.test(v.trim());

const fromDraft = (d: Draft): MediaTags => ({
  title: text(d.title),
  artist: text(d.artist),
  album: text(d.album),
  albumArtist: text(d.albumArtist),
  genre: text(d.genre),
  comment: text(d.comment),
  lyrics: text(d.lyrics),
  year: int(d.year),
  trackNo: int(d.trackNo),
  discNo: int(d.discNo),
});

export function TagEditor() {
  const media = useUi((s) => s.tagEditor);
  return media ? <Editor key={media.id} media={media} /> : null;
}

function Editor({ media }: { media: MediaRecord }) {
  const t = useT();
  const close = () => useUi.setState({ tagEditor: null });
  const titleId = useId();
  const dialogRef = useRef<HTMLDivElement>(null);
  const [original, setOriginal] = useState<Draft | null>(null);
  const [draft, setDraft] = useState<Draft | null>(null);
  const isVideo = media.kind === 'video';
  const ext = extensionOf(media.path);
  const writable = !isVideo && WRITABLE.includes(ext);
  const [writeToFile, setWriteToFile] = useState(writable);
  const [rename, setRename] = useState(false);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    let alive = true;
    backend
      .libraryTags(media.id)
      .then((tags) => {
        if (!alive) return;
        setOriginal(toDraft(tags));
        setDraft(toDraft(tags));
      })
      .catch((e: unknown) => {
        useUi.getState().pushToast({ tone: 'error', message: e instanceof Error ? e.message : String(e) });
        useUi.setState({ tagEditor: null });
      });
    return () => {
      alive = false;
    };
  }, [media.id]);

  useEffect(() => {
    if (draft) dialogRef.current?.querySelector<HTMLInputElement>('input')?.focus();
    // Focus once, when the tags arrive.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [draft === null]);

  const fields = isVideo ? VIDEO_FIELDS : AUDIO_FIELDS;
  const invalid = draft ? NUMBERS.some((k) => !validNumber(draft[k])) : true;
  const renameTo =
    draft && text(draft.artist) && text(draft.title)
      ? `${draft.artist.trim()} - ${draft.title.trim()}`
      : null;

  const save = async () => {
    if (!draft || invalid || saving) return;
    setSaving(true);
    const library = useLibrary.getState();
    // Rename first: the tag title then replaces the file-name title.
    if (rename && renameTo && !(await library.rename(media.id, renameTo))) {
      setSaving(false);
      return;
    }
    const ok = await library.updateTags(media.id, fromDraft(draft), writable && writeToFile);
    setSaving(false);
    if (!ok) return;
    close();
    useUi.getState().pushToast({
      tone: 'success',
      message: writable && writeToFile ? t('tagsSavedFile') : t('tagsSavedLibrary'),
    });
  };

  const onKeyDown = (e: KeyboardEvent) => {
    if (e.key === 'Escape') {
      e.stopPropagation();
      close();
    }
  };

  return (
    <div
      className="absolute inset-0 z-40 grid animate-fade-in place-items-center bg-scrim"
      onMouseDown={close}
    >
      <div
        ref={dialogRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        onKeyDown={onKeyDown}
        onMouseDown={(e) => e.stopPropagation()}
        className="flex max-h-[min(820px,calc(100%-32px))] w-[760px] max-w-[calc(100%-32px)] animate-dialog-in flex-col overflow-hidden rounded-xl border border-line-strong bg-surface2 shadow-dialog"
      >
        <div className="flex items-center gap-3 px-6 pb-3.5 pt-5">
          <Icon name="edit_note" size={22} className="text-accent-strong" />
          <div className="flex min-w-0 flex-1 flex-col gap-0.5">
            <h2 id={titleId} className="m-0 text-[18px] font-bold">
              {t('editTags')}
            </h2>
            <span className="truncate font-mono text-[11.5px] text-muted" title={media.path}>
              {media.path}
            </span>
          </div>
          <span className="rounded-xs border border-line bg-surface px-2 py-1 font-mono text-[11.5px] font-bold text-muted">
            {ext.toUpperCase() || '—'}
          </span>
          <IconButton icon="close" label={t('cancel')} onClick={close} />
        </div>

        <div className="flex flex-wrap gap-1.5 px-6 pb-3.5">
          <button
            type="button"
            disabled={!draft}
            onClick={() => draft && setDraft({ ...draft, ...tagsFromFileName(media.path) })}
            className="flex h-[30px] items-center gap-1.5 rounded-full border border-line-strong bg-surface px-[11px] text-[12px] font-semibold"
          >
            <Icon name="auto_fix_high" size={16} />
            {t('tagFromName')}
          </button>
          <button
            type="button"
            aria-pressed={rename}
            disabled={!renameTo}
            onClick={() => setRename((r) => !r)}
            className={`flex h-[30px] items-center gap-1.5 rounded-full border px-[11px] text-[12px] font-semibold disabled:opacity-50 ${
              rename ? 'border-chip-border bg-accent-subtle text-chip-text' : 'border-line-strong bg-surface'
            }`}
          >
            <Icon name="drive_file_rename_outline" size={16} />
            {t('tagRename')}
          </button>
        </div>

        <div className="grid min-h-0 flex-1 grid-cols-[220px_minmax(0,1fr)] gap-6 overflow-auto px-6 pb-5">
          <div className="flex flex-col gap-2.5">
            <MediaThumb
              media={media}
              className={`w-full rounded-lg border border-line-strong ${isVideo ? 'aspect-[2/3]' : 'aspect-square'}`}
            />
            <span className="text-[11.5px] leading-[1.45] text-muted">{t('coverPlanned')}</span>
          </div>
          {draft && original ? (
            <div className="grid grid-cols-2 content-start gap-x-3.5 gap-y-3">
              {fields.map((f) => {
                const value = draft[f.key];
                const changed = value !== original[f.key];
                const bad = NUMBERS.includes(f.key as NumberKey) && !validNumber(value);
                return (
                  <label key={f.key} className={`flex flex-col gap-[5px] ${f.wide ? 'col-span-2' : ''}`}>
                    <span className="text-[12px] font-bold text-muted">{t(f.label)}</span>
                    <input
                      value={value}
                      inputMode={NUMBERS.includes(f.key as NumberKey) ? 'numeric' : undefined}
                      aria-invalid={bad || undefined}
                      onChange={(e) => setDraft({ ...draft, [f.key]: e.target.value })}
                      placeholder="—"
                      className={`h-9 rounded-sm border bg-bg px-2.5 text-[13px] font-medium text-fg outline-none ${
                        bad ? 'border-danger' : changed ? 'border-accent' : 'border-line-strong'
                      }`}
                    />
                    {bad && <span className="text-[11.5px] text-danger">{t('invalidNumber')}</span>}
                  </label>
                );
              })}
              {!isVideo && (
                <label className="col-span-2 flex flex-col gap-[5px]">
                  <span className="text-[12px] font-bold text-muted">{t('fLyrics')}</span>
                  <textarea
                    value={draft.lyrics}
                    onChange={(e) => setDraft({ ...draft, lyrics: e.target.value })}
                    placeholder={t('fLyricsPh')}
                    className={`h-[72px] resize-none rounded-sm border bg-bg px-2.5 py-2 text-[13px] font-medium text-fg outline-none ${
                      draft.lyrics !== original.lyrics ? 'border-accent' : 'border-line-strong'
                    }`}
                  />
                </label>
              )}
              <span className="col-span-2 text-[12px] text-muted">
                {rename && renameTo ? t('renameNote', { name: `${renameTo}.${ext}` }) : t('tagNote')}
              </span>
            </div>
          ) : (
            <div aria-busy="true" className="min-h-40" />
          )}
        </div>

        <div className="flex items-center gap-2.5 border-t border-line bg-surface px-6 py-3.5">
          {writable ? (
            <label className="flex cursor-pointer items-center gap-2 text-[12.5px] font-semibold">
              <input
                type="checkbox"
                checked={writeToFile}
                onChange={(e) => setWriteToFile(e.target.checked)}
                className="h-[18px] w-[18px] accent-accent"
              />
              {t('tagWrite')}
            </label>
          ) : (
            <span className="text-[12.5px] text-muted">{t('tagWriteUnsupported')}</span>
          )}
          <span className="flex-1" />
          <Button onClick={close} className="h-[38px] text-[13.5px]">
            {t('cancel')}
          </Button>
          <Button
            variant="primary"
            disabled={!draft || invalid || saving}
            onClick={() => void save()}
            className="h-[38px] text-[13.5px]"
          >
            {t('save')}
          </Button>
        </div>
      </div>
    </div>
  );
}
