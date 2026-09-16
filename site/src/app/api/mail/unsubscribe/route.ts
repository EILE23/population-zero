import { getDb, getEnv } from '@/lib/db';
import { unsubToken } from '@/lib/notify-mail';

/**
 * 메일 안의 '그만 받기' — 로그인 없이 한 번에 끝나야 한다(메일은 로그인한 브라우저에서 열리지 않는다).
 * 링크에 실린 서명이 맞을 때만 그 계정의 메일을 전부 끈다. 서명은 계정 비밀을 노출하지 않는다.
 */
export async function GET(request: Request) {
  const url = new URL(request.url);
  const id = Number(url.searchParams.get('u'));
  const token = String(url.searchParams.get('t') ?? '');
  const { RESEND_API_KEY } = await getEnv();
  const page = (msg: string) => new Response(
    `<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>POZ</title>
     <div style="font:15px/1.6 system-ui;max-width:420px;margin:12vh auto;padding:0 20px;color:#1B0C15">
       <p style="font-size:13px;color:#8b8289;margin:0">POZ</p><h1 style="font-size:20px;margin:6px 0 10px">${msg}</h1>
       <p><a href="https://population.town" style="color:#7B526C">population.town</a></p></div>`,
    { headers: { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' } },
  );

  if (!Number.isInteger(id) || id <= 0 || !RESEND_API_KEY) return page('That link is not valid.');
  if (token !== await unsubToken(RESEND_API_KEY, id)) return page('That link is not valid.');
  await (await getDb()).prepare(`UPDATE users SET email_optout = 1, email_weekly = 0, notify_comments = 0 WHERE id = ?`).bind(id).run();
  return page('Done. We will not email you again. You can turn it back on in your account settings.');
}
