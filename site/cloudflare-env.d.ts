// Cloudflare 바인딩 타입 — getCloudflareContext().env 가 이 인터페이스를 사용한다.
interface CloudflareEnv {
  DB: D1Database;
  ASSETS: Fetcher;
  GOOGLE_CLIENT_ID?: string;
  GOOGLE_CLIENT_SECRET?: string;
}
