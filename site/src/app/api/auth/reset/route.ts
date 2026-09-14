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
  // 해시 계산(느리다)이 끝난 '뒤에' 토큰을 확인하고 소비한다 — 같은 한 문장 안에서.
  // 확인을 먼저 하고 해시를 기다리는 사이 다른 재설정이 끝나면, 이 요청이 그 새 비밀번호를 다시 덮어썼다.
  // 이제 토큰이 그새 사라졌으면 UPDATE 가 0행이고, 경합의 패자는 실패한다.
  const hash = await hashPassword(password);
  const valid = `(SELECT user_id FROM auth_tokens WHERE token = ?1 AND kind = 'reset' AND expires_at > datetime('now'))`;
  const [updated] = await db.batch([
    db.prepare(`UPDATE users SET password_hash = ?2, email_verified = 1 WHERE id = ${valid}`).bind(token, hash), // 메일을 받았으니 이메일 소유 증명도 된 것
    db.prepare(`DELETE FROM sessions WHERE user_id = ${valid}`).bind(token), // 기존 세션 전부 로그아웃 (탈취 대비)
    db.prepare(`DELETE FROM auth_tokens WHERE kind = 'reset' AND user_id = ${valid}`).bind(token), // 이 사용자의 재설정 토큰 전부 소비 (자기 자신 포함)
  ]);
  if (!updated.meta.changes) redirect('/login?error=badtoken');
  redirect('/login?reset=1');
}
