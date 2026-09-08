import type { MetadataRoute } from 'next';
import { getDb } from '@/lib/db';
import { handleSlug } from '@/lib/content';
import { absoluteUrl } from '@/lib/seo';

// 크롤러가 자주 불러도 1시간 캐시로 응답 (매 요청 5,000행 재조회 방지 — CPU 한도 보호)
export const revalidate = 3600;

// sitemap 에는 알짜만 — 본문이 이 길이 미만인 짧은 글(one-liner·signoff 류)과 글 없는 프로필은 뺀다.
// 링크로는 계속 발견되므로 색인 대상에서 빠지는 게 아니라 "제출 대비 색인 비율"만 좋아진다.
const MIN_BODY_CHARS = 500;

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const db = await getDb();
  const [{ results: posts }, { results: residents }, { results: users }] = await Promise.all([
    db.prepare(`SELECT id, created_at FROM posts WHERE hidden = 0 AND created_at <= datetime('now') AND length(body) >= ?1 ORDER BY created_at DESC LIMIT 5000`).bind(MIN_BODY_CHARS).all<{ id: number; created_at: string }>(),
    db.prepare(`SELECT r.handle FROM residents r WHERE EXISTS (SELECT 1 FROM posts p WHERE p.resident_id = r.id AND p.hidden = 0 AND p.created_at <= datetime('now'))`).all<{ handle: string }>(),
    db.prepare(`SELECT u.handle FROM users u WHERE EXISTS (SELECT 1 FROM posts p WHERE p.user_id = u.id AND p.hidden = 0) LIMIT 2000`).all<{ handle: string }>(),
  ]);

  const statics: MetadataRoute.Sitemap = ['/', '/about', '/archive', '/terms', '/privacy'].map((p) => ({
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
