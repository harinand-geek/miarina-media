import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { invoke } from '@tauri-apps/api/core';
import './styles/load';
import { hydrateDurableState } from './services/durableState';
import { detectPlatform, inTauri } from './services/platform';

// Playback state comes back from SQLite before any store reads it (L02);
// the app modules are loaded only after that.
await hydrateDurableState();
const { App } = await import('./app/App');

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);

// Android keeps its launch screen until the first screen is painted (two
// frames after render), so no empty window shows in between.
if (inTauri() && detectPlatform() === 'android') {
  requestAnimationFrame(() =>
    requestAnimationFrame(() => void invoke('app_ready').catch(() => {})),
  );
}
