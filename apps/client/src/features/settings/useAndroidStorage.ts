import { ANDROID_STORES } from '../../dev/fixtures';
import { backend } from '../../services/backend';
import { useSettings } from '../../stores/settings';

/** `.../files/Movies/Miarina` → `Movies/Miarina`. */
export function shortStoragePath(dir: string) {
  return dir.split(/[\\/]/).filter(Boolean).slice(-2).join('/');
}

/**
 * Where Android downloads go. The preview keeps the designed picker
 * (internal storage / SD card); the app saves in its own storage until the
 * MediaStore adapter exists (Phase 4), so it shows that, not a fixture.
 */
export function useAndroidStorage() {
  const storeId = useSettings((s) => s.androidStore);
  const downloadDir = useSettings((s) => s.downloadDir);
  if (backend.kind === 'mock') {
    const store = ANDROID_STORES.find((s) => s.id === storeId)!;
    return { icon: store.icon, label: `${store.label} · ${store.path}`, canChange: true };
  }
  return {
    icon: 'smartphone',
    label: `App storage · ${shortStoragePath(downloadDir)}`,
    canChange: false,
  };
}
