import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { dayRoster, residentsOut, tasksFor } from '@/lib/goose';
import { houses } from '@/lib/world';
import { SquareGame, type Content, type ExtraMap, type ExtraSpot, type ResidentLite } from './components/SquareGame';

/** 기본 내용 — 순찰이 site_meta.square_content 에 덧붙인다(대사·성깔). 없어도 게임은 된다 */
const DEFAULT_CONTENT: Content = {
  shoved: ['hey', 'what the hell', 'ow', 'seriously?', 'not again', 'why', 'i was reading that', 'sir', 'no', 'i have a meeting'],
  chase: ['give that back', 'HEY', 'that is mine', 'excuse me??', 'come back here', 'you absolute', 'i know where you live (i do not)'],
  giveup: ['fine.', 'whatever', 'keep it', 'i have a spare', 'unbelievable', 'this town', 'noted.'],
  caught: ['mine.', 'thank you.', 'got it', 'never again', 'stay down', 'that is for the hat'],
  thrown: ['catch', 'HAVE IT THEN', 'take it', 'incoming', 'no i insist'],
  angry: [],
};
const SPOT_KINDS = ['bench', 'garden', 'stall', 'cafe', 'booth', 'tree', 'lamp', 'bin', 'swing', 'pond', 'fountain'];
/** 마을이 지은 소품 — 순찰이 붙인 것. 종류·좌표를 여기서 한 번 더 거른다 */
function extraSpots(raw: string | null): ExtraSpot[] {
  if (!raw) return [];
  try {
    const j = JSON.parse(raw) as { spots?: unknown };
    return (Array.isArray(j.spots) ? j.spots : []).filter((s): s is ExtraSpot => !!s && typeof s === 'object' && SPOT_KINDS.includes(String((s as ExtraSpot).kind)) && typeof (s as ExtraSpot).map === 'string' && typeof (s as ExtraSpot).key === 'string').slice(0, 60)
      .map((s) => ({ key: String(s.key).slice(0, 40), map: String(s.map), kind: s.kind, name: String(s.name).slice(0, 48), x: Number(s.x) || 0, d: Math.min(0.95, Math.max(0.05, Number(s.d) || 0.5)), act: String(s.act || 'stand'), addedAt: String(s.addedAt || '') }));
  } catch { return []; }
}
/** 마을이 지은 지도 — 기존 지도 하나에 이어진다 */
function extraMaps(raw: string | null): ExtraMap[] {
  if (!raw) return [];
  try {
    const j = JSON.parse(raw) as { maps?: unknown };
    return (Array.isArray(j.maps) ? j.maps : []).filter((m): m is ExtraMap => !!m && typeof m === 'object' && typeof (m as ExtraMap).key === 'string' && Array.isArray((m as ExtraMap).spots)).slice(0, 12)
      .map((m) => ({ key: String(m.key).slice(0, 20), name: String(m.name).slice(0, 40), w: Math.min(3200, Math.max(1600, Number(m.w) || 2000)), outdoor: m.outdoor !== false, floor: [String(m.floor?.[0] ?? '#cfc7c2'), String(m.floor?.[1] ?? '#e6e0da')] as [string, string], connect: String(m.connect || 'square'),
        spots: m.spots.filter((s) => SPOT_KINDS.includes(String(s.kind))).slice(0, 8).map((s) => ({ key: String(s.key).slice(0, 40), map: String(m.key), kind: s.kind, name: String(s.name).slice(0, 48), x: Number(s.x) || 0, d: Math.min(0.95, Math.max(0.05, Number(s.d) || 0.5)), act: String(s.act || 'stand'), addedAt: String(m.addedAt || '') })), addedAt: String(m.addedAt || '') }));
  } catch { return []; }
}
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
  // 할 일의 주민은 오늘 명단(집 주인 포함) 안에서 — 명단은 모두에게 같다
  const owners = houses(handles.length).map((h) => h.owner!).filter((o) => o !== undefined);
  const roster = new Set(dayRoster(day, handles.length, owners));
  const tasks = signedIn ? tasksFor(day, me!.id, residentsOut(hour - (hour % 24), handles.length).filter((r) => roster.has(r.who)), handles) : [];
  const done = signedIn ? (await db.prepare(`SELECT key FROM goose_tasks WHERE user_id = ? AND day = ?`).bind(me!.id, day).all<{ key: string }>()).results.map((r) => r.key) : [];
  const meta = await db.prepare(`SELECT value FROM site_meta WHERE key = 'square_content'`).first<{ value: string }>();
  const content = mergeContent(meta?.value ?? null);

  return (
    <main className="mt-6">
      <div className="mx-auto max-w-[960px]">
        <p className="font-mono text-[11px] font-bold uppercase tracking-[0.14em] text-ink-soft">Square</p>
        <h1 className="mt-1.5 font-display text-[26px] font-bold tracking-tight">The residents are trying to have a nice day</h1>
        <p className="mt-1 text-[13.5px] text-ink-mid">A town square. The residents read, shop, water plants and sit. You get a list. Knock them over, take their things, put the things in the fountain. They chase you for a bit and then they give up, because they are tired.</p>
      </div>
      <div className="mt-4"><SquareGame residents={residents.map((r) => ({ ...r, line: r.line ?? '' }))} me={signedIn ? { id: me!.id, handle: me!.handle } : null} tasks={tasks} done={done} content={content} extra={extraSpots(meta?.value ?? null)} extraMaps={extraMaps(meta?.value ?? null)} /></div>
    </main>
  );
}
