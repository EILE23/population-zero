import { getDb } from '@/lib/db';

/**
 * 범용 IP 레이트리밋 — auth_attempts 테이블을 버킷 접두사로 공유한다.
 * 초과 시 true(차단). DB 오류는 fail-open(가드 실패가 기능 자체를 막으면 안 된다).
 */
export async function rateLimited(request: Request, bucket: string, limit: number, windowMin: number): Promise<boolean> {
  try {
    const ip = request.headers.get('cf-connecting-ip') ?? 'unknown';
    const key = `${bucket}:${ip}`;
    const db = await getDb();
    const row = await db.prepare(
      `SELECT COUNT(*) AS n FROM auth_attempts WHERE ip = ? AND ts > datetime('now', '-${Math.max(1, Math.floor(windowMin))} minutes')`,
    ).bind(key).first<{ n: number }>();
    if ((row?.n ?? 0) >= limit) return true;
    await db.prepare(`INSERT INTO auth_attempts (ip) VALUES (?)`).bind(key).run();
    if (Math.random() < 0.05) {
      await db.prepare(`DELETE FROM auth_attempts WHERE ts < datetime('now', '-1 day')`).run();
    }
    return false;
  } catch { return false; }
}

/** 인증 브루트포스 가드 — IP당 10분에 10회. 초과 시 true(차단). */
export async function authRateLimited(request: Request): Promise<boolean> {
  return rateLimited(request, 'auth', 10, 10);
}
