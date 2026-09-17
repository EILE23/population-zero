// 보내는 메일 — 워커의 시간당 크론이 부른다. 요청 경로가 아니라 사람을 기다리게 하지 않는다.
//
//  ① answers   : 내가 올린 질문에 주민들이 답했다. 창을 닫은 사람은 이 메일이 없으면 답을 영영 못 본다(거래성).
//  ② marketing : 수신 동의한 사람에게 주 1회, 지난주 읽을 만한 글 하나(광고성 — 명시 동의 + 언제든 해지).
//  ③ alerts    : 걸어 둔 단어가 12개국 기사에 떴다(거래성 — 본인이 그 단어를 직접 등록했다).
//  ④ brief     : 하루 한 통, 자기 나라 아침 시간에 맞춰 밤새 기사와 여기 스레드 하나.
//
// ③④ 는 모델을 부르지 않는다. 순찰이 이미 모아 둔 trends 를 문자열로 맞춰 보고 보내는 게 전부다.
// 한 사건에 한 통만 나간다(mail_log / alert_sent). 게스트(이메일 없음)와 수신 거부는 애초에 후보에서 빠진다.
const SITE = 'https://population.town';
const FROM = 'POZ <noreply@population.town>';
const PER_RUN = 40;          // Resend 무료 한도(일 100통) 안에서 — 시간당 상한
const MARKETING_UTC_HOUR = 0; // 09:00 KST 월요일
const DAILY_CAP = 90;        // Resend 무료 일 100통 — 답변 메일이 한도에 밀리지 않게 나머지 레인은 여기서 멈춘다
const ALERT_PER_RUN = 25;    // 알림 메일은 시간당 이만큼까지
const ALERT_MAX_STORIES = 8; // 한 통에 담는 기사 수 (나머지는 "and N more")

// 그 나라 아침 7시가 되는 UTC 시각. 브리핑은 받는 사람의 아침에 도착해야 브리핑이다.
const BRIEF_HOUR = { KR: 22, JP: 22, AU: 21, ID: 0, IN: 1, DE: 5, FR: 5, GB: 6, NG: 6, BR: 10, US: 11, MX: 13, '': 11 };

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

async function unsubToken(secret, userId) {
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(`unsub:${userId}`));
  return [...new Uint8Array(sig)].slice(0, 12).map((b) => b.toString(16).padStart(2, '0')).join('');
}

function shell(body, unsubUrl) {
  return `<div style="font:15px/1.6 -apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;color:#1B0C15;max-width:560px;margin:0 auto;padding:24px">
${body}
<p style="margin-top:28px;border-top:1px solid #e7e2e4;padding-top:14px;font-size:12px;color:#8b8289">
POZ · <a href="${SITE}" style="color:#7B526C">population.town</a> · <a href="${unsubUrl}" style="color:#8b8289">unsubscribe</a>
</p></div>`;
}

async function send(env, to, subject, html) {
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { authorization: `Bearer ${env.RESEND_API_KEY}`, 'content-type': 'application/json' },
    body: JSON.stringify({ from: FROM, to: [to], subject, html }),
    signal: AbortSignal.timeout(8000),
  });
  return res.ok;
}

const slug = (t) => String(t).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 60) || 'post';

/** ① 답변 알림 — 답이 실제로 보이게 된 뒤(예약 시각이 지난 뒤) 한 번만 */
async function answerMails(env) {
  const { results } = await env.DB.prepare(`
    SELECT p.id, p.title, u.id AS user_id, u.email,
      (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id AND c.resident_id IS NOT NULL AND c.hidden = 0 AND c.created_at <= datetime('now')) AS answers
    FROM posts p JOIN users u ON u.id = p.user_id
    WHERE p.user_id IS NOT NULL AND p.hidden = 0
      AND p.created_at > datetime('now','-3 days')
      AND u.email IS NOT NULL AND u.email_optout = 0 AND u.notify_comments = 1 AND u.guest = 0
      AND NOT EXISTS (SELECT 1 FROM mail_log m WHERE m.kind = 'answers' AND m.ref_id = p.id AND m.user_id = u.id)
    ORDER BY p.created_at DESC LIMIT ?`).bind(PER_RUN).all();

  let sent = 0;
  for (const p of results) {
    if (!p.answers) continue;
    const { results: answers } = await env.DB.prepare(`
      SELECT r.handle, c.body FROM comments c JOIN residents r ON r.id = c.resident_id
      WHERE c.post_id = ? AND c.hidden = 0 AND c.created_at <= datetime('now') ORDER BY c.id LIMIT 3`).bind(p.id).all();
    const path = `/p/${p.id}/${slug(p.title)}`;
    const unsub = `${SITE}/api/mail/unsubscribe?u=${p.user_id}&t=${await unsubToken(env.RESEND_API_KEY, p.user_id)}`;
    const list = answers.map((a) => `
<div style="margin:14px 0;padding:12px 14px;background:#f6f3f4;border-radius:12px">
  <div style="font-weight:700;font-size:13px">${esc(a.handle)}</div>
  <div style="margin-top:4px;color:#3a2f36">${esc(String(a.body).slice(0, 220))}${String(a.body).length > 220 ? '…' : ''}</div>
</div>`).join('');
    const html = shell(`
<p style="font-size:13px;color:#8b8289;margin:0">${p.answers === 1 ? 'Someone answered you' : `${p.answers} answers so far`}</p>
<h1 style="font-size:20px;margin:6px 0 0">${esc(p.title)}</h1>
${list}
<p style="margin-top:18px"><a href="${SITE}${path}" style="display:inline-block;background:#1B0C15;color:#fff;padding:10px 18px;border-radius:999px;text-decoration:none;font-weight:700">Read the thread</a></p>
<p style="font-size:13px;color:#8b8289">They keep going after you leave, and you can answer back.</p>`, unsub);

    const ok = await send(env, p.email, `Answers to "${String(p.title).slice(0, 60)}"`, html);
    if (!ok) continue;
    await env.DB.prepare(`INSERT OR IGNORE INTO mail_log (kind, ref_id, user_id) VALUES ('answers', ?, ?)`).bind(p.id, p.user_id).run();
    sent++;
  }
  return sent;
}

/** ② 마케팅 메일 — 주 1회(월요일), 지난 7일 중 사람 반응이 가장 좋았던 글 하나 */
async function marketingMails(env, now, budget) {
  if (budget <= 0) return 0;
  if (now.getUTCDay() !== 1 || now.getUTCHours() !== MARKETING_UTC_HOUR) return 0;
  const stamp = Number(now.toISOString().slice(0, 10).replace(/-/g, ''));
  const pick = await env.DB.prepare(`
    SELECT p.id, p.title, substr(p.body, 1, 400) AS body, COALESCE(r.handle, u.handle) AS author,
      (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id AND c.user_id IS NOT NULL AND c.hidden = 0) * 3
      + (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.id) * 2
      + (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id AND c.hidden = 0) AS score
    FROM posts p LEFT JOIN residents r ON r.id = p.resident_id LEFT JOIN users u ON u.id = p.user_id
    WHERE p.hidden = 0 AND p.created_at > datetime('now','-7 days') AND p.created_at <= datetime('now')
      AND length(p.body) >= 1500
    ORDER BY score DESC, length(p.body) DESC LIMIT 1`).first();
  if (!pick) return 0;

  const { results } = await env.DB.prepare(`
    SELECT id, email FROM users
    WHERE email IS NOT NULL AND email_weekly = 1 AND email_optout = 0 AND guest = 0
      AND NOT EXISTS (SELECT 1 FROM mail_log m WHERE m.kind = 'weekly' AND m.ref_id = ? AND m.user_id = users.id)
    LIMIT ?`).bind(stamp, Math.min(PER_RUN, budget)).all();

  const path = `/p/${pick.id}/${slug(pick.title)}`;
  const body = String(pick.body).replace(/[#*`>\[\]]/g, '').replace(/\s+/g, ' ').trim().slice(0, 260);
  let sent = 0;
  for (const u of results) {
    const unsub = `${SITE}/api/mail/unsubscribe?u=${u.id}&t=${await unsubToken(env.RESEND_API_KEY, u.id)}`;
    const html = shell(`
<p style="font-size:13px;color:#8b8289;margin:0">Worth reading this week on POZ</p>
<h1 style="font-size:20px;margin:6px 0 10px">${esc(pick.title)}</h1>
<p style="color:#3a2f36;margin:0">${esc(body)}…</p>
<p style="font-size:13px;color:#8b8289;margin:8px 0 0">by ${esc(pick.author ?? 'a resident')}</p>
<p style="margin-top:18px"><a href="${SITE}${path}" style="display:inline-block;background:#1B0C15;color:#fff;padding:10px 18px;border-radius:999px;text-decoration:none;font-weight:700">Read it</a></p>
<p style="font-size:13px;color:#8b8289">Something you want answered? <a href="${SITE}/ask" style="color:#7B526C">Ask the town</a>.</p>`, unsub);
    const ok = await send(env, u.email, esc(String(pick.title).slice(0, 70)), html);
    if (!ok) continue;
    await env.DB.prepare(`INSERT OR IGNORE INTO mail_log (kind, ref_id, user_id) VALUES ('weekly', ?, ?)`).bind(stamp, u.id).run();
    sent++;
  }
  return sent;
}

/**
 * 걸어 둔 단어가 실제로 그 기사 안에 있는지.
 * SQL 의 LIKE 는 후보를 좁히는 용도일 뿐이다 — 'ai' 가 'said' 에 걸리면 알림이 아니라 소음이니
 * 알파벳 키워드는 앞뒤가 글자·숫자가 아닐 때만 인정한다. 한글·일본어처럼 띄어쓰기가 다른 말은 그냥 포함이면 된다.
 */
function hits(haystack, keyword) {
  const text = String(haystack ?? '').toLowerCase();
  if (!/^[a-z0-9 .'&+-]+$/.test(keyword)) return text.includes(keyword);
  let from = 0;
  for (;;) {
    const at = text.indexOf(keyword, from);
    if (at < 0) return false;
    const before = text[at - 1] ?? ' ';
    const after = text[at + keyword.length] ?? ' ';
    if (!/[a-z0-9]/.test(before) && !/[a-z0-9]/.test(after)) return true;
    from = at + 1;
  }
}

function storyList(rows) {
  return rows.map((t) => `
<div style="margin:0 0 14px">
  <a href="${esc(t.url)}" style="color:#1B0C15;font-weight:700;text-decoration:none">${esc(t.title)}</a>
  <div style="font-size:12px;color:#8b8289;margin-top:3px">${esc(t.source_name ?? 'press')}${t.region ? ` · ${esc(t.region)}` : ''}</div>
</div>`).join('');
}

/** ③ 키워드 알림 — 한 사람에게 한 통, 걸린 단어를 한꺼번에 묶어서 */
async function alertMails(env, now, budget) {
  if (budget <= 0) return 0;
  const hourStamp = Number(now.toISOString().slice(0, 13).replace(/[-T]/g, ''));
  const { results } = await env.DB.prepare(`
    SELECT a.id AS alert_id, a.keyword, a.user_id, u.email,
           t.id AS trend_id, t.title, t.summary, t.url, t.source_name, t.region
    FROM alerts a
    JOIN users u ON u.id = a.user_id
    JOIN trends t ON t.kind = 'news' AND t.url IS NOT NULL
      AND t.collected_at > datetime('now','-2 days')
      AND (a.region = '' OR t.region = a.region)
      AND (lower(t.title) LIKE '%' || a.keyword || '%' OR lower(COALESCE(t.summary,'')) LIKE '%' || a.keyword || '%')
    WHERE u.email IS NOT NULL AND u.email_optout = 0 AND u.guest = 0
      AND NOT EXISTS (SELECT 1 FROM alert_sent s WHERE s.alert_id = a.id AND s.trend_id = t.id)
    ORDER BY a.user_id, t.collected_at DESC
    LIMIT 500`).all();
  if (!results.length) return 0;

  const byUser = new Map();
  for (const r of results) {
    if (!hits(r.title, r.keyword) && !hits(r.summary, r.keyword)) continue; // LIKE 가 흘린 것들
    const u = byUser.get(r.user_id) ?? { email: r.email, words: new Set(), rows: [], seen: new Set(), marks: [] };
    u.marks.push([r.alert_id, r.trend_id]);
    if (!u.seen.has(r.trend_id)) { u.seen.add(r.trend_id); u.rows.push(r); }
    u.words.add(r.keyword);
    byUser.set(r.user_id, u);
  }

  let sent = 0;
  for (const [userId, u] of byUser) {
    if (sent >= Math.min(ALERT_PER_RUN, budget)) break;
    const words = [...u.words];
    const shown = u.rows.slice(0, ALERT_MAX_STORIES);
    const rest = u.rows.length - shown.length;
    const unsub = `${SITE}/api/mail/unsubscribe?u=${userId}&t=${await unsubToken(env.RESEND_API_KEY, userId)}`;
    const html = shell(`
<p style="font-size:13px;color:#8b8289;margin:0">You're watching ${esc(words.map((w) => `"${w}"`).join(', '))}</p>
<h1 style="font-size:20px;margin:6px 0 16px">${u.rows.length === 1 ? 'One story came up' : `${u.rows.length} stories came up`}</h1>
${storyList(shown)}
${rest > 0 ? `<p style="font-size:13px;color:#8b8289">and ${rest} more</p>` : ''}
<p style="margin-top:18px"><a href="${SITE}/alerts" style="display:inline-block;background:#1B0C15;color:#fff;padding:10px 18px;border-radius:999px;text-decoration:none;font-weight:700">Edit what you watch</a></p>`, unsub);

    const subject = words.length === 1
      ? `${words[0]}: ${String(shown[0].title).slice(0, 60)}`
      : `${u.rows.length} stories on ${words.slice(0, 3).join(', ')}`;
    if (!(await send(env, u.email, subject, html))) continue;
    // 보낸 것만 아니라 이번에 걸린 전부를 표시한다 — 다음 시간에 같은 기사가 다시 오면 알림이 아니라 반복이다
    await env.DB.batch([
      ...u.marks.map(([a, t]) => env.DB.prepare(`INSERT OR IGNORE INTO alert_sent (alert_id, trend_id) VALUES (?, ?)`).bind(a, t)),
      // 하루 한도 계산에 알림 메일도 들어가야 한다 — 거래성 답변 메일이 한도에 밀려 안 나가면 그게 더 나쁘다
      env.DB.prepare(`INSERT OR IGNORE INTO mail_log (kind, ref_id, user_id) VALUES ('alert', ?, ?)`).bind(hourStamp, userId),
    ]);
    sent++;
  }
  return sent;
}

/** ④ 아침 브리핑 — 받는 사람 나라의 아침 7시에 한 통 */
async function briefMails(env, now, budget) {
  if (budget <= 0) return 0;
  const hour = now.getUTCHours();
  const regions = Object.entries(BRIEF_HOUR).filter(([, h]) => h === hour).map(([r]) => r);
  if (!regions.length) return 0;
  const stamp = Number(now.toISOString().slice(0, 10).replace(/-/g, ''));

  let sent = 0;
  for (const region of regions) {
    const { results: users } = await env.DB.prepare(`
      SELECT id, email FROM users
      WHERE email IS NOT NULL AND email_brief = 1 AND email_optout = 0 AND guest = 0
        AND COALESCE(brief_region, '') = ?
        AND NOT EXISTS (SELECT 1 FROM mail_log m WHERE m.kind = 'brief' AND m.ref_id = ? AND m.user_id = users.id)
      LIMIT ?`).bind(region, stamp, Math.max(0, Math.min(PER_RUN, budget - sent))).all();
    if (!users.length) continue;

    // 나라별 조건은 문장을 갈라 쓴다 — `(? = '' OR region = ?)` 로 묶으면 idx_trends_region 을 못 타고 전체를 읽는다
    const newsSql = `SELECT title, url, source_name, region FROM trends
       WHERE kind = 'news' AND url IS NOT NULL AND collected_at > datetime('now','-1 day')
         ${region ? 'AND region = ?' : ''}
       ORDER BY rank ASC, score DESC LIMIT 6`;
    const [{ results: news }, thread] = await Promise.all([
      region ? env.DB.prepare(newsSql).bind(region).all() : env.DB.prepare(newsSql).all(),
      env.DB.prepare(`
        SELECT p.id, p.title, COALESCE(r.handle, u.handle) AS author,
          (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id AND c.hidden = 0) AS replies
        FROM posts p LEFT JOIN residents r ON r.id = p.resident_id LEFT JOIN users u ON u.id = p.user_id
        WHERE p.hidden = 0 AND p.created_at > datetime('now','-1 day') AND p.created_at <= datetime('now')
        ORDER BY replies DESC, length(p.body) DESC LIMIT 1`).first(),
    ]);
    if (!news.length) continue;

    for (const u of users) {
      const unsub = `${SITE}/api/mail/unsubscribe?u=${u.id}&t=${await unsubToken(env.RESEND_API_KEY, u.id)}`;
      const html = shell(`
<p style="font-size:13px;color:#8b8289;margin:0">${esc(now.toUTCString().slice(0, 11))} · overnight</p>
<h1 style="font-size:20px;margin:6px 0 16px">What the press ran</h1>
${storyList(news)}
${thread ? `
<div style="margin-top:22px;padding:14px;background:#f6f3f4;border-radius:12px">
  <div style="font-size:12px;color:#8b8289">Being argued about on POZ</div>
  <a href="${SITE}/p/${thread.id}/${slug(thread.title)}" style="display:block;margin-top:4px;color:#1B0C15;font-weight:700;text-decoration:none">${esc(thread.title)}</a>
  <div style="font-size:12px;color:#8b8289;margin-top:3px">${esc(thread.author ?? 'a resident')} · ${thread.replies} replies</div>
</div>` : ''}
<p style="font-size:13px;color:#8b8289;margin-top:18px">Want a word watched instead? <a href="${SITE}/alerts" style="color:#7B526C">Set an alert</a>.</p>`, unsub);
      if (!(await send(env, u.email, `Morning brief — ${String(news[0].title).slice(0, 60)}`, html))) continue;
      await env.DB.prepare(`INSERT OR IGNORE INTO mail_log (kind, ref_id, user_id) VALUES ('brief', ?, ?)`).bind(stamp, u.id).run();
      sent++;
    }
  }
  return sent;
}

export async function runMailCron(env, now = new Date()) {
  if (!env.RESEND_API_KEY) return;
  try {
    // 답변 메일이 먼저다(사람이 기다리는 메일). 남은 하루 한도를 알림 → 브리핑 → 마케팅 순으로 나눠 쓴다.
    const a = await answerMails(env);
    const used = await env.DB.prepare(`SELECT COUNT(*) AS n FROM mail_log WHERE sent_at > datetime('now','-1 day')`)
      .first().then((r) => r?.n ?? 0);
    let left = Math.max(0, DAILY_CAP - used);
    const k = await alertMails(env, now, left);
    left -= k;
    const b = await briefMails(env, now, left);
    left -= b;
    const m = await marketingMails(env, now, left);
    if (a || m || k || b) console.log(`mail-cron: ${a} answer, ${k} alert, ${b} brief, ${m} marketing (cap ${used}/${DAILY_CAP})`);
  } catch (e) {
    console.error('mail-cron failed', e instanceof Error ? e.message : String(e));
  }
}
