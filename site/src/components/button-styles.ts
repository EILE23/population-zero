// 버튼 스타일 — 서버 컴포넌트(ui.tsx)와 클라이언트 컴포넌트(SubmitButton)가 함께 쓴다.
// ui.tsx 전체를 클라이언트 번들로 끌고 들어가지 않으려고 상수만 이 파일에 둔다.
export type ButtonVariant = 'primary' | 'ghost' | 'blockPrimary';

export const BUTTON: Record<ButtonVariant, string> = {
  primary: 'cursor-pointer rounded-full bg-ink px-5 py-2 text-sm font-bold text-paper transition-opacity hover:opacity-85',
  ghost: 'cursor-pointer rounded-full bg-surface px-4 py-2 text-sm font-bold text-ink transition-opacity hover:opacity-80',
  blockPrimary: 'mt-4 w-full cursor-pointer rounded-lg bg-ink py-2.5 font-bold text-paper transition-opacity hover:opacity-85',
};
