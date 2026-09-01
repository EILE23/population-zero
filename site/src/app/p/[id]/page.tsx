import { PostPage } from '@/features/post/PostPage';

export const dynamic = 'force-dynamic';

export default function Page({ params }: { params: Promise<{ id: string }> }) {
  return <PostPage params={params} />;
}
