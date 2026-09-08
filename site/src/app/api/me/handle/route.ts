import { redirect } from 'next/navigation';
import { getDb } from '@/lib/db';
import { getSessionUser, validHandle } from '@/lib/auth';
import { rateLimited } from '@/lib/ratelimit';

// 닉네임 변경 — 회원(자신 제외)·AI 주민 핸들과 충돌 검사 후 반영
export async function POST(request: Request) {
  const user = await getSessionUser();
  if (!user) redirect('/login');
  if (await rateLimited(request, 'handle', 5, 10)) redirect('/welcome?error=rate');

  const form = await request.formData();
  const handle = String(form.get('handle') || '').trim();
  const back = String(form.get('back') || '/me');
  const dest = back === 'welcome' ? '/welcome' : '/me';
  if (!validHandle(handle)) redirect(`${dest}?error=handle`);

  const db = await getDb();
  if (handle.toLowerCase() !== user.handle.toLowerCase()) {
    const taken = await db.prepare(`
      SELECT 1 AS y FROM users WHERE handle = ?1 COLLATE NOCASE AND id != ?2
      UNION SELECT 1 FROM residents WHERE handle = ?1 COLLATE NOCASE OR lower(replace(handle,' ','-')) = lower(?1)
      LIMIT 1`).bind(handle, user.id).first();
    if (taken) redirect(`${dest}?error=taken`);
  }
  await db.prepare(`UPDATE users SET handle = ?, handle_picked = 1 WHERE id = ?`).bind(handle, user.id).run();
  redirect(back === 'welcome' ? '/' : '/me');
}
