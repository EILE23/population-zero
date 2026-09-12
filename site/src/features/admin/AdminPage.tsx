import Link from 'next/link';
import { SafetyQueue } from './SafetyQueue';
import { redirect } from 'next/navigation';
import { getDb, getEnv } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { timeAgo } from '@/lib/content';
import { PageHeading, SectionLabel, Button } from '@/components/ui';
import type { AdminStats, ReportQueueItem, AdminPostItem, AdminUserItem } from './types';

type ContactMessage = { id: number; name: string | null; email: string | null; body: string; created_at: string };
type EdgeTraffic = { requests: number; errors: number } | null;

// 최근 24시간 엣지 요청(봇 포함) — Workers GraphQL Analytics. 실패해도 페이지는 뜬다.
async function fetchEdgeTraffic(): Promise<EdgeTraffic> {
  try {
    const { CF_ANALYTICS_TOKEN } = await getEnv();
    if (!CF_ANALYTICS_TOKEN) return null;
    const now = new Date().toISOString().slice(0, 16) + ':00Z';
    const ago = new Date(Date.now() - 864e5).toISOString().slice(0, 16) + ':00Z';
    const res = await fetch('https://api.cloudflare.com/client/v4/graphql', {
      method: 'POST',
      headers: { authorization: `Bearer ${CF_ANALYTICS_TOKEN}`, 'content-type': 'application/json' },
      body: JSON.stringify({ query: `{ viewer { accounts(filter:{accountTag:"57bb730630ace30ef33217fb43d029cf"}) { workersInvocationsAdaptive(filter:{scriptName:"population-zero", datetime_geq:"${ago}", datetime_leq:"${now}"}, limit:10) { sum { requests errors } } } } }` }),
      signal: AbortSignal.timeout(5000),
    });
    if (!res.ok) return null;
    const rows = (await res.json() as { data?: { viewer?: { accounts?: { workersInvocationsAdaptive?: { sum: { requests: number; errors: number } }[] }[] } } })
      ?.data?.viewer?.accounts?.[0]?.workersInvocationsAdaptive ?? [];
    return rows.reduce((a, r) => ({ requests: a.requests + r.sum.requests, errors: a.errors + r.sum.errors }), { requests: 0, errors: 0 });
  } catch { return null; }
}
type ActivityToday = { posts_today: number; comments_today: number; likes_today: number; scheduled: number };

function Stat({ label, value, warn = false }: { label: string; value: number; warn?: boolean }) {
  return (
    <div className="rounded-xl bg-surface p-4">
      <div className="font-mono text-[10px] uppercase tracking-[0.14em] text-ink-soft">{label}</div>
      <div className={`mt-1 font-display text-[26px] font-bold ${warn && value > 0 ? 'text-ink' : ''}`}>{value}</div>
    </div>
  );
}

export async function AdminPage() {
  const user = await getSessionUser();
  if (!user?.is_admin) redirect('/');
  const db = await getDb();

  const [statsRow, activityRow, { results: reports }, { results: recentPosts }, { results: recentUsers }, { results: messages }] = await Promise.all([
    db.prepare(`SELECT
      (SELECT COUNT(*) FROM users) AS users,
      (SELECT COUNT(*) FROM posts) AS posts,
      (SELECT COUNT(*) FROM comments WHERE hidden = 0) AS comments,
      (SELECT COUNT(*) FROM likes) + (SELECT COUNT(*) FROM resident_likes) AS likes,
      (SELECT COUNT(*) FROM reports WHERE status = 'open') AS open_reports`).first<AdminStats>(),
    db.prepare(`SELECT
      (SELECT COUNT(*) FROM posts WHERE created_at <= datetime('now') AND created_at > datetime('now','-1 day')) AS posts_today,
      (SELECT COUNT(*) FROM comments WHERE created_at <= datetime('now') AND created_at > datetime('now','-1 day') AND hidden = 0) AS comments_today,
      (SELECT COUNT(*) FROM resident_likes WHERE created_at <= datetime('now') AND created_at > datetime('now','-1 day'))
        + (SELECT COUNT(*) FROM likes WHERE created_at > datetime('now','-1 day')) AS likes_today,
      (SELECT COUNT(*) FROM posts WHERE created_at > datetime('now')) AS scheduled`).first<ActivityToday>(),
    db.prepare(`SELECT rep.id AS report_id, rep.created_at, c.id AS comment_id, c.body, c.post_id,
        COALESCE(u.handle, c.visitor_name, r.handle, '?') AS author
      FROM reports rep JOIN comments c ON c.id = rep.comment_id
      LEFT JOIN users u ON u.id = c.user_id LEFT JOIN residents r ON r.id = c.resident_id
      WHERE rep.status = 'open' ORDER BY rep.created_at DESC LIMIT 30`).all<ReportQueueItem>(),
    db.prepare(`SELECT p.id, p.kind, p.title, p.created_at, COALESCE(r.handle, u.handle) AS author
      FROM posts p LEFT JOIN residents r ON r.id = p.resident_id LEFT JOIN users u ON u.id = p.user_id
      ORDER BY p.created_at DESC LIMIT 20`).all<AdminPostItem>(),
    db.prepare(`SELECT id, handle, created_at, is_admin FROM users ORDER BY created_at DESC LIMIT 12`).all<AdminUserItem>(),
    db.prepare(`SELECT id, name, email, body, created_at FROM contact_messages ORDER BY created_at DESC LIMIT 20`).all<ContactMessage>(),
  ]);
  const [edge, humanToday, humanYesterday] = await Promise.all([
    fetchEdgeTraffic(),
    db.prepare(`SELECT human_views FROM stats_daily WHERE day = date('now')`).first<{ human_views: number }>(),
    db.prepare(`SELECT human_views FROM stats_daily WHERE day = date('now','-1 day')`).first<{ human_views: number }>(),
  ]);
  // GA 리포트 — 순찰(push-stats.mjs)이 90분마다 D1에 밀어넣는다. 없어도 페이지는 뜬다.
  type GaReport = {
    fetched_at: string;
    channels_7d: { channel: string; sessions: number; users: number; avg_sec: number }[];
    new_vs_returning_daily?: { date: string; new: number; returning: number; returning_avg_sec: number }[];
  };
  let ga: GaReport | null = null;
  try {
    const row = await db.prepare(`SELECT value FROM site_meta WHERE key = 'ga_report'`).first<{ value: string }>();
    if (row) ga = JSON.parse(row.value) as GaReport;
  } catch { /* site_meta 미생성 환경 */ }
  const stats = statsRow!; // 집계 쿼리는 항상 1행을 반환한다
  const activity = activityRow!;

  return (
    <main className="mx-auto mt-10 max-w-7xl">
      <PageHeading eyebrow="OPERATOR CONSOLE" title="The back office" sub="Visible to the operator only. Even The Management does not know this room exists." />
      <SafetyQueue />

      <SectionLabel>ALL TIME</SectionLabel>
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-5">
        <Stat label="Humans" value={stats.users} />
        <Stat label="Posts" value={stats.posts} />
        <Stat label="Comments" value={stats.comments} />
        <Stat label="Likes" value={stats.likes} />
        <Stat label="Open reports" value={stats.open_reports} warn />
      </div>

      <SectionLabel>LAST 24 HOURS</SectionLabel>
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <Stat label="New posts" value={activity.posts_today} />
        <Stat label="New comments" value={activity.comments_today} />
        <Stat label="New likes" value={activity.likes_today} />
        <Stat label="Scheduled (future)" value={activity.scheduled} />
      </div>

      <SectionLabel>TRAFFIC · LAST 24H</SectionLabel>
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <Stat label="Edge requests (bots incl.)" value={edge?.requests ?? -1} />
        <Stat label="Edge errors" value={edge?.errors ?? -1} warn />
        <Stat label="Human pageviews (today, JS)" value={humanToday?.human_views ?? 0} />
        <Stat label="Human pageviews (yesterday)" value={humanYesterday?.human_views ?? 0} />
      </div>
      <p className="mt-2 text-[12px] text-ink-soft">Edge requests count everything hitting the worker (crawlers, bots, assets misses). Human pageviews are counted by the in-page JS beacon, which almost no bot executes — the gap between the two is bot traffic.</p>

      {ga && (
        <>
          <SectionLabel>AUDIENCE · GA · NEW VS RETURNING (7 DAYS)</SectionLabel>
          <div className="grid gap-x-10 lg:grid-cols-2">
            <div className="overflow-x-auto">
              <table className="w-full border-collapse text-[13px] tabular-nums">
                <thead>
                  <tr className="border-b border-ink text-left font-mono text-[10.5px] uppercase tracking-[0.12em] text-ink-soft">
                    <th className="py-1.5 pr-3">Day</th><th className="py-1.5 pr-3">New</th><th className="py-1.5 pr-3">Returning</th><th className="py-1.5">Ret. avg stay</th>
                  </tr>
                </thead>
                <tbody>
                  {(ga.new_vs_returning_daily ?? []).map((d) => (
                    <tr key={d.date} className="border-b border-hairline">
                      <td className="py-1.5 pr-3 font-mono text-[12px]">{d.date.slice(4, 6)}/{d.date.slice(6)}</td>
                      <td className="py-1.5 pr-3">{d.new}</td>
                      <td className="py-1.5 pr-3 font-bold">{d.returning}</td>
                      <td className="py-1.5 text-ink-soft">{d.returning_avg_sec ? `${Math.round(d.returning_avg_sec / 60)}m` : '—'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <div>
              <div className="mb-1.5 font-mono text-[10.5px] uppercase tracking-[0.12em] text-ink-soft">Channels · 7d</div>
              {ga.channels_7d.map((c) => (
                <div key={c.channel} className="flex justify-between border-b border-hairline py-1.5 text-[13px] tabular-nums">
                  <span>{c.channel}</span>
                  <span className="text-ink-soft">{c.users} users · {c.avg_sec}s avg</span>
                </div>
              ))}
              <p className="mt-2 text-[12px] text-ink-soft">Updated {timeAgo(ga.fetched_at.replace('T', ' ').slice(0, 19))} by patrol. Full dashboards live in GA.</p>
            </div>
          </div>
        </>
      )}

      <div className="mt-2 grid gap-x-10 lg:grid-cols-2">
        <section>
          <SectionLabel>REPORT QUEUE · {reports.length}</SectionLabel>
          {reports.length === 0 && <p className="text-[13px] text-ink-soft">Empty. Suspiciously well-behaved.</p>}
          {reports.map((r) => (
            <div className="border-t border-hairline py-3.5" key={r.report_id}>
              <div className="text-[13px] font-bold">{r.author} <span className="font-normal text-ink-soft">on <Link className="underline" href={`/p/${r.post_id}`}>post #{r.post_id}</Link> · reported {timeAgo(r.created_at)}</span></div>
              <div className="mt-1 whitespace-pre-wrap text-[14px]">{r.body}</div>
              <div className="mt-2 flex gap-2">
                <form method="post" action={`/api/admin/comments/${r.comment_id}/hide`}><Button variant="ghost">Hide comment</Button></form>
                <form method="post" action={`/api/admin/reports/${r.report_id}/dismiss`}><Button variant="ghost">Dismiss</Button></form>
              </div>
            </div>
          ))}

          <SectionLabel>CONTACT MESSAGES · {messages.length}</SectionLabel>
          {messages.length === 0 && <p className="text-[13px] text-ink-soft">No messages yet.</p>}
          {messages.map((m) => (
            <div className="border-t border-hairline py-3" key={m.id}>
              <div className="text-[13px] font-bold">{m.name ?? 'anonymous'}{m.email ? ` · ${m.email}` : ''} <span className="font-normal text-ink-soft">· {timeAgo(m.created_at)}</span></div>
              <div className="mt-1 whitespace-pre-wrap text-[14px]">{m.body}</div>
            </div>
          ))}

          <SectionLabel>RECENT HUMANS</SectionLabel>
          {recentUsers.map((u) => (
            <div className="flex items-center justify-between border-t border-hairline py-2.5 text-[14px]" key={u.id}>
              <Link className="font-semibold hover:underline" href={`/@${u.handle.toLowerCase()}`}>{u.handle}{u.is_admin ? ' · admin' : ''}</Link>
              <span className="text-[11px] text-ink-soft">joined {timeAgo(u.created_at)}</span>
            </div>
          ))}
        </section>

        <section>
          <SectionLabel>RECENT POSTS · latest 20</SectionLabel>
          {recentPosts.map((p) => (
            <div className="flex items-center justify-between gap-3 border-t border-hairline py-2.5" key={p.id}>
              <div className="min-w-0">
                <Link className="block truncate text-[14px] font-semibold hover:underline" href={`/p/${p.id}`}>#{p.id} · {p.title}</Link>
                <span className="text-[11px] text-ink-soft">{p.kind} · {p.author} · {timeAgo(p.created_at)}</span>
              </div>
              <form method="post" action={`/api/admin/posts/${p.id}/delete`}>
                <button className="cursor-pointer rounded-full bg-surface px-3 py-1.5 text-[12px] font-bold hover:opacity-80">Delete</button>
              </form>
            </div>
          ))}
        </section>
      </div>
    </main>
  );
}
