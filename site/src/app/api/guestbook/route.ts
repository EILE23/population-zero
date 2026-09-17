import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { rateLimited } from '@/lib/ratelimit';
import { sameOriginOrBearer } from '@/lib/safety';

const MAX = 600;

/**
 * 방명록에 한 줄 — 손으로 지은 홈페이지(page-serve.js)의 평범한 폼이 여기로 온다.
 *
 * 그 페이지엔 우리 스크립트가 한 줄도 없다(CSP 에서 script-src 를 뺐다). 그래서 fetch 가 아니라
 * 옛날 방식의 form POST 로 들어오고, 응답은 JSON 이 아니라 303 으로 원래 집으로 돌려보낸다.
 * 캐시된 문서는 방문자가 로그인했는지 알 수 없으니 폼은 늘 보인다 — 로그인 판단은 여기서 한다.
 */
export async function POST(request: Request) {
  if (!sameOriginOrBearer(request)) return Response.json({ error: 'origin' }, { status: 403 });

  const ct = request.headers.get('content-type') ?? '';
  const form = ct.includes('form') ? await request.formData() : null;
  const json = form ? null : ((await request.json().catch(() => ({}))) as { page?: unknown; body?: unknown });
  const pageId = Number(form ? form.get('page') : json?.page);
  const body = String((form ? form.get('body') : json?.body) ?? '').replace(/\r/g, '').trim().slice(0, MAX);

  const db = await getDb();
  const page = Number.isSafeInteger(pageId) && pageId > 0
    ? await db.prepare(`SELECT p.id, COALESCE(u.handle, r.handle) AS handle FROM pages p
        LEFT JOIN users u ON u.id = p.user_id LEFT JOIN residents r ON r.id = p.resident_id WHERE p.id = ?`)
      .bind(pageId).first<{ id: number; handle: string }>()
    : null;
  const back = page ? `/@${page.handle.toLowerCase().replace(/ /g, '-')}` : '/pages';
  const bounce = (to: string) => new Response(null, { status: 303, headers: { location: to, 'cache-control': 'no-store' } });

  if (!page) return form ? bounce('/pages') : Response.json({ error: 'no_page' }, { status: 404 });

  const user = await getSessionUser();
  if (!user || user.guest) {
    // 폼으로 왔으면 로그인 뒤 이 집으로 돌려보낸다 — 쓴 글이 사라지는 건 어쩔 수 없지만 길은 잇는다
    if (!form) return Response.json({ error: 'unauthorized', message: 'Log in to sign a guestbook.' }, { status: 401 });
    return new Response(null, {
      status: 303,
      headers: {
        location: '/login?mode=signup',
        'set-cookie': `pz_next=${encodeURIComponent(back)}; Path=/; Max-Age=900; SameSite=Lax`,
        'cache-control': 'no-store',
      },
    });
  }
  if (body.length < 2) return form ? bounce(`${back}#poz-guestbook`) : Response.json({ error: 'short', message: 'Write something first.' }, { status: 400 });
  if (await rateLimited(request, 'guestbook', 12, 60)) {
    return form ? bounce(back) : Response.json({ error: 'rate', message: 'Too many notes for now.' }, { status: 429 });
  }

  await db.prepare(`INSERT INTO guestbook (page_id, user_id, body) VALUES (?, ?, ?)`).bind(page.id, user.id, body).run();
  return form ? bounce(back) : Response.json({ ok: true });
}
