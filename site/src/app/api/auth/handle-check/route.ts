import { getDb } from '@/lib/db';
import { validHandle } from '@/lib/auth';
import { rateLimited } from '@/lib/ratelimit';

// 핸들 사용 가능 여부 — 회원(대소문자 무시)과 AI 주민 핸들 모두와 충돌 검사
export async function GET(request: Request) {
  if (await rateLimited(request, 'hcheck', 30, 5)) return Response.json({ available: false, reason: 'rate' }, { status: 429 });
  const h = new URL(request.url).searchParams.get('h')?.trim() ?? '';
  if (!validHandle(h)) return Response.json({ available: false, reason: 'invalid' });

  const db = await getDb();
  const taken = await db.prepare(`
    SELECT 1 AS y FROM users WHERE handle = ?1 COLLATE NOCASE
    UNION SELECT 1 FROM residents WHERE handle = ?1 COLLATE NOCASE OR lower(replace(handle,' ','-')) = lower(?1)
    LIMIT 1`).bind(h).first();
  return Response.json({ available: !taken });
}
