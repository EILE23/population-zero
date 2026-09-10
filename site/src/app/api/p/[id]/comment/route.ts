import { redirect } from 'next/navigation';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { rateLimited } from '@/lib/ratelimit';

const CONTROL_CHARS = new RegExp('[\\u0000-\\u0009\\u000b-\\u001f\\u007f]', 'g');

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  if (await rateLimited(request, 'comment', 10, 5)) redirect('/');
  const { id } = await params;
  const user = await getSessionUser();
  if (!user) redirect('/login');
  if (!user.email_verified) redirect('/me?error=unverified'); // 이메일 인증 전에는 글·댓글 불가

  const form = await request.formData();
  const body = String(form.get('body') || '').replace(CONTROL_CHARS, '').trim().slice(0, 1000);
  if (body) {
    const db = await getDb();
    // 대댓글: 부모가 같은 글의 댓글인지 검증, 1단계로 고정(대댓글의 대댓글은 같은 스레드에 붙임)
    let parentId: number | null = null;
    const rawParent = Number(form.get('parent_id'));
    if (Number.isInteger(rawParent) && rawParent > 0) {
      const parent = await db.prepare(`SELECT id, parent_id FROM comments WHERE id = ? AND post_id = ?`)
        .bind(rawParent, Number(id)).first<{ id: number; parent_id: number | null }>();
      if (parent) parentId = parent.parent_id ?? parent.id;
    }
    // 중복 제출 방지 — 모바일에서 버튼이 두 번 먹거나 브라우저가 재전송하면 같은 댓글이 두 개 달린다.
    // 같은 사람이 같은 글에 같은 내용을 1분 안에 다시 보내면 조용히 무시한다(사용자에겐 정상 완료로 보인다).
    const dup = await db.prepare(
      `SELECT 1 AS y FROM comments WHERE post_id = ? AND user_id = ? AND body = ? AND created_at > datetime('now','-1 minutes') LIMIT 1`,
    ).bind(Number(id), user.id, body).first();
    if (!dup) {
      await db.prepare(`INSERT INTO comments (post_id, user_id, body, parent_id) VALUES (?, ?, ?, ?)`)
        .bind(Number(id), user.id, body, parentId).run();
    }
  }
  redirect(`/p/${Number(id)}`);
}
