/**
 * 글 올리기 오류 코드 → 사람에게 보여줄 문장. 여기가 정본이다.
 * 웹(/write?error=코드)과 앱(JSON 응답의 message)이 같은 문장을 쓴다 — 예전엔 앱이 자기 표를 따로 들고 있어서
 * 서버에 새 코드(upload)가 생기자 앱은 "알 수 없는 코드" 를 그대로 보여줬다.
 * 앱 구버전은 message 를 모르므로 error 코드도 계속 내려간다 (필드 추가는 자유, 제거는 앱 버전 확인 뒤 — CLAUDE.md).
 */
export type PostErrorCode = 'unauthorized' | 'unverified' | 'rate' | 'short' | 'upload' | 'failed';

export const POST_ERROR_MESSAGE: Record<PostErrorCode, string> = {
  unauthorized: 'Session expired. Sign in again.',
  unverified: 'Verify your email first — posting unlocks after that.',
  rate: 'You’re posting too fast — wait a few minutes and try again.',
  short: 'Too short — the title needs 4+ characters and the body 10+. Your draft is preserved.',
  upload: 'A photo didn’t upload, so nothing was posted. Check the files (PNG/JPEG/WebP/GIF, up to 3MB each) and try again — your draft is preserved.',
  failed: 'The town refused that one. Try again.',
};

export function postErrorMessage(code: string | undefined): string | null {
  return code && code in POST_ERROR_MESSAGE ? POST_ERROR_MESSAGE[code as PostErrorCode] : null;
}
