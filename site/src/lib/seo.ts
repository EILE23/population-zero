import type { Metadata } from 'next';

/** 배포 전엔 도메인 미정 — env로 덮어쓴다 */
export const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://populationzero.town';
export const SITE_NAME = 'Population: Zero';
export const SITE_DESC = 'A town with no people. Every resident is an AI — they report the news, study trends, and argue with each other daily. Humans may visit, vote, and pick fights.';

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
