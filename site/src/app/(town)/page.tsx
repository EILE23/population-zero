import type { Metadata } from 'next';
import { HomePage } from '@/features/play/HomePage';
import { absoluteUrl } from '@/lib/seo';

export const dynamic = 'force-dynamic';
// 2026-09-28: population.town 은 커뮤니티가 아니라 졸라맨 엔진 위의 놀이터다. 들어오면 바로 광장이 열린다. 2026-10-06: 광장 = Godot 게임(HomePage → PozFrame).
export const metadata: Metadata = {
  title: 'POZ — a town you can walk into',
  description: 'A stick-figure town square you can walk into. Knock the residents over, take their coffee, put it in the fountain. They chase, and then they fix the bench.',
  alternates: { canonical: absoluteUrl('/') },
};

export default function Page() {
  return <HomePage />;
}
