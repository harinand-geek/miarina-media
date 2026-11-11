import { nativePlayer } from '../../services/nativePlayer';
import { savedSession, useMobilePlayback } from '../../stores/mobilePlayback';
import { useUi } from '../../stores/ui';

const STATUS_TIMEOUT_MS = 3000;

/**
 * Android launch (CDC AND-05): if the playback service is still playing the
 * saved queue (the app was swiped away, music went on), the screens attach
 * to it; otherwise the saved queue comes back minimized and paused, and the
 * first Play resumes it where it stopped. Never starts sound by itself.
 */
export async function restoreMobileSession() {
  const saved = savedSession();
  if (!saved) return;
  let playingId: number | null = null;
  try {
    // Connecting to the service starts it; never wait on it forever.
    const status = await Promise.race([
      nativePlayer.status(),
      new Promise<never>((_, reject) =>
        setTimeout(() => reject(new Error('timeout')), STATUS_TIMEOUT_MS),
      ),
    ]);
    if (status.open && status.mediaId != null) playingId = status.mediaId;
  } catch {
    // No service yet (or too slow): offer the saved queue.
  }
  // The user may have started something meanwhile.
  if (useUi.getState().nowPlaying) return;
  const store = useMobilePlayback.getState();
  if (playingId != null && saved.queue.some((m) => m.id === playingId)) {
    store.restore({ ...saved, currentId: playingId }, 'attach');
  } else {
    store.restore(saved, 'deferred');
  }
}
