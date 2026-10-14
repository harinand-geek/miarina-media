const { invoke } = window.__TAURI__.core;
const { listen } = window.__TAURI__.event;
const $ = (id) => document.getElementById(id);
const status = (text) => { $('status').textContent = text; };

$('back').onclick = () => invoke('nav', { action: 'back' });
$('forward').onclick = () => invoke('nav', { action: 'forward' });
$('reload').onclick = () => invoke('nav', { action: 'reload' });
$('bar').onsubmit = async (e) => {
  e.preventDefault();
  try { $('address').value = await invoke('navigate', { url: $('address').value }); }
  catch (err) { status(String(err)); }
};
$('chip').onclick = () => invoke('open_sheet');

const show = (snap) => {
  $('chip').hidden = snap.count === 0;
  $('chip').textContent = `⬇ ${snap.count} media`;
};
listen('detections', (e) => show(e.payload));
listen('address', (e) => { if (document.activeElement !== $('address')) $('address').value = e.payload; status('loading…'); });
listen('loaded', () => status('loaded'));
listen('shortcut', (e) => status(`shortcut ${e.payload} (page had focus)`));
listen('focus-address', () => { $('address').focus(); $('address').select(); });
listen('download-blocked', () => status('browser download refused (engine owns downloads)'));
listen('mse', () => status('player uses MSE (blob:) → analyse the page URL'));
invoke('snapshot').then(show);
