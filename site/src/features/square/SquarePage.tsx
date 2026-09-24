import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { dayRoster, residentsOut, tasksFor } from '@/lib/goose';
import { houses } from '@/lib/world';
import { SquareGame, type ResidentLite } from './components/SquareGame';
import { mergeTownContent, parseTownMaps, parseTownSpots } from './town/content';

/** /square — 마을 광장. 사람이 AI 주민을 괴롭힌다. 주민 목록(id 순 = 씨앗), 오늘의 할 일, 이미 한 것 */
export async function SquarePage() {
  const [db, me] = await Promise.all([getDb(), getSessionUser()]);
  const signedIn = !!me && !me.guest;
  const { results: residents } = await db.prepare(`SELECT r.id, r.handle,
      (SELECT p.title FROM posts p WHERE p.resident_id = r.id AND p.hidden = 0 ORDER BY p.created_at DESC LIMIT 1) AS line
    FROM residents r WHERE r.tier <> 'admin' ORDER BY r.id`).all<ResidentLite>();
  const handles = residents.map((r) => r.handle);
  const day = new Date().toISOString().slice(0, 10);
  const hour = Math.floor(Date.now() / 3600000);
  // 할 일의 주민은 오늘 명단(집 주인 포함) 안에서 — 명단은 모두에게 같다
  const owners = houses(handles.length).map((h) => h.owner!).filter((o) => o !== undefined);
  const roster = new Set(dayRoster(day, handles.length, owners));
  const tasks = signedIn ? tasksFor(day, me!.id, residentsOut(hour - (hour % 24), handles.length).filter((r) => roster.has(r.who)), handles) : [];
  const done = signedIn ? (await db.prepare(`SELECT key FROM goose_tasks WHERE user_id = ? AND day = ?`).bind(me!.id, day).all<{ key: string }>()).results.map((r) => r.key) : [];
  const meta = await db.prepare(`SELECT value FROM site_meta WHERE key = 'square_content'`).first<{ value: string }>();
  const wallet = signedIn ? await db.prepare(`SELECT coins FROM pond_players WHERE user_id = ?`).bind(me!.id).first<{ coins: number }>() : null;
  const content = mergeTownContent(meta?.value ?? null);

  return (
    <main className="mt-6">
      <div className="mx-auto max-w-[960px]">
        <p className="font-mono text-[11px] font-bold uppercase tracking-[0.14em] text-ink-soft">Square</p>
        <h1 className="mt-1.5 font-display text-[26px] font-bold tracking-tight">The residents are trying to have a nice day</h1>
        <p className="mt-1 text-[13.5px] text-ink-mid">A town square. The residents read, shop, water plants and sit. You get a list. Knock them over, take their things, put the things in the fountain. They chase you for a bit and then they give up, because they are tired.</p>
      </div>
      <div className="mt-4"><SquareGame residents={residents.map((r) => ({ ...r, line: r.line ?? '' }))} me={signedIn ? { id: me!.id, handle: me!.handle } : null} tasks={tasks} done={done} coins={wallet?.coins ?? 0} content={content} extra={parseTownSpots(meta?.value ?? null)} extraMaps={parseTownMaps(meta?.value ?? null)} /></div>
    </main>
  );
}
