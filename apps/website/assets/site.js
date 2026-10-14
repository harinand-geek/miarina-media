// Puts the visitor's platform first among the download buttons (design
// behaviour). Everything works without JavaScript: both buttons are links.
(function () {
  var android = /Android/i.test(navigator.userAgent || '');
  var buttons = document.querySelector('.download-buttons');
  var windows = document.querySelector('[data-platform="windows"]');
  var apk = document.querySelector('[data-platform="android"]');
  var note = document.getElementById('detect-note');
  if (!buttons || !windows || !apk || !note) return;

  var first = android ? apk : windows;
  var second = android ? windows : apk;
  first.classList.add('primary');
  first.classList.remove('secondary');
  second.classList.add('secondary');
  second.classList.remove('primary');
  buttons.insertBefore(first, buttons.firstChild);
  note.textContent = android
    ? 'Android détecté. Version Windows également disponible.'
    : 'Windows détecté. Version Android également disponible.';
})();
