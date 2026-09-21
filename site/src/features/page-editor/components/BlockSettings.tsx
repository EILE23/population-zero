'use client';
import type { Block, BlockKind } from '@/lib/blog-layout';

export const KIND_LABEL: Record<BlockKind, string> = {
  header: 'Header', intro: 'About', banner: 'Banner', posts: 'Posts', toc: 'Contents',
  guestbook: 'Guestbook', memes: 'Shitposts', text: 'Text', image: 'Picture', links: 'Links', divider: 'Divider',
  search: 'Search', actions: 'Buttons', chrome: 'Header bar',
};
/** 한 번만 놓을 수 있는 것들 — 블로그의 기능이라 두 개가 되면 안 된다 */
export const ONCE: BlockKind[] = ['header', 'intro', 'posts', 'guestbook', 'memes'];

const chip = (on: boolean) =>
  `cursor-pointer rounded-full px-2.5 py-1 text-[12px] font-bold ${on ? 'bg-ink text-paper' : 'border border-hairline bg-paper text-ink-mid hover:bg-surface'}`;
const field = 'w-full rounded-lg border border-hairline bg-paper px-2.5 py-1.5 text-[13px] outline-none focus:border-ink';

export function Row({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <p className="mb-1 font-mono text-[10px] uppercase tracking-[0.12em] text-ink-soft">{label}</p>
      <div className="flex flex-wrap gap-1.5">{children}</div>
    </div>
  );
}

/** 어느 블록에나 있는 것 — 위 간격, 안쪽 여백, 이 블록만의 색. 블록별 설정 아래에 붙는다 */
export function CommonSettings({ block, setProp }: {
  block: Block; setProp: (key: string, v: string | number | boolean) => void;
}) {
  const p = block.props ?? {};
  return (
    <div className="flex flex-col gap-2.5 border-t border-hairline pt-2.5">
      <Row label="Space above">
        {([['none', '0'], ['sm', 'S'], ['md', 'M'], ['lg', 'L'], ['xl', 'XL']] as const).map(([v, l]) => (
          <button key={v} onClick={() => setProp('gap', v)} className={chip((p.gap ?? 'md') === v)}>{l}</button>
        ))}
      </Row>
      <Row label="Padding inside">
        {([['none', '0'], ['sm', 'S'], ['md', 'M'], ['lg', 'L']] as const).map(([v, l]) => (
          <button key={v} onClick={() => setProp('pad', v)} className={chip((p.pad ?? 'none') === v)}>{l}</button>
        ))}
      </Row>
      <Row label="Width">
        {([['full', 'Full'], ['two-thirds', '2/3'], ['half', '1/2'], ['third', '1/3']] as const).map(([v, l]) => (
          <button key={v} onClick={() => setProp('span', v)} className={chip((p.span ?? 'full') === v)}>{l}</button>
        ))}
      </Row>
      <Row label="Place">
        {([['start', 'Left'], ['center', 'Centre'], ['end', 'Right']] as const).map(([v, l]) => (
          <button key={v} onClick={() => setProp('place', v)} className={chip((p.place ?? 'start') === v)}>{l}</button>
        ))}
      </Row>
      <Row label="Edge">
        {([['none', 'None'], ['line', 'Under-line'], ['box', 'Box'], ['shadow', 'Lifted']] as const).map(([v, l]) => (
          <button key={v} onClick={() => setProp('edge', v)} className={chip((p.edge ?? 'none') === v)}>{l}</button>
        ))}
      </Row>
      <Row label="Corners">
        {([['theme', 'As set'], ['none', 'Sharp'], ['sm', 'Soft'], ['lg', 'Round'], ['pill', 'Pill']] as const).map(([v, l]) => (
          <button key={v} onClick={() => setProp('round', v)} className={chip((p.round ?? 'theme') === v)}>{l}</button>
        ))}
      </Row>
      <Row label="Text">
        {([['none', 'Plain'], ['soft', 'Shadow'], ['hard', 'Hard shadow'], ['glow', 'Glow']] as const).map(([v, l]) => (
          <button key={v} onClick={() => setProp('shadow', v)} className={chip((p.shadow ?? 'none') === v)}>{l}</button>
        ))}
        {([['normal', 'Normal'], ['bold', 'Bold'], ['black', 'Heavy']] as const).map(([v, l]) => (
          <button key={v} onClick={() => setProp('weight', v)} className={chip((p.weight ?? 'normal') === v)}>{l}</button>
        ))}
        <button onClick={() => setProp('caps', p.caps !== true)} className={chip(p.caps === true)}>CAPS</button>
      </Row>
      <Row label="This block's colours">
        <label className="inline-flex items-center gap-1 text-[11.5px]">
          <input type="color" value={String(p.bg || '#ffffff')} onChange={(e) => setProp('bg', e.target.value)}
            className="size-6 cursor-pointer rounded border border-hairline bg-transparent p-0" />
          Background
        </label>
        <label className="inline-flex items-center gap-1 text-[11.5px]">
          <input type="color" value={String(p.ink || '#000000')} onChange={(e) => setProp('ink', e.target.value)}
            className="size-6 cursor-pointer rounded border border-hairline bg-transparent p-0" />
          Text
        </label>
        {(p.bg || p.ink) && (
          <button onClick={() => { setProp('bg', ''); setProp('ink', ''); }} className={chip(false)}>Clear</button>
        )}
      </Row>
    </div>
  );
}

/** 고른 블록의 설정 — 그 블록 바로 아래에서 펼친다(화면에서 만지는 느낌이 끊기지 않게) */
export function BlockSettings({ block, setProp, onPickImage }: {
  block: Block;
  setProp: (key: string, v: string | number | boolean) => void;
  onPickImage: () => void;
}) {
  const p = block.props ?? {};
  const pick = <T extends string>(key: string, opts: readonly (readonly [T, string])[], def: T) => (
    opts.map(([v, l]) => (
      <button key={v} onClick={() => setProp(key, v)} className={chip((p[key] ?? def) === v)}>{l}</button>
    ))
  );

  switch (block.kind) {
    case 'header':
      return (
        <>
          <Row label="Size">{pick('size', [['sm', 'S'], ['md', 'M'], ['lg', 'L'], ['xl', 'XL']] as const, 'lg')}</Row>
          <Row label="Align">{pick('align', [['left', 'Left'], ['center', 'Centre']] as const, 'left')}</Row>
          <Row label="Fill">
            {pick('fill', [['none', 'None'], ['accent', 'Accent'], ['ink', 'Dark']] as const, 'none')}
            <button onClick={onPickImage} className={chip(p.fill === 'image')}>Picture</button>
          </Row>
          <Row label="Line under">{pick('rule', [['none', 'None'], ['thin', 'Thin'], ['thick', 'Thick']] as const, 'thick')}</Row>
          <Row label="Show">
            <button onClick={() => setProp('show_handle', p.show_handle === false)} className={chip(p.show_handle !== false)}>Handle</button>
            <button onClick={() => setProp('show_avatar', p.show_avatar === false)} className={chip(p.show_avatar !== false)}>Avatar</button>
            <button onClick={() => setProp('show_follows', p.show_follows === false)} className={chip(p.show_follows !== false)}>Followers</button>
          </Row>
        </>
      );

    case 'posts':
      return (
        <>
          <Row label="How posts look">
            {pick('view', [['grid', 'Cards'], ['magazine', 'Magazine'], ['list', 'List'], ['index', 'Titles only']] as const, 'grid')}
          </Row>
          {(p.view ?? 'grid') === 'grid' && (
            <Row label="Columns">
              {[1, 2, 3].map((n) => (
                <button key={n} onClick={() => setProp('columns', n)} className={chip(Number(p.columns ?? 3) === n)}>{n}</button>
              ))}
            </Row>
          )}
          <Row label="Show">
            <button onClick={() => setProp('cover', p.cover === false)} className={chip(p.cover !== false)}>Covers</button>
            <button onClick={() => setProp('excerpt', p.excerpt === false)} className={chip(p.excerpt !== false)}>Excerpts</button>
            <button onClick={() => setProp('topics', p.topics === false)} className={chip(p.topics !== false)}>Topic tabs</button>
          </Row>
        </>
      );

    case 'toc':
      return (
        <>
          <input value={String(p.title ?? '')} onChange={(e) => setProp('title', e.target.value)} maxLength={40}
            placeholder="Contents" className={field} />
          <Row label="Include">
            <button onClick={() => setProp('topics', p.topics === false)} className={chip(p.topics !== false)}>Topics</button>
            <button onClick={() => setProp('series', p.series === false)} className={chip(p.series !== false)}>Series</button>
          </Row>
          <Row label="Latest posts">
            {[0, 5, 8, 12, 20].map((n) => (
              <button key={n} onClick={() => setProp('recent', n)} className={chip(Number(p.recent ?? 8) === n)}>{n || 'none'}</button>
            ))}
          </Row>
        </>
      );

    case 'intro':
      return (
        <>
          <Row label="Show">
            <button onClick={() => setProp('show_avatar', p.show_avatar === false)} className={chip(p.show_avatar !== false)}>Avatar</button>
            <button onClick={() => setProp('show_follows', p.show_follows === false)} className={chip(p.show_follows !== false)}>Followers</button>
          </Row>
          <Row label="Align">{pick('align', [['left', 'Left'], ['center', 'Centre']] as const, 'left')}</Row>
        </>
      );

    case 'banner':
      return (
        <>
          <input value={String(p.text ?? '')} onChange={(e) => setProp('text', e.target.value)} maxLength={400}
            placeholder="One line across the top" className={field} />
          <Row label="Height">{pick('height', [['sm', 'Short'], ['md', 'Medium'], ['lg', 'Tall']] as const, 'md')}</Row>
          <Row label="Background">
            <button onClick={onPickImage} className={chip(!!p.image)}>Pick a picture</button>
            {p.image ? <button onClick={() => setProp('image', '')} className={chip(false)}>Remove</button> : null}
          </Row>
        </>
      );

    case 'text':
      return (
        <>
          <textarea value={String(p.body ?? '')} onChange={(e) => setProp('body', e.target.value)} rows={3} maxLength={2000}
            placeholder="Write something" className={field} />
          <Row label="Align">{pick('align', [['left', 'Left'], ['center', 'Centre']] as const, 'left')}</Row>
        </>
      );

    case 'image':
      return (
        <>
          <Row label="Picture"><button onClick={onPickImage} className={chip(!!p.src)}>{p.src ? 'Change' : 'Pick one'}</button></Row>
          <input value={String(p.caption ?? '')} onChange={(e) => setProp('caption', e.target.value)} maxLength={200}
            placeholder="Caption (optional)" className={field} />
          <Row label="Size">
            <button onClick={() => setProp('full', p.full !== true)} className={chip(p.full === true)}>Full width</button>
          </Row>
        </>
      );

    case 'links':
      return (
        <>
          <p className="text-[11.5px] text-ink-soft">One per line — name, then the address after a |</p>
          <textarea value={String(p.items ?? '')} onChange={(e) => setProp('items', e.target.value)} rows={3} maxLength={1200}
            placeholder="My other site|https://example.com" className={field} />
        </>
      );

    case 'divider':
      return <Row label="Style">{pick('style', [['line', 'Line'], ['dots', 'Dots'], ['space', 'Just space']] as const, 'line')}</Row>;

    case 'chrome':
      return (
        <>
          <Row label="What it holds">
            {([['search', 'Search'], ['about', 'About'], ['contact', 'Contact'], ['bell', 'Notifications'],
               ['messages', 'Messages'], ['write', 'Write'], ['account', 'My page']] as const).map(([k, l]) => (
              <button key={k} onClick={() => setProp(k, p[k] === false || p[k] === undefined ? true : false)}
                className={chip(k === 'search' || k === 'bell' ? p[k] === true : p[k] !== false)}>{l}</button>
            ))}
          </Row>
          <Row label="Direction">{pick('dir', [['row', 'Across'], ['column', 'Down']] as const, 'row')}</Row>
          <Row label="Look">{pick('style', [['plain', 'Plain links'], ['buttons', 'Buttons']] as const, 'plain')}</Row>
        </>
      );

    case 'search':
      return (
        <>
          <input value={String(p.placeholder ?? '')} onChange={(e) => setProp('placeholder', e.target.value)} maxLength={40}
            placeholder="Search" className={field} />
          <Row label="Size">
            <button onClick={() => setProp('wide', p.wide !== true)} className={chip(p.wide === true)}>Full width</button>
          </Row>
        </>
      );

    case 'actions':
      return (
        <>
          <Row label="Show">
            <button onClick={() => setProp('write', p.write === false)} className={chip(p.write !== false)}>Write</button>
            <button onClick={() => setProp('messages', p.messages === false)} className={chip(p.messages !== false)}>Messages</button>
            <button onClick={() => setProp('follow', p.follow === false)} className={chip(p.follow !== false)}>Followers</button>
          </Row>
          <Row label="Look">{pick('style', [['button', 'Buttons'], ['link', 'Plain links']] as const, 'button')}</Row>
        </>
      );

    case 'guestbook':
      return (
        <input value={String(p.title ?? '')} onChange={(e) => setProp('title', e.target.value)} maxLength={60}
          placeholder="Guestbook" className={field} />
      );

    case 'memes':
      return (
        <>
          <input value={String(p.title ?? '')} onChange={(e) => setProp('title', e.target.value)} maxLength={40} placeholder="Shitposts" className={field} />
          <Row label="How many">
            {[3, 6, 12].map((n) => (
              <button key={n} onClick={() => setProp('limit', n)} className={chip(Number(p.limit ?? 6) === n)}>{n}</button>
            ))}
          </Row>
        </>
      );

    default:
      return null;
  }
}
