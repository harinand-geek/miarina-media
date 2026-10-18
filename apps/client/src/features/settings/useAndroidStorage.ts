import { ANDROID_STORES } from '../../dev/fixtures';
import { backend } from '../../services/backend';
import { useSettings } from '../../stores/settings';

/** `.../files/Movies/Miarina` → `Movies/Miarina`. */
export function shortStoragePath(dir: string) {
  return dir.split(/[\\/]/).filter(Boolean).slice(-2).join('/');
}

/** App-specific storage (`Android/data/<app>`): Android 10 and older. */
const inAppStorage = (dir: string) => /[\\/]Android[\\/]data[\\/]/.test(dir);

/**
 * Where Android downloads go. The preview keeps the designed picker
 * (internal storage / SD card). The app saves video in shared
 * Movies/Miarina and audio in Music/Miarina on Android 11+, or in its own
 * storage on older versions, so it shows that, not a fixture.
 */
export function useAndroidStorage(kind?: 'video' | 'audio') {
  const storeId = useSettings((s) => s.androidStore);
  const downloadDir = useSettings((s) => s.downloadDir);
  const audioDir = useSettings((s) => s.audioDownloadDir);
  if (backend.kind === 'mock') {
    const store = ANDROID_STORES.find((s) => s.id === storeId)!;
    return { icon: store.icon, label: `${store.label} · ${store.path}`, canChange: true };
  }
  // One kind (analysis sheet): only its folder; otherwise both.
  const dirs =
    kind === 'audio' && audioDir ? [audioDir] : kind ? [downloadDir] : [downloadDir, audioDir];
  const folders = dirs.filter(Boolean).map((d) => shortStoragePath(d!));
  return {
    icon: 'smartphone',
    label: `${inAppStorage(downloadDir) ? 'App storage' : 'Internal storage'} · ${folders.join(' · ')}`,
    canChange: false,
  };
}
