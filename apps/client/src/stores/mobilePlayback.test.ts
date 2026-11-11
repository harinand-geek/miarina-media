import { beforeEach, describe, expect, it } from 'vitest';
import type { MediaRecord } from '../services/types';
import { useMobilePlayback } from './mobilePlayback';
import { useUi } from './ui';

const media = (id: number) =>
  ({ id, title: `T${id}`, kind: 'audio', path: `/m/${id}.mp3`, durationSecs: 60 }) as MediaRecord;
const LIST = [1, 2, 3, 4].map(media);
const ids = () => useMobilePlayback.getState().queue.map((m) => m.id);
const current = () => useUi.getState().nowPlaying?.id;

beforeEach(() => {
  localStorage.clear();
  useUi.setState(useUi.getInitialState(), true);
  useMobilePlayback.setState({ repeat: 'off', shuffle: false, unshuffled: null, rate: 1 });
});

describe('Android play queue', () => {
  it('starts on an item with the list as queue and moves through it', () => {
    const s = useMobilePlayback.getState();
    s.start(LIST[1]!, LIST, 'Album · Test');
    expect(current()).toBe(2);
    expect(useUi.getState().mobilePlayerExpanded).toBe(true);
    expect(useMobilePlayback.getState().source).toBe('Album · Test');
    expect(s.next()).toBe(true);
    expect(current()).toBe(3);
    expect(s.previous()).toBe(true);
    expect(current()).toBe(2);
  });

  it('wraps only when the whole queue repeats', () => {
    const s = useMobilePlayback.getState();
    s.start(LIST[3]!, LIST);
    expect(s.next()).toBe(false);
    s.cycleRepeat(); // all
    expect(s.next(true)).toBe(true);
    expect(current()).toBe(1);
  });

  it('shuffles the rest and restores the order', () => {
    const s = useMobilePlayback.getState();
    s.start(LIST[2]!, LIST);
    s.setShuffle(true);
    expect(ids()[0]).toBe(3);
    expect([...ids()].sort()).toEqual([1, 2, 3, 4]);
    s.setShuffle(false);
    expect(ids()).toEqual([1, 2, 3, 4]);
  });

  it('reorders, removes others but never the playing item, and clears to it', () => {
    const s = useMobilePlayback.getState();
    s.start(LIST[0]!, LIST);
    s.move(3, 1);
    expect(ids()).toEqual([1, 4, 2, 3]);
    s.remove(0);
    expect(ids()).toEqual([1, 4, 2, 3]);
    s.remove(1);
    expect(ids()).toEqual([1, 2, 3]);
    s.clear();
    expect(ids()).toEqual([1]);
  });

  it('starts a queue of one when the player opens from elsewhere, and persists the speed', () => {
    useMobilePlayback.getState().start(LIST[0]!, LIST);
    useUi.getState().play(media(9));
    expect(ids()).toEqual([9]);
    expect(useMobilePlayback.getState().source).toBeNull();
    useUi.getState().play(null);
    expect(ids()).toEqual([]);

    useMobilePlayback.getState().setRate(1.25);
    expect(localStorage.getItem('mm:mobile:rate')).toBe('1.25');
    useMobilePlayback.getState().setRate(7);
    expect(useMobilePlayback.getState().rate).toBe(1);
  });
});
