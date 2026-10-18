// Writes one static HTML file per route into dist/, from the client build's
// index.html and the server bundle. Runs after both `vite build` steps.
import { readFile, rm, writeFile } from 'node:fs/promises';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));
const dist = `${root}dist/`;
const serverEntry = `${root}dist-ssr/entry-server.js`;

const template = await readFile(`${dist}index.html`, 'utf8');
const { paths, render } = await import(pathToFileURL(serverEntry).href);

for (const path of paths) {
  const rendered = render(path);
  // React emits image preloads ahead of the markup; they belong in <head>.
  const preloads = rendered.html.match(/^(<link [^>]*\/>)*/)[0];
  const html = rendered.html.slice(preloads.length);
  const head = preloads ? `${rendered.head}\n    ${preloads.replace(/\/></g, '/>\n    <')}` : rendered.head;
  const page = template.replace('<!--head-->', () => head).replace('<!--app-->', () => html);
  if (page.includes('<!--head-->') || page.includes('<!--app-->')) {
    throw new Error(`placeholders left in ${path}`);
  }
  const file = path === '/' ? 'index.html' : path.slice(1);
  await writeFile(`${dist}${file}`, page);
  console.log(`prerendered ${path} -> dist/${file}`);
}

await rm(`${root}dist-ssr`, { recursive: true, force: true });
