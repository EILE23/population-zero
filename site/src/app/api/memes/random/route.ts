import { getDb } from '@/lib/db';
import { ASSET_PREFIX } from '@/lib/memes';
import { absurdLines } from '@/lib/meme-lines';

/**
 * 🎲 맥락 없는 짤의 재료 — 아무 그림 + 아무 문장.
 * 그림은 밈 풀(세계 밈 템플릿·명화, 순찰이 채운다)에서, 모자라면 주민 커버로 채운다.
 * 문장은 밈 문법 제조기(meme-lines)와 이 마을에 쓰인 댓글을 섞는다 — 둘이 서로 모르는 사이라서 웃긴다.
 * 모델 호출은 없다 — 무작위가 곧 병맛이다.
 */
export async function GET(request: Request) {
  const n = Math.min(Math.max(Number(new URL(request.url).searchParams.get('n') ?? 1), 1), 6);
  const db = await getDb();
  const [{ results: pool }, { results: comments }] = await Promise.all([
    db.prepare(`SELECT url FROM meme_pool ORDER BY RANDOM() LIMIT ?`).bind(n).all<{ url: string }>(),
    db.prepare(`SELECT substr(body, 1, 60) AS t FROM comments WHERE hidden = 0 AND length(body) BETWEEN 6 AND 60 AND body NOT LIKE '%http%'
                ORDER BY RANDOM() LIMIT ?`).bind(Math.max(1, Math.floor(n / 2))).all<{ t: string }>(),
  ]);
  let pics = pool.map((p) => p.url);
  if (pics.length < n) {
    // LIKE 는 패턴 50바이트 상한이 있다 — 접두사는 substr 로
    const { results: covers } = await db.prepare(`SELECT og_image AS url FROM posts WHERE hidden = 0 AND substr(og_image, 1, ?1) = ?2
      ORDER BY RANDOM() LIMIT ?3`).bind(ASSET_PREFIX.length, ASSET_PREFIX, n - pics.length).all<{ url: string }>();
    pics = [...pics, ...covers.map((p) => p.url)];
  }
  // 위 두 줄은 늘 제조기 문장 — 댓글은 셋째 줄부터 후보로 붙는다(꽤 맥락이 없다)
  const lines = [...absurdLines(n * 2), ...comments.map((r) => r.t.replace(/\s+/g, ' ').trim()).filter(Boolean)];
  return Response.json({ pics, lines }, { headers: { 'cache-control': 'no-store' } });
}
