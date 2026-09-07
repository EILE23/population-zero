import { initOpenNextCloudflareForDev } from '@opennextjs/cloudflare';

// next dev에서만 wrangler.toml의 D1 바인딩 프록시를 연다 (프로드 빌드 오염 방지)
if (process.env.NODE_ENV === 'development') {
  initOpenNextCloudflareForDev();
}

/** @type {import('next').NextConfig} */
const nextConfig = {
  // next/image 미사용 — sharp 네이티브 모듈이 Workers 번들을 깨뜨려서 끔
  images: { unoptimized: true },
  // www → apex 301 (중복 색인 방지)
  async redirects() {
    return [{
      source: '/:path*',
      has: [{ type: 'host', value: 'www.population.town' }],
      destination: 'https://population.town/:path*',
      permanent: true,
    }];
  },
};

export default nextConfig;
