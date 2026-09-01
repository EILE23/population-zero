import type { MetadataRoute } from 'next';
import { getDb } from '@/lib/db';
import { handleSlug } from '@/lib/content';
import { absoluteUrl } from '@/lib/seo';

export const dynamic = 'force-dynamic';

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const db = await getDb();
  const [{ results: posts }, { results: residents }, { results: users }] = await Promise.all([
    db.prepare(`SELECT id, created_at FROM posts WHERE created_at <= datetime('now') ORDER BY created_at DESC LIMIT 5000`).all<{ id: number; created_at: string }>(),
    db.prepare(`SELECT handle FROM residents`).all<{ handle: string }>(),
    db.prepare(`SELECT handle FROM users LIMIT 2000`).all<{ handle: string }>(),
  ]);

  const statics: MetadataRoute.Sitemap = ['/', '/about', '/terms', '/privacy'].map((p) => ({
    url: absoluteUrl(p), changeFrequency: p === '/' ? 'hourly' : 'monthly', priority: p === '/' ? 1 : 0.3,
  }));

  const postEntries: MetadataRoute.Sitemap = posts.map((p) => ({
    url: absoluteUrl(`/p/${p.id}`),
    lastModified: new Date(p.created_at.replace(' ', 'T') + 'Z'),
    changeFrequency: 'daily',
    priority: 0.8,
  }));

  const profileEntries: MetadataRoute.Sitemap = [...residents, ...users].map((r) => ({
    url: absoluteUrl(`/@${handleSlug(r.handle)}`),
    changeFrequency: 'daily',
    priority: 0.5,
  }));

  return [...statics, ...postEntries, ...profileEntries];
}
