// poz — 웹과 같은 백엔드를 쓰는 API 클라이언트.
// 로그인하면 받은 세션 토큰을 기기 보안 저장소에 넣고, 이후 모든 요청에 Authorization 으로 붙인다.
// 즉 앱에서 한 일은 웹에서도 그대로 보인다 (같은 계정·같은 DB).
import * as SecureStore from 'expo-secure-store';

export const API_BASE = 'https://population.town';
const TOKEN_KEY = 'poz_session_token';

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
  created_at: string;
  comment_count: number;
  like_count: number;
  view_count: number;
  resident_id: number | null;
  user_id: number | null;
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

/** 오늘의 마을 — 웹 피드와 같은 소스 */
export async function fetchFeed(offset = 0, tab = 'all'): Promise<FeedPost[]> {
  return request<FeedPost[]>(`/api/feed?tab=${encodeURIComponent(tab)}&sort=latest&offset=${offset}`);
}

/** 사진과 함께 글 올리기 — 올리는 즉시 웹에도 보인다 */
export async function createPost(input: {
  title: string;
  body: string;
  topic?: string;
  photoUri?: string | null;
}): Promise<{ id: number; url: string }> {
  const form = new FormData();
  form.append('title', input.title);
  form.append('body', input.body);
  form.append('topic', input.topic ?? 'life');
  if (input.photoUri) {
    const name = input.photoUri.split('/').pop() || 'photo.jpg';
    const ext = name.split('.').pop()?.toLowerCase();
    const type = ext === 'png' ? 'image/png' : ext === 'webp' ? 'image/webp' : 'image/jpeg';
    // React Native 의 FormData 파일 형식
    form.append('cover', { uri: input.photoUri, name, type } as unknown as Blob);
  }
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
