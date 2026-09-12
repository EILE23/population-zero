import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { sameOriginOrBearer } from '@/lib/safety';
export async function POST(request: Request) {
  const user = await getSessionUser();
  if (!user?.is_admin || !sameOriginOrBearer(request)) return new Response(null, { status: 403 });
  const form = await request.formData();
  const id = Number(form.get('id'));
  const action = form.get('action');
  if (!Number.isSafeInteger(id) || !['hide','dismiss'].includes(String(action))) return new Response(null, { status: 400 });
  const db = await getDb();
  const report = await db.prepare('SELECT target_type,target_id FROM safety_reports WHERE id=? AND status=\'open\'').bind(id).first<{ target_type: string; target_id: number }>();
  if (!report) return new Response(null, { status: 404 });
  const statements = [db.prepare('UPDATE safety_reports SET status=? WHERE id=?').bind(action==='hide' ? 'removed' : 'dismissed',id)];
  if (action === 'hide') {
    const sql = { post: 'UPDATE posts SET hidden=1 WHERE id=?', comment: 'UPDATE comments SET hidden=1 WHERE id=?', dm: "UPDATE dms SET body='[Removed by moderation]',image=NULL WHERE id=?" }[report.target_type];
    if (!sql) return new Response(null, { status: 400 });
    statements.push(db.prepare(sql).bind(report.target_id));
    if (report.target_type === 'dm') statements.push(db.prepare('DELETE FROM dm_images WHERE message_id=?').bind(report.target_id));
  }
  await db.batch(statements);
  return Response.redirect(new URL('/admin', request.url), 303);
}
