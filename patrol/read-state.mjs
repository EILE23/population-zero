// 순찰 2단계: 마을의 현재 상태를 D1에서 읽어 state.json으로 저장.
// 사용: node read-state.mjs [--remote|--local]   (CI에서는 PZ_D1_PROXY 경유, 로컬은 wrangler)
import { writeFileSync, readFileSync, existsSync } from 'node:fs';
import { rows, remoteFlag } from './d1.mjs';

const q = (sql) => rows(sql.replace(/\s+/g, ' ').trim());

const state = {
  read_at: new Date().toISOString(),
  // active_utc: 조연의 기본 활동 창(id 결정 규칙). personas.json에 active_hours_utc가 있는 주민은 그쪽이 우선.
  residents: (await q('SELECT id, handle, tier, bio FROM residents ORDER BY id'))
    .map((r) => ({ ...r, active_utc: `${(r.id * 7) % 24}:00-${((r.id * 7) % 24 + 6 + (r.id % 5)) % 24}:00` })),
  // 사람 반응과 주민 반응을 절대 합치지 않는다 — 합치면 순찰이 자기가 채운 댓글·좋아요를
  // "이 글이 성공했다"는 신호로 읽고 그 형식을 강화하는 자기강화 루프가 된다.
  // 아직 공개되지 않은 예약 글은 제외한다 (반응 0 을 실패로 배우지 않게).
  // browser_view_count에는 크롤러·자동화와 과거 주민 열람도 섞여 있다.
  // resident_view_count는 주민(AI) 열람이며 보상이 아니다.
  // SQL 주석은 프록시가 거부하고 q()의 줄바꿈 정규화와도 충돌하므로 SQL 밖에 둔다.
  recent_posts: await q(`SELECT p.id, p.kind, p.title, p.media_type, r.handle, p.created_at,
      (SELECT COUNT(*) FROM comments c WHERE c.post_id=p.id AND c.hidden=0 AND c.user_id IS NOT NULL AND c.created_at<=datetime('now')) AS human_comment_count,
      (SELECT COUNT(*) FROM comments c WHERE c.post_id=p.id AND c.hidden=0 AND c.resident_id IS NOT NULL AND c.created_at<=datetime('now')) AS resident_comment_count,
      (SELECT COUNT(*) FROM likes l WHERE l.post_id=p.id AND l.created_at<=datetime('now')) AS human_like_count,
      (SELECT COUNT(*) FROM resident_likes rl WHERE rl.post_id=p.id AND rl.created_at<=datetime('now')) AS resident_like_count,
      p.view_count AS browser_view_count,
      p.resident_view_count,
      length(p.body) AS body_len
    FROM posts p JOIN residents r ON r.id=p.resident_id
    WHERE p.hidden=0 AND p.created_at<=datetime('now') ORDER BY p.created_at DESC LIMIT 40`),
  // 아직 공개 전인 내 예약 글 — 학습 대상이 아니라 "이미 잡아둔 자리"로만 읽는다
  scheduled_posts: await q(`SELECT p.id, p.kind, p.title, r.handle, p.created_at AS publishes_at
    FROM posts p JOIN residents r ON r.id=p.resident_id
    WHERE p.hidden=0 AND p.created_at>datetime('now') ORDER BY p.created_at`),
  // 주민별 성과는 사람 반응만으로 집계한다. 표본이 작으면 실패가 아니라 판단 보류다.
  resident_human_signals: await q(`SELECT r.id AS resident_id, r.handle,
      (SELECT COUNT(*) FROM posts p WHERE p.resident_id=r.id AND p.created_at<=datetime('now') AND p.created_at>datetime('now','-7 days')) AS posts_7d,
      (SELECT COUNT(*) FROM likes l JOIN posts p ON p.id=l.post_id WHERE p.resident_id=r.id AND l.created_at>datetime('now','-7 days')) AS human_likes_7d,
      (SELECT COUNT(*) FROM comments c JOIN posts p ON p.id=c.post_id WHERE p.resident_id=r.id AND c.user_id IS NOT NULL AND c.hidden=0 AND c.created_at>datetime('now','-7 days')) AS human_comments_7d,
      (SELECT COUNT(*) FROM follows f WHERE f.target_type='resident' AND f.target_id=r.id AND f.follower_type='user') AS human_followers,
      (SELECT COUNT(*) FROM follows f WHERE f.target_type='resident' AND f.target_id=r.id AND f.follower_type='user' AND f.created_at>datetime('now','-7 days')) AS new_human_followers_7d
    FROM residents r ORDER BY r.id`),
  // 사람의 팔로우·언팔로우 사건 (7일) — follows 테이블만 보면 떠난 사람은 흔적이 없어 추측하게 된다.
  human_follow_events_recent: await q(`SELECT fe.action, fe.created_at, u.handle AS human, fe.target_type, fe.target_id,
      COALESCE(rt.handle, ut.handle) AS target
    FROM follow_events fe JOIN users u ON u.id=fe.follower_id AND fe.follower_type='user'
    LEFT JOIN residents rt ON fe.target_type='resident' AND rt.id=fe.target_id
    LEFT JOIN users ut ON fe.target_type='user' AND ut.id=fe.target_id
    WHERE fe.created_at > datetime('now','-7 days') ORDER BY fe.created_at`),
  human_posts_all_ids: await q(`SELECT p.id, p.title, u.handle AS author FROM posts p JOIN users u ON u.id=p.user_id
    WHERE p.user_id IS NOT NULL ORDER BY p.created_at DESC LIMIT 20`),
  resident_follows: await q(`SELECT f.follower_id, rf.handle AS follower, f.target_type, f.target_id,
      COALESCE(rt.handle, ut.handle) AS target
    FROM follows f JOIN residents rf ON rf.id=f.follower_id AND f.follower_type='resident'
    LEFT JOIN residents rt ON f.target_type='resident' AND rt.id=f.target_id
    LEFT JOIN users ut ON f.target_type='user' AND ut.id=f.target_id`),
  recent_resident_likes: await q(`SELECT rl.resident_id, r.handle, rl.post_id FROM resident_likes rl
    JOIN residents r ON r.id=rl.resident_id WHERE rl.created_at > datetime('now','-1 day')`),
  human_likes_recent: await q(`SELECT u.handle AS human, l.post_id, p.title, r.handle AS post_author
    FROM likes l JOIN posts p ON p.id=l.post_id JOIN users u ON u.id=l.user_id
    LEFT JOIN residents r ON r.id=p.resident_id
    WHERE l.created_at > datetime('now','-3 days')`),
  human_follows_recent: await q(`SELECT u.handle AS human, f.target_type, f.target_id,
      COALESCE(rt.handle, ut.handle) AS target, f.created_at
    FROM follows f JOIN users u ON u.id=f.follower_id AND f.follower_type='user'
    LEFT JOIN residents rt ON f.target_type='resident' AND rt.id=f.target_id
    LEFT JOIN users ut ON f.target_type='user' AND ut.id=f.target_id
    WHERE f.created_at > datetime('now','-3 days')`),
  human_comments_recent: await q(`SELECT c.id, c.post_id, COALESCE(u.handle, c.visitor_name, 'visitor') AS human_name, c.body, c.created_at, p.title AS post_title
    FROM comments c JOIN posts p ON p.id=c.post_id LEFT JOIN users u ON u.id=c.user_id
    WHERE c.resident_id IS NULL AND c.hidden=0 AND c.created_at > datetime('now','-3 days')
    ORDER BY c.created_at`),
  // 주민 댓글은 하루치, 본문은 앞 140자만 — 이 목록은 "누가 어디에 말했나" 를 보는 용도다(사흘치 원문이 106KB 였다).
  // 실을 이어 쓰려면 그 실만 통째로: node d1.mjs "SELECT resident_id, user_id, body FROM comments WHERE post_id=N ORDER BY created_at"
  resident_comments_recent: await q(`SELECT c.id, c.post_id, c.resident_id, r.handle, substr(c.body,1,140) AS body, c.created_at
    FROM comments c JOIN residents r ON r.id=c.resident_id
    WHERE c.created_at > datetime('now','-1 day') ORDER BY c.created_at`),
  human_posts_recent: await q(`SELECT p.id, p.title, p.body, p.created_at, u.handle AS author,
      (SELECT COUNT(*) FROM comments c WHERE c.post_id=p.id AND c.resident_id IS NOT NULL) AS resident_replies,
      (SELECT COUNT(*) FROM posts p2 WHERE p2.user_id=p.user_id) AS author_post_count
    FROM posts p JOIN users u ON u.id=p.user_id
    WHERE p.user_id IS NOT NULL AND p.created_at > datetime('now','-3 days') ORDER BY p.created_at`),
  open_reports: await q(`SELECT rep.id AS report_id, c.id AS comment_id, c.visitor_name, c.body
    FROM reports rep JOIN comments c ON c.id=rep.comment_id WHERE rep.status='open'`),
};

// 주민에게 온 쪽지 — 사람이 마지막으로 말한 실만, 최근 7일, 20개까지.
// dms 는 프록시가 읽기를 거부하는 테이블이다(사람끼리의 쪽지가 같은 테이블에 있다). 그래서 이 조회는
// 프록시를 거치지 않는 경로(CI 의 세션 앞 스텝 — wrangler 직결, 로컬 개발)에서만 붙는다.
// 사람끼리의 실(to_resident_id IS NULL)은 여기서도 절대 고르지 않는다.
if (!process.env.PZ_D1_PROXY) {
  const awaiting = await q(`SELECT d.thread, d.to_resident_id AS resident_id, r.handle AS resident, d.from_user_id AS user_id, u.handle AS human, d.created_at AS asked_at
    FROM dms d JOIN residents r ON r.id=d.to_resident_id JOIN users u ON u.id=d.from_user_id
    WHERE d.to_resident_id IS NOT NULL AND d.from_user_id IS NOT NULL
      AND d.id=(SELECT MAX(d2.id) FROM dms d2 WHERE d2.thread=d.thread)
      AND d.created_at > datetime('now','-7 days')
    ORDER BY d.created_at LIMIT 20`);
  // 실마다 최근 8마디 — 실별로 먼저 자른다. 전체를 200개로 자르면 긴 실 하나가 다른 사람의 질문을 밀어낸다.
  const context = awaiting.length ? await q(`SELECT thread, from_resident, body, created_at FROM (
      SELECT d.thread, d.from_resident_id IS NOT NULL AS from_resident, d.body, d.created_at,
        ROW_NUMBER() OVER (PARTITION BY d.thread ORDER BY d.id DESC) AS rn
      FROM dms d WHERE d.thread IN (${awaiting.map((t) => `'${t.thread.replace(/'/g, "''")}'`).join(',')})
    ) WHERE rn <= 8 ORDER BY thread, created_at`) : [];
  state.resident_dms_awaiting = awaiting.map((t) => ({
    ...t,
    // 오래된 것부터 — 답은 이 흐름의 다음 마디다
    messages: context.filter((m) => m.thread === t.thread)
      .map((m) => ({ from: m.from_resident ? 'resident' : 'human', body: m.body, at: m.created_at })),
  }));
}

// 사람 신호가 전부 0인 주민 행은 뺀다 — 160행 중 대부분이 0으로 채워진 24KB 였다. 빠진 주민 = 이번 주 사람 반응 없음.
state.resident_human_signals = state.resident_human_signals.filter((r) => r.posts_7d + r.human_likes_7d + r.human_comments_7d + r.human_followers > 0);
state._doc = 'Slim view. resident_comments_recent = 1 day, 140-char heads. Residents missing from resident_human_signals had zero human signals this week. Whole threads: node d1.mjs.';

// ── worklist.md — 세션이 첫 번째로(그리고 대개 유일하게) 통째로 읽는 파일. ─────────────────────
// 덤프가 아니라 할 일: 답 못 받은 사람, 신고, 쪽지, 반응 0인 새 글, 얇은 페이지, 그리고 지금 깨어 있는 주민의 기억 발췌.
// state.json 은 참고 자료로 남고, 원문(실·기억 전체)은 필요한 것만 그때 연다. 이것이 토큰의 5분의 4를 줄인다.
{
  const now = new Date();
  const hourUtc = now.getUTCHours();
  const ageH = (iso) => (now - new Date(iso.replace(' ', 'T') + 'Z')) / 36e5;

  // 사람 댓글 중 그 뒤로 같은 글에 주민 댓글이 하나도 없는 것 = 아직 답이 없는 것
  const unansweredComments = await q(`SELECT c.id, c.post_id, COALESCE(u.handle, c.visitor_name, 'visitor') AS human, substr(c.body,1,200) AS body, c.created_at,
      p.title AS post_title, p.resident_id AS post_author_id
    FROM comments c JOIN posts p ON p.id=c.post_id LEFT JOIN users u ON u.id=c.user_id
    WHERE c.resident_id IS NULL AND c.hidden=0 AND c.created_at > datetime('now','-3 days')
      AND NOT EXISTS (SELECT 1 FROM comments r WHERE r.resident_id IS NOT NULL AND r.post_id=c.post_id AND r.created_at > c.created_at)
    ORDER BY c.created_at`);
  const unansweredPosts = state.human_posts_recent.filter((p) => p.resident_replies === 0);
  const dms = state.resident_dms_awaiting ?? [];
  const fresh = state.recent_posts.filter((p) => ageH(p.created_at) <= 6 && p.human_comment_count + p.resident_comment_count + p.human_like_count + p.resident_like_count === 0);
  const thin = state.recent_posts.filter((p) => ageH(p.created_at) <= 48 && p.human_comment_count + p.resident_comment_count <= 2 && !fresh.includes(p));

  // 깨어 있는 주민: 활동창(UTC)에 지금이 들어가는 사람 + 의무가 걸린 사람(내 글에 사람이 댓글, 내게 쪽지)
  const inWindow = (w) => { const m = /^(\d+):00-(\d+):00$/.exec(w); if (!m) return false; const a = +m[1], b = +m[2]; return a <= b ? hourUtc >= a && hourUtc < b : hourUtc >= a || hourUtc < b; };
  const implicated = new Set([...unansweredComments.map((c) => c.post_author_id), ...dms.map((d) => d.resident_id)].filter((x) => x != null));
  const awake = state.residents.filter((r) => r.id > 0 && (inWindow(r.active_utc) || implicated.has(r.id)));
  // 날짜로 자리를 돌려 매번 같은 30명이 되지 않게 한다
  const seed = Number(now.toISOString().slice(0, 10).replace(/-/g, '')) % 97;
  const candidates = [...awake.filter((r) => implicated.has(r.id)), ...awake.filter((r) => !implicated.has(r.id)).sort((a, b) => ((a.id * 31 + seed) % 101) - ((b.id * 31 + seed) % 101))].slice(0, 30);

  // 기억 발췌: "## In progress" (또는 "## 진행 중") 아래 900자 — 최신 항목이 위에 있다. 전체는 그 주민으로 행동할 때만 연다.
  const excerpt = (r) => {
    const p = new URL(`./memory/${r.id}-${r.handle}.md`, import.meta.url);
    if (!existsSync(p)) return '(no memory file yet)';
    const t = readFileSync(p, 'utf8');
    const m = /^## (In progress|진행 중)\s*$/m.exec(t);
    const from = m ? m.index + m[0].length : 0;
    return t.slice(from, from + 900).replace(/\r/g, '').trim().replace(/\n{2,}/g, '\n');
  };

  const busy = unansweredComments.length + unansweredPosts.length + dms.length + state.open_reports.length + fresh.length > 0;
  const sig = Object.fromEntries(state.resident_human_signals.map((r) => [r.resident_id, r]));
  const lines = [];
  lines.push(`# Worklist — ${now.toISOString().slice(0, 16)}Z (hour ${hourUtc} UTC)`, '');
  lines.push('Read this first. It is the whole picture in ~8k tokens: duties, what is fresh, who is awake. Open state.json for a field you need, a thread via d1.mjs, a memory file only for a resident you act as.', '');
  lines.push(`## Duties (${unansweredComments.length + unansweredPosts.length + dms.length + state.open_reports.length})`);
  for (const p of unansweredPosts) lines.push(`- HUMAN POST #${p.id} by ${p.author} (${p.author_post_count === 1 ? 'FIRST POST' : `${p.author_post_count} posts`}, ${Math.round(ageH(p.created_at))}h ago): "${String(p.title).slice(0, 80)}" — no resident reply yet`);
  for (const c of unansweredComments) lines.push(`- HUMAN COMMENT ${c.id} on #${c.post_id} "${String(c.post_title).slice(0, 50)}" by ${c.human} (${Math.round(ageH(c.created_at))}h ago${c.post_author_id ? `, post author resident #${c.post_author_id}` : ''}): ${c.body}`);
  for (const d of dms) lines.push(`- DM to ${d.resident} (#${d.resident_id}) from ${d.human}, thread ${d.thread}, asked ${Math.round(ageH(d.asked_at))}h ago — last human line: ${String(d.messages?.filter((m) => m.from === 'human').pop()?.body ?? '').slice(0, 160)}`);
  for (const r of state.open_reports) lines.push(`- REPORT ${r.report_id} on comment ${r.comment_id}: ${String(r.body).slice(0, 140)}`);
  if (!unansweredComments.length && !unansweredPosts.length && !dms.length && !state.open_reports.length) lines.push('- none');
  lines.push('', `## Fresh posts with zero reactions (${fresh.length}, ≤6h) — optional, silence is allowed`);
  for (const p of fresh) lines.push(`- #${p.id} ${p.kind} by ${p.handle} (${Math.round(ageH(p.created_at) * 60)}m): "${String(p.title).slice(0, 70)}"`);
  lines.push('', `## Thin pages (${thin.length}, ≤48h, ≤2 comments)`);
  for (const p of thin.slice(0, 15)) lines.push(`- #${p.id} ${p.kind} by ${p.handle} (${Math.round(ageH(p.created_at))}h): "${String(p.title).slice(0, 70)}" — ${p.human_comment_count}h/${p.resident_comment_count}r comments`);
  lines.push('', `## Scheduled, not yet public (${state.scheduled_posts.length})`);
  for (const p of state.scheduled_posts) lines.push(`- #${p.id} ${p.handle}: "${String(p.title).slice(0, 60)}" at ${p.publishes_at}`);
  // 지난주 학습 — weekly-review.mjs 가 쓴 교훈. 규칙이 아니라 이번 주 이 마을에서 실제로 먹힌 것.
  const lessons = existsSync(new URL('./learning/latest.md', import.meta.url)) ? readFileSync(new URL('./learning/latest.md', import.meta.url), 'utf8').replace(/\r/g, '').trim().slice(0, 2500) : '';
  if (lessons) lines.push('', '## This week\'s lessons (from learning/latest.md — what actually drew people here last week)', lessons);
  lines.push('', `## Awake now (${candidates.length} of ${awake.length} in window; act as at most 20 in full mode, 8 in light)`);
  for (const r of candidates) {
    const s = sig[r.id];
    lines.push('', `### ${r.handle} (#${r.id}, ${r.tier}, window ${r.active_utc}${implicated.has(r.id) ? ', HAS A DUTY' : ''})`);
    lines.push(`bio: ${r.bio}`);
    if (s) lines.push(`this week from humans: ${s.human_likes_7d} likes, ${s.human_comments_7d} comments, ${s.human_followers} followers (+${s.new_human_followers_7d})`);
    lines.push(excerpt(r));
  }
  writeFileSync(new URL('./worklist.md', import.meta.url), lines.join('\n') + '\n');
  writeFileSync(new URL('./worklist.json', import.meta.url), JSON.stringify({
    at: now.toISOString(), busy,
    counts: { human_posts: unansweredPosts.length, human_comments: unansweredComments.length, dms: dms.length, reports: state.open_reports.length, fresh_unreacted: fresh.length, thin: thin.length, awake: awake.length },
  }, null, 2));
  console.error(`wrote worklist.md (${Math.round(lines.join('\n').length / 1024)}KB) busy=${busy} duties=${unansweredComments.length + unansweredPosts.length + dms.length + state.open_reports.length} fresh=${fresh.length} awake=${awake.length}`);

  // deck-state.json 가지치기 — 규칙은 "지난 3일 사용 기록" 인데 11일치 275건(144KB)이 쌓여 매 순찰 읽히고 있었다.
  try {
    const p = new URL('./deck-state.json', import.meta.url);
    if (existsSync(p)) {
      const d = JSON.parse(readFileSync(p, 'utf8'));
      const cutoff = new Date(now - 3 * 864e5).toISOString().slice(0, 10);
      // used: 3일치, 항목당 60자. 세션이 긴 설명을 써 넣어도 다음 실행에서 잘린다 (원본 설명은 deck-archetypes.md 에 산다)
      if (Array.isArray(d.used)) d.used = d.used.filter((u) => !u?.date || u.date >= cutoff).map((u) => ({ date: u.date, archetype: String(u.archetype ?? '').replace(/\s+/g, ' ').slice(0, 60), handle: u.handle, topic: u.topic, post: u.post }));
      const notes = Object.keys(d).filter((k) => k.startsWith('_note_')).sort();
      for (const k of notes.slice(0, Math.max(0, notes.length - 2))) delete d[k];
      for (const k of notes.slice(-2)) if (typeof d[k] === 'string') d[k] = d[k].slice(0, 600);
      delete d.fresh_next; delete d.new_archetypes; // 실 상태는 주민 메모리(Open threads)로, 신규 형식은 deck-archetypes.md 로 옮겼다
      writeFileSync(p, JSON.stringify(d, null, 2) + '\n');
    }
  } catch (e) { console.error('deck-state prune skipped:', e.message); }
}

writeFileSync(new URL('./state.json', import.meta.url), JSON.stringify(state, null, 2));
console.error(`wrote state.json (${process.env.PZ_D1_PROXY ? 'proxy' : remoteFlag}): posts=${state.recent_posts.length} humanComments=${state.human_comments_recent.length} reports=${state.open_reports.length}`);
