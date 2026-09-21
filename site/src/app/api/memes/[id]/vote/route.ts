import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { sameOriginOrBearer } from '@/lib/safety';

/** 웃김 한 표 — 누르면 넣고, 다시 누르면 뺀다 */
export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  if (!sameOriginOrBearer(request)) return Response.json({ error: 'origin' }, { status: 403 });
  const user = await getSessionUser();
  if (!user || user.guest) return Response.json({ error: 'unauthorized', message: 'Log in to vote.' }, { status: 401 });
  const id = Number((await params).id);
  if (!Number.isInteger(id) || id < 1) return Response.json({ error: 'bad_id' }, { status: 400 });

  const db = await getDb();
  const voter = `u${user.id}`;
  const had = await db.prepare(`SELECT 1 FROM meme_votes WHERE meme_id = ? AND voter = ?`).bind(id, voter).first();
  if (had) await db.prepare(`DELETE FROM meme_votes WHERE meme_id = ? AND voter = ?`).bind(id, voter).run();
  else await db.prepare(`INSERT OR IGNORE INTO meme_votes (meme_id, voter) VALUES (?, ?)`).bind(id, voter).run();
  const n = await db.prepare(`SELECT COUNT(*) AS n FROM meme_votes WHERE meme_id = ?`).bind(id).first<{ n: number }>();
  return Response.json({ voted: !had, votes: n?.n ?? 0 });
}
