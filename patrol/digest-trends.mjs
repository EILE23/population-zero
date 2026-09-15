// trends.json(700KB+) → trends-digest.json(~35KB). 세션이 통째로 읽는 건 다이제스트뿐이다.
// 원본은 남겨 둔다 — 고른 항목의 링크·채널·조회수는 trends.json 을 제목으로 grep 해서 확인한다.
// 사용: node digest-trends.mjs   (CI 에서는 fetch-trends 직후, 세션 앞)
import { readFileSync, writeFileSync, existsSync } from 'node:fs';

const src = new URL('./trends.json', import.meta.url);
if (!existsSync(src)) { console.error('digest-trends: no trends.json'); process.exit(0); }
const raw = readFileSync(src, 'utf8');
const { fetched_at, sources = {} } = JSON.parse(raw);

const clip = (s, n) => String(s ?? '').replace(/\s+/g, ' ').trim().slice(0, n);
const ok = (v) => v && !(typeof v === 'object' && !Array.isArray(v) && 'error' in v);
const region = (name) => name.match(/_([a-z]{2})$/)?.[1]?.toUpperCase() ?? null;

// 뉴스: 나라별로 매체를 섞어 순위순 12개 — "지금 KR 에서 무슨 일" 이 한 목록으로 보인다
const news = {};
for (const [name, v] of Object.entries(sources)) {
  if (!/^rss_/.test(name) || !ok(v) || !Array.isArray(v.items)) continue;
  const key = v.region ?? 'global';
  (news[key] ??= []).push(...v.items.slice(0, 6).map((it, i) => ({ t: clip(it.title, 110), s: name.replace(/^rss_/, ''), r: i })));
}
for (const k of Object.keys(news)) news[k] = news[k].sort((a, b) => a.r - b.r).slice(0, k === 'global' ? 30 : 12).map(({ t, s }) => ({ t, s }));

// 영상: 나라별 유튜브 5 + 데일리모션 3 (id 는 임베드에 필요하니 남긴다)
const videos = {};
for (const [name, v] of Object.entries(sources)) {
  if (!ok(v) || !Array.isArray(v)) continue;
  if (/^youtube_trending_/.test(name)) (videos[region(name)] ??= []).push(...v.slice(0, 5).map((x) => ({ yt: x.id, t: clip(x.title, 90), ch: clip(x.channel, 40) })));
  else if (/^dailymotion_trending_/.test(name)) (videos[region(name)] ??= []).push(...v.slice(0, 3).map((x) => ({ dm: x.id, t: clip(x.title, 90), ch: clip(x.channel, 40) })));
  else if (/^youtube_shorts_hot_/.test(name)) (videos[`${region(name)}_shorts`] ??= []).push(...v.slice(0, 5).map((x) => ({ yt: x.id, t: clip(x.title, 90), ch: clip(x.channel, 40) })));
}

// 검색어: 나라별 10개
const keywords = {};
for (const [name, v] of Object.entries(sources)) if (/^google_trends_/.test(name) && ok(v) && Array.isArray(v)) keywords[region(name)] = v.slice(0, 10).map((s) => clip(s, 60));

// 커뮤니티·차트·위키: 소스별 짧게
const community = {};
const short = (name, v, n, f) => { if (ok(v) && Array.isArray(v)) community[name] = v.slice(0, n).map(f); };
short('reddit_all_top_day', sources.reddit_all_top_day, 10, (x) => clip(x.title, 110));
short('bluesky_trending', sources.bluesky_trending, 10, (x) => clip(x.topic, 80));
short('bluesky_hot_posts', sources.bluesky_hot_posts, 6, (x) => ({ t: clip(x.text, 140), by: clip(x.author, 30), likes: x.likes }));
short('mastodon_trending_tags', sources.mastodon_trending_tags, 10, (x) => clip(x.tag, 40));
short('mastodon_trending_links', sources.mastodon_trending_links, 6, (x) => ({ t: clip(x.title, 100), via: clip(x.provider, 30) }));
short('hackernews_top', sources.hackernews_top, 10, (x) => ({ t: clip(x.title, 110), score: x.score }));
short('github_new_hot_repos', sources.github_new_hot_repos, 6, (x) => ({ repo: x.name, stars: x.stars, desc: clip(x.desc, 90) }));
short('apple_music_top_us', sources.apple_music_top_us, 10, (x) => `${clip(x.name, 50)} — ${clip(x.artist, 40)}`);
short('rss_knowyourmeme', sources.rss_knowyourmeme?.items, 4, (x) => clip(x.title, 100));
short('vimeo_staffpicks', sources.vimeo_staffpicks?.items, 4, (x) => clip(x.title, 80));
for (const [name, v] of Object.entries(sources)) if (/^wikipedia_top_/.test(name) && ok(v)) community[name] = v.slice(0, 6).map((x) => clip(x.article, 60));
for (const [name, v] of Object.entries(sources)) if (/^reddit_/.test(name) && name !== 'reddit_all_top_day' && ok(v) && Array.isArray(v)) community[name] = v.slice(0, 5).map((x) => clip(x.title, 100));

const digest = {
  fetched_at, digested_at: new Date().toISOString(),
  _doc: 'Headlines only. news.<REGION> = top stories across that country\'s outlets (s = source key, minus rss_). videos.<REGION> = yt (YouTube id) / dm (Dailymotion id). For a link, og_from, channel or view count, grep the title in trends.json — never read that file whole.',
  news, videos, keywords, community,
};
const text = JSON.stringify(digest);
writeFileSync(new URL('./trends-digest.json', import.meta.url), text);
console.error(`digest-trends: ${Object.keys(news).length} news regions, ${Object.keys(videos).length} video lists, ${Math.round(text.length / 1024)}KB (from ${Math.round(raw.length / 1024)}KB)`);
