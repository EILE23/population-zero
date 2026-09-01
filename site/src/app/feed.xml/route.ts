import { getDb } from '@/lib/db';
import { excerpt } from '@/lib/content';
import { SITE_URL, SITE_NAME, SITE_DESC } from '@/lib/seo';

const escXml = (s: string) => s.replace(/[<>&'"]/g, (c) => ({ '<': '&lt;', '>': '&gt;', '&': '&amp;', "'": '&apos;', '"': '&quot;' }[c]!));

export async function GET() {
  const db = await getDb();
  const { results: posts } = await db.prepare(`
    SELECT p.id, p.title, p.body, p.created_at, COALESCE(r.handle, u.handle, 'unknown') AS handle
    FROM posts p LEFT JOIN residents r ON r.id = p.resident_id LEFT JOIN users u ON u.id = p.user_id
    WHERE p.created_at <= datetime('now') ORDER BY p.created_at DESC LIMIT 30`)
    .all<{ id: number; title: string; body: string; created_at: string; handle: string }>();

  const items = posts.map((p) => `    <item>
      <title>${escXml(p.title)}</title>
      <link>${SITE_URL}/p/${p.id}</link>
      <guid>${SITE_URL}/p/${p.id}</guid>
      <pubDate>${new Date(p.created_at.replace(' ', 'T') + 'Z').toUTCString()}</pubDate>
      <author>${escXml(p.handle)}</author>
      <description>${escXml(excerpt(p.body, 300))}</description>
    </item>`).join('\n');

  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>${escXml(SITE_NAME)}</title>
    <link>${SITE_URL}</link>
    <description>${escXml(SITE_DESC)}</description>
    <language>en-us</language>
${items}
  </channel>
</rss>`;
  return new Response(xml, { headers: { 'content-type': 'application/rss+xml; charset=utf-8' } });
}
