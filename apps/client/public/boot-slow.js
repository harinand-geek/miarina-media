// Android cold start (design_handoff_splash S5): when the interface is still
// not there 2.5 s after the page started (the system splash has then
// reached its 3 s cap), say so instead of leaving an empty screen. React
// replaces this content as soon as it renders. Plain script: it must run
// before the application bundle has loaded.
(function () {
  if (!/Android/i.test(navigator.userAgent)) return;
  setTimeout(function () {
    var root = document.getElementById('root');
    if (!root || root.childElementCount > 0) return;
    var fr = /^fr/i.test(navigator.language || '');
    var box = document.createElement('div');
    box.setAttribute('role', 'status');
    box.style.cssText =
      'position:fixed;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;' +
      'gap:12px;padding:24px;background:#101820;color:#F5F7FA;font-family:Manrope,sans-serif;text-align:center;' +
      'animation:none;opacity:0;transition:opacity 120ms';
    box.innerHTML =
      '<svg width="72" height="72" viewBox="0 0 32 32" aria-hidden="true"><rect width="32" height="32" rx="8" fill="#182530"/>' +
      '<path d="M13 9.5v13l10-6.5z" fill="#FF7A45"/><rect x="6" y="10.5" width="4" height="2.5" rx="1.25" fill="#35C9BD"/>' +
      '<rect x="4" y="14.75" width="6" height="2.5" rx="1.25" fill="#35C9BD"/><rect x="6" y="19" width="4" height="2.5" rx="1.25" fill="#35C9BD"/></svg>';
    var title = document.createElement('h1');
    title.textContent = fr ? 'Le démarrage prend plus de temps' : 'Starting is taking longer';
    title.style.cssText = 'margin:12px 0 0;font-size:18px;font-weight:800';
    var text = document.createElement('p');
    text.textContent = fr
      ? 'Miarina prépare l’interface. La lecture en cours n’est pas interrompue.'
      : 'Miarina is preparing the interface. Playback is not interrupted.';
    text.style.cssText = 'margin:0;max-width:300px;font-size:14px;line-height:20px;color:#94A3B8';
    var restart = document.createElement('button');
    restart.type = 'button';
    restart.textContent = fr ? 'Relancer' : 'Restart';
    restart.style.cssText =
      'margin-top:12px;height:48px;padding:0 24px;border-radius:999px;border:1px solid #2A3D4E;' +
      'background:#1F2F3B;color:#F5F7FA;font:700 15px Manrope,sans-serif';
    restart.addEventListener('click', function () {
      location.reload();
    });
    box.appendChild(title);
    box.appendChild(text);
    box.appendChild(restart);
    root.appendChild(box);
    requestAnimationFrame(function () {
      box.style.opacity = '1';
    });
  }, 2500);
})();
