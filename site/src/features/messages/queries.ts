import { getDb } from '@/lib/db';
import { otherParty, threadParties } from '@/lib/dm';
import type { SessionUser } from '@/types/db';

export interface ThreadSummary {
  thread: string;
  preview: string;
  created_at: string;
  unread: number;
  other: { kind: 'user' | 'resident'; id: number; handle: string; avatar: string | null };
}

export interface ThreadMessage {
  id: number;
  body: string;
  image: string | null;
  created_at: string;
  mine: boolean;
  read: boolean;
}

type ThreadRow = ThreadSummary['other'] & {
  thread: string;
  body: string;
  created_at: string;
  unread: number;
  other_handle: string;
  other_kind: 'user' | 'resident';
  other_id: number;
  other_avatar: string | null;
};

/**
 * 내 쪽지함 — 대화마다 마지막 한 줄.
 * 앱의 채팅 목록과 같은 데이터다: 웹은 읽는 곳이라 목록으로, 앱은 말을 거는 곳이라 말풍선으로 그린다.
 */
export async function fetchThreads(user: SessionUser): Promise<ThreadSummary[]> {
  const db = await getDb();
  const { results } = await db.prepare(`
    WITH mine AS (SELECT * FROM dms WHERE from_user_id = ?1 OR to_user_id = ?1),
    last AS (SELECT thread, MAX(id) AS last_id FROM mine GROUP BY thread)
    SELECT m.thread, m.body, m.created_at,
      (SELECT COUNT(*) FROM mine x WHERE x.thread = m.thread AND x.to_user_id = ?1 AND x.read_at IS NULL) AS unread,
      COALESCE(ru.handle, rr.handle, 'someone') AS other_handle,
      CASE WHEN ru.id IS NOT NULL THEN 'user' ELSE 'resident' END AS other_kind,
      COALESCE(ru.id, rr.id, 0) AS other_id,
      ru.avatar_url AS other_avatar
    FROM last l
    JOIN mine m ON m.id = l.last_id
    LEFT JOIN users ru ON ru.id = CASE WHEN m.from_user_id = ?1 THEN m.to_user_id ELSE m.from_user_id END
    LEFT JOIN residents rr ON rr.id = CASE WHEN m.from_user_id = ?1 THEN m.to_resident_id ELSE m.from_resident_id END
    ORDER BY l.last_id DESC LIMIT 50`).bind(user.id).all<ThreadRow>();

  return results.map((t) => ({
    thread: t.thread,
    preview: t.body.slice(0, 160),
    created_at: t.created_at,
    unread: t.unread,
    other: { kind: t.other_kind, id: t.other_id, handle: t.other_handle, avatar: t.other_avatar },
  }));
}

export interface ThreadView {
  thread: string;
  other: ThreadSummary['other'] | null;
  /** 사람과의 대화만 실시간이다 — 주민은 순찰 때 답한다 */
  live: boolean;
  messages: ThreadMessage[];
}

/** 대화 한 줄기 + 연 순간 읽음 처리 */
export async function fetchThread(user: SessionUser, thread: string): Promise<ThreadView | null> {
  // 열쇠를 찍어 맞혀도 남의 대화는 열리지 않는다
  if (!threadParties(thread).some((p) => p.kind === 'user' && p.id === user.id)) return null;

  const db = await getDb();
  const { results } = await db.prepare(
    `SELECT id, body, image, created_at, read_at, from_user_id FROM dms WHERE thread = ? ORDER BY id LIMIT 300`,
  ).bind(thread).all<{ id: number; body: string; image: string | null; created_at: string; read_at: string | null; from_user_id: number | null }>();

  if (results.some((m) => m.from_user_id !== user.id && !m.read_at)) {
    await db.prepare(
      `UPDATE dms SET read_at = datetime('now') WHERE thread = ? AND to_user_id = ? AND read_at IS NULL`,
    ).bind(thread, user.id).run();
  }

  // 상대가 주민이면 아바타가 없다 — 두 조회의 결과 모양이 달라 한 자리에서 맞춰 둔다
  const party = otherParty(thread, { kind: 'user', id: user.id });
  const who: { handle: string; avatar: string | null } | null = !party
    ? null
    : party.kind === 'resident'
      ? await db.prepare(`SELECT handle, NULL AS avatar FROM residents WHERE id = ?`).bind(party.id)
          .first<{ handle: string; avatar: string | null }>()
      : await db.prepare(`SELECT handle, avatar_url AS avatar FROM users WHERE id = ?`).bind(party.id)
          .first<{ handle: string; avatar: string | null }>();

  return {
    thread,
    other: party && who
      ? { kind: party.kind, id: party.id, handle: who.handle, avatar: who.avatar }
      : null,
    live: party?.kind === 'user',
    messages: results.map((m) => ({
      id: m.id,
      body: m.body,
      image: m.image,
      created_at: m.created_at,
      mine: m.from_user_id === user.id,
      read: m.read_at != null,
    })),
  };
}
