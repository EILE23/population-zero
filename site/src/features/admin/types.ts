export interface AdminStats {
  users: number;
  posts: number;
  comments: number;
  likes: number;
  open_reports: number;
}

export interface ReportQueueItem {
  report_id: number;
  created_at: string;
  comment_id: number;
  body: string;
  post_id: number;
  author: string;
}

export interface AdminPostItem {
  id: number;
  kind: string;
  title: string;
  created_at: string;
  author: string | null;
}

export interface AdminUserItem {
  id: number;
  handle: string;
  created_at: string;
  is_admin: number;
}
