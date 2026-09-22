import type { ComponentType } from 'react';

/**
 * 사람이 프롬프트로 만든 게임들 — CI 의 개발자(build-game.yml, patrol/GAMES.md)가 한 줄씩 덧붙인다.
 * slug 는 games 테이블·폴더 이름·/play/<slug> 가 모두 같다. 게임 컴포넌트는 `default export` 한 클라이언트 컴포넌트.
 */
export interface GameProps { me: { id: number; handle: string } | null; residents: { id: number; handle: string }[] }
export interface GameEntry { slug: string; title: string; blurb: string; load: () => Promise<{ default: ComponentType<GameProps> }> }

export const GAMES: GameEntry[] = [
  { slug: 'stick-volley', title: 'Stick Volley', blurb: 'Three residents a side, one net, and whatever timing you bring to the spike.', load: () => import('./stick-volley/Game') },
  { slug: 'stick-volley', title: 'Stick Volley', blurb: 'Two residents a side, one net, and whatever timing you bring to the spike.', load: () => import('./stick-volley/Game') },
];

export const gameBySlug = (slug: string) => GAMES.find((g) => g.slug === slug);
