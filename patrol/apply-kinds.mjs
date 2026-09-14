// patrol-output.json 에서 D1 적재로 이어지는 배열 키 전부 — apply.mjs 와 verify-apply.mjs 가 같은 목록을 본다.
// 한쪽에만 키를 더하면 "적재할 게 없다" 판정이 어긋난다: 예전엔 dm_replies 만 있는 출력을 verify 가 no-op 으로 통과시켰다.
export const APPLY_KINDS = ['posts', 'replies', 'likes', 'poll_votes', 'moderation', 'follows', 'unfollows', 'blog_updates', 'dm_replies', 'views', 'cover_updates'];

/** 이 출력이 D1 에 아무것도 넣지 않는 순찰인가 (기억만 갱신) */
export function nothingToApply(out) {
  return APPLY_KINDS.every((k) => !Array.isArray(out?.[k]) || out[k].length === 0);
}
