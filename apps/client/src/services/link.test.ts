import { describe, expect, it } from 'vitest';
import { checkLinkLocally } from './link';

// Mirrors crates/media-core/src/url.rs so the browser preview behaves like the app.
describe('checkLinkLocally', () => {
  it('accepts http and https links', () => {
    expect(checkLinkLocally(' https://mango.blender.org/download/ ')).toEqual({
      ok: true,
      url: 'https://mango.blender.org/download/',
      host: 'mango.blender.org',
    });
  });

  it.each([
    ['', 'empty'],
    ['mango.blender', 'malformed'],
    ['file:///C:/Windows/win.ini', 'unsupported_scheme'],
    ['javascript:alert(1)', 'unsupported_scheme'],
    ['https://user:pass@example.org/', 'contains_credentials'],
    [`https://example.org/${'a'.repeat(2048)}`, 'too_long'],
  ])('rejects %j as %s', (input, code) => {
    expect(checkLinkLocally(input)).toEqual({ ok: false, code });
  });
});
