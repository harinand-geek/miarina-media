import { fireEvent, render, screen } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { backend } from '../services/backend';
import { LocalThumb } from './LocalThumb';
import logo from '../assets/logo.svg';

afterEach(() => vi.restoreAllMocks());

describe('LocalThumb', () => {
  it('shows the cached picture, then the placeholder if it cannot be read', () => {
    vi.spyOn(backend, 'mediaUrl').mockImplementation((p) => `asset://${p}`);
    const { container } = render(
      <LocalThumb path="C:/data/thumbnails/sources/ab.jpg" kind="video" />,
    );
    const img = container.querySelector('img');
    expect(img).toHaveAttribute('src', 'asset://C:/data/thumbnails/sources/ab.jpg');
    expect(screen.queryByText('Video')).toBeNull();

    fireEvent.error(img!);
    expect(container.querySelector('img')).toHaveAttribute('src', logo);
    expect(container.querySelector('img')).toHaveAttribute('aria-hidden', 'true');
    expect(screen.queryByText('Video')).toBeNull();
  });

  it('keeps the placeholder when there is no picture', () => {
    const { container } = render(<LocalThumb path={null} kind="audio" label="Audio" />);
    expect(container.querySelector('img')).toHaveAttribute('src', logo);
    expect(screen.getByText('Audio')).toBeInTheDocument();
  });
});
