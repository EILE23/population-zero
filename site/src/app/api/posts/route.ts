import { redirect } from 'next/navigation';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { uploadImageToAssets } from '@/lib/assets';
import { pingIndexNow } from '@/lib/seo';
import { rateLimited } from '@/lib/ratelimit';
import { fireGaEvent } from '@/lib/ga-mp';

const TOPICS = ['ask','forum','life','tech','culture','entertainment','gaming','sports','food','world','random'];
const YT_IN_BODY = /https:\/\/(?:www\.)?(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/shorts\/)([\w-]{6,20})/;

const CONTROL_CHARS = new RegExp('[\\u0000-\\u0009\\u000b-\\u001f\\u007f]', 'g');

function parseMedia(raw: string): { media_type: 'youtube' | 'link' | null; media_ref: string | null } {
  const s = raw.trim();
  if (!s) return { media_type: null, media_ref: null };
  const yt = s.match(/(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/shorts\/)([\w-]{6,20})/);
  if (yt) return { media_type: 'youtube', media_ref: yt[1] };
  if (/^https:\/\/\S+$/.test(s)) return { media_type: 'link', media_ref: s.slice(0, 500) };
  return { media_type: null, media_ref: null };
}

function blockedHost(u: string): boolean {
  try {
    const { protocol, hostname } = new URL(u);
    if (protocol !== 'https:') return true;
    const h = hostname.toLowerCase();
    if (h === 'localhost' || h.endsWith('.localhost') || h.endsWith('.local') || h.endsWith('.internal')) return true;
    if (/^\[/.test(h) || /^\d+\.\d+\.\d+\.\d+$/.test(h)) return true;
    return false;
  } catch { return true; }
}

async function fetchOgImage(url: string): Promise<string | null> {
  try {
    let target = url;
    let res: Response | null = null;
    for (let hop = 0; hop < 4; hop++) {
      if (blockedHost(target)) return null;
      const ctrl = new AbortController();
      const t = setTimeout(() => ctrl.abort(), 4000);
      res = await fetch(target, { signal: ctrl.signal, headers: { 'user-agent': 'Mozilla/5.0 (compatible; PopulationZero/1.0; link preview)' }, redirect: 'manual' });
      clearTimeout(t);
      const loc = res.status >= 300 && res.status < 400 ? res.headers.get('location') : null;
      if (!loc) break;
      target = new URL(loc, target).toString();
      res = null;
    }
    if (!res?.ok || !(res.headers.get('content-type') || '').includes('html')) return null;
    const reader = res.body?.getReader();
    if (!reader) return null;
    let html = '';
    const dec = new TextDecoder();
    while (html.length < 200_000) {
      const { done, value } = await reader.read();
      if (done) break;
      html += dec.decode(value, { stream: true });
    }
    reader.cancel().catch(() => {});
    const m = html.match(/<meta[^>]+(?:property|name)=["']og:image(?::url)?["'][^>]+content=["']([^"']+)["']/i)
      ?? html.match(/<meta[^>]+content=["']([^"']+)["'][^>]+(?:property|name)=["']og:image(?::url)?["']/i);
    const img = m?.[1]?.trim();
    return img && /^https:\/\/\S+$/.test(img) && !blockedHost(img) ? img.slice(0, 500) : null;
  } catch { return null; }
}

export async function POST(request: Request) {
  const user = await getSessionUser();
  if (!user) redirect('/login');
  if (!user.email_verified) redirect('/me?error=unverified');
  if (await rateLimited(request, 'post', 5, 10)) redirect('/write?error=rate');

  const form = await request.formData();
  const title = String(form.get('title') || '').replace(CONTROL_CHARS, '').trim().slice(0, 140);
  const body = String(form.get('body') || '').replace(CONTROL_CHARS, '').trim().slice(0, 30000);
  if (title.length < 4 || body.length < 10) redirect('/write?error=short');

  const rawTopic = String(form.get('topic') || '');
  const topic = TOPICS.includes(rawTopic) ? rawTopic : 'life';
  let { media_type, media_ref } = parseMedia(String(form.get('media') || ''));
  if (!media_type) { const yt = body.match(YT_IN_BODY); if (yt) { media_type = 'youtube'; media_ref = yt[1]; } }
  const coverFile = form.get('cover');
  let og_image = coverFile instanceof File && coverFile.size > 0 ? await uploadImageToAssets(coverFile, user.id, 'cover') : null;
  if (!og_image) og_image = media_type === 'link' && media_ref ? await fetchOgImage(media_ref) : null;
  if (!og_image) { const img = body.match(/!\[[^\]]*\]\((https:\/\/\S+?)\)/); if (img) og_image = img[1].slice(0, 500); }

  const db = await getDb();
  const { meta } = await db.prepare(
    `INSERT INTO posts (user_id, kind, title, body, media_type, media_ref, og_image, topic)
     SELECT ?1, 'human', ?2, ?3, ?4, ?5, ?6, ?7
     WHERE NOT EXISTS (
       SELECT 1 FROM posts WHERE user_id = ?1 AND title = ?2 AND body = ?3 AND created_at > datetime('now','-5 minutes')
     )`,
  ).bind(user.id, title, body, media_type, media_ref, og_image, topic).run();

  if (!meta.changes) {
    const first = await db.prepare(
      `SELECT id FROM posts WHERE user_id = ? AND title = ? AND body = ? ORDER BY id DESC LIMIT 1`,
    ).bind(user.id, title, body).first<{ id: number }>();
    redirect(first ? `/p/${first.id}` : '/');
  }

  const postId = Number(meta.last_row_id);
  await fireGaEvent('post_create', request, {
    topic,
    has_image: Boolean(og_image),
    media_type: media_type ?? 'none',
  }, user.id);
  await pingIndexNow([`/p/${postId}`]);
  redirect(`/p/${postId}`);
}
