import { StrictMode } from 'react';
import { renderToString } from 'react-dom/server';
import { ROUTES, SITE, type Route } from './routes';

export const paths = ROUTES.map((route) => route.path);

const escape = (text: string) =>
  text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

function head(route: Route): string {
  const url = SITE + route.path;
  const tags = [
    `<title>${escape(route.title)}</title>`,
    `<meta name="description" content="${escape(route.description)}" />`,
    `<link rel="canonical" href="${escape(url)}" />`,
  ];
  if (route.alternates) {
    const { fr, en } = route.alternates;
    tags.push(
      `<link rel="alternate" hreflang="fr" href="${escape(SITE + fr)}" />`,
      `<link rel="alternate" hreflang="en" href="${escape(SITE + en)}" />`,
      `<link rel="alternate" hreflang="x-default" href="${escape(SITE + fr)}" />`,
    );
  }
  if (route.og) {
    tags.push(
      `<meta property="og:title" content="${escape(route.og.title)}" />`,
      `<meta property="og:description" content="${escape(route.og.description)}" />`,
      `<meta property="og:url" content="${escape(url)}" />`,
      `<meta property="og:image" content="${escape(SITE + route.og.image)}" />`,
      '<meta property="og:type" content="website" />',
    );
  }
  return tags.join('\n    ');
}

/** HTML for one page: what goes in `<head>` and in `#root`. */
export function render(path: string): { head: string; html: string; lang: string } {
  const route = ROUTES.find((r) => r.path === path);
  if (!route) throw new Error(`unknown route ${path}`);
  const { Page } = route;
  return {
    lang: route.lang ?? 'fr',
    head: head(route),
    html: renderToString(
      <StrictMode>
        <Page />
      </StrictMode>,
    ),
  };
}
