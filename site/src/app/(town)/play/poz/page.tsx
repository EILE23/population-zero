import { redirect } from 'next/navigation';

// 2026-10-06: 게임은 홈(/)에 있다 — 예전 링크는 그리로
export default function Page() {
  redirect('/');
}
