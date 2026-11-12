import { beforeEach, describe, expect, it, vi } from 'vitest';
const mocks = vi.hoisted(() => ({ invoke: vi.fn() }));
vi.mock('@tauri-apps/api/core', () => ({ invoke: mocks.invoke }));
vi.mock('../../services/platform', () => ({ inTauri: () => true }));
import { useUpdates } from './useUpdates';
const release = { version: '0.1.8', notes: 'Test', size: 100 };

/** Answers by command name; `{ reject }` makes the command fail. */
let answers: Record<string, unknown> = {};
const commands = () => mocks.invoke.mock.calls.map((c) => c[0]);
beforeEach(() => {
  mocks.invoke.mockReset();
  answers = {
    app_update_check: release,
    app_update_auto_allowed: false,
    app_update_download: release,
    app_update_progress: 0,
    app_update_prefs: { channel: 'stable', autoDownload: false },
  };
  mocks.invoke.mockImplementation((command: string, args?: Record<string, unknown>) => {
    const answer = answers[command];
    if (answer && typeof answer === 'object' && 'reject' in answer)
      return Promise.reject((answer as { reject: unknown }).reject);
    if (command === 'app_update_set_prefs') return Promise.resolve(args?.prefs);
    return Promise.resolve(answer);
  });
  useUpdates.setState({
    phase: 'idle',
    release: null,
    error: '',
    checked: false,
    downloaded: 0,
    prefs: { channel: 'stable', autoDownload: false },
  });
});

describe('application updates', () => {
  it('checks and downloads without installing automatically', async () => {
    await useUpdates.getState().check();
    expect(useUpdates.getState().phase).toBe('available');
    await useUpdates.getState().download();
    expect(useUpdates.getState().phase).toBe('ready');
    expect(commands()).toEqual([
      'app_update_check',
      'app_update_auto_allowed',
      'app_update_download',
    ]);
  });

  it('downloads by itself only when allowed, and still never installs', async () => {
    answers.app_update_auto_allowed = true;
    await useUpdates.getState().check();
    await vi.waitFor(() => expect(useUpdates.getState().phase).toBe('ready'));
    expect(commands()).toContain('app_update_download');
    expect(commands()).not.toContain('app_update_install');
  });

  it('keeps installation disabled after a failed verification', async () => {
    answers.app_update_download = { reject: { message: 'Invalid signature' } };
    await useUpdates.getState().check();
    await useUpdates.getState().download();
    expect(useUpdates.getState().phase).toBe('available');
    expect(useUpdates.getState().error).toBe('Invalid signature');
    await useUpdates.getState().install();
    expect(commands()).not.toContain('app_update_install');
  });

  it('a canceled download keeps its bytes for a resume, without an error', async () => {
    answers.app_update_download = { reject: { code: 'update_canceled', message: 'canceled' } };
    answers.app_update_progress = 40;
    await useUpdates.getState().check();
    await useUpdates.getState().download();
    expect(useUpdates.getState()).toMatchObject({ phase: 'available', downloaded: 40, error: '' });
  });

  it('explains a lost connection instead of the network library text', async () => {
    answers.app_update_download = {
      reject: { code: 'update_network', message: 'error decoding response body' },
    };
    answers.app_update_progress = 60;
    await useUpdates.getState().check();
    await useUpdates.getState().download();
    expect(useUpdates.getState()).toMatchObject({ phase: 'available', downloaded: 60 });
    expect(useUpdates.getState().error).toMatch(/connection to the update server/);
  });

  it('finds a ready or partial download again after a relaunch', async () => {
    answers.app_update_status = { release, ready: true, downloaded: 100, downloading: false };
    await useUpdates.getState().restore();
    expect(useUpdates.getState().phase).toBe('ready');

    useUpdates.setState({ phase: 'idle', release: null, downloaded: 0 });
    answers.app_update_status = { release, ready: false, downloaded: 30, downloading: false };
    await useUpdates.getState().restore();
    expect(useUpdates.getState()).toMatchObject({ phase: 'available', downloaded: 30 });
  });

  it('allows retry after Android install permission denial', async () => {
    useUpdates.setState({ phase: 'ready', release });
    answers.app_update_install = { reject: { message: 'Allow installation' } };
    answers.app_update_status = { release, ready: true, downloaded: 100, downloading: false };
    await useUpdates.getState().install();
    expect(useUpdates.getState().phase).toBe('ready');
    expect(useUpdates.getState().error).toBe('Allow installation');
  });

  it('explains that a conversion must finish first', async () => {
    useUpdates.setState({ phase: 'ready', release });
    answers.app_update_install = { reject: { code: 'update_converting', message: 'busy' } };
    answers.app_update_status = { release, ready: true, downloaded: 100, downloading: false };
    await useUpdates.getState().install();
    expect(useUpdates.getState().phase).toBe('ready');
    expect(useUpdates.getState().error).toMatch(/conversion/i);
  });

  it('saves the channel and the automatic download choice', async () => {
    await useUpdates.getState().setPrefs({ channel: 'beta' });
    await useUpdates.getState().setPrefs({ autoDownload: true });
    expect(useUpdates.getState().prefs).toEqual({ channel: 'beta', autoDownload: true });
    expect(mocks.invoke).toHaveBeenLastCalledWith('app_update_set_prefs', {
      prefs: { channel: 'beta', autoDownload: true },
    });
  });
});
