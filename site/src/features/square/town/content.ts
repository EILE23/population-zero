import type { ExtraMap, ExtraSpot, Content } from '../components/SquareGame';
import type { PropKind } from '@/lib/world';

const SPOT_KINDS: PropKind[] = ['house', 'bench', 'garden', 'stall', 'cafe', 'booth', 'tree', 'lamp', 'bin', 'swing', 'pond', 'fountain', 'bakery', 'post', 'station', 'church', 'gate', 'board', 'stage', 'pullbar', 'benchpress', 'steps', 'chesstable', 'pebbletoss', 'bocce', 'simon', 'busstop', 'echoboard', 'replyboard'];

export const DEFAULT_SQUARE_CONTENT: Content = {
  shoved: ['hey', 'what the hell', 'ow', 'seriously?', 'not again', 'why', 'i was reading that', 'sir', 'no', 'i have a meeting'],
  chase: ['give that back', 'HEY', 'that is mine', 'excuse me??', 'come back here', 'you absolute', 'i know where you live (i do not)'],
  giveup: ['fine.', 'whatever', 'keep it', 'i have a spare', 'unbelievable', 'this town', 'noted.'],
  caught: ['mine.', 'thank you.', 'got it', 'never again', 'stay down', 'that is for the hat'],
  thrown: ['catch', 'HAVE IT THEN', 'take it', 'incoming', 'no i insist'],
  angry: [],
};

/**
 * Dynamic town content written by patrol. Keep parsing here so SquarePage remains routing/data glue
 * and future town-growth jobs have one stable schema boundary to extend.
 */
export function parseTownSpots(raw: string | null): ExtraSpot[] {
  if (!raw) return [];
  try {
    const j = JSON.parse(raw) as { spots?: unknown };
    return (Array.isArray(j.spots) ? j.spots : [])
      .filter((s): s is ExtraSpot => !!s && typeof s === 'object' && SPOT_KINDS.includes(String((s as ExtraSpot).kind) as PropKind) && typeof (s as ExtraSpot).map === 'string' && typeof (s as ExtraSpot).key === 'string')
      .slice(0, 80)
      .map((s) => ({
        key: String(s.key).slice(0, 40),
        map: String(s.map),
        kind: s.kind,
        name: String(s.name).slice(0, 48),
        x: Number(s.x) || 0,
        d: Math.min(0.95, Math.max(0.05, Number(s.d) || 0.5)),
        act: String(s.act || 'stand'),
        addedAt: String(s.addedAt || ''),
      }));
  } catch {
    return [];
  }
}

export function parseTownMaps(raw: string | null): ExtraMap[] {
  if (!raw) return [];
  try {
    const j = JSON.parse(raw) as { maps?: unknown };
    return (Array.isArray(j.maps) ? j.maps : [])
      .filter((m): m is ExtraMap => !!m && typeof m === 'object' && typeof (m as ExtraMap).key === 'string' && Array.isArray((m as ExtraMap).spots))
      .slice(0, 20)
      .map((m) => ({
        key: String(m.key).slice(0, 20),
        name: String(m.name).slice(0, 40),
        w: Math.min(3600, Math.max(1400, Number(m.w) || 2000)),
        outdoor: m.outdoor !== false,
        floor: [String(m.floor?.[0] ?? '#cfc7c2'), String(m.floor?.[1] ?? '#e6e0da')] as [string, string],
        connect: String(m.connect || 'square'),
        spots: m.spots
          .filter((s) => SPOT_KINDS.includes(String(s.kind) as PropKind))
          .slice(0, 14)
          .map((s) => ({
            key: String(s.key).slice(0, 40),
            map: String(m.key),
            kind: s.kind,
            name: String(s.name).slice(0, 48),
            x: Number(s.x) || 0,
            d: Math.min(0.95, Math.max(0.05, Number(s.d) || 0.5)),
            act: String(s.act || 'stand'),
            addedAt: String(m.addedAt || ''),
          })),
        addedAt: String(m.addedAt || ''),
      }));
  } catch {
    return [];
  }
}

export function mergeTownContent(raw: string | null): Content {
  if (!raw) return DEFAULT_SQUARE_CONTENT;
  try {
    const j = JSON.parse(raw) as Partial<Record<keyof Content, unknown>>;
    const arr = (k: keyof Content) => [
      ...DEFAULT_SQUARE_CONTENT[k],
      ...(Array.isArray(j[k]) ? (j[k] as unknown[]).filter((x): x is string => typeof x === 'string' && x.length <= 80).slice(0, 300) : []),
    ];
    return { shoved: arr('shoved'), chase: arr('chase'), giveup: arr('giveup'), caught: arr('caught'), thrown: arr('thrown'), angry: arr('angry') };
  } catch {
    return DEFAULT_SQUARE_CONTENT;
  }
}
