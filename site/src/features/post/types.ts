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
  /** 이 글이 가진/공유한 앨범의 사진 (없으면 빈 배열) */
  images: string[];
  /** 앨범 정보 — originPostId 가 이 글이면 '앨범 글', 아니면 남의(또는 내 옛) 앨범을 공유한 글 */
  album: { id: number; originPostId: number | null; owner: string | null } | null;
  options: PollOptionRow[];
  comments: CommentView[];
  myLike: boolean;
  myVote: number | null;
}
