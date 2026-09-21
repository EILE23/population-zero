'use client';
import { useEffect, useRef, useState } from 'react';
import { Play } from 'lucide-react';
import { youtubeId, type MemeKind } from '@/lib/memes';

/**
 * 벽의 한 장 — 올리면 살아난다.
 *   image  살짝 커진다
 *   gif    평소엔 첫 프레임(캔버스에 한 번 그린 것), 올리면 진짜 GIF 가 돈다 — 벽 전체가 동시에 꿈틀대면 아무것도 안 보인다
 *   video  평소엔 썸네일, 올리면 유튜브가 소리 없이 돈다(iframe 은 그때 처음 붙는다 — 40개가 한꺼번에 뜨면 안 된다)
 * 클릭은 항상 영구링크로 간다(iframe 은 pointer-events 를 끈다).
 */
export function MediaCard({ kind, png, image, alt }: { kind: MemeKind; png: string; image: string; alt: string }) {
  const [hover, setHover] = useState(false);
  const still = useRef<HTMLCanvasElement>(null);
  const [frozen, setFrozen] = useState(false);
  const yt = kind === 'video' ? youtubeId(image) : null;

  // GIF 첫 프레임 — 이미지가 오면 캔버스에 한 번 찍고 그걸 보여 준다. 실패하면(캔버스 오염 등) 그냥 GIF 를 보여 준다
  useEffect(() => {
    if (kind !== 'gif') return;
    const im = new Image(); im.crossOrigin = 'anonymous';
    im.onload = () => {
      const c = still.current; if (!c) return;
      c.width = im.naturalWidth; c.height = im.naturalHeight;
      try { c.getContext('2d')?.drawImage(im, 0, 0); setFrozen(true); } catch { /* 위 주석 */ }
    };
    im.src = png;
  }, [kind, png]);

  return (
    <span className="relative block overflow-hidden" onMouseEnter={() => setHover(true)} onMouseLeave={() => setHover(false)}>
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src={png} alt={alt} loading="lazy"
        className={`block w-full transition-transform duration-300 ${kind === 'image' ? 'group-hover:scale-[1.03]' : ''} ${kind === 'gif' && frozen && !hover ? 'invisible' : ''}`} />
      {kind === 'gif' && <canvas ref={still} className={`absolute inset-0 h-full w-full ${frozen && !hover ? '' : 'hidden'}`} aria-hidden />}
      {kind === 'gif' && <span className="absolute left-2 top-2 rounded bg-ink/80 px-1.5 font-mono text-[10px] font-bold text-paper">GIF</span>}
      {yt && !hover && (
        <span className="absolute inset-0 grid place-items-center">
          <span className="grid size-12 place-items-center rounded-full bg-ink/80 text-paper"><Play size={20} aria-hidden fill="currentColor" /></span>
        </span>
      )}
      {yt && hover && (
        <iframe
          src={`https://www.youtube-nocookie.com/embed/${yt}?autoplay=1&mute=1&controls=0&playsinline=1&loop=1&playlist=${yt}&rel=0`}
          title={alt || 'video'} tabIndex={-1} aria-hidden
          className="pointer-events-none absolute inset-0 h-full w-full"
          allow="autoplay; encrypted-media"
        />
      )}
    </span>
  );
}
