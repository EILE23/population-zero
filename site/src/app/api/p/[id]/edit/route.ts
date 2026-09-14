import { redirect } from 'next/navigation';
import { purgePaths, postPaths } from '@/lib/cache';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { uploadImageToAssets } from '@/lib/assets';
import { rateLimited } from '@/lib/ratelimit';

const CONTROL_CHARS = new RegExp('[\\u0000-\\u0009\\u000b-\\u001f\\u007f]', 'g');
const TOPICS = ['tech','culture','entertainment','world','business','sports','science','gaming','food','career','life','ask','random','forum'];

// 본인 글 수정 — 글쓰기와 같은 폼(제목·본문·주제·썸네일). 게시 시각은 그대로, edited_at만 기록
export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const user = await getSessionUser();
  if (!user) redirect('/login');
  if (!user.email_verified) redirect('/me?error=unverified');
  const { id } = await params;
  const postId = Number(id);

  // 소유권을 먼저 확인한다 — 예전에는 업로드를 먼저 하고 UPDATE 의 user_id 조건으로 판정해서,
  // 남의 글 ID 로 요청하면 수정은 막혀도 이미지가 자산 저장소에 남았다.
  const db = await getDb();
  // 옛 제목은 퍼지에 필요하다 — 제목이 바뀌면 옛 슬러그 주소에 옛 글이 남는다
  const owned = await db.prepare(`SELECT title FROM posts WHERE id = ? AND user_id = ?`).bind(postId, user.id).first<{ title: string }>();
  if (!owned) redirect('/');

  const form = await request.formData();
  const title = String(form.get('title') || '').replace(CONTROL_CHARS, '').trim().slice(0, 140);
  const body = String(form.get('body') || '').replace(CONTROL_CHARS, '').trim().slice(0, 30000);
  if (title.length < 4 || body.length < 10) redirect(`/p/${postId}/edit`);
  const rawTopic = String(form.get('topic') || '');
  const topic = TOPICS.includes(rawTopic) ? rawTopic : null;

  // 썸네일: 새 파일 업로드 > 제거 플래그 > 기존 유지
  const coverFile = form.get('cover');
  const hasNewCover = coverFile instanceof File && coverFile.size > 0;
  // 업로드는 글쓰기와 같은 한도를 쓴다 — 수정 경로만 quota 밖에 있으면 그쪽으로 우회된다
  if (hasNewCover && await rateLimited(request, 'upload', 20, 10, true)) redirect(`/p/${postId}/edit?error=rate`);
  const newCover = hasNewCover ? await uploadImageToAssets(coverFile, user.id, 'cover') : null;
  const removeCover = String(form.get('remove_cover') || '') === '1';
  const coverSql = newCover ? `, og_image = ?` : removeCover ? `, og_image = NULL` : '';

  // 연재명은 비우면 해제된다 — 폼에 항상 실려 오므로 '없음'과 '지움'을 구분할 필요가 없다
  const series = String(form.get('series') || '').replace(CONTROL_CHARS, '').trim().slice(0, 60) || null;

  const binds: (string | number | null)[] = [title, body, series];
  if (topic) binds.push(topic);
  if (newCover) binds.push(newCover);
  binds.push(postId, user.id);
  const { meta } = await db.prepare(
    `UPDATE posts SET title = ?, body = ?, series = ?${topic ? ', topic = ?' : ''}${coverSql}, edited_at = datetime('now') WHERE id = ? AND user_id = ?`,
  ).bind(...binds).run();
  if (meta.changes === 0) redirect('/'); // 내 글이 아니면 조용히 홈으로
  await purgePaths(postPaths(postId, user.handle, [owned.title, title]));
  redirect(`/p/${postId}`);
}
