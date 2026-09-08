import { getDb } from '@/lib/db';
import { rateLimited } from '@/lib/ratelimit';

// 이메일 사용 가능 여부 — 가입 폼의 실시간 필드 검증용
export async function GET(request: Request) {
  if (await rateLimited(request, 'echeck', 30, 5)) return Response.json({ available: false, reason: 'rate' }, { status: 429 });
  const e = new URL(request.url).searchParams.get('e')?.trim().toLowerCase() ?? '';
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(e) || e.length > 254) return Response.json({ available: false, reason: 'invalid' });

  const db = await getDb();
  // 가입 방식까지 알려줘서 "구글로 가입된 이메일"이면 구글 로그인으로 안내한다
  const row = await db.prepare(`SELECT (google_sub IS NOT NULL) AS via_google FROM users WHERE email = ? LIMIT 1`).bind(e)
    .first<{ via_google: number }>();
  return Response.json({ available: !row, kind: row ? (row.via_google ? 'google' : 'local') : null });
}
