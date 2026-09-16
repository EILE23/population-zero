import { redirect } from 'next/navigation';
import { getDb } from '@/lib/db';
import { getSessionUser, createSession } from '@/lib/auth';
import { rateLimited } from '@/lib/ratelimit';
import { sameOriginOrBearer } from '@/lib/safety';
import { fireGaEvent } from '@/lib/ga-mp';
import { pingIndexNow } from '@/lib/seo';

const CONTROL_CHARS = new RegExp('[\\u0000-\\u0009\\u000b-\\u001f\\u007f]', 'g');
const GUEST_QUESTION_LIMIT = 3; // 게스트 한 명이 가입 없이 물을 수 있는 수 — 그 뒤엔 계정을 만든다

/**
 * 질문 올리기 — 계정이 없어도 된다.
 *
 * 하드월(가입해야 물어볼 수 있음)은 전환을 0으로 만든다: 방문자는 가치를 보기 전에 가입하지 않는다.
 * 그래서 먼저 묻게 하고, 답이 도착한 뒤에 "이 질문을 내 것으로" 가져가며 가입하게 한다.
 * 익명 질문자는 guest=1 인 users 행 + 세션으로 존재한다. 가입하면 그 행이 그대로 승격되므로(auth/signup)
 * 질문·답·받은 알림이 전부 따라온다.
 */
export async function POST(request: Request) {
  const wantsJson = (request.headers.get('accept') ?? '').includes('application/json');
  const fail = (error: string, status: number, path: string): Response => {
    if (wantsJson) return Response.json({ error }, { status });
    redirect(path);
  };
  if (!sameOriginOrBearer(request)) return fail('origin', 403, '/ask?error=origin');

  const form = await request.formData();
  const body = String(form.get('body') || '').replace(CONTROL_CHARS, '').trim().slice(0, 4000);
  if (body.length < 15) return fail('short', 400, '/ask?error=short');
  // 제목은 따로 받지 않는다 — 첫 문장이 제목이다 (사람은 질문을 한 덩어리로 쓴다)
  const firstLine = body.split('\n')[0].split(/(?<=[.?!])\s/)[0].trim();
  const title = (firstLine.length > 90 ? firstLine.slice(0, 87).trimEnd() + '…' : firstLine) || body.slice(0, 90);

  const db = await getDb();
  let user = await getSessionUser();

  if (user && !user.email_verified && !user.guest) return fail('unverified', 403, '/me?error=unverified');

  if (!user) {
    // 익명 — 스팸을 막을 만큼만 좁게: 한 아이피에서 한 시간에 2개
    if (await rateLimited(request, 'ask-guest', 2, 60, true)) return fail('rate', 429, '/ask?error=rate');
    const suffix = crypto.randomUUID().replace(/-/g, '').slice(0, 6);
    const created = await db.prepare(
      `INSERT INTO users (handle, guest, email_verified, handle_picked) VALUES (?, 1, 0, 0) RETURNING id`,
    ).bind(`guest_${suffix}`).first<{ id: number }>();
    if (!created) return fail('failed', 500, '/ask?error=failed');
    await createSession(created.id);
    user = await getSessionUser();
    if (!user) return fail('failed', 500, '/ask?error=failed');
  } else if (user.guest) {
    const [asked] = (await db.prepare(`SELECT COUNT(*) AS n FROM posts WHERE user_id = ?`).bind(user.id).all<{ n: number }>()).results;
    if ((asked?.n ?? 0) >= GUEST_QUESTION_LIMIT) return fail('claim', 403, '/ask?error=claim');
    if (await rateLimited(request, 'ask-guest', 2, 60, true)) return fail('rate', 429, '/ask?error=rate');
  } else if (await rateLimited(request, 'post', 5, 10)) {
    return fail('rate', 429, '/ask?error=rate');
  }

  const row = await db.prepare(
    `INSERT INTO posts (user_id, kind, title, body, topic) VALUES (?, 'human', ?, ?, 'ask') RETURNING id`,
  ).bind(user.id, title, body).first<{ id: number }>();
  if (!row) return fail('failed', 500, '/ask?error=failed');

  await fireGaEvent('post_create', request, { topic: 'ask', guest: user.guest ? 1 : 0 }, user.id);
  await pingIndexNow([`/p/${row.id}`]);
  if (wantsJson) return Response.json({ id: row.id, url: `/p/${row.id}` }, { status: 201 });
  redirect(`/p/${row.id}?asked=1`);
}
