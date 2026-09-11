import { initOpenNextCloudflareForDev } from '@opennextjs/cloudflare';

// next dev에서만 wrangler.toml의 D1 바인딩 프록시를 연다 (프로드 빌드 오염 방지)
if (process.env.NODE_ENV === 'development') {
  initOpenNextCloudflareForDev();
}

/** @type {import('next').NextConfig} */
const nextConfig = {
  // next/image 미사용 — sharp 네이티브 모듈이 Workers 번들을 깨뜨려서 끔
  images: { unoptimized: true },
  poweredByHeader: false, // x-powered-by 노출 제거
  // Resolve real routes (including /p/[id]/edit) before the decorative SEO slug fallback.
  async rewrites() {
    return { fallback: [{ source: '/p/:id/:slug', destination: '/p/:id' }] };
  },
  // www → apex 301 (중복 색인 방지)
  async redirects() {
    return [{
      source: '/:path*',
      has: [{ type: 'host', value: 'www.population.town' }],
      destination: 'https://population.town/:path*',
      permanent: true,
    }];
  },
  // 보안 응답 헤더 (2026-09 보안 점검) — CSP는 GA·JSON-LD 인라인 때문에 frame-ancestors만 적용
  async headers() {
    return [
      {
        source: '/:path*',
        headers: [
          { key: 'Strict-Transport-Security', value: 'max-age=31536000; includeSubDomains' },
          { key: 'X-Content-Type-Options', value: 'nosniff' },
          { key: 'X-Frame-Options', value: 'DENY' },
          { key: 'Content-Security-Policy', value: "frame-ancestors 'none'" },
          { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
          { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
        ],
      },
      {
        // 개발용 CORS — Expo 웹 미리보기(localhost)에서 API 를 부를 수 있게.
        // localhost 출처에만 열고 자격증명(쿠키)은 허용하지 않는다. 앱은 Bearer 토큰을 쓰므로
        // 쿠키가 필요 없고, 쿠키를 허용하지 않으므로 다른 사이트가 방문자 세션을 악용할 수 없다.
        source: '/api/:path*',
        has: [{ type: 'header', key: 'origin', value: 'http://localhost:8081' }],
        headers: [
          { key: 'Access-Control-Allow-Origin', value: 'http://localhost:8081' },
          { key: 'Access-Control-Allow-Methods', value: 'GET, POST, DELETE, OPTIONS' },
          { key: 'Access-Control-Allow-Headers', value: 'content-type, authorization, accept' },
          { key: 'Vary', value: 'Origin' },
        ],
      },
      {
        // Expo 웹 기본 포트 대안 (19006)
        source: '/api/:path*',
        has: [{ type: 'header', key: 'origin', value: 'http://localhost:19006' }],
        headers: [
          { key: 'Access-Control-Allow-Origin', value: 'http://localhost:19006' },
          { key: 'Access-Control-Allow-Methods', value: 'GET, POST, DELETE, OPTIONS' },
          { key: 'Access-Control-Allow-Headers', value: 'content-type, authorization, accept' },
          { key: 'Vary', value: 'Origin' },
        ],
      },
      {
        // 재설정 토큰이 URL에 실리는 페이지 — 리퍼러·캐시로 새지 않게
        source: '/reset',
        headers: [
          { key: 'Referrer-Policy', value: 'no-referrer' },
          { key: 'Cache-Control', value: 'no-store' },
        ],
      },
    ];
  },
};

export default nextConfig;
