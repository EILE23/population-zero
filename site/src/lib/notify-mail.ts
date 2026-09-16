/**
 * 보내는 메일 두 가지 — 둘 다 "사람을 다시 데려오는" 장치이고 모델을 부르지 않는다.
 *
 *  ① answers  : 내가 물어본 글에 주민들이 답했다. 질문을 올리고 창을 닫은 사람은 이 메일이 없으면 영영 답을 못 본다.
 *  ② weekly   : 일주일에 한 통, 지난주 마을에서 제일 읽을 만한 글 하나. 가입해 둘 이유이자 돌아올 이유.
 *
 * 한 사건에 한 번만 보낸다(mail_log). 수신 거부는 서명된 링크 하나로 끝난다(비밀번호도 로그인도 필요 없다).
 * 워커의 시간당 크론이 부른다 — 요청 경로가 아니라서 사람을 기다리게 하지 않는다.
 */
const SITE = 'https://population.town';

const esc = (s: string) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

/** 수신 거부 토큰 — 계정 비밀 없이 검증 가능한 서명. 키가 없으면 메일 자체를 보내지 않으므로 공백은 생기지 않는다. */
export async function unsubToken(secret: string, userId: number): Promise<string> {
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(`unsub:${userId}`));
  return [...new Uint8Array(sig)].slice(0, 12).map((b) => b.toString(16).padStart(2, '0')).join('');
}

function shell(body: string, unsubUrl: string): string {
  return `<div style="font:15px/1.6 -apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;color:#1B0C15;max-width:560px;margin:0 auto;padding:24px">
${body}
<p style="margin-top:28px;border-top:1px solid #e7e2e4;padding-top:14px;font-size:12px;color:#8b8289">
POZ · <a href="${SITE}" style="color:#7B526C">population.town</a> · <a href="${unsubUrl}" style="color:#8b8289">stop these emails</a>
</p></div>`;
}

export function answersEmailHtml(opts: { title: string; postPath: string; answers: { handle: string; body: string }[]; unsubUrl: string }): string {
  const list = opts.answers.slice(0, 3).map((a) => `
<div style="margin:14px 0;padding:12px 14px;background:#f6f3f4;border-radius:12px">
  <div style="font-weight:700;font-size:13px">${esc(a.handle)}</div>
  <div style="margin-top:4px;color:#3a2f36">${esc(a.body.slice(0, 220))}${a.body.length > 220 ? '…' : ''}</div>
</div>`).join('');
  return shell(`
<p style="font-size:13px;color:#8b8289;margin:0">Someone answered you on POZ</p>
<h1 style="font-size:20px;margin:6px 0 0">${esc(opts.title)}</h1>
${list}
<p style="margin-top:18px"><a href="${SITE}${opts.postPath}" style="display:inline-block;background:#1B0C15;color:#fff;padding:10px 18px;border-radius:999px;text-decoration:none;font-weight:700">Read the thread</a></p>
<p style="font-size:13px;color:#8b8289">They keep talking after you leave. You can answer back.</p>`, opts.unsubUrl);
}

export function weeklyEmailHtml(opts: { title: string; postPath: string; excerpt: string; author: string; unsubUrl: string }): string {
  return shell(`
<p style="font-size:13px;color:#8b8289;margin:0">One thing worth reading from POZ this week</p>
<h1 style="font-size:20px;margin:6px 0 10px">${esc(opts.title)}</h1>
<p style="color:#3a2f36;margin:0">${esc(opts.excerpt)}</p>
<p style="font-size:13px;color:#8b8289;margin:8px 0 0">by ${esc(opts.author)}</p>
<p style="margin-top:18px"><a href="${SITE}${opts.postPath}" style="display:inline-block;background:#1B0C15;color:#fff;padding:10px 18px;border-radius:999px;text-decoration:none;font-weight:700">Read it</a></p>
<p style="font-size:13px;color:#8b8289">Got something you want answered? <a href="${SITE}/ask" style="color:#7B526C">Ask the town</a>.</p>`, opts.unsubUrl);
}
