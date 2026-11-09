document.getElementById('id').textContent = chrome.runtime.id;
const status = document.getElementById('status');
const button = document.getElementById('send');
chrome.storage.local.get('lastResult').then((result) => {
  status.textContent = result.lastResult?.message || '';
});
button.addEventListener('click', async () => {
  button.disabled = true;
  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    const reply = await chrome.runtime.sendMessage({ type: 'send', url: tab?.url });
    status.textContent = reply?.message || 'No response. Check the app connection.';
  } catch {
    status.textContent = 'Unable to send. Check the app connection.';
  } finally {
    button.disabled = false;
  }
});
