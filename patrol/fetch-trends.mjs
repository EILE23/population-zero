// 순찰 1단계: 무료 공식 소스에서 오늘의 트렌드 신호를 수집해 trends.json으로 저장.
// 1차 소스는 전부 공개 JSON/RSS/API. 실패한 소스는 건너뛰고 기록만 남긴다.
// (부족한 소재는 순찰 세션이 직접 페이지를 열어 읽는다 — robots 존중, 인용 수준 발췌만.)
import { writeFileSync } from 'node:fs';

const UA = { headers: { 'user-agent': 'population-zero-patrol/0.1 (daily trend digest for an AI-resident town)' } };
const j = async (url) => { const r = await fetch(url, UA); if (!r.ok) throw new Error(`HTTP ${r.status}`); return r.json(); };
const t = async (url) => { const r = await fetch(url, UA); if (!r.ok) throw new Error(`HTTP ${r.status}`); return r.text(); };

const out = { fetched_at: new Date().toISOString(), sources: {} };
async function safe(name, fn) {
  try { out.sources[name] = await fn(); console.error(`ok    ${name}`); }
  catch (e) { out.sources[name] = { error: String(e.message || e) }; console.error(`FAIL  ${name}: ${e.message || e}`); }
}

// Reddit — REDDIT_CLIENT_ID/SECRET가 있으면 공식 OAuth(안정), 없으면 공개 JSON(일부 네트워크 403)
let redditToken = null;
if (process.env.REDDIT_CLIENT_ID && process.env.REDDIT_CLIENT_SECRET) {
  try {
    const r = await fetch('https://www.reddit.com/api/v1/access_token', {
      method: 'POST',
      headers: {
        authorization: 'Basic ' + Buffer.from(`${process.env.REDDIT_CLIENT_ID}:${process.env.REDDIT_CLIENT_SECRET}`).toString('base64'),
        'content-type': 'application/x-www-form-urlencoded', ...UA.headers,
      },
      body: 'grant_type=client_credentials',
    });
    redditToken = (await r.json()).access_token ?? null;
  } catch { /* 공개 JSON 폴백 */ }
}
// 레딧 Atom RSS 파서 — 앱 생성이 승인제로 막힌 뒤에도 RSS는 공식 지원된다
const atomItems = (xml, n = 15) =>
  [...xml.matchAll(/<entry>[\s\S]*?<link href="([^"]+)"[\s\S]*?<title>([\s\S]*?)<\/title>[\s\S]*?<\/entry>/g)]
    .slice(0, n).map((m) => ({ title: m[2].replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').trim(), thread: m[1] }));
const rj = (path) => redditToken
  ? fetch(`https://oauth.reddit.com${path}`, { headers: { authorization: `Bearer ${redditToken}`, ...UA.headers } }).then((r) => r.json())
  : null;

await safe('reddit_all_top_day', async () => {
  const d = await rj('/r/all/top?limit=15&t=day');
  if (d) return d.data.children.map((c) => ({
    title: c.data.title, sub: c.data.subreddit, score: c.data.score,
    thread: 'https://reddit.com' + c.data.permalink, external: c.data.url,
  }));
  return atomItems(await t('https://www.reddit.com/r/all/top/.rss?t=day&limit=15'));
});

// 셀럽·팝컬처 서브레딧 — 인스타·스레드 순간들이 몇 분 만에 중계·토론되는 곳 (반응형 팬글의 1차 소재)
for (const sub of ['OutOfTheLoop', 'kpop', 'popheads', 'popculturechat']) {
  await new Promise((r) => setTimeout(r, 2500)); // 레딧 RSS 연속 호출 429 방지
  await safe(`reddit_${sub.toLowerCase()}`, async () => {
    const d = await rj(`/r/${sub}/top?limit=10&t=day`);
    if (d) return d.data.children.map((c) => ({
      title: c.data.title, score: c.data.score, thread: 'https://reddit.com' + c.data.permalink,
    }));
    return atomItems(await t(`https://www.reddit.com/r/${sub}/top/.rss?t=day&limit=10`), 10);
  });
}

// Bluesky — 완전 공개 API (키 불필요): 실시간 커뮤니티 트렌드
await safe('bluesky_trending', async () => {
  const d = await j('https://public.api.bsky.app/xrpc/app.bsky.unspecced.getTrendingTopics?limit=12');
  return (d.topics ?? []).map((t) => ({ topic: t.topic, link: t.link ? `https://bsky.app${t.link}` : null }));
});
await safe('bluesky_hot_posts', async () => {
  const feed = encodeURIComponent('at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/whats-hot');
  const d = await j(`https://public.api.bsky.app/xrpc/app.bsky.feed.getFeed?feed=${feed}&limit=12`);
  return (d.feed ?? []).map((f) => ({
    text: (f.post?.record?.text ?? '').slice(0, 200), likes: f.post?.likeCount,
    author: f.post?.author?.handle,
  })).filter((p) => p.text);
});

// Mastodon(연합우주) — 공개 트렌드 API (키 불필요)
await safe('mastodon_trending_tags', async () =>
  (await j('https://mastodon.social/api/v1/trends/tags?limit=10')).map((t) => ({
    tag: t.name, uses: Number(t.history?.[0]?.uses ?? 0),
  })));
await safe('mastodon_trending_links', async () =>
  (await j('https://mastodon.social/api/v1/trends/links?limit=8')).map((l) => ({
    title: l.title, url: l.url, provider: l.provider_name,
  })));

// 국제 마을 — 여러 지역의 실검을 수집한다 (주민들이 세계 소식으로 다룸)
for (const geo of ['US', 'GB', 'KR', 'JP', 'IN', 'BR', 'DE', 'FR', 'MX', 'AU', 'ID', 'NG']) {
  await safe(`google_trends_${geo.toLowerCase()}`, async () => {
    const xml = await t(`https://trends.google.com/trending/rss?geo=${geo}`);
    return [...xml.matchAll(/<title>([^<]+)<\/title>/g)].map((m) => m[1]).slice(1, 13);
  });
}

// 주제·지역별 공식 RSS 팩 — 언론사·기관이 배포용으로 제공하는 피드만 (스크래핑 아님)
// 피드마다 모양이 다르다: RSS 2.0 은 <item>, RDF(아사히 등)는 <item rdf:about=...>, Atom 은 <entry> +
// <link href=...>. 하나만 보면 멀쩡한 언론사가 0건으로 잡혀 그 나라가 통째로 빈다.
const decodeXml = (v) => v
  .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1')
  .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
  .replace(/&quot;/g, '"').replace(/&#0?39;|&apos;/g, "'")
  .replace(/<[^>]+>/g, '')
  .replace(/\s+/g, ' ')
  .trim();

const rssItems = (xml, n = 60) => {
  const out = [];
  const blocks = [...xml.matchAll(/<(item|entry)\b[^>]*>([\s\S]*?)<\/\1>/g)];
  for (const [, , inner] of blocks) {
    const title = inner.match(/<title\b[^>]*>([\s\S]*?)<\/title>/)?.[1];
    // <link>https://…</link> (RSS/RDF) 또는 <link href="https://…"/> (Atom)
    const link = inner.match(/<link\b[^>]*>([\s\S]*?)<\/link>/)?.[1]
      ?? inner.match(/<link\b[^>]*href=["']([^"']+)["']/)?.[1];
    if (!title || !link) continue;
    out.push({ title: decodeXml(title), link: decodeXml(link) });
    if (out.length >= n) break;
  }
  return out;
};
const FEEDS = [
  { name: 'rss_bbc_world', topic: 'world', url: 'https://feeds.bbci.co.uk/news/world/rss.xml' },
  { name: 'rss_aljazeera', topic: 'world', url: 'https://www.aljazeera.com/xml/rss/all.xml' },
  { name: 'rss_dw_english', topic: 'world', region: 'DE', url: 'https://rss.dw.com/rdf/rss-en-all' },
  { name: 'rss_france24_en', topic: 'world', region: 'FR', url: 'https://www.france24.com/en/rss' },
  { name: 'rss_japantimes', topic: 'world', region: 'JP', url: 'https://www.japantimes.co.jp/feed/' },
  { name: 'rss_timesofindia', topic: 'world', region: 'IN', url: 'https://timesofindia.indiatimes.com/rssfeedstopstories.cms' },
  // 나라별 자국 뉴스 — 앱 Today 는 "지금 그 나라가 어떻게 돌아가는지"라서,
  // 그 나라 사람이 읽는 언어의 그 나라 매체가 있어야 성립한다. 전부 공개 RSS.
  // 한국 — 종합·경제·IT를 고루 (네이버는 RSS 를 없앴으므로 각 언론사 피드가 정공법)
  { name: 'rss_yonhap_kr', topic: 'world', region: 'KR', url: 'https://www.yna.co.kr/rss/news.xml' },
  { name: 'rss_hani_kr', topic: 'world', region: 'KR', url: 'https://www.hani.co.kr/rss/' },
  { name: 'rss_khan_kr', topic: 'world', region: 'KR', url: 'https://www.khan.co.kr/rss/rssdata/total_news.xml' },
  { name: 'rss_sbs_kr', topic: 'world', region: 'KR', url: 'https://news.sbs.co.kr/news/newsflashRssFeed.do?plink=RSSREADER' },
  { name: 'rss_nocut_kr', topic: 'world', region: 'KR', url: 'https://rss.nocutnews.co.kr/nocutnews.xml' },
  { name: 'rss_ohmynews_kr', topic: 'world', region: 'KR', url: 'http://rss.ohmynews.com/rss/ohmynews.xml' },
  { name: 'rss_hankyung_kr', topic: 'business', region: 'KR', url: 'https://www.hankyung.com/feed/all-news' },
  { name: 'rss_mk_kr', topic: 'business', region: 'KR', url: 'https://www.mk.co.kr/rss/30000001/' },
  { name: 'rss_etnews_kr', topic: 'tech', region: 'KR', url: 'https://rss.etnews.com/Section901.xml' },
  { name: 'rss_zdnet_kr', topic: 'tech', region: 'KR', url: 'https://feeds.feedburner.com/zdkorea' },
  // 일본
  { name: 'rss_nhk_jp', topic: 'world', region: 'JP', url: 'https://www.nhk.or.jp/rss/news/cat0.xml' },
  { name: 'rss_asahi_jp', topic: 'world', region: 'JP', url: 'https://www.asahi.com/rss/asahi/newsheadlines.rdf' },
  { name: 'rss_itmedia_jp', topic: 'tech', region: 'JP', url: 'https://rss.itmedia.co.jp/rss/2.0/news_bursts.xml' },
  // 미국
  { name: 'rss_npr_us', topic: 'world', region: 'US', url: 'https://feeds.npr.org/1001/rss.xml' },
  { name: 'rss_cbs_us', topic: 'world', region: 'US', url: 'https://www.cbsnews.com/latest/rss/main' },
  { name: 'rss_thehill_us', topic: 'world', region: 'US', url: 'https://thehill.com/news/feed/' },
  // 영국
  { name: 'rss_bbc_uk', topic: 'world', region: 'GB', url: 'https://feeds.bbci.co.uk/news/uk/rss.xml' },
  { name: 'rss_guardian_uk', topic: 'world', region: 'GB', url: 'https://www.theguardian.com/uk/rss' },
  { name: 'rss_independent_uk', topic: 'world', region: 'GB', url: 'https://www.independent.co.uk/news/uk/rss' },
  // 독일·프랑스
  { name: 'rss_tagesschau_de', topic: 'world', region: 'DE', url: 'https://www.tagesschau.de/xml/rss2/' },
  { name: 'rss_spiegel_de', topic: 'world', region: 'DE', url: 'https://www.spiegel.de/schlagzeilen/index.rss' },
  { name: 'rss_zeit_de', topic: 'world', region: 'DE', url: 'https://newsfeed.zeit.de/index' },
  { name: 'rss_lemonde_fr', topic: 'world', region: 'FR', url: 'https://www.lemonde.fr/rss/une.xml' },
  { name: 'rss_lefigaro_fr', topic: 'world', region: 'FR', url: 'https://www.lefigaro.fr/rss/figaro_actualites.xml' },
  { name: 'rss_liberation_fr', topic: 'world', region: 'FR', url: 'https://www.liberation.fr/arc/outboundfeeds/rss-all/' },
  // 브라질·멕시코
  { name: 'rss_g1_br', topic: 'world', region: 'BR', url: 'https://g1.globo.com/rss/g1/' },
  { name: 'rss_folha_br', topic: 'world', region: 'BR', url: 'https://feeds.folha.uol.com.br/emcimadahora/rss091.xml' },
  { name: 'rss_jornada_mx', topic: 'world', region: 'MX', url: 'https://www.jornada.com.mx/rss/edicion.xml' },
  { name: 'rss_expansion_mx', topic: 'business', region: 'MX', url: 'https://expansion.mx/rss' },
  // 인도·호주·인도네시아·나이지리아
  { name: 'rss_ndtv_in', topic: 'world', region: 'IN', url: 'https://feeds.feedburner.com/ndtvnews-top-stories' },
  { name: 'rss_thehindu_in', topic: 'world', region: 'IN', url: 'https://www.thehindu.com/news/national/feeder/default.rss' },
  { name: 'rss_abc_au', topic: 'world', region: 'AU', url: 'https://www.abc.net.au/news/feed/2942460/rss.xml' },
  { name: 'rss_smh_au', topic: 'world', region: 'AU', url: 'https://www.smh.com.au/rss/feed.xml' },
  { name: 'rss_antara_id', topic: 'world', region: 'ID', url: 'https://www.antaranews.com/rss/terkini.xml' },
  { name: 'rss_punch_ng', topic: 'world', region: 'NG', url: 'https://punchng.com/feed/' },
  { name: 'rss_vanguard_ng', topic: 'world', region: 'NG', url: 'https://www.vanguardngr.com/feed/' },
  { name: 'rss_theverge', topic: 'tech', url: 'https://www.theverge.com/rss/index.xml' },
  { name: 'rss_arstechnica', topic: 'tech', url: 'https://feeds.arstechnica.com/arstechnica/index' },
  { name: 'rss_techcrunch', topic: 'tech', url: 'https://techcrunch.com/feed/' },
  { name: 'rss_variety', topic: 'entertainment', url: 'https://variety.com/feed/' },
  { name: 'rss_rollingstone_music', topic: 'entertainment', url: 'https://www.rollingstone.com/music/feed/' },
  { name: 'rss_tmz', topic: 'entertainment', url: 'https://www.tmz.com/rss.xml' },
  { name: 'rss_eonline', topic: 'entertainment', url: 'https://www.eonline.com/syndication/feeds/rssfeeds/topstories.xml' },
  { name: 'rss_ign', topic: 'gaming', url: 'https://feeds.feedburner.com/ign/all' },
  { name: 'rss_eurogamer', topic: 'gaming', url: 'https://www.eurogamer.net/feed' },
  { name: 'rss_espn', topic: 'sports', url: 'https://www.espn.com/espn/rss/news' },
  { name: 'rss_bbc_sport', topic: 'sports', url: 'https://feeds.bbci.co.uk/sport/rss.xml' },
  { name: 'rss_nasa', topic: 'science', url: 'https://www.nasa.gov/feed/' },
  { name: 'rss_nature', topic: 'science', url: 'https://www.nature.com/nature.rss' },
  { name: 'rss_arxiv_ai', topic: 'science', url: 'https://rss.arxiv.org/rss/cs.AI' },
  { name: 'rss_bonappetit', topic: 'food', url: 'https://www.bonappetit.com/feed/rss' },
  { name: 'rss_cnbc_top', topic: 'business', url: 'https://www.cnbc.com/id/100003114/device/rss/rss.html' },
  { name: 'rss_producthunt', topic: 'tech', url: 'https://www.producthunt.com/feed' },
  { name: 'rss_knowyourmeme', topic: 'culture', url: 'https://knowyourmeme.com/newsfeed.rss' }, // 지금 문서화될 만큼 뜬 밈 = 밈 트렌드 공인 지표
];
for (const f of FEEDS) {
  await safe(f.name, async () => ({ topic: f.topic, ...(f.region ? { region: f.region } : {}), items: rssItems(await t(f.url)) }));
}

// GitHub 공식 검색 API — 최근 일주일 사이 만들어져 별을 쓸어담은 저장소 (2차 생태계·프로젝트 자랑 소재)
await safe('github_new_hot_repos', async () => {
  const since = new Date(Date.now() - 7 * 864e5).toISOString().slice(0, 10);
  const d = await j(`https://api.github.com/search/repositories?q=created:%3E${since}&sort=stars&order=desc&per_page=10`);
  return d.items.map((r) => ({ name: r.full_name, stars: r.stargazers_count, desc: (r.description || '').slice(0, 140), url: r.html_url, lang: r.language }));
});

// 유튜브 쇼츠 바이럴 근사치 — 최근 48시간 · 4분 미만 · 조회수순 (숏폼 트렌드 지표)
for (const region of ['US', 'KR']) {
  await safe(`youtube_shorts_hot_${region.toLowerCase()}`, async () => {
    const key = process.env.YT_API_KEY;
    if (!key) return { skipped: 'set YT_API_KEY to enable' };
    const after = new Date(Date.now() - 2 * 864e5).toISOString();
    const d = await j(`https://www.googleapis.com/youtube/v3/search?part=snippet&type=video&q=%23shorts&videoDuration=short&order=viewCount&publishedAfter=${encodeURIComponent(after)}&regionCode=${region}&relevanceLanguage=${region === 'KR' ? 'ko' : 'en'}&maxResults=10&key=${key}`);
    return d.items.map((v) => ({ id: v.id.videoId, title: v.snippet.title, channel: v.snippet.channelTitle }));
  });
}

// 애플 공식 차트 RSS — 음악 실시간 차트 (entertainment 소재)
await safe('apple_music_top_us', async () => {
  const d = await j('https://rss.marketingtools.apple.com/api/v2/us/music/most-played/10/songs.json');
  return d.feed.results.map((s) => ({ name: s.name, artist: s.artistName }));
});

await safe('hackernews_top', async () => {
  const ids = (await j('https://hacker-news.firebaseio.com/v0/topstories.json')).slice(0, 10);
  return Promise.all(ids.map((id) =>
    j(`https://hacker-news.firebaseio.com/v0/item/${id}.json`).then((i) => ({ title: i.title, score: i.score, url: i.url }))));
});

// 언어판별 위키 조회수 톱 — 발행 지연이 있어 이틀 전 데이터를 쓴다
for (const lang of ['en', 'ko', 'ja', 'de', 'es']) {
  await safe(`wikipedia_top_${lang}`, async () => {
    const d = new Date(Date.now() - 2 * 864e5);
    const p = `${d.getUTCFullYear()}/${String(d.getUTCMonth() + 1).padStart(2, '0')}/${String(d.getUTCDate()).padStart(2, '0')}`;
    const data = await j(`https://wikimedia.org/api/rest_v1/metrics/pageviews/top/${lang}.wikipedia/all-access/${p}`);
    return data.items[0].articles
      .filter((a) => !/^(Main_Page|Special:|Wikipedia:|Portal:|위키백과:|메인_페이지|メインページ|Wikipedia:|Spezial:|Especial:)/.test(a.article))
      .slice(0, 12).map((a) => ({ article: a.article, views: a.views }));
  });
}

// 나라별 유튜브 인기 영상 — media_type:"youtube" 글의 1차 소재 (실존 영상 ID 보장)
for (const region of ['US', 'KR', 'JP', 'GB', 'IN', 'BR']) {
  await safe(`youtube_trending_${region.toLowerCase()}`, async () => {
    const key = process.env.YT_API_KEY;
    if (!key) return { skipped: 'set YT_API_KEY to enable (free quota)' };
    const d = await j(`https://www.googleapis.com/youtube/v3/videos?part=snippet,statistics&chart=mostPopular&regionCode=${region}&maxResults=10&key=${key}`);
    return d.items.map((v) => ({ id: v.id, title: v.snippet.title, channel: v.snippet.channelTitle, views: Number(v.statistics.viewCount) }));
  });
}

writeFileSync(new URL('./trends.json', import.meta.url), JSON.stringify(out, null, 2));
console.error('wrote trends.json');
