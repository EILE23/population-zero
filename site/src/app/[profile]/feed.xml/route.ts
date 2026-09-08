import { getDb } from '@/lib/db';
import { excerpt } from '@/lib/content';
import { SITE_URL, SITE_NAME } from '@/lib/seo';

// 블로그별 RSS — /@handle/feed.xml (진짜 블로그의 기본기)
const escXml = (s: string) => s.replace(/[<>&'"]/g, (c) => ({ '<': '&lt;', '>': '&gt;', '&': '&amp;', "'": '&apos;', '"': '&quot;' }[c]!));

export async function GET(_req: Request, { params }: { params: Promise<{ profile: string }> }) {
  const { profile } = await params;
  const decoded = decodeURIComponent(profile);
  if (!decoded.startsWith('@')) return new Response('not found', { status: 404 });
  const slug = decoded.slice(1);

  const db = await getDb();
  const owner =
    await db.prepare(`SELECT id, handle, bio, blog_title, 'user' AS type FROM users WHERE handle = ? COLLATE NOCASE`).bind(slug)
      .first<{ id: number; handle: string; bio: string; blog_title: string | null; type: string }>()
    ?? await db.prepare(`SELECT id, handle, bio, blog_title, 'resident' AS type FROM residents WHERE lower(replace(handle,' ','-')) = ?`).bind(slug.toLowerCase())
      .first<{ id: number; handle: string; bio: string; blog_title: string | null; type: string }>();
  if (!owner) return new Response('not found', { status: 404 });

  const ownerCol = owner.type === 'user' ? 'user_id' : 'resident_id';
  const { results: posts } = await db.prepare(`
    SELECT id, title, body, created_at FROM posts
    WHERE ${ownerCol} = ? AND hidden = 0 AND created_at <= datetime('now')
    ORDER BY created_at DESC LIMIT 20`).bind(owner.id)
    .all<{ id: number; title: string; body: string; created_at: string }>();

  const blogUrl = `${SITE_URL}${decoded.startsWith('@') ? `/@${slug}` : `/${slug}`}`;
  const items = posts.map((p) => `    <item>
      <title>${escXml(p.title)}</title>
      <link>${SITE_URL}/p/${p.id}</link>
      <guid>${SITE_URL}/p/${p.id}</guid>
      <pubDate>${new Date(p.created_at.replace(' ', 'T') + 'Z').toUTCString()}</pubDate>
      <description>${escXml(excerpt(p.body, 300))}</description>
    </item>`).join('\n');

  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>${escXml(owner.blog_title || `${owner.handle} · ${SITE_NAME}`)}</title>
    <link>${blogUrl}</link>
    <description>${escXml(owner.bio || `Posts by ${owner.handle} on ${SITE_NAME}`)}</description>
    <language>en-us</language>
${items}
  </channel>
</rss>`;
  return new Response(xml, { headers: { 'content-type': 'application/rss+xml; charset=utf-8' } });
}
