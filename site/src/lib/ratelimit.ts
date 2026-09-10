import { getDb } from '@/lib/db';

/**
 * 범용 IP 레이트리밋 — auth_attempts 테이블을 버킷 접두사로 공유한다. 초과 시 true(차단).
 *
 * 세는 것과 기록하는 것을 한 문장으로 묶는다. 나눠 놓으면 동시에 들어온 요청이 전부 같은 수를
 * 읽고 다 같이 통과한다 — 한도를 걸어 둔 이유가 바로 그 순간의 폭주라서, 그때 안 걸리면 의미가 없다.
 * INSERT ... SELECT ... WHERE (COUNT) < limit 은 SQLite 안에서 원자적으로 실행된다.
 *
 * 실패 처리는 용도에 따라 다르다:
 *  - 기본은 fail-open. 가드가 깨졌다고 사이트 기능 자체가 멈추면 안 된다.
 *  - `failClosed`(로그인·가입·업로드처럼 남용 비용이 큰 곳)는 DB 오류 시 차단한다.
 *    보호가 사라진 채로 열어 두는 것보다 잠시 막는 편이 낫다.
 */
export async function rateLimited(
  request: Request,
  bucket: string,
  limit: number,
  windowMin: number,
  failClosed = false,
): Promise<boolean> {
  const ip = request.headers.get('cf-connecting-ip') ?? 'unknown';
  const key = `${bucket}:${ip}`;
  const minutes = Math.max(1, Math.floor(windowMin));
  try {
    const db = await getDb();
    // 한도 미만일 때만 행이 생긴다. changes === 0 이면 이미 한도에 닿았다는 뜻.
    const res = await db.prepare(
      `INSERT INTO auth_attempts (ip)
       SELECT ?1
       WHERE (SELECT COUNT(*) FROM auth_attempts WHERE ip = ?1 AND ts > datetime('now', '-${minutes} minutes')) < ?2`,
    ).bind(key, limit).run();
    const allowed = (res.meta.changes ?? 0) > 0;
    if (allowed && Math.random() < 0.05) {
      await db.prepare(`DELETE FROM auth_attempts WHERE ts < datetime('now', '-1 day')`).run();
    }
    return !allowed;
  } catch {
    return failClosed;
  }
}

/** 인증 브루트포스 가드 — IP당 10분에 10회. DB 오류 시에는 막는다(무방비로 여는 것보다 낫다). */
export async function authRateLimited(request: Request): Promise<boolean> {
  return rateLimited(request, 'auth', 10, 10, true);
}
