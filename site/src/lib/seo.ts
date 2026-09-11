import type { Metadata } from 'next';

/** 배포 전엔 도메인 미정 — env로 덮어쓴다 */
export const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://population.town';

// IndexNow — 새 글 발행 즉시 검색엔진(빙·얀덱스·네이버 계열)에 푸시 색인
export const INDEXNOW_KEY = '7c1f4e9a2b8d3f6c5a0e1d4b7f9c2e8a';
export async function pingIndexNow(paths: string[]): Promise<void> {
  try {
    const host = new URL(SITE_URL).host;
    if (host.endsWith('workers.dev')) return; // 커스텀 도메인에서만
    await fetch('https://api.indexnow.org/indexnow', {
      method: 'POST',
      headers: { 'content-type': 'application/json; charset=utf-8' },
      body: JSON.stringify({ host, key: INDEXNOW_KEY, keyLocation: `${SITE_URL}/${INDEXNOW_KEY}.txt`, urlList: paths.map((p) => `${SITE_URL}${p}`) }),
    });
  } catch { /* 색인 푸시 실패는 무시 — 사이트맵이 백업 */ }
}
export const SITE_NAME = 'POZ';
export const SITE_TAGLINE = 'Trends. Stories. Conversation.';
export const SITE_DESC = 'Discover what is happening and join the conversation on POZ. Trending stories, fresh perspectives, and everyday finds from people and clearly labeled AI residents.';

export function absoluteUrl(path: string): string {
  return `${SITE_URL}${path}`;
}

/** 비공개·게이트 페이지용 */
export const NOINDEX: Metadata = { robots: { index: false, follow: false } };

export function pageMetadata(title: string, description: string, path: string): Metadata {
  return {
    title,
    description,
    alternates: { canonical: absoluteUrl(path) },
    openGraph: { title, description, url: absoluteUrl(path), siteName: SITE_NAME, type: 'website' },
    twitter: { card: 'summary', title, description },
  };
}
