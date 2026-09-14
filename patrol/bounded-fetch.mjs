// 상한이 있는 HTML 읽기 — 순찰의 링크 미리보기·og:image 추출이 공유한다.
//
// `(await res.text()).slice(0, N)` 는 상한이 아니다: 응답 전체를 메모리에 받은 '뒤에' 자른다.
// 느리거나 끝없이 보내는 페이지 하나가 수집기의 메모리와 대역폭을 다 쓸 수 있다.
// 여기서는 스트림을 바이트 단위로 세다가 상한에 닿으면 연결을 끊고, 마감 시한은 리다이렉트부터
// 본문 읽기까지 이어진다. Content-Length 는 믿지 않는다 (없거나 거짓일 수 있다).
export async function fetchHtmlBounded(url, { maxBytes = 200_000, timeoutMs = 7000, userAgent = 'Mozilla/5.0 (compatible; PopulationZero/1.0; link preview)' } = {}) {
  const ctrl = new AbortController();
  const deadline = setTimeout(() => ctrl.abort(), timeoutMs);
  let reader;
  try {
    const res = await fetch(url, { signal: ctrl.signal, redirect: 'follow', headers: { 'user-agent': userAgent } });
    if (!res.ok || !(res.headers.get('content-type') || '').includes('html')) return null;
    reader = res.body?.getReader();
    if (!reader) return null;
    const chunks = [];
    let received = 0;
    while (received < maxBytes) {
      const { done, value } = await reader.read();
      if (done) break;
      chunks.push(value);
      received += value.byteLength;
    }
    // 마지막 청크가 상한을 넘겼으면 바이트 단위로 자른다 — 다바이트 문자가 잘려도 TextDecoder 가 대체 문자로 처리한다
    const buf = new Uint8Array(Math.min(received, maxBytes));
    let off = 0;
    for (const c of chunks) {
      const take = Math.min(c.byteLength, buf.length - off);
      if (take <= 0) break;
      buf.set(c.subarray(0, take), off);
      off += take;
    }
    return new TextDecoder('utf-8', { fatal: false }).decode(buf);
  } catch { return null; } finally {
    clearTimeout(deadline);
    reader?.cancel().catch(() => {});
  }
}
