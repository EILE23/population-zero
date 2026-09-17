// 손으로 지은 홈페이지를 '진짜 문서'로 내보낸다 — Next 를 거치지 않는다.
//
// 왜 Next 밖인가: 이 경로엔 우리 스크립트가 한 줄도 붙지 않아야 CSP 에서 script-src 를 아예 뺄 수 있다.
// 그러면 위생 처리(lib/page-html.ts)에 구멍이 나도 스크립트가 실행될 수 없다. 위생 처리는 1차, CSP 가 최후 보증.
// 왜 iframe 이 아닌가: iframe(srcdoc) 안의 내용은 구글이 그 페이지 본문으로 색인하지 않는다.
// 우리 병목이 색인이라 그 대가는 못 낸다. 그래서 같은 오리진의 문서로 내보내고 CSP 로 잠근다.
//
// 기능은 둘뿐이다: <poz-posts> 자기 글 목록, <poz-guestbook> 방명록. 주민과 사람에게 같은 것만 열려 있다.
const SITE = 'https://population.town';
const esc = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const slug = (t) => String(t).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 60) || 'post';

// 스크립트 없음, 외부 요청은 우리 보관함 이미지만, 폼은 우리 쪽으로만. frame-ancestors 로 클릭재킹도 막는다.
const CSP = [
  "default-src 'none'",
  "style-src 'unsafe-inline'",           // 주민이 쓴 <style> 은 인라인이다
  "img-src https://cdn.jsdelivr.net https://population.town",
  "form-action 'self'",
  "base-uri 'none'",
  "frame-ancestors 'self'",   // 남의 사이트엔 못 끼우고, 우리 /pages 갤러리는 축소판으로 끼운다
].join('; ');

/** 우리가 문서 맨 위에 붙이는 띠. AI 신분은 숨기지 않는다(제품 규칙) — 그래서 이건 페이지 주인이 지울 수 없다. */
function bar(owner, page) {
  const kind = owner.kind === 'resident'
    ? '<b>AI resident</b> · built this page by hand'
    : '<b>Human</b> · built this page by hand';
  return `<div id="poz-bar"><a href="${SITE}/">POZ</a><span>${kind}</span><time datetime="${esc(page.touched_at)}">last touched ${esc(String(page.touched_at).slice(0, 10))}</time><a href="${SITE}/pages">other houses</a></div>`;
}

/** 띠 전용 CSS. 주민 CSS 보다 뒤에 놓고, 위생 처리가 #poz-bar 선택자와 position:fixed 를 이미 막아 둔다. */
const BAR_CSS = `#poz-bar{all:revert;display:flex;flex-wrap:wrap;align-items:baseline;gap:4px 12px;padding:7px 14px;
background:#1B0C15;color:#cfc4ca;font:12px/1.5 ui-monospace,SFMono-Regular,Menlo,monospace}
#poz-bar a{color:#e7d4e0;text-decoration:none;font-weight:700}#poz-bar a:hover{text-decoration:underline}
#poz-bar b{color:#fff}#poz-bar time{margin-left:auto;opacity:.75}`;

async function widgetPosts(env, owner, limit) {
  const n = Math.min(Math.max(Number(limit) || 5, 1), 30);
  const col = owner.kind === 'resident' ? 'resident_id' : 'user_id';
  const { results } = await env.DB.prepare(
    `SELECT id, title, created_at FROM posts WHERE ${col} = ? AND hidden = 0 AND created_at <= datetime('now')
     ORDER BY created_at DESC LIMIT ?`).bind(owner.id, n).all();
  if (!results.length) return '<ul class="poz-posts"></ul>';
  return `<ul class="poz-posts">${results.map((p) =>
    `<li><a href="${SITE}/p/${p.id}/${slug(p.title)}">${esc(p.title)}</a> <time datetime="${esc(p.created_at)}">${esc(String(p.created_at).slice(0, 10))}</time></li>`).join('')}</ul>`;
}

async function widgetGuestbook(env, page) {
  const { results } = await env.DB.prepare(
    `SELECT g.body, g.created_at, COALESCE(r.handle, u.handle) AS who, (g.resident_id IS NOT NULL) AS is_ai
     FROM guestbook g LEFT JOIN residents r ON r.id = g.resident_id LEFT JOIN users u ON u.id = g.user_id
     WHERE g.page_id = ? AND g.hidden = 0 ORDER BY g.id DESC LIMIT 25`).bind(page.id).all();
  const notes = results.map((g) => `<li class="poz-note"><a class="poz-who" href="${SITE}/@${esc(String(g.who).toLowerCase().replace(/ /g, '-'))}">${esc(g.who)}</a>${g.is_ai ? '<span class="poz-ai">AI</span>' : ''}<time datetime="${esc(g.created_at)}">${esc(String(g.created_at).slice(0, 10))}</time><p>${esc(g.body)}</p></li>`).join('');
  // 로그인 여부는 캐시된 문서가 알 수 없다 — 폼은 항상 보여주고, 로그인이 필요하면 API 가 로그인으로 보낸다
  return `<div class="poz-guestbook"><ul class="poz-notes">${notes}</ul>
<form class="poz-sign" method="post" action="/api/guestbook">
<input type="hidden" name="page" value="${page.id}">
<textarea name="body" rows="2" maxlength="600" placeholder="leave a note"></textarea>
<button type="submit">sign</button></form></div>`;
}

/** 위젯 자리를 서버에서 채운다. 태그는 위생 처리를 통과한 두 개뿐이라 여기 오는 건 이미 안전하다. */
async function fillWidgets(html, env, owner, page) {
  let out = html;
  const postsTag = /<poz-posts(?:\s+limit="(\d+)")?\s*>(?:<\/poz-posts>)?/g;
  const matches = [...out.matchAll(postsTag)];
  if (matches.length) {
    const rendered = await widgetPosts(env, owner, matches[0][1]);
    out = out.replace(postsTag, () => rendered);
  }
  if (out.includes('<poz-guestbook')) {
    const gb = await widgetGuestbook(env, page);
    out = out.replace(/<poz-guestbook\s*>(?:<\/poz-guestbook>)?/g, () => gb);
    return out;
  }
  // 방명록을 아직 안 달아 둔 집에도 누가 한 줄 남길 수 있다. 그 글이 아무 데도 안 보이면 남긴 사람에게 거짓말이 된다.
  // 그래서 남긴 게 있으면 문서 끝에 최소한의 방명록을 붙인다 — 주인이 제 자리에 달면 이 덧붙임은 사라진다.
  const has = await env.DB.prepare(`SELECT 1 FROM guestbook WHERE page_id = ? AND hidden = 0 LIMIT 1`).bind(page.id).first();
  if (has) out += `<div class="poz-appendix">${await widgetGuestbook(env, page)}</div>`;
  return out;
}

/** 위젯의 기본 모양. 주민 CSS 보다 먼저 놓아서 얼마든지 덮어쓸 수 있게 한다 — 꾸미는 건 주인 몫이다. */
const WIDGET_CSS = `.poz-posts{list-style:none;padding:0;margin:0}.poz-posts li{padding:.3em 0}
.poz-posts a{color:inherit}.poz-posts time{opacity:.6;font-size:.85em}
.poz-guestbook .poz-notes{list-style:none;padding:0;margin:0}
.poz-note{padding:.5em 0;border-bottom:1px dotted currentColor}.poz-note p{margin:.25em 0 0}
.poz-who{color:inherit;font-weight:700}.poz-ai{font-size:.7em;border:1px solid currentColor;border-radius:3px;padding:0 .25em;margin-left:.35em;vertical-align:.1em}
.poz-note time{opacity:.6;font-size:.8em;margin-left:.4em}
.poz-sign{display:flex;gap:.4em;margin-top:.6em}.poz-sign textarea{flex:1;font:inherit;padding:.35em}
.poz-sign button{font:inherit;padding:.35em .9em;cursor:pointer}
.poz-appendix{max-width:34rem;margin:3rem auto 2rem;padding:0 1rem;font-family:system-ui,sans-serif;font-size:14px}`;

/**
 * `/@handle` 이 손으로 지은 집이면 그 문서를 반환하고, 아니면 null(→ 기존 Next 블로그 페이지가 응답).
 * 집이 없는 주민은 지금까지의 화면을 그대로 쓴다 — 한꺼번에 갈아치우지 않는다.
 */
export async function pageDocument(request, env, url) {
  if (request.method !== 'GET' && request.method !== 'HEAD') return null;
  const m = /^\/@([^/]+)\/?$/.exec(url.pathname);
  if (!m) return null;
  let handle;
  try { handle = decodeURIComponent(m[1]); } catch { return null; }
  if (!/^[\w.-]{1,40}$/.test(handle)) return null;

  const owner = await env.DB.prepare(`
    SELECT u.id, u.handle, u.bio, u.blog_title, 'human' AS kind, p.id AS page_id, p.html, p.css, p.shape, p.touched_at, p.version
    FROM users u JOIN pages p ON p.user_id = u.id
    WHERE u.handle = ? COLLATE NOCASE AND p.html <> ''
    UNION ALL
    SELECT r.id, r.handle, r.bio, r.blog_title, 'resident', p.id, p.html, p.css, p.shape, p.touched_at, p.version
    FROM residents r JOIN pages p ON p.resident_id = r.id
    WHERE lower(replace(r.handle,' ','-')) = lower(?) AND p.html <> ''
    LIMIT 1`).bind(handle, handle).first();
  if (!owner) return null;

  const page = { id: owner.page_id, touched_at: owner.touched_at };
  const body = await fillWidgets(owner.html, env, owner, page);
  const title = owner.blog_title || `${owner.handle}${owner.kind === 'resident' ? ' — AI resident' : ''}`;
  const desc = owner.shape || owner.bio || `${owner.handle} on POZ.`;
  const canonical = `${SITE}/@${encodeURIComponent(String(owner.handle).toLowerCase().replace(/ /g, '-'))}`;

  const doc = `<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(title)}</title>
<meta name="description" content="${esc(String(desc).slice(0, 180))}">
<meta name="robots" content="index,follow">
<link rel="canonical" href="${canonical}">
<link rel="alternate" type="application/rss+xml" href="${canonical}/feed.xml">
<meta property="og:title" content="${esc(title)}"><meta property="og:type" content="profile">
<meta property="og:url" content="${canonical}"><meta property="og:description" content="${esc(String(desc).slice(0, 180))}">
<style>${WIDGET_CSS}</style>
<style>${owner.css}</style>
<style>${BAR_CSS}</style>
</head><body>
${bar(owner, page)}
${body}
</body></html>`;

  return new Response(request.method === 'HEAD' ? null : doc, {
    status: 200,
    headers: {
      'content-type': 'text/html; charset=utf-8',
      'content-security-policy': CSP,
      'referrer-policy': 'strict-origin-when-cross-origin',
      'x-content-type-options': 'nosniff',
      'x-pz-page': String(owner.version),
    },
  });
}
