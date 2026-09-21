/**
 * 맥락 없는 문장 제조기 — 🎲 의 재료. 모델 호출 없음(요청 경로에 LLM 금지), 무작위 조합이 곧 병맛이다.
 *
 * 한 문장은 '밈 문법(틀)' 에 '아무 명사·동사' 를 끼운 것이다. 틀은 세계 밈이 실제로 쓰는 것들
 * (nobody: / me explaining / when the / POV / it's giving / tfw / literally me …)이고 빈칸은 서로 모르는
 * 사이라서 웃긴다. 한국 밈 문법은 넣지 않는다 — 외국 수요가 과녁이다.
 * 욕은 밈의 일부라 몇 개 둔다. 사람을 겨누는 말은 없다.
 */
const NOUNS = [
  'a raccoon', 'the tax office', 'my landlord', 'a wet sock', 'the moon', 'a fax machine', 'seven geese', 'a lukewarm bath',
  'the group chat', 'a single grape', 'the 3am fridge', 'an unpaid intern', 'a haunted Roomba', 'the printer', 'a very old cheese',
  'my sleep paralysis demon', 'a divorced pigeon', 'the last slice', 'an HR email', 'a sad trombone', 'a horse in a suit',
  'the customer support bot', 'my Wi-Fi at 2%', 'a knight with no plan', 'grandma\'s lawyer', 'the mitochondria', 'a bootleg Shrek',
  'a lobster on parole', 'the DMV', 'my unread emails', 'a gas station sushi', 'the void', 'a guy named Kevin', 'the airport carpet',
  'an emotional support cactus', 'a medieval peasant', 'the ghost of my ex', 'a microwave burrito', 'the algorithm',
];
const VERBS = [
  'files taxes', 'apologises to the toaster', 'buys a boat', 'starts a podcast', 'runs for mayor', 'learns the recorder',
  'joins a cult', 'unionises', 'cries in Excel', 'opens a bakery', 'texts back', 'declares bankruptcy', 'goes to therapy',
  'moves to Ohio', 'invents a new sin', 'gets a mortgage', 'wins the lottery', 'forgets its password', 'sues the ocean',
  'becomes a landlord', 'learns Excel', 'eats the evidence', 'cancels the meeting', 'pays rent in coins', 'discovers fire again',
  'gets promoted', 'joins the navy', 'skips leg day', 'quits mid-shift', 'asks for a raise', 'writes a memoir', 'moves in',
];
const ADJ = ['financially', 'spiritually', 'legally', 'emotionally', 'politically', 'medically', 'aggressively', 'lukewarm', 'feral', 'unpaid', 'suspicious', 'slightly damp', 'historically', 'tax-deductible'];

const FRAMES: ((n: () => string, v: () => string, a: () => string) => string)[] = [
  (n) => `nobody:\n${n()}:`,
  (n, v) => `me explaining why ${n()} ${v()}`,
  (n, v) => `when ${n()} ${v()} and you have to act normal`,
  (n) => `POV: you are ${n()}`,
  (n) => `it's giving ${n()}`,
  (n, v) => `tfw ${n()} ${v()} again`,
  (n) => `literally me and ${n()}`,
  (n, v) => `day 47: ${n()} still ${v()}`,
  (n) => `${n()} (allegedly)`,
  (n, v) => `${n()} ${v()}. this is fine.`,
  (n) => `is ${n()} in the room with us right now`,
  (n, v) => `BREAKING: ${n()} ${v()}`,
  (n, v, a) => `${n()} is ${a()} ${v().replace(/s$/, 'ing').replace(/ies$/, 'ying')}`,
  (n) => `no thoughts. just ${n()}.`,
  (n) => `the audacity of ${n()}`,
  (n, v) => `${n()} said what the hell and ${v()}`,
  (n) => `not ${n()} again`,
  (n, v) => `bro ${v()} 💀`,
  (n) => `${n()} owes me money`,
  (n, v) => `why does ${n()} always ${v().replace(/^(\w+)s\b/, '$1')}`,
  (n) => `we do not talk about ${n()}`,
  (n, v) => `me: i'll be normal today\nalso me: ${v()}`,
  (n) => `${n()} core`,
  (n, v) => `imagine ${n()} ${v()}. couldn't be me.`,
  (n) => `HELP ${n().toUpperCase()} IS HERE`,
  (n, v) => `${n()} ${v()} and honestly? good for them`,
  (n) => `sir this is ${n()}`,
  (n, v) => `they said i couldn't ${v().replace(/^(\w+)s\b/, '$1')}. so ${n()} did.`,
  (n) => `${n()}. that's it. that's the post.`,
  (n, v) => `shit, ${n()} ${v()}`,
];

const pick = <T,>(xs: readonly T[]) => xs[Math.floor(Math.random() * xs.length)];

/** 한 문장. 같은 호출 안에서 명사가 겹치지 않게 뽑는다 */
export function absurdLine(): string {
  const used = new Set<string>();
  const fresh = (xs: readonly string[]) => { let x = pick(xs); for (let i = 0; i < 5 && used.has(x); i++) x = pick(xs); used.add(x); return x; };
  return pick(FRAMES)(() => fresh(NOUNS), () => fresh(VERBS), () => pick(ADJ));
}

export function absurdLines(n: number): string[] {
  const out = new Set<string>();
  for (let i = 0; i < n * 4 && out.size < n; i++) out.add(absurdLine());
  return [...out];
}
