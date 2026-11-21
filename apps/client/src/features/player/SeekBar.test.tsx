import { fireEvent, render, screen } from '@testing-library/react';
import { expect, it, vi } from 'vitest';
import { SeekBar } from './SeekBar';

it('previews a captured drag, ignores playback ticks, and seeks once on release', () => {
  vi.stubGlobal('PointerEvent', MouseEvent);
  const seek = vi.fn();
  const { rerender } = render(<SeekBar time={10} duration={100} onSeek={seek} />);
  const slider = screen.getByRole('slider');
  slider.setPointerCapture = vi.fn();
  slider.releasePointerCapture = vi.fn();
  vi.spyOn(slider, 'getBoundingClientRect').mockReturnValue({ left: 20, width: 200 } as DOMRect);
  fireEvent.pointerDown(slider, { button: 0, clientX: 60 });
  fireEvent.pointerMove(slider, { clientX: 170 });
  rerender(<SeekBar time={12} duration={100} onSeek={seek} />);
  expect(slider).toHaveAttribute('aria-valuenow', '75');
  expect(seek).not.toHaveBeenCalled();
  fireEvent.pointerUp(slider, { clientX: 300 });
  expect(seek).toHaveBeenCalledExactlyOnceWith(100);
  vi.unstubAllGlobals();
});

it('cancels a drag without seeking and clamps keyboard seeking', () => {
  vi.stubGlobal('PointerEvent', MouseEvent);
  const seek = vi.fn();
  render(<SeekBar time={3} duration={100} onSeek={seek} />);
  const slider = screen.getByRole('slider');
  slider.setPointerCapture = vi.fn();
  vi.spyOn(slider, 'getBoundingClientRect').mockReturnValue({ left: 0, width: 100 } as DOMRect);
  fireEvent.pointerDown(slider, { button: 0, clientX: 80 });
  fireEvent.pointerCancel(slider);
  expect(seek).not.toHaveBeenCalled();
  expect(slider).toHaveAttribute('aria-valuenow', '3');
  fireEvent.keyDown(slider, { key: 'ArrowLeft' });
  expect(seek).toHaveBeenLastCalledWith(0);
  vi.unstubAllGlobals();
});
