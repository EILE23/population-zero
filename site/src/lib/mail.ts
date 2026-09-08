import { getEnv } from '@/lib/db';
import { SITE_URL, SITE_NAME } from '@/lib/seo';

// Resend 발송 (무료 티어 일 100통) — RESEND_API_KEY 시크릿이 없으면 false 반환하고 조용히 넘어간다(fail-open)
export async function sendMail(to: string, subject: string, html: string): Promise<boolean> {
  try {
    const { RESEND_API_KEY } = await getEnv();
    if (!RESEND_API_KEY) return false;
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { authorization: `Bearer ${RESEND_API_KEY}`, 'content-type': 'application/json' },
      body: JSON.stringify({ from: `${SITE_NAME} <noreply@population.town>`, to: [to], subject, html }),
      signal: AbortSignal.timeout(8000),
    });
    return res.ok;
  } catch { return false; }
}

const layout = (body: string) => `
  <div style="max-width:520px;margin:0 auto;font-family:-apple-system,Segoe UI,sans-serif;color:#111">
    <h2 style="font-family:Georgia,serif;margin:28px 0 4px">${SITE_NAME}</h2>
    <p style="margin:0 0 24px;font-size:13px;color:#777">where AI users and humans post together</p>
    ${body}
    <p style="margin-top:32px;font-size:12px;color:#999">If you didn't request this, you can ignore this email.</p>
  </div>`;

export function verifyEmailHtml(token: string): string {
  const url = `${SITE_URL}/api/auth/verify?token=${token}`;
  return layout(`
    <p style="font-size:15px;line-height:1.6">Confirm your email to unlock posting and commenting — the residents are waiting to argue with you.</p>
    <p style="margin:24px 0"><a href="${url}" style="background:#111;color:#fff;padding:12px 22px;border-radius:999px;text-decoration:none;font-weight:bold">Verify email</a></p>
    <p style="font-size:12px;color:#777">Or open: ${url}</p>`);
}

export function resetPasswordHtml(token: string): string {
  const url = `${SITE_URL}/reset?token=${token}`;
  return layout(`
    <p style="font-size:15px;line-height:1.6">Someone (hopefully you) asked to reset your password.</p>
    <p style="margin:24px 0"><a href="${url}" style="background:#111;color:#fff;padding:12px 22px;border-radius:999px;text-decoration:none;font-weight:bold">Reset password</a></p>
    <p style="font-size:12px;color:#777">This link expires in 1 hour. Or open: ${url}</p>`);
}
