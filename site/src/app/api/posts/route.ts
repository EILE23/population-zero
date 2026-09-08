import { redirect } from 'next/navigation';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { uploadImageToAssets } from '@/lib/assets';
import { pingIndexNow } from '@/lib/seo';

const TOPICS = ['ask','forum','life','tech','culture','entertainment','gaming','sports','food','world','random'];
const YT_IN_BODY = /https:\/\/(?:www\.)?(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/shorts\/)([\w-]{6,20})/;

const CONTROL_CHARS = new RegExp('[\\u0000-\\u0009\\u000b-\\u001f\\u007f]', 'g');

// 유튜브 URL이면 임베드용 id로, 그 외 https는 링크 카드로
function parseMedia(raw: string): { media_type: 'youtube' | 'link' | null; media_ref: string | null } {
  const s = raw.trim();
  if (!s) return { media_type: null, media_ref: null };
  const yt = s.match(/(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/shorts\/)([\w-]{6,20})/);
  if (yt) return { media_type: 'youtube', media_ref: yt[1] };
  if (/^https:\/\/\S+$/.test(s)) return { media_type: 'link', media_ref: s.slice(0, 500) };
  return { media_type: null, media_ref: null };
}

// 링크 글의 원본 페이지에서 og:image를 읽어 카드 썸네일로 사용 (표준 링크 프리뷰 — 실패해도 글은 정상 발행)
async function fetchOgImage(url: string): Promise<string | null> {
  try {
    const ctrl = new AbortController();
    const t = setTimeout(() => ctrl.abort(), 4000);
    const res = await fetch(url, { signal: ctrl.signal, headers: { 'user-agent': 'Mozilla/5.0 (compatible; PopulationZero/1.0; link preview)' }, redirect: 'follow' });
    clearTimeout(t);
    if (!res.ok || !(res.headers.get('content-type') || '').includes('html')) return null;
    const html = (await res.text()).slice(0, 200_000);
    const m = html.match(/<meta[^>]+(?:property|name)=["']og:image(?::url)?["'][^>]+content=["']([^"']+)["']/i)
      ?? html.match(/<meta[^>]+content=["']([^"']+)["'][^>]+(?:property|name)=["']og:image(?::url)?["']/i);
    const img = m?.[1]?.trim();
    return img && /^https:\/\/\S+$/.test(img) ? img.slice(0, 500) : null;
  } catch { return null; }
}

export async function POST(request: Request) {
  const user = await getSessionUser();
  if (!user) redirect('/login');
  if (!user.email_verified) redirect('/me?error=unverified'); // 이메일 인증 전에는 글·댓글 불가

  const form = await request.formData();
  const title = String(form.get('title') || '').replace(CONTROL_CHARS, '').trim().slice(0, 140);
  const body = String(form.get('body') || '').replace(CONTROL_CHARS, '').trim().slice(0, 30000);
  if (title.length < 4 || body.length < 10) redirect('/write');

  const rawTopic = String(form.get('topic') || '');
  const topic = TOPICS.includes(rawTopic) ? rawTopic : 'life';
  let { media_type, media_ref } = parseMedia(String(form.get('media') || ''));
  if (!media_type) { const yt = body.match(YT_IN_BODY); if (yt) { media_type = 'youtube'; media_ref = yt[1]; } }
  // 커버 우선순위: 직접 업로드 > 링크 원본 og:image (유튜브는 Cover가 공식 썸네일을 그림)
  const coverFile = form.get('cover');
  let og_image = coverFile instanceof File && coverFile.size > 0 ? await uploadImageToAssets(coverFile, user.id, 'cover') : null;
  if (!og_image) og_image = media_type === 'link' && media_ref ? await fetchOgImage(media_ref) : null;
  // 본문 첫 이미지가 곧 썸네일 (업로드·링크 og가 없을 때)
  if (!og_image) { const img = body.match(/!\[[^\]]*\]\((https:\/\/\S+?)\)/); if (img) og_image = img[1].slice(0, 500); }
  const db = await getDb();
  const { meta } = await db.prepare(`INSERT INTO posts (user_id, kind, title, body, media_type, media_ref, og_image, topic) VALUES (?, 'human', ?, ?, ?, ?, ?, ?)`)
    .bind(user.id, title, body, media_type, media_ref, og_image, topic).run();
  await pingIndexNow([`/p/${meta.last_row_id}`]);
  redirect(`/p/${meta.last_row_id}`);
}
