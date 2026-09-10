// JSON-LD를 <script> 안에 넣기 전 안전하게 직렬화한다.
//
// JSON.stringify 결과에는 사용자가 쓴 `</script>` 가 그대로 남고, 브라우저 HTML 파서는 그것이
// JSON 문자열 안에 있든 말든 스크립트의 끝으로 읽는다. 글 제목·본문·블로그 소개에
// `</script><script>…</script>` 를 저장해 두면 그 페이지를 여는 모든 사람에게 실행되는
// 저장형 XSS 가 된다. React 본문 렌더링이 안전해도 이 경로는 별개다.
//
// `<` 만 막아도 스크립트 종료는 불가능해지지만, `&`(엔티티 트릭)와
// U+2028/U+2029(자바스크립트가 줄바꿈으로 취급해 파싱을 깨뜨림)까지 함께 이스케이프한다.
// 이스케이프해도 JSON 으로는 같은 값으로 파싱되므로 구조화 데이터의 의미는 변하지 않는다.
//
// **JSON-LD 를 심는 자리는 예외 없이 이 함수를 거친다.**

// U+2028/U+2029 는 소스에 날것으로 두지 않는다 — 편집기·도구에 따라 줄바꿈으로 읽혀 파일이 깨진다.
const LINE_SEP = String.fromCharCode(0x2028);
const PARA_SEP = String.fromCharCode(0x2029);

const ESCAPES: Record<string, string> = {
  '<': '\\u003c',
  '>': '\\u003e',
  '&': '\\u0026',
  [LINE_SEP]: '\\u2028',
  [PARA_SEP]: '\\u2029',
};

const DANGEROUS = new RegExp(`[<>&${LINE_SEP}${PARA_SEP}]`, 'g');

export function safeJsonLd(data: unknown): string {
  return JSON.stringify(data).replace(DANGEROUS, (c) => ESCAPES[c]);
}
