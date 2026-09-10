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
  // /p/{id}/{slug} → /p/{id} 로 내부 렌더 (슬러그는 SEO·가독성용 장식, id 가 정본). /edit 는 정적이라 안 걸린다.
  async rewrites() {
    return [{ source: '/p/:id/:slug', destination: '/p/:id' }];
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
