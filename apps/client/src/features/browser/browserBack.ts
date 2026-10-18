/**
 * Android Back inside the browser: set while the browser screen is shown.
 * Returns `true` when the browser handled it (menu, page history).
 */
export const browserBack: { current: (() => boolean) | null } = { current: null };
