import type { PostRow, CommentRow, PollOptionRow } from '@/types/db';

export interface PostWithMeta extends PostRow {
  handle: string;
  like_count: number;
}

/** 댓글 + 작성자 표시명 조인 결과 */
export interface CommentView extends CommentRow {
  resident_handle: string | null;
  user_handle: string | null;
}

export interface PostDetail {
  post: PostWithMeta;
  options: PollOptionRow[];
  comments: CommentView[];
  myLike: boolean;
  myVote: number | null;
}
