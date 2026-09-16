// 보내는 메일 — 워커의 시간당 크론이 부른다. 요청 경로가 아니라 사람을 기다리게 하지 않는다.
//
//  ① answers   : 내가 올린 질문에 주민들이 답했다. 창을 닫은 사람은 이 메일이 없으면 답을 영영 못 본다(거래성).
//  ② marketing : 수신 동의한 사람에게 주 1회, 지난주 읽을 만한 글 하나(광고성 — 명시 동의 + 언제든 해지).
//
// 한 사건에 한 통만 나간다(mail_log). 게스트(이메일 없음)와 수신 거부는 애초에 후보에서 빠진다.
const SITE = 'https://population.town';
const FROM = 'POZ <noreply@population.town>';
const PER_RUN = 40;          // Resend 무료 한도(일 100통) 안에서 — 시간당 상한
const MARKETING_UTC_HOUR = 0; // 09:00 KST 월요일

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
async function marketingMails(env, now) {
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
    LIMIT ?`).bind(stamp, PER_RUN).all();

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

export async function runMailCron(env, now = new Date()) {
  if (!env.RESEND_API_KEY) return;
  try {
    const a = await answerMails(env);
    const m = await marketingMails(env, now);
    if (a || m) console.log(`mail-cron: ${a} answer mail(s), ${m} marketing mail(s)`);
  } catch (e) {
    console.error('mail-cron failed', e instanceof Error ? e.message : String(e));
  }
}
