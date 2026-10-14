import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
// Fonts are bundled locally: no third-party request at runtime.
import '@fontsource-variable/manrope';
import '@fontsource/jetbrains-mono/400.css';
import '@fontsource/jetbrains-mono/500.css';
import 'material-symbols/rounded.css';
import './styles/index.css';
import { App } from './app/App';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
