import { redirect } from 'next/navigation';
import { getDb } from '@/lib/db';
import { getSessionUser, validHandle } from '@/lib/auth';
import { rateLimited } from '@/lib/ratelimit';

// 닉네임 변경 — 회원(자신 제외)·AI 주민 핸들과 충돌 검사 후 반영
// JSON 요청(인라인 수정)은 JSON으로, 폼 요청(선택 모달)은 리다이렉트로 응답한다
export async function POST(request: Request) {
  const isJson = (request.headers.get('content-type') || '').includes('application/json');
  const user = await getSessionUser();
  if (!user) return isJson ? new Response('unauthorized', { status: 401 }) : redirect('/login');

  let handle = '';
  let back = '/me';
  if (isJson) {
    handle = String(((await request.json().catch(() => ({}))) as { handle?: string }).handle || '').trim();
  } else {
    const form = await request.formData();
    handle = String(form.get('handle') || '').trim();
    back = String(form.get('back') || '/me');
  }
  const dest = back === 'welcome' ? '/welcome' : '/me';
  if (!validHandle(handle)) return isJson ? Response.json({ error: 'handle' }, { status: 400 }) : redirect(`${dest}?error=handle`);

  const db = await getDb();
  if (handle.toLowerCase() !== user.handle.toLowerCase()) {
    const taken = await db.prepare(`
      SELECT 1 AS y FROM users WHERE handle = ?1 COLLATE NOCASE AND id != ?2
      UNION SELECT 1 FROM residents WHERE handle = ?1 COLLATE NOCASE OR lower(replace(handle,' ','-')) = lower(?1)
      LIMIT 1`).bind(handle, user.id).first();
    if (taken) return isJson ? Response.json({ error: 'taken' }, { status: 409 }) : redirect(`${dest}?error=taken`);
  }
  // 제한은 실제 변경 직전에만 — 중복·형식 오류 같은 실패 시도는 카운트하지 않는다
  if (await rateLimited(request, 'handle', 15, 10)) {
    return isJson ? Response.json({ error: 'rate' }, { status: 429 }) : redirect(`${dest}?error=rate`);
  }
  await db.prepare(`UPDATE users SET handle = ?, handle_picked = 1 WHERE id = ?`).bind(handle, user.id).run();
  if (isJson) return Response.json({ handle });
  redirect(back === 'welcome' ? '/' : '/me');
}
