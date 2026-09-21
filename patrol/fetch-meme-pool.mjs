// 밈 풀 채우기 — 바탕 그림은 만들지 않고 가져온다. 모델 호출 0, 이미지 생성 토큰 0.
//
//   imgflip  https://api.imgflip.com/get_memes — 지금 세계에서 제일 많이 쓰이는 템플릿 100장. 키 없음. 순위가 곧 유행이라
//            매 순찰 다시 받아 rank 를 갱신한다(새로 뜬 밈은 며칠 안에 여기 올라온다).
//   met      메트로폴리탄 미술관 공개 API — 퍼블릭 도메인(CC0) 그림. 매 순찰 검색어 몇 개를 굴려 몇 장씩 더한다.
//            "명화에 헛소리" 는 밈의 한 장르라 imgflip 템플릿과 섞이면 벽이 한 톤이 되지 않는다.
// 둘 다 CORS(*) 가 열려 있어 브라우저 캔버스가 그대로 쓴다(실측). 우리 보관함으로 옮기지 않는다 — 핫링크.
// 허용 출처 목록은 site/src/lib/memes.ts 의 PICTURE_HOSTS 와 같아야 한다(거기 없으면 API 가 거절한다).
//
// 실행: node fetch-meme-pool.mjs [--dry-run]   (D1 은 d1.mjs 경유 — CI 는 wrangler 직결, 로컬은 내 로그인)
import { d1, rows } from './d1.mjs';

const esc = (s) => String(s).replace(/'/g, "''");
const log = (m) => console.log(`[meme-pool] ${m}`);
const DRY = process.argv.includes('--dry-run');
const MET_PER_RUN = Number(process.env.MEME_MET_PER_RUN ?? 8);
const UA = { 'user-agent': 'pz-patrol (population.town)' };

async function imgflip() {
  const res = await fetch('https://api.imgflip.com/get_memes', { headers: UA });
  const d = await res.json();
  if (!d.success) throw new Error('imgflip: not success');
  const memes = d.data.memes.filter((m) => /^https:\/\/i\.imgflip\.com\/[\w-]+\.(jpe?g|png)$/.test(m.url));
  if (!memes.length) throw new Error('imgflip: empty');
  const values = memes.map((m, i) => `('${esc(m.url)}', 'imgflip', '${esc(String(m.name).slice(0, 80))}', ${i + 1}, ${m.width | 0}, ${m.height | 0})`);
  if (!DRY) {
    await d1(`INSERT INTO meme_pool (url, source, title, rank, w, h) VALUES ${values.join(', ')}
      ON CONFLICT(url) DO UPDATE SET rank = excluded.rank, title = excluded.title, seen = datetime('now');`);
    // 목록에서 빠진 지 오래된 템플릿은 순위를 뒤로 — 지우진 않는다(이미 만든 짤이 가리킨다)
    await d1(`UPDATE meme_pool SET rank = 999 WHERE source = 'imgflip' AND seen < datetime('now', '-14 days') AND rank < 999;`);
  }
  log(`imgflip ${memes.length}장 — 1위 "${memes[0].name}"`);
  return memes.length;
}

// 검색어는 '짤이 될 만한 장면' 이다. 초상화만 나오면 벽이 지루하다 — 동물·소동·표정·괴물이 섞여야 한다
const TERMS = ['cat', 'dog', 'banquet', 'knight', 'sleeping', 'fish', 'monster', 'bath', 'skull', 'drunk', 'party', 'baby', 'horse',
  'lion', 'kitchen', 'soldier', 'king', 'moon', 'cheese', 'angry', 'crying', 'devil', 'hell', 'money', 'sea monster', 'wrestling',
  'goat', 'pig', 'shouting', 'dancing', 'fool', 'card players', 'tavern', 'storm', 'owl', 'rabbit', 'demon', 'clown', 'laughing'];
const shuffle = (xs) => xs.map((x) => [Math.random(), x]).sort((a, b) => a[0] - b[0]).map((p) => p[1]);

async function met() {
  const have = new Set((await rows(`SELECT url FROM meme_pool WHERE source = 'met'`)).map((r) => r.url));
  const found = [];
  for (const term of shuffle(TERMS).slice(0, 3)) {
    const s = await fetch(`https://collectionapi.metmuseum.org/public/collection/v1/search?q=${encodeURIComponent(term)}&hasImages=true&isPublicDomain=true`, { headers: UA })
      .then((r) => r.json()).catch(() => null);
    const ids = shuffle(s?.objectIDs ?? []).slice(0, 6);
    for (const id of ids) {
      if (found.length >= MET_PER_RUN) break;
      const o = await fetch(`https://collectionapi.metmuseum.org/public/collection/v1/objects/${id}`, { headers: UA }).then((r) => r.json()).catch(() => null);
      const url = o?.primaryImageSmall;
      if (!o?.isPublicDomain || !url || !url.startsWith('https://images.metmuseum.org/') || have.has(url)) continue;
      // 그림·판화만 — 도자기 파편이나 동전은 짤이 안 된다
      if (!/painting|print|drawing|watercolor|photograph/i.test(`${o.classification} ${o.objectName}`)) continue;
      found.push({ url, title: `${o.title || 'Untitled'}${o.artistDisplayName ? ` — ${o.artistDisplayName}` : ''}`.slice(0, 80) });
      have.add(url);
    }
  }
  if (found.length && !DRY) {
    const values = found.map((f) => `('${esc(f.url)}', 'met', '${esc(f.title)}', 0)`);
    await d1(`INSERT OR IGNORE INTO meme_pool (url, source, title, rank) VALUES ${values.join(', ')};`);
  }
  log(`met +${found.length}장${found.length ? ` — "${found[0].title}"` : ''}`);
  return found.length;
}

let ok = 0;
for (const job of [imgflip, met]) {
  try { await job(); ok++; } catch (e) { log(`실패: ${e.message.slice(0, 160)}`); }
}
const n = DRY ? [] : await rows(`SELECT source, COUNT(*) AS n FROM meme_pool GROUP BY source`);
log(`${ok}/2 출처 · 풀 ${n.map((r) => `${r.source} ${r.n}`).join(', ') || '(dry)'}`);
