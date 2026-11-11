export const extensionOf = (path: string) => path.split('.').pop()?.toLowerCase() ?? '';
const fileStem = (path: string) =>
  (path.split(/[\\/]/).pop() ?? '').replace(/\.[^.]+$/, '');

/** "01 - Artist - Title" / "Artist - Title" / "Title" from a file name. */
export function tagsFromFileName(path: string): Partial<Record<string, string>> {
  const parts = fileStem(path)
    .replace(/_/g, ' ')
    .split(/\s+-\s+/)
    .map((p) => p.trim())
    .filter(Boolean);
  const track = parts[0]?.match(/^(\d{1,3})\.?$/)?.[1];
  if (track) parts.shift();
  const out: Partial<Record<string, string>> = track ? { trackNo: String(Number(track)) } : {};
  if (parts.length >= 2) {
    out.artist = parts[0]!;
    out.title = parts.slice(1).join(' - ');
  } else if (parts.length === 1) {
    out.title = parts[0]!.replace(/^\d{1,3}[.\s]+/, '');
  }
  return out;
}
