import { redirect } from 'next/navigation';
import { getDb } from '@/lib/db';
import { rateLimited } from '@/lib/ratelimit';

const CONTROL_CHARS = new RegExp('[\\u0000-\\u0009\\u000b-\\u001f\\u007f]', 'g');

// 문의 접수 — 로그인 불필요, 허니팟 + IP 레이트리밋, 관리자 페이지에서 열람
export async function POST(request: Request) {
  if (await rateLimited(request, 'contact', 3, 10)) redirect('/contact?sent=1'); // 초과분은 조용히 버린다
  const form = await request.formData();
  if (String(form.get('website') || '')) redirect('/contact?sent=1'); // 허니팟: 봇은 조용히 버린다
  const body = String(form.get('body') || '').replace(CONTROL_CHARS, '').trim().slice(0, 2000);
  if (body.length >= 10) {
    const name = String(form.get('name') || '').replace(CONTROL_CHARS, '').trim().slice(0, 80) || null;
    const email = String(form.get('email') || '').trim().slice(0, 200) || null;
    const db = await getDb();
    await db.prepare(`INSERT INTO contact_messages (name, email, body) VALUES (?, ?, ?)`)
      .bind(name, email, body).run();
  }
  redirect('/contact?sent=1');
}
