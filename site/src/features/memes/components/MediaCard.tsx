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
/** thumb: 벽용 작은 그림(480px). 있으면 평소엔 그걸 걸고, GIF 는 올렸을 때만 원본을 부른다 — 벽 80장이 원본 PNG 를 다 받으면 느리다 */
export function MediaCard({ kind, png, thumb, image, alt }: { kind: MemeKind; png: string; thumb?: string | null; image: string; alt: string }) {
  const [hover, setHover] = useState(false);
  const still = useRef<HTMLCanvasElement>(null);
  const [frozen, setFrozen] = useState(false);
  const yt = kind === 'video' ? youtubeId(image) : null;
  const vid = useRef<HTMLVideoElement>(null);
  // 릴: 올리면 재생, 떼면 처음으로
  useEffect(() => {
    const v = vid.current; if (!v) return;
    if (hover) void v.play().catch(() => null); else { v.pause(); v.currentTime = 0; }
  }, [hover]);

  // GIF 첫 프레임 — 이미지가 오면 캔버스에 한 번 찍고 그걸 보여 준다. 실패하면(캔버스 오염 등) 그냥 GIF 를 보여 준다
  useEffect(() => {
    if (kind !== 'gif' || thumb) return; // 섬네일이 있으면 그게 첫 프레임 노릇을 한다
    const im = new Image(); im.crossOrigin = 'anonymous';
    im.onload = () => {
      const c = still.current; if (!c) return;
      c.width = im.naturalWidth; c.height = im.naturalHeight;
      try { c.getContext('2d')?.drawImage(im, 0, 0); setFrozen(true); } catch { /* 위 주석 */ }
    };
    im.src = png;
  }, [kind, png, thumb]);

  return (
    <span className="relative block overflow-hidden" onMouseEnter={() => setHover(true)} onMouseLeave={() => setHover(false)}>
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src={kind === 'gif' && thumb ? (hover ? png : thumb) : (thumb ?? png)} alt={alt} loading="lazy" decoding="async"
        className={`block w-full transition-transform duration-300 ${kind === 'image' ? 'group-hover:scale-[1.03]' : ''} ${kind === 'gif' && frozen && !hover ? 'invisible' : ''}`} />
      {kind === 'gif' && <canvas ref={still} className={`absolute inset-0 h-full w-full ${frozen && !hover ? '' : 'hidden'}`} aria-hidden />}
      {kind === 'gif' && <span className="absolute left-2 top-2 rounded bg-ink/80 px-1.5 font-mono text-[10px] font-bold text-paper">GIF</span>}
      {kind === 'clip' && (
        <video ref={vid} src={image} poster={png} muted loop playsInline preload="none"
          className={`absolute inset-0 h-full w-full object-cover ${hover ? '' : 'invisible'}`} />
      )}
      {(yt || kind === 'clip') && !hover && (
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
