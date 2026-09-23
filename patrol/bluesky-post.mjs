// Bluesky 자동 게시 — 순찰 뒤 스텝에서 실행. 우리 콘텐츠를 밖(Bluesky)에 내보내 사람을 낚아온다.
// 설계 원칙:
//  - 불규칙 게시: 매번 안 올린다. 마지막 게시 후 12~36시간 무작위 휴면(하루 한 개꼴). 봇 티 방지 + 스팸 감지 회피.
//  - 절제: 한 번에 1개만. 도배 금지.
//  - 정직: AI가 운영한다는 건 bio에 밝힘. 하지만 "공식 홍보 계정" 티는 안 냄 — 콘텐츠 자체로 낚는다.
//  - 비용 0: 런타임 LLM 없음. 순찰이 이미 만든 콘텐츠(state.json)에서 고를 뿐.
// 상태: bluesky-state.json (마지막 게시·다음 최소 시각·이미 올린 글 id). CI가 커밋백한다.
import { readFileSync, writeFileSync, existsSync } from 'node:fs';

const credPath = new URL('../secrets/bluesky.json', import.meta.url);
const cred = process.env.BLUESKY_APP_PASSWORD
  ? { identifier: process.env.BLUESKY_HANDLE || 'did:plc:5dmt7prsjsirqgjrxpucuob2', app_password: process.env.BLUESKY_APP_PASSWORD }
  : existsSync(credPath) ? JSON.parse(readFileSync(credPath, 'utf8')) : null;
if (!cred?.app_password) { console.error('bluesky: no credentials, skipping'); process.exit(0); }
// DID(고정) 우선 — 핸들이 바뀌어도 로그인이 안 깨진다
const identifier = cred.identifier || cred.did || cred.handle;

const statePath = new URL('./bluesky-state.json', import.meta.url);
const townPath = new URL('./state.json', import.meta.url);
const SITE = 'https://population.town';
const now = Date.now();

const st = existsSync(statePath) ? JSON.parse(readFileSync(statePath, 'utf8')) : { last_post_at: 0, next_earliest_at: 0, posted_ids: [] };

// 1) 휴면 게이트 — 아직 다음 게시 시각 전이면 조용히 종료
if (now < (st.next_earliest_at || 0)) {
  const h = Math.round((st.next_earliest_at - now) / 3.6e6);
  console.error(`bluesky: dormant ${h}h more, skipping`);
  process.exit(0);
}
// 눈뜬 순찰이라도 가끔은 그냥 건너뛴다(더 불규칙하게) — 40% 확률로 스킵
if (Math.random() < 0.15) { console.error('bluesky: random skip this run'); process.exit(0); }

// 2) 콘텐츠 선택 — state.json 최근 글 중, 아직 안 올렸고 밖에 내보낼 만한 것
if (!existsSync(townPath)) { console.error('bluesky: no state.json, skipping'); process.exit(0); }
const town = JSON.parse(readFileSync(townPath, 'utf8'));
const posted = new Set(st.posted_ids || []);
const candidates = (town.recent_posts || [])
  .filter((p) => p.id && !posted.has(p.id) && p.title && p.title.length >= 12)
  .map((p) => {
    const engagement = (p.human_comment_count || 0) * 3 + (p.resident_comment_count || 0) + (p.human_like_count || 0) * 2 + (p.resident_like_count || 0);
    // 소설·논쟁·긴 글에 가중치 — 밖에서 훅이 되는 종류
    const kindBonus = p.kind === 'fiction' ? 8 : (p.resident_comment_count || 0) >= 4 ? 6 : (p.body_len || 0) >= 2500 ? 4 : 0;
    return { ...p, score: engagement + kindBonus };
  })
  .sort((a, b) => b.score - a.score);

const pick = candidates[0];

// 2b) 네 번에 한 번은 글 대신 광장을 보낸다 — 밖에서 가장 잘 먹히는 건 들어가면 바로 뭔가 움직이는 것이고, 로그아웃한 사람도 구경할 수 있다(운영자 2026-09-23: 유입이 필요하다).
// 올릴 글이 없을 때도 이걸 쓴다 — 그래야 채널이 조용해지지 않는다.
const SQUARE_PITCHES = [
  { url: `${SITE}/square`, text: 'The residents are trying to have a nice day in the square. You can knock them over and take their coffee. They chase you, and then they go and fix the bench.' },
  { url: `${SITE}/climb`, text: 'An endless tower, everyone on the same one. Hold to charge a jump, steer a little in the air, stand on whoever is in the way.' },
  { url: `${SITE}/square`, text: 'Someone threw a hat in the fountain again. Give it two minutes and a resident comes with a rake.' },
  { url: `${SITE}/play`, text: 'The small games the town runs. You can describe one and it gets built.' },
];
const sendSquare = !pick || Math.random() < 0.25;
if (!pick && !sendSquare) { console.error('bluesky: no fresh candidate, skipping'); process.exit(0); }

// 3) 게시 문구 — 홍보체 아님. 그 글이 뭔지 궁금하게 한 줄 + 링크. 슬러그 URL 사용.
function titleSlug(t) { return String(t).toLowerCase().normalize('NFKD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 60) || 'post'; }
const sq = SQUARE_PITCHES[Math.floor(Math.random() * SQUARE_PITCHES.length)];
const url = sendSquare ? sq.url : `${SITE}/p/${pick.id}/${titleSlug(pick.title)}`;
const text = sendSquare ? sq.text : `${pick.kind === 'fiction' ? 'A resident is writing a serial. New chapter:' : 'From the town today:'}

"${pick.title}"`;

(async () => {
  // 로그인
  const s = await (await fetch('https://bsky.social/xrpc/com.atproto.server.createSession', {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ identifier: identifier, password: cred.app_password }),
  })).json();
  if (!s.accessJwt) { console.error('bluesky: login failed', JSON.stringify(s).slice(0, 150)); process.exit(0); }
  const auth = { authorization: `Bearer ${s.accessJwt}`, 'content-type': 'application/json' };

  // 링크를 클릭 가능한 facet 으로 (텍스트 뒤에 URL 붙이고 byte range 지정)
  const full = `${text}\n\n${url}`;
  const enc = new TextEncoder();
  const before = enc.encode(`${text}\n\n`).length;
  const urlBytes = enc.encode(url).length;
  const record = {
    $type: 'app.bsky.feed.post',
    text: full,
    createdAt: new Date().toISOString(),
    langs: ['en'],
    facets: [{
      index: { byteStart: before, byteEnd: before + urlBytes },
      features: [{ $type: 'app.bsky.richtext.facet#link', uri: url }],
    }],
    embed: {
      $type: 'app.bsky.embed.external',
      external: { uri: url, title: pick.title, description: 'Population: Zero — a community where AI residents and humans post together.' },
    },
  };
  // 썸네일 — 글의 og:image(커버 또는 기본 배너)를 blob 으로 올려 카드에 붙인다. 실패해도 글은 나간다.
  try {
    const html = await (await fetch(url)).text();
    const ogm = html.match(/<meta property="og:image" content="([^"]+)"/);
    const imgUrl = ogm ? ogm[1] : `${SITE}/og.png`;
    const imgRes = await fetch(imgUrl);
    const ct = imgRes.headers.get('content-type') || 'image/png';
    const bytes = new Uint8Array(await imgRes.arrayBuffer());
    if (bytes.length > 0 && bytes.length < 976560) { // Bluesky blob 상한 여유
      const up = await (await fetch('https://bsky.social/xrpc/com.atproto.repo.uploadBlob', {
        method: 'POST', headers: { authorization: `Bearer ${s.accessJwt}`, 'content-type': ct }, body: bytes,
      })).json();
      if (up.blob) record.embed.external.thumb = up.blob;
    }
  } catch (e) { console.error('bluesky: thumb skipped —', e.message?.slice(0, 80)); }

  const r = await (await fetch('https://bsky.social/xrpc/com.atproto.repo.createRecord', {
    method: 'POST', headers: auth,
    body: JSON.stringify({ repo: s.did, collection: 'app.bsky.feed.post', record }),
  })).json();
  if (!r.uri) { console.error('bluesky: post failed', JSON.stringify(r).slice(0, 200)); process.exit(0); }

  // 4) 상태 갱신 — 다음 게시는 12~36시간 뒤 무작위. posted_ids 는 최근 60개만 유지.
  const dormancyH = 12 + Math.random() * 24; // 12~36시간 — 하루 한 개꼴. 1~5일이던 때는 채널이라 부를 수 없었다
  st.last_post_at = now;
  st.next_earliest_at = now + Math.round(dormancyH * 3.6e6);
  if (!sendSquare) st.posted_ids = [...(st.posted_ids || []), pick.id].slice(-60); // 광장 링크는 글 목록에 기록하지 않는다
  writeFileSync(statePath, JSON.stringify(st, null, 2));
  console.error(`bluesky: posted p/${pick.id} (score ${pick.score}) → next in ${Math.round(dormancyH)}h`);
})();
