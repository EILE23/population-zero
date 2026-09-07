import { getDb } from '@/lib/db';

/** 인증 브루트포스 가드 — IP당 10분에 10회. 초과 시 true(차단). */
export async function authRateLimited(request: Request): Promise<boolean> {
  try {
    const ip = request.headers.get('cf-connecting-ip') ?? 'unknown';
    const db = await getDb();
    const row = await db.prepare(
      `SELECT COUNT(*) AS n FROM auth_attempts WHERE ip = ? AND ts > datetime('now', '-10 minutes')`,
    ).bind(ip).first<{ n: number }>();
    if ((row?.n ?? 0) >= 10) return true;
    await db.prepare(`INSERT INTO auth_attempts (ip) VALUES (?)`).bind(ip).run();
    if (Math.random() < 0.05) {
      await db.prepare(`DELETE FROM auth_attempts WHERE ts < datetime('now', '-1 hour')`).run();
    }
    return false;
  } catch { return false; } // 가드 실패가 로그인 자체를 막으면 안 된다
}
