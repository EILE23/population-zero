import { redirect } from 'next/navigation';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { uploadImageToAssets } from '@/lib/assets';

const CONTROL_CHARS = new RegExp('[\\u0000-\\u0009\\u000b-\\u001f\\u007f]', 'g');
const TOPICS = ['tech','culture','entertainment','world','business','sports','science','gaming','food','career','life','ask','random','forum'];

// 본인 글 수정 — 글쓰기와 같은 폼(제목·본문·주제·썸네일). 게시 시각은 그대로, edited_at만 기록
export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const user = await getSessionUser();
  if (!user) redirect('/login');
  const { id } = await params;
  const postId = Number(id);

  const form = await request.formData();
  const title = String(form.get('title') || '').replace(CONTROL_CHARS, '').trim().slice(0, 140);
  const body = String(form.get('body') || '').replace(CONTROL_CHARS, '').trim().slice(0, 30000);
  if (title.length < 4 || body.length < 10) redirect(`/p/${postId}/edit`);
  const rawTopic = String(form.get('topic') || '');
  const topic = TOPICS.includes(rawTopic) ? rawTopic : null;

  // 썸네일: 새 파일 업로드 > 제거 플래그 > 기존 유지
  const coverFile = form.get('cover');
  const newCover = coverFile instanceof File && coverFile.size > 0 ? await uploadImageToAssets(coverFile, user.id, 'cover') : null;
  const removeCover = String(form.get('remove_cover') || '') === '1';
  const coverSql = newCover ? `, og_image = ?` : removeCover ? `, og_image = NULL` : '';

  const db = await getDb();
  const binds: (string | number)[] = [title, body];
  if (topic) binds.push(topic);
  if (newCover) binds.push(newCover);
  binds.push(postId, user.id);
  const { meta } = await db.prepare(
    `UPDATE posts SET title = ?, body = ?${topic ? ', topic = ?' : ''}${coverSql}, edited_at = datetime('now') WHERE id = ? AND user_id = ?`,
  ).bind(...binds).run();
  if (meta.changes === 0) redirect('/'); // 내 글이 아니면 조용히 홈으로
  redirect(`/p/${postId}`);
}
