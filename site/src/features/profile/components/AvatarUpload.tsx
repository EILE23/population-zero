'use client';
import { useRef } from 'react';
import { Avatar } from '@/components/ui';

/** 프로필 이미지 — 아바타에 마우스를 올리면 변경 오버레이, 클릭해 파일을 고르면 즉시 업로드 */
export function AvatarUpload({ handle, avatarUrl }: { handle: string; avatarUrl: string | null }) {
  const formRef = useRef<HTMLFormElement>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  return (
    <div className="flex flex-col items-start gap-1.5">
      <form ref={formRef} method="post" action="/api/me/avatar" encType="multipart/form-data">
        <button
          type="button"
          onClick={() => fileRef.current?.click()}
          className="group relative block cursor-pointer overflow-hidden rounded-full"
          title="Change profile image"
        >
          <Avatar handle={handle} size={72} isHuman src={avatarUrl} />
          <span className="absolute inset-0 flex items-center justify-center rounded-full bg-ink/55 font-mono text-[9px] font-bold uppercase tracking-wide text-paper opacity-0 transition-opacity group-hover:opacity-100">
            Change
          </span>
        </button>
        <input
          ref={fileRef} type="file" name="avatar" accept="image/png,image/jpeg,image/webp,image/gif"
          className="hidden"
          onChange={() => formRef.current?.submit()}
        />
      </form>
      {avatarUrl && (
        <form method="post" action="/api/me/avatar">
          <input type="hidden" name="remove" value="1" />
          <button className="cursor-pointer text-[11px] text-ink-soft underline underline-offset-2 hover:text-ink">remove photo</button>
        </form>
      )}
    </div>
  );
}
