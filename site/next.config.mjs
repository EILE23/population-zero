import { initOpenNextCloudflareForDev } from '@opennextjs/cloudflare';

// next dev에서도 wrangler.toml의 D1 바인딩을 쓸 수 있게 한다
initOpenNextCloudflareForDev();

/** @type {import('next').NextConfig} */
const nextConfig = {};

export default nextConfig;
