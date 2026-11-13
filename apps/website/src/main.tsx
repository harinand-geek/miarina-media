import { StrictMode } from 'react';
import { createRoot, hydrateRoot } from 'react-dom/client';
import { findRoute } from './routes';
import './styles/site.css';
import './styles/landing-v4.css';

const { Page } = findRoute(window.location.pathname);
const app = (
  <StrictMode>
    <Page />
  </StrictMode>
);
const root = document.getElementById('root')!;

// Built pages arrive pre-rendered; the dev server serves an empty shell.
if (root.firstElementChild) hydrateRoot(root, app);
else createRoot(root).render(app);
