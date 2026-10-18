import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { invoke } from '@tauri-apps/api/core';
import './styles/load';
import { App } from './app/App';
import { detectPlatform, inTauri } from './services/platform';

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
