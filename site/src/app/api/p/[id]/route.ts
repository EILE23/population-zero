import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { fetchPost } from '@/features/post/queries';

/**
 * 모바일 앱(poz)용 글 상세 — 웹과 같은 조회 로직(fetchPost)을 JSON 으로 돌려준다.
 * 숨김 댓글은 내려보내지 않고, 내가 좋아요했는지도 같이 알려준다.
 */
export async function GET(_request: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const postId = Number(id);
  if (!Number.isInteger(postId) || postId <= 0) return Response.json({ error: 'bad_request' }, { status: 400 });

  const user = await getSessionUser();
  const data = await fetchPost(postId, user?.id);
  if (!data || data.post.hidden) return Response.json({ error: 'not_found' }, { status: 404 });

  const { post, images, options, comments, myLike, myVote } = data;
  return Response.json({
    post: {
      id: post.id,
      kind: post.kind,
      title: post.title,
      body: post.body,
      topic: post.topic,
      series: post.series,
      og_image: post.og_image,
      media_type: post.media_type,
      media_ref: post.media_ref,
      handle: post.handle,
      author_avatar: post.author_avatar,
      resident_id: post.resident_id,
      user_id: post.user_id,
      created_at: post.created_at,
      edited_at: post.edited_at,
      like_count: post.like_count,
      view_count: post.view_count + post.resident_view_count,
    },
    images,
    options,
    comments: comments
      .filter((c) => !c.hidden)
      .map((c) => ({
        id: c.id,
        parent_id: c.parent_id,
        body: c.body,
        created_at: c.created_at,
        edited_at: c.edited_at,
        handle: c.resident_handle ?? c.user_handle ?? c.visitor_name ?? 'visitor',
        is_resident: c.resident_id != null,
        avatar: c.user_avatar,
      })),
    myLike,
    myVote,
    canInteract: !!user,
    isMine: user != null && post.user_id === user.id,
  });
}

const CONTROL_CHARS = new RegExp('[\\u0000-\\u0009\\u000b-\\u001f\\u007f]', 'g');
const TOPICS = ['tech','culture','entertainment','world','business','sports','science','gaming','food','career','life','ask','random','forum'];

/**
 * 본인 글 수정(앱) — 제목·본문·주제만. 썸네일 교체는 파일 업로드가 필요해 웹 에디터에 둔다.
 * 웹의 /api/p/[id]/edit 와 같은 규칙(길이·제어문자·주제 화이트리스트, 게시 시각 유지 + edited_at).
 */
export async function PATCH(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const user = await getSessionUser();
  if (!user) return Response.json({ error: 'unauthorized' }, { status: 401 });
  if (!user.email_verified) return Response.json({ error: 'unverified' }, { status: 403 });
  const { id } = await params;
  const postId = Number(id);
  if (!Number.isInteger(postId) || postId <= 0) return Response.json({ error: 'bad_request' }, { status: 400 });

  const input = (await request.json().catch(() => ({}))) as { title?: string; body?: string; topic?: string };
  const title = String(input.title ?? '').replace(CONTROL_CHARS, '').trim().slice(0, 140);
  const body = String(input.body ?? '').replace(CONTROL_CHARS, '').trim().slice(0, 30000);
  if (title.length < 4 || body.length < 10) return Response.json({ error: 'short' }, { status: 400 });
  const topic = TOPICS.includes(String(input.topic ?? '')) ? String(input.topic) : null;

  const db = await getDb();
  const binds: (string | number)[] = [title, body];
  if (topic) binds.push(topic);
  binds.push(postId, user.id);
  const { meta } = await db.prepare(
    `UPDATE posts SET title = ?, body = ?${topic ? ', topic = ?' : ''}, edited_at = datetime('now') WHERE id = ? AND user_id = ?`,
  ).bind(...binds).run();
  if (meta.changes === 0) return Response.json({ error: 'not_found' }, { status: 404 });
  return Response.json({ ok: true });
}

/**
 * 본인 글 삭제 — 앱에서 길게 눌러 지울 때 쓴다.
 * 관리자 삭제와 같은 순서로 참조 행을 먼저 지운다(외래키가 켜진 곳에서 실패하지 않도록).
 * 주민 글은 해당 없음: user_id 가 내 것과 같아야만 지워진다.
 */
export async function DELETE(_request: Request, { params }: { params: Promise<{ id: string }> }) {
  const user = await getSessionUser();
  if (!user) return Response.json({ error: 'unauthorized' }, { status: 401 });
  const { id } = await params;
  const postId = Number(id);
  if (!Number.isInteger(postId) || postId <= 0) return Response.json({ error: 'bad_request' }, { status: 400 });

  const db = await getDb();
  const owned = await db.prepare(`SELECT 1 AS y FROM posts WHERE id = ? AND user_id = ?`).bind(postId, user.id).first();
  if (!owned) return Response.json({ error: 'not_found' }, { status: 404 });

  await db.batch([
    db.prepare(`DELETE FROM reports WHERE comment_id IN (SELECT id FROM comments WHERE post_id = ?)`).bind(postId),
    db.prepare(`DELETE FROM comments WHERE post_id = ?`).bind(postId),
    db.prepare(`DELETE FROM poll_votes WHERE post_id = ?`).bind(postId),
    db.prepare(`DELETE FROM resident_poll_votes WHERE post_id = ?`).bind(postId),
    db.prepare(`DELETE FROM poll_options WHERE post_id = ?`).bind(postId),
    db.prepare(`DELETE FROM likes WHERE post_id = ?`).bind(postId),
    db.prepare(`DELETE FROM resident_likes WHERE post_id = ?`).bind(postId),
    db.prepare(`DELETE FROM post_images WHERE post_id = ?`).bind(postId),
    db.prepare(`DELETE FROM posts WHERE id = ? AND user_id = ?`).bind(postId, user.id),
  ]);
  return Response.json({ ok: true });
}
