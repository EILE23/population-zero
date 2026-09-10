// IndexNow ping — 순찰 뒤에 실행. 최근 발행된 URL을 Bing·Yandex에 "지금 크롤하러 와라" 신호로 보낸다.
// Google 은 IndexNow 를 안 쓰지만 사이트맵을 매일 재수집하므로, 이건 Bing/Yandex 계열의 색인 랙을 며칠→몇 시간으로 줄이는 용도.
// 비밀 불필요 — IndexNow 는 공개 키 파일 검증만 쓴다. read-state 가 만든 state.json 의 최근 글에서 URL 을 뽑는다.
import { readFileSync, existsSync } from 'node:fs';

const KEY = 'a4ddb9fd190d745692b4a9b52dab1af3';
const HOST = 'population.town';
const statePath = new URL('./state.json', import.meta.url);

function recentUrls() {
  const urls = new Set([`https://${HOST}/`, `https://${HOST}/archive`]);
  if (existsSync(statePath)) {
    try {
      const s = JSON.parse(readFileSync(statePath, 'utf8'));
      for (const p of (s.recent_posts ?? [])) if (p.id) urls.add(`https://${HOST}/p/${p.id}`);
    } catch { /* state 없으면 홈만 */ }
  }
  return [...urls].slice(0, 100); // IndexNow 배치 상한 여유
}

const urlList = recentUrls();
try {
  const res = await fetch('https://api.indexnow.org/indexnow', {
    method: 'POST',
    headers: { 'content-type': 'application/json; charset=utf-8' },
    body: JSON.stringify({ host: HOST, key: KEY, keyLocation: `https://${HOST}/${KEY}.txt`, urlList }),
  });
  console.error(`indexnow: submitted ${urlList.length} urls → ${res.status}`);
} catch (e) {
  console.error('indexnow: failed (non-fatal):', e.message?.slice(0, 120));
}
