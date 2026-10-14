// Puts the visitor's platform first among the download buttons. Without
// JavaScript both buttons still work: they are plain links.
(function () {
  var android = /Android/i.test(navigator.userAgent || '');
  var buttons = document.querySelector('.download-buttons');
  var windows = document.querySelector('[data-platform="windows"]');
  var apk = document.querySelector('[data-platform="android"]');
  if (!buttons || !windows || !apk) return;

  var first = android ? apk : windows;
  var second = android ? windows : apk;
  first.classList.add('primary');
  first.classList.remove('secondary');
  second.classList.add('secondary');
  second.classList.remove('primary');
  buttons.insertBefore(first, buttons.firstChild);
})();
