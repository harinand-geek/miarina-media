import { useEffect, useId, useRef, useState } from 'react';
import { Button } from '../../components/Button';
import { Icon } from '../../components/Icon';
import { useT } from '../../i18n';
import { usePlaylists } from '../../stores/playlists';
import { useUi, type PlaylistDialog } from '../../stores/ui';

/**
 * Playlist dialogs (COM-06): name a new playlist, rename one, or add
 * entries to a playlist. Not in the design handoff: built from the rename
 * dialog layout, with the design tokens.
 */
export function PlaylistDialogs() {
  const dialog = useUi((s) => s.playlistDialog);
  if (!dialog) return null;
  // A new dialog starts from fresh state.
  const key = dialog.kind === 'rename' ? `r${dialog.id}` : `${dialog.kind}${dialog.ids.join(',')}`;
  return dialog.kind === 'add' ? (
    <AddDialog key={key} ids={dialog.ids} />
  ) : (
    <NameDialog key={key} dialog={dialog} />
  );
}

const close = () => useUi.setState({ playlistDialog: null });

function Frame({
  titleId,
  onSubmit,
  children,
}: {
  titleId: string;
  onSubmit: () => void;
  children: React.ReactNode;
}) {
  return (
    <div
      className="fixed inset-0 z-40 grid animate-fade-in place-items-center bg-scrim"
      onMouseDown={close}
    >
      <form
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        onMouseDown={(e) => e.stopPropagation()}
        onKeyDown={(e) => e.key === 'Escape' && close()}
        onSubmit={(e) => {
          e.preventDefault();
          onSubmit();
        }}
        className="flex w-[420px] max-w-[calc(100%-32px)] animate-dialog-in flex-col gap-3 rounded-xl border border-line-strong bg-surface p-6 shadow-dialog"
      >
        {children}
      </form>
    </div>
  );
}

function NameDialog({ dialog }: { dialog: Exclude<PlaylistDialog, { kind: 'add' }> }) {
  const t = useT();
  const titleId = useId();
  const [name, setName] = useState(dialog.kind === 'rename' ? dialog.name : '');
  const [saving, setSaving] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);
  useEffect(() => {
    inputRef.current?.select();
  }, []);

  const submit = async () => {
    const value = name.trim();
    if (!value) return;
    setSaving(true);
    const store = usePlaylists.getState();
    const ok =
      dialog.kind === 'rename'
        ? await store.rename(dialog.id, value)
        : !!(await store.create(value, dialog.ids));
    setSaving(false);
    if (ok) close();
  };

  return (
    <Frame titleId={titleId} onSubmit={() => void submit()}>
      <h2 id={titleId} className="m-0 text-[17px] font-bold">
        {dialog.kind === 'rename' ? t('renamePlaylist') : t('newPlaylist')}
      </h2>
      {dialog.kind === 'create' && dialog.ids.length > 0 && (
        <p className="m-0 text-[12.5px] text-muted">
          {t('playlistFrom', { n: dialog.ids.length })}
        </p>
      )}
      <input
        ref={inputRef}
        value={name}
        maxLength={120}
        onChange={(e) => setName(e.target.value)}
        aria-label={t('playlistName')}
        placeholder={t('playlistName')}
        className="h-11 rounded-sm border border-line-strong bg-bg px-3 text-[13.5px] text-fg outline-none focus:border-accent focus:shadow-[0_0_0_3px_rgba(53,201,189,.18)]"
      />
      <div className="mt-1 flex justify-end gap-2">
        <Button type="button" onClick={close} className="h-[38px] text-[13px]">
          {t('cancel')}
        </Button>
        <Button
          type="submit"
          variant="primary"
          disabled={saving || !name.trim()}
          className="h-[38px] text-[13px]"
        >
          {dialog.kind === 'rename' ? t('rename') : t('createPlaylist')}
        </Button>
      </div>
    </Frame>
  );
}

function AddDialog({ ids }: { ids: number[] }) {
  const t = useT();
  const titleId = useId();
  const list = usePlaylists((s) => s.list);
  const [choice, setChoice] = useState<number | 'new' | null>(list[0]?.id ?? 'new');
  const [name, setName] = useState('');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    void usePlaylists.getState().load();
  }, []);

  const submit = async () => {
    if (choice === null) return;
    setSaving(true);
    const store = usePlaylists.getState();
    const ok =
      choice === 'new'
        ? !!name.trim() && !!(await store.create(name.trim(), ids))
        : await store.add(choice, ids);
    setSaving(false);
    if (ok) close();
  };

  const option = (id: number | 'new', label: string, detail?: string) => {
    const on = choice === id;
    return (
      <button
        key={id}
        type="button"
        role="radio"
        aria-checked={on}
        onClick={() => setChoice(id)}
        className={`flex h-11 items-center gap-3 rounded-md border px-3 text-left text-[13.5px] ${
          on ? 'border-accent bg-accent-subtle' : 'border-line bg-bg hover:bg-surface2'
        }`}
      >
        <Icon name={id === 'new' ? 'add' : 'queue_music'} size={18} className="text-muted" />
        <span className="min-w-0 flex-1 truncate font-semibold">{label}</span>
        {detail && <span className="shrink-0 text-[12px] text-muted">{detail}</span>}
      </button>
    );
  };

  return (
    <Frame titleId={titleId} onSubmit={() => void submit()}>
      <h2 id={titleId} className="m-0 text-[17px] font-bold">
        {t('addToPlaylistTitle', { n: ids.length })}
      </h2>
      <div
        role="radiogroup"
        aria-labelledby={titleId}
        className="flex max-h-[280px] flex-col gap-1.5 overflow-auto"
      >
        {list.map((p) => option(p.id, p.name, t('tracksCount', { n: p.count })))}
        {option('new', t('newPlaylist'))}
      </div>
      {choice === 'new' && (
        <input
          autoFocus
          value={name}
          maxLength={120}
          onChange={(e) => setName(e.target.value)}
          aria-label={t('playlistName')}
          placeholder={t('playlistName')}
          className="h-11 rounded-sm border border-line-strong bg-bg px-3 text-[13.5px] text-fg outline-none focus:border-accent"
        />
      )}
      <div className="mt-1 flex justify-end gap-2">
        <Button type="button" onClick={close} className="h-[38px] text-[13px]">
          {t('cancel')}
        </Button>
        <Button
          type="submit"
          variant="primary"
          disabled={saving || choice === null || (choice === 'new' && !name.trim())}
          className="h-[38px] text-[13px]"
        >
          {t('add')}
        </Button>
      </div>
    </Frame>
  );
}
