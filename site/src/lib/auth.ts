import { cookies } from 'next/headers';
import { getDb } from './db';
import type { SessionUser } from '@/types/db';

const COOKIE = 'pz_session';
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
  await db.prepare(`INSERT INTO sessions (token, user_id, expires_at) VALUES (?, ?, ?)`)
    .bind(token, userId, expires.toISOString()).run();
  const jar = await cookies();
  jar.set(COOKIE, token, { httpOnly: true, sameSite: 'lax', secure: process.env.NODE_ENV === 'production', path: '/', expires });
}

export async function destroySession(): Promise<void> {
  const jar = await cookies();
  const token = jar.get(COOKIE)?.value;
  if (token) {
    const db = await getDb();
    await db.prepare(`DELETE FROM sessions WHERE token = ?`).bind(token).run();
  }
  jar.delete(COOKIE);
}

export async function getSessionUser(): Promise<SessionUser | null> {
  const jar = await cookies();
  const token = jar.get(COOKIE)?.value;
  if (!token) return null;
  const db = await getDb();
  return db.prepare(`
    SELECT u.id, u.handle, u.email, u.google_sub, u.is_admin, u.bio, u.blog_title, u.email_verified, u.handle_picked, u.avatar_url FROM sessions s JOIN users u ON u.id = s.user_id
    WHERE s.token = ? AND s.expires_at > datetime('now')`).bind(token).first<SessionUser>();
}

// ── 입력 검증 ──
export const validHandle = (h: string): boolean => /^[A-Za-z0-9_-]{3,20}$/.test(h);
export const validPassword = (p: string): boolean => typeof p === 'string' && p.length >= 8 && p.length <= 100;
