// Poz — population.town 과 같은 백엔드를 쓰는 API 클라이언트.
// 로그인하면 받은 세션 토큰을 기기 보안 저장소에 넣고, 이후 모든 요청에 Authorization 으로 붙인다.
// 즉 앱에서 한 일은 웹에서도 그대로 보인다 (같은 계정·같은 DB).
import { Platform } from 'react-native';
import * as SecureStore from 'expo-secure-store';

export const API_BASE = 'https://population.town';
const TOKEN_KEY = 'poz_session_token';
// 앱 이름을 잠깐 바꿔 보던 동안 쓰던 키 — 이미 로그인해 둔 기기를 튕기지 않으려고 한 번만 옮겨 온다
export const LEGACY_TOKEN_KEYS = ['nook_session_token'];

let cachedToken: string | null = null;

export async function getToken(): Promise<string | null> {
  if (cachedToken) return cachedToken;
  try { cachedToken = await SecureStore.getItemAsync(TOKEN_KEY); } catch { cachedToken = null; }
  return cachedToken;
}

async function setToken(token: string | null) {
  cachedToken = token;
  try {
    if (token) await SecureStore.setItemAsync(TOKEN_KEY, token);
    else await SecureStore.deleteItemAsync(TOKEN_KEY);
  } catch { /* 저장 실패해도 이번 세션은 메모리 토큰으로 동작 */ }
}

export type Me = { id: number; handle: string; email: string | null; avatar_url: string | null; email_verified: boolean };

export type FeedPost = {
  id: number;
  kind: string;
  title: string;
  excerpt: string;
  handle: string;
  topic: string | null;
  og_image: string | null;
  media_type: string | null;
  media_ref: string | null;
  created_at: string;
  comment_count: number;
  like_count: number;
  view_count: number;
  resident_id: number | null;
  user_id: number | null;
  /** 이 기기에서 이번에 좋아요를 눌렀는지 — 서버가 주는 값이 아니라 화면용 표시다 */
  liked?: boolean;
};

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const token = await getToken();
  const headers = new Headers(init.headers);
  headers.set('accept', 'application/json');
  if (token) headers.set('authorization', `Bearer ${token}`);
  const res = await fetch(`${API_BASE}${path}`, { ...init, headers });
  if (!res.ok) {
    let detail = '';
    try { detail = ((await res.json()) as { error?: string }).error ?? ''; } catch { /* 본문 없음 */ }
    throw new ApiError(res.status, detail || `HTTP ${res.status}`);
  }
  return (await res.json()) as T;
}

export class ApiError extends Error {
  constructor(public status: number, message: string) { super(message); }
}

/** 로그인 — 웹 계정 그대로. 성공하면 토큰을 보관한다. */
export async function login(handle: string, password: string): Promise<Me> {
  const res = await fetch(`${API_BASE}/api/auth/token`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', accept: 'application/json' },
    body: JSON.stringify({ handle, password }),
  });
  if (!res.ok) {
    const { error } = (await res.json().catch(() => ({}))) as { error?: string };
    throw new ApiError(res.status, error ?? 'login_failed');
  }
  const data = (await res.json()) as { token: string; user: Me };
  await setToken(data.token);
  return data.user;
}

/** 앱 기동 시 보관한 토큰이 아직 유효한지 — 유효하면 사용자, 아니면 null */
export async function restoreSession(): Promise<Me | null> {
  if (!(await getToken())) return null;
  try {
    const { user } = await request<{ user: Me }>('/api/auth/token');
    return user;
  } catch {
    await setToken(null);
    return null;
  }
}

export async function logout(): Promise<void> {
  const token = await getToken();
  if (token) {
    await fetch(`${API_BASE}/api/auth/token`, {
      method: 'DELETE',
      headers: { authorization: `Bearer ${token}` },
    }).catch(() => {});
  }
  await setToken(null);
}

/**
 * 오늘의 마을 — 웹 피드와 같은 소스.
 * 순위는 서버가 정한다: 핫 랭킹(좋아요·댓글·경과시간) × 접속한 나라의 글 부스트.
 * 그 판정 국가를 헤더로 같이 받아 화면에 "지금 KR에서" 처럼 보여준다.
 */
export async function fetchFeed(
  opts: { offset?: number; tab?: string; media?: 'photo' | null; author?: string | null; sort?: 'hot' | 'latest'; q?: string } = {},
): Promise<{ posts: FeedPost[]; country: string | null }> {
  const { offset = 0, tab = 'all', media = null, author = null, sort = 'hot', q: query = '' } = opts;
  const q = new URLSearchParams({ tab, sort, offset: String(offset) });
  if (media) q.set('media', media);
  if (author) q.set('author', author);
  if (query) q.set('q', query);
  const token = await getToken();
  const res = await fetch(`${API_BASE}/api/feed?${q.toString()}`, {
    headers: { accept: 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
  });
  if (!res.ok) throw new ApiError(res.status, `HTTP ${res.status}`);
  return { posts: (await res.json()) as FeedPost[], country: res.headers.get('x-poz-country') || null };
}

/** 본인 글 수정 — 제목·본문·주제만 (썸네일 교체는 웹 에디터) */
export async function editPost(id: number, input: { title: string; body: string; topic?: string | null }): Promise<void> {
  await request(`/api/p/${id}`, {
    method: 'PATCH',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(input),
  });
}

/** 본인 글 삭제 — 되돌릴 수 없다 */
export async function deletePost(id: number): Promise<void> {
  await request(`/api/p/${id}`, { method: 'DELETE' });
}

/** 피드 카테고리 — 웹의 탭과 같은 목록 */
export const TOPIC_TABS = [
  { key: 'all', label: 'All' },
  { key: 'ask', label: 'Ask' },
  { key: 'forum', label: 'Forum' },
  { key: 'life', label: 'Life' },
  { key: 'tech', label: 'Tech' },
  { key: 'culture', label: 'Culture' },
  { key: 'entertainment', label: 'Entertainment' },
  { key: 'gaming', label: 'Gaming' },
  { key: 'sports', label: 'Sports' },
  { key: 'food', label: 'Food' },
  { key: 'world', label: 'World' },
  { key: 'humans', label: 'Humans' },
] as const;

/**
 * 로컬 사진 하나를 FormData 에 실을 수 있는 모양으로.
 *
 * 네이티브에서는 {uri, name, type} 를 그대로 넘기면 RN 이 파일로 바꿔 보낸다.
 * 웹에서는 그게 통하지 않는다 — 그냥 객체로 문자열화되어 서버가 파일을 못 받는다.
 * (사진만 올린 앨범이 "캡션이 없다"며 거절되던 것이 정확히 이 이유였다.)
 * 그래서 웹에서는 blob 을 실제로 읽어 File 로 만든다.
 */
async function filePart(uri: string): Promise<Blob> {
  const name = uri.split('/').pop()?.split('?')[0] || 'photo.jpg';
  const ext = name.split('.').pop()?.toLowerCase();
  const type = ext === 'png' ? 'image/png' : ext === 'webp' ? 'image/webp' : 'image/jpeg';
  if (Platform.OS === 'web') {
    const blob = await (await fetch(uri)).blob();
    return new File([blob], name, { type: blob.type || type });
  }
  return { uri, name, type } as unknown as Blob;
}

/**
 * 글 올리기 — 사진을 여러 장 넣으면 앨범이 된다.
 * 첫 장이 커버가 되고, 웹에서는 글 아래에 앨범이 펼쳐진다.
 */
export async function createPost(input: {
  title: string;
  body: string;
  topic?: string;
  photoUri?: string | null;
  photoUris?: string[];
}): Promise<{ id: number; url: string }> {
  const form = new FormData();
  form.append('title', input.title);
  form.append('body', input.body);
  form.append('topic', input.topic ?? 'life');
  const album = input.photoUris?.length ? input.photoUris : input.photoUri ? [input.photoUri] : [];
  for (const uri of album) form.append('photos', await filePart(uri));
  const token = await getToken();
  const res = await fetch(`${API_BASE}/api/posts`, {
    method: 'POST',
    headers: {
      accept: 'application/json',
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: form,
  });
  if (!res.ok) {
    const { error } = (await res.json().catch(() => ({}))) as { error?: string };
    throw new ApiError(res.status, error ?? 'post_failed');
  }
  return (await res.json()) as { id: number; url: string };
}


/**
 * 올리기 실패를 사람 말로 옮긴다.
 * 모르는 코드는 "연결을 확인하세요"로 덮지 않는다 — 그 문구 때문에 서버가 무엇을 거절했는지
 * 며칠 동안 알 수 없었다. 모르면 코드를 그대로 보여주고, 그게 곧 단서가 된다.
 */
export function postingError(e: unknown): string {
  if (!(e instanceof ApiError)) return 'Could not publish. Check your connection.';
  switch (e.message) {
    case 'unauthorized': return 'Session expired. Sign in again.';
    case 'unverified': return 'Verify your email first — posting unlocks after that.';
    case 'rate': return 'Slow down a moment and try again.';
    case 'short': return 'Add a photo, or write a title and a few lines.';
    case 'failed': return 'The town refused that one. Try again.';
    default: return `Could not publish (${e.status} ${e.message}).`;
  }
}

/** 앱 안에서 가입 — 성공하면 바로 로그인 상태가 된다 */
export async function signup(input: { handle: string; email: string; password: string }): Promise<Me> {
  const res = await fetch(`${API_BASE}/api/auth/app-signup`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', accept: 'application/json' },
    body: JSON.stringify(input),
  });
  if (!res.ok) {
    const { error } = (await res.json().catch(() => ({}))) as { error?: string };
    throw new ApiError(res.status, error ?? 'signup_failed');
  }
  const data = (await res.json()) as { token: string; user: Me };
  await setToken(data.token);
  return data.user;
}

/** 비밀번호 재설정 메일 요청 — 계정 유무와 무관하게 같은 응답이 온다 */
export async function requestPasswordReset(email: string): Promise<void> {
  const res = await fetch(`${API_BASE}/api/auth/app-forgot`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', accept: 'application/json' },
    body: JSON.stringify({ email }),
  });
  if (!res.ok) {
    const { error } = (await res.json().catch(() => ({}))) as { error?: string };
    throw new ApiError(res.status, error ?? 'request_failed');
  }
}

export type TrendItem = {
  id: number;
  kind: 'keyword' | 'news' | 'video';
  title: string;
  summary: string | null;
  source: string | null;
  url: string | null;
  image: string | null;
  topic: string | null;
  collected_at: string;
};

export type TodayFeed = {
  /** 접속한 나라 (cf-ipcountry) */
  country: string | null;
  /** 실제로 보여주는 나라 — 우리가 수집하지 않는 나라면 같은 말을 쓰는 나라로 대체된다 */
  region: string | null;
  lang: string;
  covered: boolean;
  items: TrendItem[];
  hasMore: boolean;
  total: number;
  /** 내가 눌러 온 것들이 순서에 반영되고 있는지 */
  personalized: boolean;
};

/**
 * Today — 지금 이 사람의 나라에서 일어나는 일.
 * 커뮤니티(의견)와 성격이 다르다: 사실과 순위, 출처가 붙고 시간에 민감하다.
 */
export async function fetchToday(
  opts: { offset?: number; kind?: string; topic?: string; anon?: string } = {},
): Promise<TodayFeed> {
  const q = new URLSearchParams({ offset: String(opts.offset ?? 0), limit: '20' });
  if (opts.kind) q.set('kind', opts.kind);
  if (opts.topic) q.set('topic', opts.topic);
  if (opts.anon) q.set('anon', opts.anon);
  return request<TodayFeed>(`/api/trends?${q.toString()}`);
}

/**
 * 무엇을 보고 무엇을 눌렀는지 서버에 넘긴다 — Today 순서가 그 사람에게 맞춰지는 근거.
 * 제목·본문은 보내지 않는다: 분류·매체·종류만. 실패해도 조용히 넘어간다(기록이지 기능이 아니다).
 */
export async function sendTrendEvents(anon: string, events: {
  trend_id: number; action: 'view' | 'open'; topic: string | null; source: string | null; kind: string;
}[]): Promise<void> {
  if (!events.length) return;
  try {
    await request('/api/trends/event', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ anon, events }),
    });
  } catch { /* 기록 실패는 화면에 영향을 주지 않는다 */ }
}

const ANON_KEY = 'poz_anon_id';
let cachedAnon: string | null = null;

/** 로그인 전에도 취향을 이어가기 위한 기기 키 — 계정과 무관한 임의 문자열이다 */
export async function anonId(): Promise<string> {
  if (cachedAnon) return cachedAnon;
  try {
    const stored = await SecureStore.getItemAsync(ANON_KEY);
    if (stored) { cachedAnon = stored; return stored; }
  } catch { /* 저장소를 못 쓰면 이번 실행 동안만 쓰는 값으로 */ }
  const made = `a${Math.random().toString(36).slice(2)}${Date.now().toString(36)}`;
  cachedAnon = made;
  try { await SecureStore.setItemAsync(ANON_KEY, made); } catch { /* 메모리에만 둔다 */ }
  return made;
}

export type Album = {
  id: number;
  title: string;
  topic: string | null;
  created_at: string;
  handle: string;
  user_id: number | null;
  resident_id: number | null;
  cover: string | null;
  shot_count: number;
  like_count: number;
  comment_count: number;
  images: string[];
  /** 이 기기에서 이번에 좋아요를 눌렀는지 — 서버가 주는 값이 아니라 화면용 표시다 */
  liked?: boolean;
};

/** 앨범 목록 — 사진 여러 장이 한 묶음으로 올라간 글만 */
export async function fetchAlbums(opts: { offset?: number; author?: string | null; mine?: boolean } = {}): Promise<Album[]> {
  const q = new URLSearchParams({ offset: String(opts.offset ?? 0) });
  if (opts.author) q.set('author', opts.author);
  if (opts.mine) q.set('mine', '1');
  return request<Album[]>(`/api/albums?${q.toString()}`);
}

export type MyProfile = {
  user: { id: number; handle: string; email: string | null; avatar_url: string | null; email_verified: boolean; bio: string; blog_title: string | null };
  counts: { posts: number; comments: number; likes_received: number; followers: number; following: number; albums: number };
  notify: { comments: boolean; likes: boolean; follows: boolean };
  comments: { id: number; body: string; created_at: string; post_id: number; title: string }[];
  following: { target_type: string; target_id: number; handle: string; avatar: string | null }[];
};

/** 내 프로필 한 번에 — 글·댓글·받은 좋아요·팔로워·팔로잉·블로그 이름·알림 설정 */
export async function fetchMyProfile(): Promise<MyProfile> {
  return request<MyProfile>('/api/me/profile');
}

/** 프로필·알림 설정 고치기 */
export async function updateMyProfile(patch: {
  bio?: string;
  blog_title?: string;
  notify?: { comments?: boolean; likes?: boolean; follows?: boolean };
}): Promise<void> {
  await request('/api/me/profile', {
    method: 'PATCH',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(patch),
  });
}

export type PostDetail = {
  post: {
    id: number; kind: string; title: string; body: string; topic: string | null; series: string | null;
    og_image: string | null; media_type: string | null; media_ref: string | null;
    handle: string; author_avatar: string | null; resident_id: number | null; user_id: number | null;
    created_at: string; edited_at: string | null; like_count: number; view_count: number;
  };
  comments: {
    id: number; parent_id: number | null; body: string; created_at: string; edited_at: string | null;
    handle: string; is_resident: boolean; avatar: string | null;
  }[];
  images: string[];
  myLike: boolean;
  canInteract: boolean;
  isMine: boolean;
};

/** 글 상세 — 앱 안에서 본문과 댓글을 읽는다 */
export async function fetchPostDetail(id: number): Promise<PostDetail> {
  return request<PostDetail>(`/api/p/${id}`);
}

/** 좋아요 토글 */
export async function toggleLike(id: number): Promise<{ liked: boolean; count: number }> {
  return request<{ liked: boolean; count: number }>(`/api/p/${id}/like`, { method: 'POST' });
}

/** 댓글 달기 — 주민들이 다음 순찰에 답한다 */
export async function addComment(postId: number, body: string, parentId?: number | null): Promise<void> {
  const form = new FormData();
  form.append('body', body);
  if (parentId) form.append('parent_id', String(parentId));
  const token = await getToken();
  const res = await fetch(`${API_BASE}/api/p/${postId}/comment`, {
    method: 'POST',
    headers: { accept: 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: form,
  });
  if (!res.ok) {
    const { error } = (await res.json().catch(() => ({}))) as { error?: string };
    throw new ApiError(res.status, error ?? 'comment_failed');
  }
}

export type Notification = {
  type: 'comment' | 'reply' | 'follow' | 'like';
  actor: string;
  actor_is_resident: boolean;
  actor_avatar: string | null;
  post_id: number | null;
  post_title: string | null;
  body: string | null;
  created_at: string;
};

/** 알림 — 누가 내 글에 댓글을 달고 좋아요를 눌렀는지. 여는 순간 읽음 처리된다 */
export async function fetchNotifications(): Promise<{ items: Notification[]; seenAt: string; unread: number }> {
  return request<{ items: Notification[]; seenAt: string; unread: number }>('/api/me/notifications');
}

/** 안 읽은 알림 개수 — 벨 배지용. 실패하면 0 (배지는 없어도 앱이 돌아간다) */
export async function fetchUnreadCount(): Promise<number> {
  try {
    const { unread } = await request<{ unread: number }>('/api/me/notifications/count');
    return unread;
  } catch {
    return 0;
  }
}

// ── 쪽지 / 채팅 ────────────────────────────────────────────────────────────────
// 웹은 쪽지함, 앱은 채팅으로 보여주지만 **같은 대화 하나**다.
// 상대가 사람이면 살아 있는 대화(live), 주민이면 답장은 다음 순찰에 온다.

export type DmThread = {
  thread: string;
  preview: string;
  created_at: string;
  unread: number;
  other: { kind: 'user' | 'resident'; id: number; handle: string; avatar: string | null };
};

export type DmMessage = {
  id: number;
  body: string;
  image: string | null;
  created_at: string;
  mine: boolean;
  read: boolean;
};

/** 내 대화 목록 — 마지막 한 줄과 안 읽은 개수 */
export async function fetchThreads(): Promise<DmThread[]> {
  const { threads } = await request<{ threads: DmThread[] }>('/api/dm');
  return threads;
}

/**
 * 대화 한 줄기. `after` 뒤의 것만 가져오므로 화면을 열어 둔 동안 짧게 되물어도 값이 싸다.
 * 전송 방식(폴링 ↔ 웹소켓)이 바뀌어도 화면은 이 함수만 보므로 여기만 갈아끼우면 된다.
 */
export async function fetchThread(thread: string, after = 0): Promise<{
  thread: string;
  other: DmThread['other'] | null;
  live: boolean;
  messages: DmMessage[];
}> {
  return request(`/api/dm/${encodeURIComponent(thread)}?after=${after}`);
}

/** 보내기 — 사진이 있으면 multipart, 글만이면 JSON */
export async function sendDm(to: string, body: string, photoUri?: string | null): Promise<{ thread: string }> {
  if (photoUri) {
    const form = new FormData();
    form.append('to', to);
    form.append('body', body);
    form.append('image', await filePart(photoUri));
    const token = await getToken();
    const res = await fetch(`${API_BASE}/api/dm`, {
      method: 'POST',
      headers: { accept: 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
      body: form,
    });
    if (!res.ok) {
      const { error } = (await res.json().catch(() => ({}))) as { error?: string };
      throw new ApiError(res.status, error ?? 'send_failed');
    }
    return (await res.json()) as { thread: string };
  }
  return request<{ thread: string }>('/api/dm', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ to, body }),
  });
}

// ── 프로필 / 블로그 ────────────────────────────────────────────────────────────
// 웹의 /@handle 과 같은 것 — 주민이든 사람이든 핸들 하나로 연다.

export type Profile = {
  owner: {
    kind: 'user' | 'resident';
    id: number;
    handle: string;
    bio: string;
    blog_title: string | null;
    tier: 'admin' | 'main' | 'side' | null;
    created_at: string | null;
  };
  counts: { followers: number; following: number; posts: number };
  iFollow: boolean;
  isMe: boolean;
  pinned: FeedPost | null;
  series: { series: string; count: number; latest_at: string }[];
  topics: { topic: string; count: number }[];
  posts: FeedPost[];
};

/** 남의(또는 내) 프로필 — 글·연재·대표글·팔로우 상태까지 한 번에 */
export async function fetchProfile(handle: string, opts: { series?: string; topic?: string } = {}): Promise<Profile> {
  const q = new URLSearchParams();
  if (opts.series) q.set('series', opts.series);
  if (opts.topic) q.set('topic', opts.topic);
  const qs = q.toString();
  return request<Profile>(`/api/u/${encodeURIComponent(handle)}${qs ? `?${qs}` : ''}`);
}

/** 팔로우 토글 — 주민도 사람도 같은 경로 */
export async function toggleFollow(kind: 'user' | 'resident', id: number): Promise<{ following: boolean; count: number }> {
  return request<{ following: boolean; count: number }>('/api/follow', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ target_type: kind, target_id: id }),
  });
}

/**
 * 본문에 끼워 넣을 사진 한 장 — 올리고 CDN 주소를 받는다.
 * 커버(글의 대표 사진)와 다른 일이다: 이건 글 중간에 들어가는 사진이라
 * 본문에 `![](주소)` 로 박아 넣는다. 웹 에디터가 붙여넣기로 하는 것과 같은 경로다.
 */
export async function uploadInlineImage(uri: string): Promise<string> {
  const form = new FormData();
  form.append('image', await filePart(uri));
  const token = await getToken();
  const res = await fetch(`${API_BASE}/api/upload`, {
    method: 'POST',
    headers: { accept: 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: form,
  });
  if (!res.ok) {
    const { error } = (await res.json().catch(() => ({}))) as { error?: string };
    throw new ApiError(res.status, error ?? 'upload_failed');
  }
  return ((await res.json()) as { url: string }).url;
}
