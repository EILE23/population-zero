import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { rateLimited } from '@/lib/ratelimit';
import { sameOriginOrBearer } from '@/lib/safety';

/**
 * 게임 만들기 요청 — 제목과 설명을 큐에 넣는다. 하루 몇 개씩 CI(build-game.yml)가 꺼내 엔진 위에 구현해 /play/<slug> 로 올린다.
 * 한 사람에 진행 중(queued·building) 하나. 설명은 개발자에게 '데이터'로 전달되고 규칙(patrol/GAMES.md)이 그 위에 있다.
 */
const RESERVED = new Set(['climb', 'square', 'play', 'engine', 'registry', 'new', 'api', 'admin']);
const slugOf = (title: string) => title.toLowerCase().normalize('NFKD').replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 24).replace(/-+$/g, '');

export async function POST(request: Request) {
  if (!sameOriginOrBearer(request)) return Response.json({ error: 'origin' }, { status: 403 });
  const user = await getSessionUser();
  if (!user || user.guest) return Response.json({ error: 'unauthorized', message: 'Log in to make a game.' }, { status: 401 });
  if (await rateLimited(request, 'games', 6, 60)) return Response.json({ error: 'rate', message: 'Too many requests. Try again in an hour.' }, { status: 429 });
  const b = (await request.json().catch(() => ({}))) as { title?: unknown; prompt?: unknown };
  const title = String(b.title ?? '').replace(/\s+/g, ' ').trim();
  const prompt = String(b.prompt ?? '').replace(/\r/g, '').trim();
  if (title.length < 3 || title.length > 40) return Response.json({ error: 'title', message: 'Title: 3 to 40 characters.' }, { status: 400 });
  if (prompt.length < 40 || prompt.length > 900) return Response.json({ error: 'prompt', message: 'Describe the game in 40 to 900 characters. What you do, what the residents do, how it ends.' }, { status: 400 });
  const db = await getDb();
  const pending = await db.prepare(`SELECT slug, status FROM games WHERE user_id = ? AND status IN ('queued', 'building') LIMIT 1`).bind(user.id).first<{ slug: string; status: string }>();
  if (pending) return Response.json({ error: 'pending', message: `You already have one in the queue (${pending.slug}). One at a time.` }, { status: 409 });
  let base = slugOf(title); if (base.length < 3 || RESERVED.has(base)) base = `${base || 'game'}-${user.handle.toLowerCase().replace(/[^a-z0-9]/g, '').slice(0, 8) || 'x'}`.slice(0, 24);
  let slug = base;
  for (let k = 2; k < 30; k++) {
    const taken = await db.prepare(`SELECT 1 FROM games WHERE slug = ?`).bind(slug).first();
    if (!taken) break;
    slug = `${base.slice(0, 24 - String(k).length - 1)}-${k}`;
  }
  await db.prepare(`INSERT INTO games (slug, title, prompt, user_id) VALUES (?, ?, ?, ?)`).bind(slug, title, prompt, user.id).run();
  const ahead = await db.prepare(`SELECT COUNT(*) AS n FROM games WHERE status IN ('queued', 'building') AND slug <> ?`).bind(slug).first<{ n: number }>();
  return Response.json({ ok: true, slug, ahead: ahead?.n ?? 0 }, { status: 201 });
}
