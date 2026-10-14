import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import './styles/load';
import { BrowserOverlayApp } from './features/browser/BrowserApps';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <BrowserOverlayApp />
  </StrictMode>,
);
