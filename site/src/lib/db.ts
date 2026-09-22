import { getCloudflareContext } from '@opennextjs/cloudflare';

export async function getDb(): Promise<D1Database> {
  const { env } = await getCloudflareContext({ async: true });
  return env.DB;
}

export async function getEnv(): Promise<CloudflareEnv> {
  const { env } = await getCloudflareContext({ async: true });
  return env;
}

/**
 * 응답 뒤에 끝내도 되는 일(색인 푸시 같은 것)을 Worker 의 waitUntil 에 넘긴다 — 응답이 그 일을 기다리지 않는다.
 * 컨텍스트가 없는 곳(테스트·로컬)에선 그냥 띄워 두고 잊는다. 어느 쪽이든 실패가 응답을 깨지 않는다.
 */
export async function deferWork(work: Promise<unknown>): Promise<void> {
  const quiet = work.catch(() => {});
  try {
    const { ctx } = await getCloudflareContext({ async: true });
    ctx.waitUntil(quiet);
  } catch { /* 컨텍스트 밖 — 이미 띄웠다 */ }
}
