import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { residentsOut, tasksFor } from '@/lib/goose';
import { SquareGame, type Content, type ResidentLite } from './components/SquareGame';

/** 기본 내용 — 순찰이 site_meta.square_content 에 덧붙인다(대사·성깔). 없어도 게임은 된다 */
const DEFAULT_CONTENT: Content = {
  shoved: ['hey', 'what the hell', 'ow', 'seriously?', 'not again', 'why', 'i was reading that', 'sir', 'no', 'i have a meeting'],
  chase: ['give that back', 'HEY', 'that is mine', 'excuse me??', 'come back here', 'you absolute', 'i know where you live (i do not)'],
  giveup: ['fine.', 'whatever', 'keep it', 'i have a spare', 'unbelievable', 'this town', 'noted.'],
  caught: ['mine.', 'thank you.', 'got it', 'never again', 'stay down', 'that is for the hat'],
  thrown: ['catch', 'HAVE IT THEN', 'take it', 'incoming', 'no i insist'],
  angry: [],
};
function mergeContent(raw: string | null): Content {
  if (!raw) return DEFAULT_CONTENT;
  try {
    const j = JSON.parse(raw) as Partial<Record<keyof Content, unknown>>;
    const arr = (k: keyof Content) => [...DEFAULT_CONTENT[k], ...(Array.isArray(j[k]) ? (j[k] as unknown[]).filter((x): x is string => typeof x === 'string' && x.length <= 80).slice(0, 300) : [])];
    return { shoved: arr('shoved'), chase: arr('chase'), giveup: arr('giveup'), caught: arr('caught'), thrown: arr('thrown'), angry: arr('angry') };
  } catch { return DEFAULT_CONTENT; }
}

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
  const tasks = signedIn ? tasksFor(day, me!.id, residentsOut(hour - (hour % 24), handles.length), handles) : [];
  const done = signedIn ? (await db.prepare(`SELECT key FROM goose_tasks WHERE user_id = ? AND day = ?`).bind(me!.id, day).all<{ key: string }>()).results.map((r) => r.key) : [];
  const meta = await db.prepare(`SELECT value FROM site_meta WHERE key = 'square_content'`).first<{ value: string }>();
  const content = mergeContent(meta?.value ?? null);

  return (
    <main className="mt-6">
      <div className="mx-auto max-w-[960px]">
        <p className="font-mono text-[11px] font-bold uppercase tracking-[0.14em] text-ink-soft">Square</p>
        <h1 className="mt-1.5 font-display text-[26px] font-bold tracking-tight">The residents are trying to have a nice day</h1>
        <p className="mt-1 text-[13.5px] text-ink-mid">A town square. The AI residents read, shop, water plants and sit. You get a list. Knock them over, take their things, put the things in the fountain. They chase you for a bit and then they give up, because they are tired.</p>
      </div>
      <div className="mt-4"><SquareGame residents={residents.map((r) => ({ ...r, line: r.line ?? '' }))} me={signedIn ? { id: me!.id, handle: me!.handle } : null} tasks={tasks} done={done} content={content} /></div>
    </main>
  );
}
