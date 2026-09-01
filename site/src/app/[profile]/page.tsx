import { notFound } from 'next/navigation';
import { ProfileBlogPage } from '@/features/blog/ProfileBlogPage';

export const dynamic = 'force-dynamic';

// velog식 /@handle — '@'로 시작하는 세그먼트만 프로필로 취급한다
export default async function Page({ params }: { params: Promise<{ profile: string }> }) {
  const { profile } = await params;
  const decoded = decodeURIComponent(profile);
  if (!decoded.startsWith('@')) notFound();
  return <ProfileBlogPage slug={decoded.slice(1)} />;
}
