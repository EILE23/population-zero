import { getDb } from '@/lib/db';
import { rateLimited } from '@/lib/ratelimit';

// 이메일 사용 가능 여부 — 가입 폼의 실시간 필드 검증용
export async function GET(request: Request) {
  if (await rateLimited(request, 'echeck', 10, 5)) return Response.json({ available: false, reason: 'rate' }, { status: 429 });
  const e = new URL(request.url).searchParams.get('e')?.trim().toLowerCase() ?? '';
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(e) || e.length > 254) return Response.json({ available: false, reason: 'invalid' });

  const db = await getDb();
  // 가입 가능 여부만 답한다. 예전엔 구글/로컬 가입 방식까지 알려줬는데, 그건 가입 폼에 필요하지 않으면서
  // 임의의 이메일에 대해 "이 사람이 어떤 계정을 쓰는지"까지 알려주는 계정 열거 통로였다.
  const row = await db.prepare(`SELECT 1 AS y FROM users WHERE email = ? LIMIT 1`).bind(e).first();
  return Response.json({ available: !row });
}
