import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';

const CONTROL_CHARS = new RegExp('[\\u0000-\\u0009\\u000b-\\u001f\\u007f]', 'g');

type Counts = {
  posts: number; comments: number; likes_received: number;
  followers: number; following: number; albums: number;
};

/**
 * 앱 Me 화면 — 웹 프로필(/me)이 보여주는 것들을 한 번에 JSON 으로.
 * 글·댓글·좋아요한 글·팔로워·팔로잉·블로그 이름·알림 설정까지 같은 자리에 있어야
 * 앱에서도 웹과 같은 계정이라는 게 드러난다.
 */
export async function GET() {
  const user = await getSessionUser();
  if (!user) return Response.json({ error: 'unauthorized' }, { status: 401 });

  const db = await getDb();
  const [counts, prefs, comments, follows] = await Promise.all([
    db.prepare(`SELECT
        (SELECT COUNT(*) FROM posts WHERE user_id = ?1) AS posts,
        (SELECT COUNT(*) FROM comments WHERE user_id = ?1 AND hidden = 0) AS comments,
        (SELECT COUNT(*) FROM likes l JOIN posts p ON p.id = l.post_id WHERE p.user_id = ?1)
          + (SELECT COUNT(*) FROM resident_likes rl JOIN posts p ON p.id = rl.post_id WHERE p.user_id = ?1 AND rl.created_at <= datetime('now')) AS likes_received,
        (SELECT COUNT(*) FROM follows WHERE target_type = 'user' AND target_id = ?1) AS followers,
        (SELECT COUNT(*) FROM follows WHERE follower_type = 'user' AND follower_id = ?1) AS following,
        (SELECT COUNT(DISTINCT pi.post_id) FROM post_images pi JOIN posts p ON p.id = pi.post_id WHERE p.user_id = ?1) AS albums`)
      .bind(user.id).first<Counts>(),
    db.prepare(`SELECT notify_comments, notify_likes, notify_follows FROM users WHERE id = ?`).bind(user.id)
      .first<{ notify_comments: number; notify_likes: number; notify_follows: number }>(),
    db.prepare(`SELECT c.id, c.body, c.created_at, c.post_id, p.title
                FROM comments c JOIN posts p ON p.id = c.post_id
                WHERE c.user_id = ? AND c.hidden = 0 ORDER BY c.created_at DESC LIMIT 20`)
      .bind(user.id).all<{ id: number; body: string; created_at: string; post_id: number; title: string }>(),
    // 내가 팔로우한 주민·사람 (앱에서 바로 그 사람 글로 갈 수 있게 핸들까지)
    db.prepare(`SELECT f.target_type, f.target_id, COALESCE(r.handle, u.handle) AS handle, u.avatar_url AS avatar
                FROM follows f
                LEFT JOIN residents r ON f.target_type = 'resident' AND r.id = f.target_id
                LEFT JOIN users u ON f.target_type = 'user' AND u.id = f.target_id
                WHERE f.follower_type = 'user' AND f.follower_id = ?
                ORDER BY f.created_at DESC LIMIT 50`)
      .bind(user.id).all<{ target_type: string; target_id: number; handle: string | null; avatar: string | null }>(),
  ]);

  return Response.json({
    user: {
      id: user.id,
      handle: user.handle,
      email: user.email,
      avatar_url: user.avatar_url,
      email_verified: !!user.email_verified,
      bio: user.bio ?? '',
      blog_title: user.blog_title ?? null,
    },
    counts: counts ?? { posts: 0, comments: 0, likes_received: 0, followers: 0, following: 0, albums: 0 },
    notify: {
      comments: !!(prefs?.notify_comments ?? 1),
      likes: !!(prefs?.notify_likes ?? 1),
      follows: !!(prefs?.notify_follows ?? 1),
    },
    comments: comments.results,
    following: follows.results.filter((f) => f.handle),
  });
}

/** 프로필·알림 설정 고치기 — 앱에서 폼 제출 없이 바로 반영한다 */
export async function PATCH(request: Request) {
  const user = await getSessionUser();
  if (!user) return Response.json({ error: 'unauthorized' }, { status: 401 });

  const input = (await request.json().catch(() => ({}))) as {
    bio?: string; blog_title?: string;
    notify?: { comments?: boolean; likes?: boolean; follows?: boolean };
  };

  const sets: string[] = [];
  const binds: (string | number | null)[] = [];
  if (typeof input.bio === 'string') {
    sets.push('bio = ?');
    binds.push(input.bio.replace(CONTROL_CHARS, '').trim().slice(0, 300));
  }
  if (typeof input.blog_title === 'string') {
    const t = input.blog_title.replace(CONTROL_CHARS, '').trim().slice(0, 60);
    sets.push('blog_title = ?');
    binds.push(t || null);
  }
  for (const [key, col] of [['comments', 'notify_comments'], ['likes', 'notify_likes'], ['follows', 'notify_follows']] as const) {
    const v = input.notify?.[key];
    if (typeof v === 'boolean') { sets.push(`${col} = ?`); binds.push(v ? 1 : 0); }
  }
  if (!sets.length) return Response.json({ error: 'nothing_to_update' }, { status: 400 });

  const db = await getDb();
  await db.prepare(`UPDATE users SET ${sets.join(', ')} WHERE id = ?`).bind(...binds, user.id).run();
  return Response.json({ ok: true });
}
