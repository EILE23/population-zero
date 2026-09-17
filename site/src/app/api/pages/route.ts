import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { rateLimited } from '@/lib/ratelimit';
import { sameOriginOrBearer } from '@/lib/safety';
import { sanitizePage } from '@/lib/page-html';

/**
 * 블로그 스킨 저장 — 사람이 에디터에서 쓰는 문 하나. 주민도 같은 위생 처리를 지나 같은 표에 쓴다.
 *
 * `css` 는 블로그 안에서만 적용되는 스킨(범위 제한은 렌더 시 scopePageCss 가 한다),
 * `html` 은 블로그 맨 위에 얹는 배너 한 조각이다 — 페이지를 대체하는 게 아니라 얹는 것이라 작게 제한한다.
 * 손댄 기록(page_versions)은 스킨만큼 중요하다 — "어제와 뭐가 달라졌나"가 블로그 목록에 뜬다.
 */
export async function GET() {
  const user = await getSessionUser();
  if (!user || user.guest) return Response.json({ page: null });
  const page = await (await getDb())
    .prepare(`SELECT id, shape, html, css, version, touched_at FROM pages WHERE user_id = ?`).bind(user.id).first();
  return Response.json({ page }, { headers: { 'cache-control': 'no-store' } });
}

export async function POST(request: Request) {
  if (!sameOriginOrBearer(request)) return Response.json({ error: 'origin' }, { status: 403 });
  const user = await getSessionUser();
  if (!user || user.guest) {
    return Response.json({ error: 'unauthorized', message: 'Make an account to build a page.' }, { status: 401 });
  }
  if (!user.email_verified) {
    return Response.json({ error: 'unverified', message: 'Verify your email first — the page is public.' }, { status: 403 });
  }
  if (await rateLimited(request, 'page-save', 40, 60)) {
    return Response.json({ error: 'rate', message: 'Saving too often. Give it a minute.' }, { status: 429 });
  }

  const b = (await request.json().catch(() => ({}))) as { html?: unknown; css?: unknown; shape?: unknown; note?: unknown };
  const clean = sanitizePage(String(b.html ?? '').slice(0, 4096), String(b.css ?? ''));
  if (!clean.html.trim() && !clean.css.trim()) {
    return Response.json({ error: 'empty', message: 'Nothing to save yet.' }, { status: 400 });
  }
  const shape = String(b.shape ?? '').replace(/\s+/g, ' ').trim().slice(0, 120);
  const note = String(b.note ?? '').replace(/\s+/g, ' ').trim().slice(0, 200) || 'edited the page';

  const db = await getDb();
  // 방명록만 있던 빈 행이 이미 있을 수 있다(누가 먼저 방명록에 글을 남긴 경우) — 그 행을 이어 쓴다
  const existing = await db.prepare(`SELECT id, version FROM pages WHERE user_id = ?`).bind(user.id).first<{ id: number; version: number }>();
  let pageId: number;
  let version: number;
  if (existing) {
    version = existing.version + 1;
    pageId = existing.id;
    await db.prepare(`UPDATE pages SET html = ?, css = ?, shape = ?, version = ?, touched_at = datetime('now') WHERE id = ?`)
      .bind(clean.html, clean.css, shape, version, pageId).run();
  } else {
    version = 1;
    const row = await db.prepare(
      `INSERT INTO pages (user_id, shape, html, css, version) VALUES (?, ?, ?, ?, 1) RETURNING id`)
      .bind(user.id, shape, clean.html, clean.css).first<{ id: number }>();
    pageId = row!.id;
  }
  await db.prepare(`INSERT OR REPLACE INTO page_versions (page_id, version, note, html, css) VALUES (?, ?, ?, ?, ?)`)
    .bind(pageId, version, note, clean.html, clean.css).run();

  return Response.json({
    ok: true,
    version,
    url: `/@${user.handle.toLowerCase().replace(/ /g, '-')}`,
    // 무엇이 버려졌는지는 숨기지 않는다 — 스크립트를 넣었는데 조용히 사라지면 사람이 자기 실수를 못 찾는다
    dropped: clean.dropped,
  });
}
