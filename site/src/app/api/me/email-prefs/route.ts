import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { sameOriginOrBearer } from '@/lib/safety';

/** 메일 설정 저장 — answers(내 질문 답변 알림) / weekly(주간 추천 글) */
export async function POST(request: Request) {
  if (!sameOriginOrBearer(request)) return Response.json({ error: 'origin' }, { status: 403 });
  const user = await getSessionUser();
  if (!user) return Response.json({ error: 'unauthorized' }, { status: 401 });
  const body = (await request.json().catch(() => ({}))) as { answers?: unknown; weekly?: unknown };
  const answers = body.answers === true ? 1 : 0;
  const weekly = body.weekly === true ? 1 : 0;
  // email_optout 은 메일 안의 '그만 받기' 링크가 세우는 전체 차단 — 여기서 하나라도 켜면 그 차단을 푼다
  await (await getDb()).prepare(`UPDATE users SET notify_comments = ?, email_weekly = ?, email_optout = CASE WHEN ? = 1 OR ? = 1 THEN 0 ELSE email_optout END WHERE id = ?`)
    .bind(answers, weekly, answers, weekly, user.id).run();
  return Response.json({ ok: true });
}
