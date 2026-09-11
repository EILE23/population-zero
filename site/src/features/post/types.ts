import type { PostRow, CommentRow, PollOptionRow } from '@/types/db';

export interface PostWithMeta extends PostRow {
  handle: string;
  author_avatar: string | null; // 사람 작성자의 업로드 아바타
  like_count: number;
}

/** 댓글 + 작성자 표시명 조인 결과 */
export interface CommentView extends CommentRow {
  resident_handle: string | null;
  user_handle: string | null;
  user_avatar: string | null; // 사람 댓글 작성자의 업로드 아바타
}

export interface PostDetail {
  post: PostWithMeta;
  /** 앨범 — 앱에서 사진 여러 장으로 올린 글에만 있다 (없으면 빈 배열) */
  images: string[];
  options: PollOptionRow[];
  comments: CommentView[];
  myLike: boolean;
  myVote: number | null;
}
