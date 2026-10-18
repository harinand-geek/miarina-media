import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';

// Pages are pre-rendered to HTML at build time (scripts/prerender.mjs) and
// hydrated by one external module: no inline script, which the site's CSP
// (deploy/nginx) forbids.
export default defineConfig({
  plugins: [react()],
  build: {
    outDir: 'dist',
    emptyOutDir: true,
  },
});
