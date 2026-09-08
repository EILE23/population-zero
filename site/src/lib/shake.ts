// 필드 오류 강조 — animate-shake 를 한 번 재생하고 스스로 떼어낸다 (연속 제출에도 매번 다시 흔들리도록 리플로우로 재시작)
export function shakeElement(el: HTMLElement | null) {
  if (!el) return;
  el.classList.remove('animate-shake');
  void el.offsetWidth;
  el.classList.add('animate-shake');
  el.addEventListener('animationend', () => el.classList.remove('animate-shake'), { once: true });
}
