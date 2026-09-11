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
  // 리다이렉트부터 본문 읽기까지 하나의 마감 시한을 공유한다. 예전에는 헤더를 받자마자 타이머를
  // 지워서, 헤더만 빨리 주고 본문을 흘려보내지 않는 서버가 요청 전체를 붙잡을 수 있었다.
  const ctrl = new AbortController();
  const deadline = setTimeout(() => ctrl.abort(), 6000);
  let reader: ReadableStreamDefaultReader<Uint8Array> | undefined;
  try {
    let target = url;
    let res: Response | null = null;
    for (let hop = 0; hop < 4; hop++) {
      if (blockedHost(target)) return null;
      res = await fetch(target, { signal: ctrl.signal, headers: { 'user-agent': 'Mozilla/5.0 (compatible; PopulationZero/1.0; link preview)' }, redirect: 'manual' });
      const loc = res.status >= 300 && res.status < 400 ? res.headers.get('location') : null;
      if (!loc) break;
      target = new URL(loc, target).toString();
      res = null;
    }
    if (!res?.ok || !(res.headers.get('content-type') || '').includes('html')) return null;
    reader = res.body?.getReader();
    if (!reader) return null;
    let html = '';
    const dec = new TextDecoder();
    while (html.length < 200_000) {
      const { done, value } = await reader.read();
      if (done) break;
      html += dec.decode(value, { stream: true });
    }
    const m = html.match(/<meta[^>]+(?:property|name)=["']og:image(?::url)?["'][^>]+content=["']([^"']+)["']/i)
      ?? html.match(/<meta[^>]+content=["']([^"']+)["'][^>]+(?:property|name)=["']og:image(?::url)?["']/i);
    const img = m?.[1]?.trim();
    return img && /^https:\/\/\S+$/.test(img) && !blockedHost(img) ? img.slice(0, 500) : null;
  } catch { return null; } finally {
    clearTimeout(deadline);
    reader?.cancel().catch(() => {}); // 상한에서 멈췄든 예외로 빠졌든 연결을 반드시 닫는다
  }
}

type CreateResult =
  | { ok: true; id: number }
  | { ok: false; error: 'unauthorized' | 'unverified' | 'rate' | 'short' | 'failed' };

/**
 * 글 생성 본체 — 웹 폼(리다이렉트)과 앱(JSON)이 같은 로직을 쓴다.
 * 결과만 돌려주고, 응답 형태는 호출하는 쪽이 정한다.
 */
async function createHumanPost(request: Request): Promise<CreateResult> {
  const user = await getSessionUser();
  if (!user) return { ok: false, error: 'unauthorized' };
  if (!user.email_verified) return { ok: false, error: 'unverified' };
  if (await rateLimited(request, 'post', 5, 10)) return { ok: false, error: 'rate' };

  const form = await request.formData();
  const title = String(form.get('title') || '').replace(CONTROL_CHARS, '').trim().slice(0, 140);
  const body = String(form.get('body') || '').replace(CONTROL_CHARS, '').trim().slice(0, 30000);
  if (title.length < 4 || body.length < 10) return { ok: false, error: 'short' };

  const rawTopic = String(form.get('topic') || '');
  const topic = TOPICS.includes(rawTopic) ? rawTopic : 'life';
  let { media_type, media_ref } = parseMedia(String(form.get('media') || ''));
  if (!media_type) { const yt = body.match(YT_IN_BODY); if (yt) { media_type = 'youtube'; media_ref = yt[1]; } }
  // 앨범 — 앱에서 사진을 여러 장 올린다. 첫 장이 커버(og_image)가 되고 나머지는 post_images 로 간다.
  // 한 번에 올릴 수 있는 장수를 제한한다: 무료 티어에서 한 요청이 오래 붙들리지 않게.
  const albumFiles = form.getAll('photos').filter((f): f is File => f instanceof File && f.size > 0).slice(0, 10);
  const coverFile = form.get('cover');
  // 사진만 올리는 글은 말이 없어도 된다 — 사진이 곧 내용이다.
  // 글로만 올리는 경우에만 제목·본문 길이를 따진다.
  const photoOnly = albumFiles.length > 0;
  if (!photoOnly && (title.length < 4 || body.length < 10)) return { ok: false, error: 'short' };
  const album: string[] = [];
  for (const file of albumFiles) {
    const url = await uploadImageToAssets(file, user.id, 'cover');
    if (url) album.push(url);
  }
  let og_image: string | null = album[0]
    ?? (coverFile instanceof File && coverFile.size > 0 ? await uploadImageToAssets(coverFile, user.id, 'cover') : null);
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

  // 5분 내 같은 글 재전송(더블 탭·재시도) — 새로 만들지 않고 기존 글로 안내한다
  if (!meta.changes) {
    const first = await db.prepare(
      `SELECT id FROM posts WHERE user_id = ? AND title = ? AND body = ? ORDER BY id DESC LIMIT 1`,
    ).bind(user.id, title, body).first<{ id: number }>();
    return first ? { ok: true, id: first.id } : { ok: false, error: 'failed' };
  }

  const postId = Number(meta.last_row_id);
  // 앨범이 두 장 이상이면 전부 기록한다 (한 장짜리는 커버만으로 충분하다)
  if (album.length > 1) {
    await db.batch(album.map((url, i) =>
      db.prepare(`INSERT INTO post_images (post_id, url, sort) VALUES (?, ?, ?)`).bind(postId, url, i)));
  }
  await fireGaEvent('post_create', request, {
    topic,
    has_image: Boolean(og_image),
    media_type: media_type ?? 'none',
  }, user.id);
  await pingIndexNow([`/p/${postId}`]);
  return { ok: true, id: postId };
}

const WEB_ERROR_PATH: Record<Exclude<CreateResult, { ok: true }>['error'], string> = {
  unauthorized: '/login',
  unverified: '/me?error=unverified',
  rate: '/write?error=rate',
  short: '/write?error=short',
  failed: '/',
};
const JSON_ERROR_STATUS: Record<Exclude<CreateResult, { ok: true }>['error'], number> = {
  unauthorized: 401, unverified: 403, rate: 429, short: 400, failed: 500,
};

export async function POST(request: Request) {
  // 앱(poz)은 Accept: application/json 을 보낸다 — 브라우저 폼은 리다이렉트, 앱은 JSON
  const wantsJson = (request.headers.get('accept') ?? '').includes('application/json');
  const result = await createHumanPost(request);

  if (result.ok) {
    if (wantsJson) return Response.json({ id: result.id, url: `/p/${result.id}` }, { status: 201 });
    redirect(`/p/${result.id}`);
  }
  if (wantsJson) return Response.json({ error: result.error }, { status: JSON_ERROR_STATUS[result.error] });
  redirect(WEB_ERROR_PATH[result.error]);
}
