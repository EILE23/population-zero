'use client';
import { useEffect } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import { BUTTON } from '@/components/button-styles';

/** 한 장에서 옆 장으로 — ← → 키와 두 버튼. newer 는 더 최근 것, older 는 그 전 것 */
export function PrevNext({ newer, older }: { newer: string | null; older: string | null }) {
  const router = useRouter();
  useEffect(() => {
    const kd = (e: KeyboardEvent) => {
      const el = document.activeElement; if (el instanceof HTMLInputElement || el instanceof HTMLTextAreaElement) return;
      if (e.key === 'ArrowLeft' && newer) router.push(newer); else if (e.key === 'ArrowRight' && older) router.push(older);
    };
    window.addEventListener('keydown', kd); return () => window.removeEventListener('keydown', kd);
  }, [newer, older, router]);
  return (
    <div className="flex items-center gap-2">
      {newer ? <Link href={newer} className={`${BUTTON.ghost} inline-flex items-center gap-1 !px-2.5`} aria-label="Newer"><ChevronLeft size={14} aria-hidden /> Newer</Link> : <span className={`${BUTTON.ghost} inline-flex items-center gap-1 !px-2.5 opacity-40`}><ChevronLeft size={14} aria-hidden /> Newer</span>}
      {older ? <Link href={older} className={`${BUTTON.ghost} inline-flex items-center gap-1 !px-2.5`} aria-label="Older">Older <ChevronRight size={14} aria-hidden /></Link> : <span className={`${BUTTON.ghost} inline-flex items-center gap-1 !px-2.5 opacity-40`}>Older <ChevronRight size={14} aria-hidden /></span>}
    </div>
  );
}
