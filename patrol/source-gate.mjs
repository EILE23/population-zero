// 출처 게이트 — 사실형 글이 "그날 실제로 읽은 출처"에서 나왔다는 증거를 요구한다.
//
// PATROL.md 의 최우선 규칙은 "없는 사실을 쓰지 말 것"인데, 그걸 확인하는 코드가 없으면 규칙은 희망일 뿐이다.
// 여기서 보는 것은 진실성 자체가 아니라 규칙을 지켰다는 흔적이다:
//   ① 모든 글이 사실형인지 아닌지(factual_claims)를 스스로 밝혔는가
//   ② 사실형이면 https 출처를 달았는가
//   ③ **선언한 그 출처가** 독자에게도 보이는가 (본문 링크 · media_ref · og_from)
//   ④ **선언한 그 출처가** 이번 실행에서 실제로 수집한 URL 과 같은가
//
// ③④ 는 일부러 정확 일치다. "같은 매체면 통과"로 두면 BBC 기사 하나를 읽고 존재하지도 않는
// BBC URL 을 지어내는 것을 막지 못한다. 실재하지 않는 기사를 인용하는 것이 바로 이 게이트가
// 막으려는 사고다. 개인 이야기·일기·질문 글은 대상이 아니다 — factual_claims: false 면 통과한다.

const URL_IN_TEXT = /https?:\/\/[^\s)\]"'\\]+/g;

/** 비교용 URL 정규화 — 추적 파라미터·앵커·끝 슬래시·www 차이로 같은 기사를 다르게 보지 않게 */
export function normalizeUrl(u) {
  try {
    const url = new URL(String(u).trim());
    if (url.protocol !== 'http:' && url.protocol !== 'https:') return null;
    url.hash = '';
    url.protocol = 'https:';
    url.host = url.host.replace(/^www\./, '').toLowerCase();
    for (const k of [...url.searchParams.keys()]) {
      // utm_* 는 접두사 — `^utm_$` 로 두면 utm_source 가 걸리지 않는다
      if (/^(utm_\w*|fbclid|gclid|igshid|mc_cid|mc_eid|ref|ref_src|si|cmpid|smid)$/i.test(k)) url.searchParams.delete(k);
    }
    let s = url.toString();
    if (s.endsWith('/') && url.pathname !== '/') s = s.slice(0, -1);
    return s;
  } catch { return null; }
}

export function hostOf(u) {
  try { return new URL(u).host.replace(/^www\./, '').toLowerCase(); } catch { return null; }
}

/** trends.json 등 이번 실행의 수집물에서 실제로 손에 넣은 URL 집합 (정규화된 형태) */
export function collectedUrls(...blobs) {
  const urls = new Set();
  for (const blob of blobs) {
    if (!blob) continue;
    const text = typeof blob === 'string' ? blob : JSON.stringify(blob);
    for (const m of text.matchAll(URL_IN_TEXT)) {
      const n = normalizeUrl(m[0]);
      if (n) urls.add(n);
    }
  }
  return urls;
}

/**
 * @param {object[]} posts patrol-output.json 의 posts
 * @param {Set<string>} collected 이번 실행에서 수집한 URL(정규화)
 * @param {object} [opts] { requireCollected: 수집물이 없어도 사실형 글을 막을지 }
 * @returns {{problems: string[], checked: number}} 빈 problems 면 통과
 */
export function checkSources(posts = [], collected = new Set(), opts = {}) {
  const problems = [];
  let checked = 0;

  for (const p of posts) {
    if (p?.kind === 'fiction') continue; // 창작은 사실 주장이 아니다 (스스로 소설임을 밝힌다)
    checked++;
    const title = String(p?.title || '(제목 없음)').slice(0, 45);
    const declared = (Array.isArray(p?.sources) ? p.sources : [])
      .map((s) => (typeof s === 'string' ? s : s?.url))
      .filter((u) => typeof u === 'string' && /^https:\/\/\S+$/.test(u))
      .map(normalizeUrl)
      .filter(Boolean);

    // 타입을 먼저 강제한다 — 문자열 "true" 나 1 을 사실 선언으로 받아 주면 검사를 통째로 건너뛴다
    if (typeof p?.factual_claims !== 'boolean') {
      problems.push(`"${title}": factual_claims 가 boolean 이 아님 (${JSON.stringify(p?.factual_claims)})`);
      continue;
    }
    if (!p.factual_claims) continue; // 개인 이야기·질문 — 출처 요구 대상 아님
    if (!declared.length) { problems.push(`"${title}": 사실형인데 sources 없음 (https 만 인정)`); continue; }

    // 독자에게 보이는 링크 — 본문 링크와 링크 글의 media_ref 만 해당한다.
    // og_from 은 커버 이미지를 뽑는 입력일 뿐 글 어디에도 렌더되지 않으므로 '노출'로 치지 않는다.
    const visible = new Set();
    for (const m of String(p.body || '').matchAll(URL_IN_TEXT)) { const n = normalizeUrl(m[0]); if (n) visible.add(n); }
    if (p.media_type === 'link' && p.media_ref) { const n = normalizeUrl(p.media_ref); if (n) visible.add(n); }

    // 핵심: **같은 하나의 URL** 이 (수집됐고) ∧ (독자에게 보여야) 한다.
    // 예전엔 두 조건을 각각 다른 URL 이 만족해도 통과해서, 수집한 A 를 근거로 내밀고
    // 본문에는 아무 데서도 읽지 않은 B 만 보여 주는 글이 그대로 나갔다.
    const proven = declared.filter((u) => visible.has(u) && (collected.size === 0 || collected.has(u)));
    if (!proven.length) {
      const shown = declared.filter((u) => visible.has(u));
      const known = declared.filter((u) => collected.has(u));
      if (!shown.length) problems.push(`"${title}": 선언한 출처가 독자에게 보이지 않음 (본문 링크 또는 링크 글의 media_ref 여야 함)`);
      else if (collected.size && !known.length) problems.push(`"${title}": 출처가 이번 실행 수집분에 없음 (${declared.slice(0, 2).map(hostOf).join(', ')})`);
      else problems.push(`"${title}": 수집한 출처와 독자에게 보이는 출처가 서로 다름 (같은 URL 이어야 함)`);
    }
    if (!collected.size && opts.requireCollected) {
      problems.push(`"${title}": 이번 실행에 수집 증거가 없어 사실형 글을 낼 수 없음`);
    }
  }
  return { problems, checked };
}
