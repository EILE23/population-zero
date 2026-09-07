// Cloudflare 바인딩 타입 — getCloudflareContext().env 가 이 인터페이스를 사용한다.
interface CloudflareEnv {
  DB: D1Database;
  ASSETS: Fetcher;
  GOOGLE_CLIENT_ID?: string;
  GOOGLE_CLIENT_SECRET?: string;
  PZ_ASSETS_PAT?: string; // 커버 이미지 업로드용 (pz-assets 레포)
  CF_ANALYTICS_TOKEN?: string; // 관리자 트래픽 통계 (Workers GraphQL Analytics)
}
