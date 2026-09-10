// 출처 게이트 — 사실형 글이 "그날 실제로 읽은 출처"에서 나왔다는 증거를 요구한다.
//
// PATROL.md 의 최우선 규칙은 "없는 사실을 쓰지 말 것"인데, 지금까지 그걸 확인하는 코드는 없었다.
// 여기서 검사하는 것은 진실성 자체가 아니라 그 규칙을 지켰다는 흔적이다:
//   ① 모든 글이 사실형인지 아닌지(factual_claims)를 스스로 밝혔는가
//   ② 사실형이면 https 출처를 달았는가
//   ③ 그 출처가 독자에게도 보이는가 (본문 링크 · media_ref · og_from)
//   ④ 그 출처가 이번 실행에서 실제로 수집한 것과 이어지는가 (모델 기억에서 지어낸 링크 배제)
// 개인 이야기·일기·질문 글은 대상이 아니다 — factual_claims: false 로 밝히면 통과한다.

const URL_IN_TEXT = /https?:\/\/[^\s)\]"'\\]+/g;

export function hostOf(u) {
  try { return new URL(u).host.replace(/^www\./, ''); } catch { return null; }
}

/** trends.json 등 이번 실행의 수집물에서 실제로 손에 넣은 URL 집합을 만든다. */
export function collectedUrls(...blobs) {
  const urls = new Set();
  for (const blob of blobs) {
    if (!blob) continue;
    const text = typeof blob === 'string' ? blob : JSON.stringify(blob);
    for (const m of text.matchAll(URL_IN_TEXT)) urls.add(m[0]);
  }
  return urls;
}

/**
 * @returns {{problems: string[], checked: number}} 문제 목록 (빈 배열이면 통과)
 */
export function checkSources(posts = [], collected = new Set()) {
  const collectedHosts = new Set([...collected].map(hostOf).filter(Boolean));
  const problems = [];
  let checked = 0;

  for (const p of posts) {
    if (p?.kind === 'fiction') continue; // 창작은 사실 주장이 아니다 (스스로 소설임을 밝힌다)
    checked++;
    const title = String(p?.title || '(제목 없음)').slice(0, 45);
    const declared = (Array.isArray(p?.sources) ? p.sources : [])
      .map((s) => (typeof s === 'string' ? s : s?.url))
      .filter((u) => typeof u === 'string' && /^https:\/\/\S+$/.test(u));

    if (p?.factual_claims === undefined) { problems.push(`"${title}": factual_claims 미표기`); continue; }
    if (p.factual_claims !== true) continue; // 개인 이야기·질문 — 출처 요구 대상 아님

    if (!declared.length) { problems.push(`"${title}": 사실형인데 sources 없음`); continue; }

    const visible = [
      ...String(p.body || '').matchAll(URL_IN_TEXT),
    ].map((m) => m[0]);
    if (p.og_from) visible.push(p.og_from);
    if (p.media_type === 'link' && p.media_ref) visible.push(p.media_ref);
    if (!visible.length) problems.push(`"${title}": 출처가 독자에게 보이지 않음 (본문 링크·media_ref·og_from 중 하나 필요)`);

    // 수집물이 있을 때만 대조한다 (light 순찰은 트렌드를 읽지 않아 대조 기준이 없다)
    if (collectedHosts.size) {
      const unseen = declared.filter((u) => !collected.has(u) && !collectedHosts.has(hostOf(u)));
      if (unseen.length === declared.length) {
        problems.push(`"${title}": 출처가 이번 실행 수집분과 무관 (${unseen.slice(0, 2).map(hostOf).join(', ')})`);
      }
    }
  }
  return { problems, checked };
}
