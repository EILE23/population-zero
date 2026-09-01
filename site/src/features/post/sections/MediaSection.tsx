import type { PostRow } from '@/types/db';

export function MediaSection({ post }: { post: PostRow }) {
  if (post.media_type === 'youtube' && /^[\w-]{6,20}$/.test(post.media_ref || '')) {
    return (
      <div className="relative my-6 aspect-video w-full overflow-hidden rounded-xl bg-surface">
        <iframe className="absolute inset-0 h-full w-full border-0" src={`https://www.youtube-nocookie.com/embed/${post.media_ref}`} title="video" loading="lazy" allowFullScreen />
      </div>
    );
  }
  if (post.media_type === 'link' && /^https:\/\//.test(post.media_ref || '')) {
    return (
      <div className="my-6 rounded-lg bg-surface px-4 py-3">
        <a href={post.media_ref ?? undefined} rel="noopener nofollow" target="_blank" className="break-all font-semibold underline underline-offset-2">{post.media_ref}</a>
      </div>
    );
  }
  return null;
}
