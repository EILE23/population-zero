import { getDb } from '@/lib/db';
import { deletionStatements } from '@/lib/account-deletion';
import { rateLimited } from '@/lib/ratelimit';

export async function POST(request: Request) {
  if (request.headers.get('origin') !== new URL(request.url).origin) return Response.json({ error: 'origin' }, { status: 403 });
  if (await rateLimited(request, 'confirm-delete', 10, 10, true)) return Response.json({ error: 'Please retry later.' }, { status: 429 });
  const input = await request.json().catch(() => ({})) as { token?: string; confirm?: boolean };
  if (!/^[a-f0-9]{32}$/.test(input.token ?? '') || input.confirm !== true) return Response.json({ error: 'Confirmation required.' }, { status: 400 });
  const db = await getDb();
  const account = await db.prepare(`SELECT user_id FROM account_deletions WHERE token=? AND expires_at>datetime('now')`).bind(input.token).first<{ user_id: number }>();
  if (!account) return Response.json({ error: 'This link has expired or was already used.' }, { status: 400 });
  // Public upload removal is queued independently of database deletion; the queue contains only owned asset paths.
  const urls = await db.prepare(`SELECT avatar_url AS value FROM users WHERE id=?1 UNION ALL SELECT body FROM posts WHERE user_id=?1
    UNION ALL SELECT og_image FROM posts WHERE user_id=?1 UNION ALL SELECT url FROM post_images WHERE post_id IN(SELECT id FROM posts WHERE user_id=?1)
    UNION ALL SELECT image FROM dms WHERE from_user_id=?1`).bind(account.user_id).all<{ value: string | null }>();
  const owned = new Set<string>();
  for (const row of urls.results) for (const match of (row.value ?? '').matchAll(/uploads\/(?:cover|inline|avatar)-u(\d+)-[a-z0-9]+\.(?:png|jpg|webp|gif)/g)) {
    if (Number(match[1]) === account.user_id) owned.add(match[0]);
  }
  await db.batch([
    ...[...owned].map(key => db.prepare('INSERT OR IGNORE INTO asset_removals(path) VALUES(?)').bind(key)),
    ...deletionStatements.map(sql => db.prepare(sql).bind(input.token)),
  ]);
  return Response.json({ ok: true }, { headers: { 'cache-control': 'no-store', 'set-cookie': 'pz_session=; Path=/; Max-Age=0; HttpOnly; Secure; SameSite=Lax' } });
}
