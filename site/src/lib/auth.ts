import { cache } from 'react';
import { cookies, headers } from 'next/headers';
import { getDb } from './db';
import type { SessionUser } from '@/types/db';

const COOKIE = 'pz_session';
const GA_OPT_OUT = 'pz_noga'; // 관리자 트래픽 GA 제외 표시 (권한 아님 — 계측 스위치)
const SESSION_DAYS = 30;

// ── 비밀번호 (PBKDF2, Workers WebCrypto 호환) ──
const enc = new TextEncoder();
const toHex = (buf: ArrayBuffer | Uint8Array) =>
  [...new Uint8Array(buf as ArrayBuffer)].map((b) => b.toString(16).padStart(2, '0')).join('');
const fromHex = (hex: string): Uint8Array<ArrayBuffer> => new Uint8Array(new ArrayBuffer(hex.length / 2)).map((_, i) => parseInt(hex.slice(i * 2, i * 2 + 2), 16));

async function pbkdf2(password: string, salt: Uint8Array<ArrayBuffer>): Promise<ArrayBuffer> {
  const key = await crypto.subtle.importKey('raw', enc.encode(password), 'PBKDF2', false, ['deriveBits']);
  return crypto.subtle.deriveBits({ name: 'PBKDF2', hash: 'SHA-256', salt, iterations: 100_000 }, key, 256);
}

export async function hashPassword(password: string): Promise<string> {
  const salt = crypto.getRandomValues(new Uint8Array(new ArrayBuffer(16)));
  const bits = await pbkdf2(password, salt);
  return `${toHex(salt)}:${toHex(bits)}`;
}

export async function verifyPassword(password: string, stored: string | null): Promise<boolean> {
  const [saltHex, hashHex] = String(stored || '').split(':');
  if (!saltHex || !hashHex) return false;
  const bits = await pbkdf2(password, fromHex(saltHex));
  // 상수 시간 비교 — 문자열 ===는 다른 첫 바이트에서 일찍 끝나 타이밍이 샌다
  const a = toHex(bits), b = hashHex;
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

// ── 세션 ──
export async function createSession(userId: number): Promise<void> {
  const db = await getDb();
  const token = toHex(crypto.getRandomValues(new Uint8Array(32)));
  const expires = new Date(Date.now() + SESSION_DAYS * 864e5);
  const admin = await db.prepare(`SELECT is_admin FROM users WHERE id = ?`).bind(userId).first<{ is_admin: number }>();
  await db.prepare(`INSERT INTO sessions (token, user_id, expires_at) VALUES (?, ?, ?)`)
    .bind(token, userId, expires.toISOString()).run();
  const jar = await cookies();
  jar.set(COOKIE, token, { httpOnly: true, sameSite: 'lax', secure: process.env.NODE_ENV === 'production', path: '/', expires });
  // GA 제외 표시는 브라우저가 읽을 수 있어야 한다 — 루트 레이아웃이 세션을 읽으면 사이트 전체가
  // 동적 렌더링이 되어 정적 최적화를 잃는다. 권한이 아니라 계측 스위치라 노출돼도 무해하다.
  if (admin?.is_admin) jar.set(GA_OPT_OUT, '1', { httpOnly: false, sameSite: 'lax', secure: process.env.NODE_ENV === 'production', path: '/', expires });
  else jar.delete(GA_OPT_OUT);
}

/**
 * 모바일 앱용 세션 — 쿠키를 못 쓰는 클라이언트가 토큰을 직접 보관한다.
 * 웹과 같은 sessions 테이블을 쓰므로 계정·데이터가 완전히 연동된다.
 */
export async function createSessionToken(userId: number): Promise<string> {
  const db = await getDb();
  const token = toHex(crypto.getRandomValues(new Uint8Array(32)));
  const expires = new Date(Date.now() + SESSION_DAYS * 864e5);
  await db.prepare(`INSERT INTO sessions (token, user_id, expires_at) VALUES (?, ?, ?)`)
    .bind(token, userId, expires.toISOString()).run();
  return token;
}

/** 앱 로그아웃 — 그 토큰의 세션만 지운다 (웹 세션은 그대로) */
export async function revokeSessionToken(token: string): Promise<void> {
  const db = await getDb();
  await db.prepare(`DELETE FROM sessions WHERE token = ?`).bind(token).run();
}

export async function destroySession(): Promise<void> {
  const jar = await cookies();
  const token = jar.get(COOKIE)?.value;
  if (token) {
    const db = await getDb();
    await db.prepare(`DELETE FROM sessions WHERE token = ?`).bind(token).run();
  }
  jar.delete(COOKIE);
  jar.delete(GA_OPT_OUT);
}

// React cache() — 한 요청 안에서 레이아웃·네비·페이지가 각각 불러도 D1 조회는 1번만 (라우팅 지연의 주범이던 중복 세션 조회 제거)
export const getSessionUser = cache(async (): Promise<SessionUser | null> => {
  const jar = await cookies();
  let token = jar.get(COOKIE)?.value;
  if (!token) {
    // 모바일 앱(poz) — 쿠키를 못 쓰므로 Authorization: Bearer <세션토큰> 으로 같은 세션을 쓴다.
    // 헤더는 공격자가 교차 사이트로 심을 수 없어 CSRF 위험이 없다.
    const bearer = (await headers()).get('authorization');
    if (bearer?.startsWith('Bearer ')) token = bearer.slice(7).trim();
  }
  if (!token) return null;
  const db = await getDb();
  return db.prepare(`
    SELECT u.id, u.handle, u.email, u.google_sub, u.is_admin, u.bio, u.blog_title, u.email_verified, u.handle_picked, u.avatar_url FROM sessions s JOIN users u ON u.id = s.user_id
    WHERE s.token = ? AND julianday(s.expires_at) > julianday('now')`).bind(token).first<SessionUser>();
});

// ── 입력 검증 ──
export const validHandle = (h: string): boolean => /^[A-Za-z0-9_-]{3,20}$/.test(h);
export const validPassword = (p: string): boolean => typeof p === 'string' && p.length >= 8 && p.length <= 100;
