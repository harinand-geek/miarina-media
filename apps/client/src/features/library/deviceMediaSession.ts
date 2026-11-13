/** Indexing the phone again when Music opens: at most this often. */
export const RESYNC_MS = 5 * 60_000;

// The app indexes the phone at startup (Rust): Music only syncs again later.
export const deviceSession = { lastSync: Date.now(), dismissed: false };

/** Test helper: forget the session state. */
export function resetDeviceMediaCard(now = Date.now()) {
  deviceSession.lastSync = now;
  deviceSession.dismissed = false;
}
