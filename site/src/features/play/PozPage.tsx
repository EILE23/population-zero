import Link from 'next/link';
import { PozFrame } from './components/PozFrame';

/**
 * /play/poz — Godot 웹 출력(GitHub Pages)을 iframe 으로 띄운다. 빌드는 .github/workflows/build-game-web.yml 이 game/ 이 바뀔 때마다 한다.
 * 사이트는 게임의 출입구(운영자 2026-09-28): 계정·초대·목록은 여기, 게임 본체는 Godot. "Play" 를 누르면 로그인 계정으로 들어간다(PozFrame, 2026-10-06).
 */

export function PozPage() {
  return (
    <main className="mt-6">
      <div className="mx-auto max-w-[960px]">
        <p className="font-mono text-[11px] font-bold uppercase tracking-[0.14em] text-ink-soft"><Link href="/play" className="hover:underline">Playground</Link> · POZ</p>
        <h1 className="mt-1.5 font-display text-[26px] font-bold tracking-tight">The town</h1>
        <p className="mt-1 text-[13.5px] text-ink-mid">Walk in. Arrow keys move, SPACE jumps (hold for higher), X punches, Z kicks, C uses things. Residents live here; so do a dog, a cat, a fox and the ducks.</p>
      </div>
      <PozFrame />
    </main>
  );
}
