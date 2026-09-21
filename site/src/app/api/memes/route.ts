import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { rateLimited } from '@/lib/ratelimit';
import { sameOriginOrBearer } from '@/lib/safety';
import { cleanStyle, isAsset, isPicture, kindOf, memeHref, TEXT_MAX, youtubeId, youtubeThumb, type MemeKind } from '@/lib/memes';
import { purgePaths } from '@/lib/cache';

/**
 * 짤 게시판 — 목록·올리기. 세 가지가 같은 행이다:
 *   만든 짤   {image: 바탕, png: 합성 결과, style}       — 합성은 브라우저가 했고 PNG 는 /api/upload 로 이미 올라와 있다
 *   올린 그림 {png: 업로드 주소, caption}                — GIF 면 kind='gif'
 *   유튜브    {video: 유튜브 주소, caption}               — image=원 주소, png=썸네일(공유 미리보기)
 * 앱도 같은 경로를 쓴다(Bearer).
 */
export async function GET(request: Request) {
  const url = new URL(request.url);
  const before = Number(url.searchParams.get('before') ?? 0);
  const db = await getDb();
  const { results } = await db.prepare(`
    SELECT m.id, m.kind, m.png, m.image, m.top, m.bottom, m.remix_of, m.created_at,
           COALESCE(u.handle, r.handle) AS who, (m.resident_id IS NOT NULL) AS is_ai,
           (SELECT COUNT(*) FROM meme_votes v WHERE v.meme_id = m.id) AS votes,
           (SELECT COUNT(*) FROM memes x WHERE x.remix_of = m.id AND x.hidden = 0) AS remixes
    FROM memes m LEFT JOIN users u ON u.id = m.user_id LEFT JOIN residents r ON r.id = m.resident_id
    WHERE m.hidden = 0 ${before > 0 ? `AND m.id < ${Math.floor(before)}` : ''}
    ORDER BY m.id DESC LIMIT 40`).all();
  return Response.json({ memes: results }, { headers: { 'cache-control': 'public, max-age=30' } });
}

const clean = (s: unknown, max: number) => String(s ?? '').replace(/[\u0000-\u0008\u000b-\u001f\u007f]/g, '').replace(/\s+/g, ' ').trim().slice(0, max);

export async function POST(request: Request) {
  if (!sameOriginOrBearer(request)) return Response.json({ error: 'origin' }, { status: 403 });
  const user = await getSessionUser();
  if (!user || user.guest) return Response.json({ error: 'unauthorized', message: 'Log in to post.' }, { status: 401 });
  if (await rateLimited(request, 'meme', 30, 60)) return Response.json({ error: 'rate', message: 'Slow down a bit.' }, { status: 429 });

  const b = (await request.json().catch(() => ({}))) as {
    image?: unknown; png?: unknown; style?: unknown; remix_of?: unknown; video?: unknown; caption?: unknown; clip?: unknown;
  };
  const caption = clean(b.caption, TEXT_MAX);
  let kind: MemeKind, image: string, png: string, style = cleanStyle(null), top = caption, bottom = '';

  const yt = youtubeId(b.video);
  if (b.video !== undefined && b.video !== '' && !yt) {
    return Response.json({ error: 'video', message: 'Only YouTube links for now (watch, shorts, youtu.be).' }, { status: 400 });
  }
  if (yt) {
    kind = 'video'; image = `https://www.youtube.com/watch?v=${yt}`; png = youtubeThumb(yt);
  } else if (b.clip !== undefined) {
    // 릴 — 브라우저가 녹화한 영상(우리 보관함) + 포스터 PNG. 정의(style)는 리믹스용으로 같이 둔다
    if (!isAsset(b.clip) || !/\.(webm|mp4)$/.test(b.clip) || !isAsset(b.png)) {
      return Response.json({ error: 'clip', message: 'The clip has to be one recorded here.' }, { status: 400 });
    }
    kind = 'clip'; image = b.clip; png = b.png; style = cleanStyle(b.style);
    if (!caption) { top = style.texts[0]?.t ?? ''; bottom = style.texts[1]?.t ?? ''; }
  } else {
    // 결과 PNG(또는 올린 그림)는 우리가 올린 것이어야 한다. 바탕은 풀의 출처면 된다
    if (!isAsset(b.png)) return Response.json({ error: 'image', message: 'The picture has to be one you uploaded here.' }, { status: 400 });
    png = b.png; image = isPicture(b.image) ? b.image : png; kind = kindOf(png);
    style = cleanStyle(b.style);
    // 위·아래 두 줄은 목록·검색용 요약 — 만든 짤은 첫 두 글자, 올린 그림은 캡션
    if (!caption) { top = style.texts[0]?.t ?? ''; bottom = style.texts[1]?.t ?? ''; }
  }
  const remixOf = Number.isInteger(b.remix_of) && Number(b.remix_of) > 0 ? Number(b.remix_of) : null;

  const db = await getDb();
  const row = await db.prepare(`
    INSERT INTO memes (user_id, kind, image, png, top, bottom, style, remix_of)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?) RETURNING id`)
    .bind(user.id, kind, image, png, top, bottom, JSON.stringify(style), remixOf).first<{ id: number }>();
  if (!row) return Response.json({ error: 'failed' }, { status: 500 });

  await purgePaths(['/memes', memeHref(row.id)]).catch(() => null);
  return Response.json({ ok: true, id: row.id, url: memeHref(row.id) }, { status: 201 });
}
