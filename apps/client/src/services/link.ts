import { invoke } from '@tauri-apps/api/core';
import { inTauri } from './platform';
import type { LinkErrorCode } from './types';

export type LinkCheck =
  { ok: true; url: string; host: string } | { ok: false; code: LinkErrorCode };

/**
 * Validates a pasted link. Inside Tauri the Rust `media-core` rules are the
 * authority; the browser fallback only exists for UI development and tests.
 */
export async function checkLink(input: string): Promise<LinkCheck> {
  if (inTauri()) {
    try {
      const valid = await invoke<{ url: string; host: string }>('validate_media_url', {
        url: input,
      });
      return { ok: true, ...valid };
    } catch (code) {
      return { ok: false, code: code as LinkErrorCode };
    }
  }
  return checkLinkLocally(input);
}

export function checkLinkLocally(input: string): LinkCheck {
  const trimmed = input.trim();
  if (!trimmed) return { ok: false, code: 'empty' };
  if (trimmed.length > 2048) return { ok: false, code: 'too_long' };
  let url: URL;
  try {
    url = new URL(trimmed);
  } catch {
    return { ok: false, code: 'malformed' };
  }
  if (url.protocol !== 'http:' && url.protocol !== 'https:') {
    return { ok: false, code: 'unsupported_scheme' };
  }
  if (!url.hostname) return { ok: false, code: 'missing_host' };
  if (url.username || url.password) return { ok: false, code: 'contains_credentials' };
  return { ok: true, url: url.href, host: url.hostname };
}
