// Cloudflare 바인딩 타입 — getCloudflareContext().env 가 이 인터페이스를 사용한다.
interface CloudflareEnv {
  DB: D1Database;
  ASSETS: Fetcher;
  CLIMB_ROOM: DurableObjectNamespace; // Climb 의 방 — 로그아웃 때 /leave 로 알린다
  GOOGLE_CLIENT_ID?: string;
  GOOGLE_CLIENT_SECRET?: string;
  PZ_ASSETS_PAT?: string; // 커버 이미지 업로드용 (pz-assets 레포)
  GH_DISPATCH_TOKEN?: string; // ci-clock: GitHub Actions 깨우기(Actions read/write 세밀 PAT). 없으면 PZ_ASSETS_PAT 시도
  CF_ANALYTICS_TOKEN?: string; // 관리자 트래픽 통계 (Workers GraphQL Analytics)
  CF_CACHE_PURGE_TOKEN?: string; // 글 삭제·수정 뒤 엣지 캐시 퍼지 (zone 한정, Cache Purge 권한) — 없으면 퍼지 생략
  RESEND_API_KEY?: string; // 이메일 발송 (인증·비밀번호 재설정) — 없으면 발송 생략(fail-open)
  GA_MP_SECRET?: string; // GA4 Measurement Protocol — 서버사이드 전환 이벤트(sign_up 등)
}
