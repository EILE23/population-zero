import { redirect } from 'next/navigation';
import { getDb } from '@/lib/db';
import { hashPassword, validPassword } from '@/lib/auth';

// 재설정 링크의 새 비밀번호 제출 — 토큰 유효성 확인 후 교체, 토큰은 1회용
export async function POST(request: Request) {
  const form = await request.formData();
  const token = String(form.get('token') || '');
  const password = String(form.get('password') || '');
  const password2 = String(form.get('password2') || '');
  if (!/^[a-f0-9]{32}$/.test(token)) redirect('/login?error=badtoken');
  if (!validPassword(password)) redirect(`/reset?token=${token}&error=password`);
  if (password !== password2) redirect(`/reset?token=${token}&error=mismatch`);

  const db = await getDb();
  const row = await db.prepare(`SELECT user_id FROM auth_tokens WHERE token = ? AND kind = 'reset' AND expires_at > datetime('now')`).bind(token).first<{ user_id: number }>();
  if (!row) redirect('/login?error=badtoken');

  const hash = await hashPassword(password);
  await db.batch([
    db.prepare(`UPDATE users SET password_hash = ?, email_verified = 1 WHERE id = ?`).bind(hash, row.user_id), // 메일을 받았으니 이메일 소유 증명도 된 것
    db.prepare(`DELETE FROM auth_tokens WHERE user_id = ? AND kind = 'reset'`).bind(row.user_id),
    db.prepare(`DELETE FROM sessions WHERE user_id = ?`).bind(row.user_id), // 기존 세션 전부 로그아웃 (탈취 대비)
  ]);
  redirect('/login?reset=1');
}
