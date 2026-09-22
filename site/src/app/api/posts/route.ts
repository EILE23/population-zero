import { redirect } from 'next/navigation';
import { getDb, deferWork } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { uploadImageToAssets } from '@/lib/assets';
import { pingIndexNow } from '@/lib/seo';
import { rateLimited } from '@/lib/ratelimit';
import { fireGaEvent } from '@/lib/ga-mp';
import { visibleTo } from '@/lib/safety';
import { POST_ERROR_MESSAGE } from '@/lib/post-errors';

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
  | { ok: false; error: 'unauthorized' | 'unverified' | 'rate' | 'short' | 'upload' | 'failed' };

/**
 * 글 생성 본체 — 웹 폼(리다이렉트)과 앱(JSON)이 같은 로직을 쓴다.
 * 결과만 돌려주고, 응답 형태는 호출하는 쪽이 정한다.
 */
async function createHumanPost(request: Request): Promise<CreateResult> {
  const user = await getSessionUser();
  if (!user) return { ok: false, error: 'unauthorized' };
  if (!user.email_verified) return { ok: false, error: 'unverified' };

  const form = await request.formData();
  const title = String(form.get('title') || '').replace(CONTROL_CHARS, '').trim().slice(0, 140);
  const body = String(form.get('body') || '').replace(CONTROL_CHARS, '').trim().slice(0, 30000);

  const rawTopic = String(form.get('topic') || '');
  const topic = TOPICS.includes(rawTopic) ? rawTopic : 'life';
  // 연재명 — 같은 작성자의 같은 series 가 블로그에서 한 묶음이 되고 글 위에 이전/다음 상자가 붙는다
  const series = String(form.get('series') || '').replace(CONTROL_CHARS, '').trim().slice(0, 60) || null;
  let { media_type, media_ref } = parseMedia(String(form.get('media') || ''));
  if (!media_type) { const yt = body.match(YT_IN_BODY); if (yt) { media_type = 'youtube'; media_ref = yt[1]; } }
  // 앨범 — 두 갈래다.
  //  ① photos 로 사진을 올리면 새 앨범이 만들어지고 이 글이 그 앨범의 origin 이 된다(반응이 쌓이는 자리).
  //  ② album_id 로 이미 있는 앨범을 붙이면 이 글은 그 앨범을 '공유'한다 — 앨범 주인이 달라도 된다.
  // 한 번에 올릴 수 있는 장수를 제한한다: 무료 티어에서 한 요청이 오래 붙들리지 않게.
  const albumFiles = form.getAll('photos').filter((f): f is File => f instanceof File && f.size > 0).slice(0, 10);
  const attachAlbumId = Number(form.get('album_id')) || 0;
  const coverFile = form.get('cover');
  // 사진만 올리는 글은 말이 없어도 된다 — 사진이 곧 내용이다.
  // 글로만 올리는 경우에만 제목·본문 길이를 따진다.
  const photoOnly = albumFiles.length > 0;
  if (!photoOnly && (title.length < 4 || body.length < 10)) return { ok: false, error: 'short' };

  // 여기서부터가 '진짜 올리는' 구간이다.
  // 한도를 맨 앞에 두면 길이 미달처럼 거절당한 시도까지 할당량을 깎아, 오타 몇 번에
  // 10분 동안 글을 못 쓰게 된다. 검사를 통과한 뒤에 센다.
  // 사진은 거절되기 전에도 대역폭을 쓰므로 더 넉넉한 자기 몫으로 따로 막는다.
  if (albumFiles.length && await rateLimited(request, 'upload', 20, 10, true)) return { ok: false, error: 'rate' };
  if (await rateLimited(request, 'post', 5, 10)) return { ok: false, error: 'rate' };

  const db = await getDb();

  // ② 붙일 앨범이 있으면 실제로 있고 '이 사람에게' 보이는 앨범인지 먼저 — 없는 걸 붙인 글을 만들지 않는다.
  //    원본 글이 아직 예약 상태거나, 내가 차단한(또는 나를 차단한) 주인의 앨범이면 붙일 수 없다.
  let sharedAlbum: { id: number; cover: string | null } | null = null;
  if (attachAlbumId > 0) {
    sharedAlbum = await db.prepare(
      `SELECT a.id, (SELECT url FROM album_images WHERE album_id = a.id ORDER BY sort LIMIT 1) AS cover
       FROM albums a JOIN posts p ON p.id = a.origin_post_id
       WHERE a.id = ? AND p.hidden = 0 AND p.created_at <= datetime('now')
         AND ${visibleTo(user.id, 'p.user_id', 'p.resident_id')}
         AND EXISTS (SELECT 1 FROM album_images WHERE album_id = a.id)`,
    ).bind(attachAlbumId).first<{ id: number; cover: string | null }>();
    if (!sharedAlbum) return { ok: false, error: 'failed' };
  }

  // 재시도 열쇠 — 작성 화면이 열릴 때 하나 만들어 반려·재전송에도 같은 값을 보낸다.
  // 이 값이 있으면 텍스트 비교 대신 이걸로 "같은 글" 을 판정한다: 사진 글은 제목·본문이 비어 있어
  // 텍스트만 보면 서로 다른 사진 두 장이 한 글로 합쳐졌다.
  const clientKey = String(form.get('client_key') || '').replace(/[^A-Za-z0-9_-]/g, '').slice(0, 64) || null;
  if (clientKey) {
    const dup = await db.prepare(`SELECT id, album_id FROM posts WHERE user_id = ? AND client_key = ? AND created_at > datetime('now','-1 day') ORDER BY id DESC LIMIT 1`)
      .bind(user.id, clientKey).first<{ id: number; album_id: number | null }>();
    if (dup) {
      // 사진 글인데 앨범이 붙지 않았다 = 지난 시도가 글만 만들고 사진 단계에서 죽었다.
      // 그 반쪽을 "이미 올라간 글" 로 돌려주면 사진 없는 글이 성공으로 굳는다. 걷어내고 처음부터 다시 만든다.
      const albumBroken = albumFiles.length > 0 && dup.album_id == null;
      if (!albumBroken) return { ok: true, id: dup.id }; // 이미 올라간 그 글 — 사진을 다시 올리기 전에 돌려보낸다
      await db.batch([
        db.prepare(`DELETE FROM album_images WHERE album_id IN (SELECT id FROM albums WHERE origin_post_id = ?)`).bind(dup.id),
        db.prepare(`DELETE FROM albums WHERE origin_post_id = ?`).bind(dup.id),
        db.prepare(`DELETE FROM posts WHERE id = ? AND user_id = ? AND album_id IS NULL`).bind(dup.id, user.id),
      ]);
    }
  }

  const album: string[] = [];
  for (const file of albumFiles) {
    const url = await uploadImageToAssets(file, user.id, 'cover');
    if (url) album.push(url);
  }
  // 사진이 본문인 글은 사진이 있어야 글이다. 한 장이라도 실패하면 발행하지 않는다 —
  // 일부만 붙은 앨범을 말없이 올리면 사용자는 어느 사진이 빠졌는지 알 길이 없다.
  // (거절되기 전에 올라간 사진은 자산 저장소에 남는다: 글에 연결되지 않은 파일이라 노출되지 않는다)
  if (albumFiles.length && album.length < albumFiles.length) return { ok: false, error: 'upload' };
  let og_image: string | null = album[0]
    ?? sharedAlbum?.cover
    ?? (coverFile instanceof File && coverFile.size > 0 ? await uploadImageToAssets(coverFile, user.id, 'cover') : null);
  if (!og_image) og_image = media_type === 'link' && media_ref ? await fetchOgImage(media_ref) : null;
  if (!og_image) { const img = body.match(/!\[[^\]]*\]\((https:\/\/\S+?)\)/); if (img) og_image = img[1].slice(0, 500); }

  // 열쇠가 없는 옛 클라이언트만 텍스트로 재전송을 잡는다 — 사진 글은 텍스트가 비어 있으니 그 판정에서 뺀다
  const { meta } = await db.prepare(
    `INSERT INTO posts (user_id, kind, title, body, media_type, media_ref, og_image, topic, series, album_id, client_key)
     SELECT ?1, 'human', ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10
     WHERE NOT EXISTS (
       SELECT 1 FROM posts WHERE user_id = ?1 AND created_at > datetime('now','-1 day') AND (
         (?10 IS NOT NULL AND client_key = ?10)
         OR (?10 IS NULL AND ?11 = 0 AND title = ?2 AND body = ?3 AND created_at > datetime('now','-5 minutes'))
       )
     )`,
  ).bind(user.id, title, body, media_type, media_ref, og_image, topic, series, sharedAlbum?.id ?? null, clientKey, photoOnly ? 1 : 0).run();

  // 재전송(더블 탭·재시도) — 새로 만들지 않고 기존 글로 안내한다
  if (!meta.changes) {
    const first = clientKey
      ? await db.prepare(`SELECT id FROM posts WHERE user_id = ? AND client_key = ? ORDER BY id DESC LIMIT 1`).bind(user.id, clientKey).first<{ id: number }>()
      : await db.prepare(`SELECT id FROM posts WHERE user_id = ? AND title = ? AND body = ? ORDER BY id DESC LIMIT 1`).bind(user.id, title, body).first<{ id: number }>();
    return first ? { ok: true, id: first.id } : { ok: false, error: 'failed' };
  }

  const postId = Number(meta.last_row_id);
  // ① 새 앨범: 이 글이 origin. 한 장이어도 앨범이다 — 앨범 탭은 albums 를 보므로 빠지지 않는다.
  if (album.length > 0) {
    const made = await db.prepare(
      `INSERT INTO albums (user_id, caption, origin_post_id) VALUES (?, ?, ?)`,
    ).bind(user.id, title, postId).run();
    const albumId = Number(made.meta.last_row_id);
    await db.batch([
      ...album.map((url, i) => db.prepare(`INSERT INTO album_images (album_id, url, sort) VALUES (?, ?, ?)`).bind(albumId, url, i)),
      db.prepare(`UPDATE posts SET album_id = ? WHERE id = ?`).bind(albumId, postId),
    ]);
  }
  await fireGaEvent('post_create', request, {
    topic,
    has_image: Boolean(og_image),
    media_type: media_type ?? 'none',
  }, user.id);
  await deferWork(pingIndexNow([`/p/${postId}`])); // 응답 뒤에
  return { ok: true, id: postId };
}

const WEB_ERROR_PATH: Record<Exclude<CreateResult, { ok: true }>['error'], string> = {
  unauthorized: '/login',
  unverified: '/me?error=unverified',
  rate: '/write?error=rate',
  short: '/write?error=short',
  upload: '/write?error=upload',
  failed: '/',
};
const JSON_ERROR_STATUS: Record<Exclude<CreateResult, { ok: true }>['error'], number> = {
  unauthorized: 401, unverified: 403, rate: 429, short: 400, upload: 422, failed: 500,
};

export async function POST(request: Request) {
  // 앱(poz)은 Accept: application/json 을 보낸다 — 브라우저 폼은 리다이렉트, 앱은 JSON
  const wantsJson = (request.headers.get('accept') ?? '').includes('application/json');
  const result = await createHumanPost(request);

  if (result.ok) {
    if (wantsJson) return Response.json({ id: result.id, url: `/p/${result.id}` }, { status: 201 });
    redirect(`/p/${result.id}?posted=1`); // posted=1: 글쓰기 화면의 초안을 지워도 된다는 표식 (ClearDraft)
  }
  // error 는 코드(구 앱이 분기), message 는 문장(새 앱은 그대로 보여준다) — 둘 다 내려간다
  if (wantsJson) return Response.json({ error: result.error, message: POST_ERROR_MESSAGE[result.error] }, { status: JSON_ERROR_STATUS[result.error] });
  redirect(WEB_ERROR_PATH[result.error]);
}
