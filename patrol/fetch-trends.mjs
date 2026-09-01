// 순찰 1단계: 무료 공식 소스에서 오늘의 트렌드 신호를 수집해 trends.json으로 저장.
// 크롤링 없음 — 전부 공개 JSON/RSS/API. 실패한 소스는 건너뛰고 기록만 남긴다.
import { writeFileSync } from 'node:fs';

const UA = { headers: { 'user-agent': 'population-zero-patrol/0.1 (daily trend digest for an AI-resident town)' } };
const j = async (url) => { const r = await fetch(url, UA); if (!r.ok) throw new Error(`HTTP ${r.status}`); return r.json(); };
const t = async (url) => { const r = await fetch(url, UA); if (!r.ok) throw new Error(`HTTP ${r.status}`); return r.text(); };

const out = { fetched_at: new Date().toISOString(), sources: {} };
async function safe(name, fn) {
  try { out.sources[name] = await fn(); console.error(`ok    ${name}`); }
  catch (e) { out.sources[name] = { error: String(e.message || e) }; console.error(`FAIL  ${name}: ${e.message || e}`); }
}

await safe('reddit_all_top_day', async () =>
  (await j('https://www.reddit.com/r/all/top.json?limit=15&t=day')).data.children.map((c) => ({
    title: c.data.title, sub: c.data.subreddit, score: c.data.score,
    thread: 'https://reddit.com' + c.data.permalink, external: c.data.url,
  })));

await safe('reddit_outoftheloop', async () =>
  (await j('https://www.reddit.com/r/OutOfTheLoop/top.json?limit=10&t=day')).data.children.map((c) => ({
    title: c.data.title, score: c.data.score, thread: 'https://reddit.com' + c.data.permalink,
  })));

await safe('google_trends_us', async () => {
  const xml = await t('https://trends.google.com/trending/rss?geo=US');
  return [...xml.matchAll(/<title>([^<]+)<\/title>/g)].map((m) => m[1]).slice(1, 21);
});

await safe('hackernews_top', async () => {
  const ids = (await j('https://hacker-news.firebaseio.com/v0/topstories.json')).slice(0, 10);
  return Promise.all(ids.map((id) =>
    j(`https://hacker-news.firebaseio.com/v0/item/${id}.json`).then((i) => ({ title: i.title, score: i.score, url: i.url }))));
});

await safe('wikipedia_top_yesterday', async () => {
  const d = new Date(Date.now() - 864e5);
  const p = `${d.getUTCFullYear()}/${String(d.getUTCMonth() + 1).padStart(2, '0')}/${String(d.getUTCDate()).padStart(2, '0')}`;
  const data = await j(`https://wikimedia.org/api/rest_v1/metrics/pageviews/top/en.wikipedia/all-access/${p}`);
  return data.items[0].articles
    .filter((a) => !/^(Main_Page|Special:|Wikipedia:|Portal:)/.test(a.article))
    .slice(0, 15).map((a) => ({ article: a.article, views: a.views }));
});

await safe('youtube_trending_us', async () => {
  const key = process.env.YT_API_KEY;
  if (!key) return { skipped: 'set YT_API_KEY to enable (free quota)' };
  const d = await j(`https://www.googleapis.com/youtube/v3/videos?part=snippet,statistics&chart=mostPopular&regionCode=US&maxResults=10&key=${key}`);
  return d.items.map((v) => ({ id: v.id, title: v.snippet.title, channel: v.snippet.channelTitle, views: Number(v.statistics.viewCount) }));
});

writeFileSync(new URL('./trends.json', import.meta.url), JSON.stringify(out, null, 2));
console.error('wrote trends.json');
