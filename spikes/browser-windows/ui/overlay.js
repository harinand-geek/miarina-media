const { invoke } = window.__TAURI__.core;
const { listen } = window.__TAURI__.event;
const $ = (id) => document.getElementById(id);

const render = (snap) => {
  $('fab-label').textContent = snap.count > 1 ? `Download · ${snap.count}` : 'Download';
  $('items').replaceChildren(...snap.items.map((m) => {
    const li = document.createElement('li');
    li.textContent = `${m.kind} · ${m.name || '(no name)'} · ${m.host} · ${m.mime || '—'} · via ${m.via}`;
    return li;
  }));
};
listen('detections', (e) => render(e.payload));
listen('sheet', (e) => document.body.classList.toggle('open', e.payload));
$('fab').onclick = () => invoke('open_sheet');
$('scrim').onclick = () => invoke('close_sheet');
$('close').onclick = () => invoke('close_sheet');
document.addEventListener('keydown', (e) => { if (e.key === 'Escape') invoke('close_sheet'); });
invoke('snapshot').then(render);
