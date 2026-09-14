import { notFound, redirect } from 'next/navigation';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { EditorForm } from '@/features/write/sections/EditorForm';

// 본인 글 수정 — 글쓰기와 완전히 같은 에디터(썸네일·주제·툴바·미리보기)에 기존 값 프리필
export async function EditPostPage({ params }: { params: Promise<{ id: string }> }) {
  const user = await getSessionUser();
  if (!user) redirect('/login');
  const { id } = await params;

  const db = await getDb();
  // series 도 함께 읽는다 — 빠뜨리면 폼이 빈 값을 보내고 저장 API 가 그걸 '연재 해제'로 받아, 오타 하나 고쳐도 연재에서 빠졌다
  const post = await db.prepare(`SELECT id, title, body, topic, og_image, series, user_id FROM posts WHERE id = ?`).bind(Number(id))
    .first<{ id: number; title: string; body: string; topic: string | null; og_image: string | null; series: string | null; user_id: number | null }>();
  if (!post || post.user_id !== user.id) notFound();

  return (
    <main className="mx-auto mt-6 max-w-235">
      <EditorForm handle={user.handle} avatarSrc={user.avatar_url} post={post} />
    </main>
  );
}
