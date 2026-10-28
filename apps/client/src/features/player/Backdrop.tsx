import { useEffect, useRef, useState } from 'react';
import { backend } from '../../services/backend';

/** Small frame: the blur does not need the source video's full resolution. */
const FRAME_W = 48;
const FRAME_H = 27;
/** How often the frame follows the video while it plays. */
const FRAME_MS = 400;

const LOOK =
  'pointer-events-none absolute inset-[-10%] h-[120%] w-[120%] object-cover blur-3xl brightness-[0.55] saturate-150';

/**
 * Blurred copy of the current video frame behind the player, filling the
 * bars around the picture (instead of the placeholder stripes).
 */
export function VideoBackdrop({ video }: { video: HTMLVideoElement | null }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const ctx = canvasRef.current?.getContext('2d');
    if (!video || !ctx) return;
    const draw = () => {
      if (document.hidden || video.readyState < 2) return;
      try {
        ctx.drawImage(video, 0, 0, FRAME_W, FRAME_H);
      } catch {
        // Nothing to draw yet.
      }
    };
    let timer = 0;
    const follow = () => {
      window.clearInterval(timer);
      if (!document.hidden && !video.paused && !video.ended) {
        timer = window.setInterval(draw, FRAME_MS);
      }
      draw();
    };
    const events = ['loadeddata', 'seeked', 'play', 'pause', 'ended'] as const;
    for (const e of events) video.addEventListener(e, follow);
    document.addEventListener('visibilitychange', follow);
    follow();
    return () => {
      window.clearInterval(timer);
      for (const e of events) video.removeEventListener(e, follow);
      document.removeEventListener('visibilitychange', follow);
    };
  }, [video]);
  return (
    <canvas ref={canvasRef} width={FRAME_W} height={FRAME_H} aria-hidden="true" className={LOOK} />
  );
}

/** Blurred thumbnail behind an audio player; nothing when there is none. */
export function ThumbBackdrop({ path }: { path: string | null | undefined }) {
  const [failed, setFailed] = useState<string | null>(null);
  if (!path || failed === path) return null;
  return (
    <img
      src={backend.mediaUrl(path)}
      alt=""
      aria-hidden="true"
      onError={() => setFailed(path)}
      className={LOOK}
    />
  );
}
