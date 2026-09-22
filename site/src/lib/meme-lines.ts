/**
 * 맥락 없는 문장 제조기 — 🎲 의 재료. 모델 호출 없음(요청 경로에 LLM 금지), 무작위 조합이 곧 병맛이다.
 *
 * 한 문장은 '밈 문법(틀)' 에 '아무 명사·동사' 를 끼운 것이다. 틀은 세계 밈이 실제로 쓰는 것들
 * (nobody: / me explaining / when the / POV / it's giving / tfw / literally me …)이고 빈칸은 서로 모르는
 * 사이라서 웃긴다. 한국 밈 문법은 넣지 않는다 — 외국 수요가 과녁이다.
 * 욕은 밈의 일부라 몇 개 둔다. 사람을 겨누는 말은 없다.
 *
 * 동사는 세 꼴(3인칭 단수 / 원형 / -ing)을 다 적어 둔다. 정규식으로 s 를 떼고 ing 를 붙이던 시절엔
 * "files taxeing", "crie in Excel" 이 나왔다 — 엉뚱한 건 좋지만 문법이 틀리면 그냥 오타로 읽힌다.
 * 명사는 복수 여부를 적어 "seven geese files" 가 되지 않게 한다.
 */
type Noun = { t: string; pl?: true };
type Verb = { s: string; base: string; ing: string };

const NOUNS: Noun[] = [
  { t: 'a raccoon' }, { t: 'the tax office' }, { t: 'my landlord' }, { t: 'a wet sock' }, { t: 'the moon' }, { t: 'a fax machine' },
  { t: 'seven geese', pl: true }, { t: 'a lukewarm bath' }, { t: 'the group chat' }, { t: 'a single grape' }, { t: 'the 3am fridge' },
  { t: 'an unpaid intern' }, { t: 'a haunted Roomba' }, { t: 'the printer' }, { t: 'a very old cheese' }, { t: 'my sleep paralysis demon' },
  { t: 'a divorced pigeon' }, { t: 'the last slice' }, { t: 'an HR email' }, { t: 'a sad trombone' }, { t: 'a horse in a suit' },
  { t: 'the customer support bot' }, { t: 'my Wi-Fi at 2%' }, { t: 'a knight with no plan' }, { t: "grandma's lawyer" }, { t: 'the mitochondria', pl: true },
  { t: 'a bootleg Shrek' }, { t: 'a lobster on parole' }, { t: 'the DMV' }, { t: 'my unread emails', pl: true }, { t: 'a gas station sushi' },
  { t: 'the void' }, { t: 'a guy named Kevin' }, { t: 'the airport carpet' }, { t: 'an emotional support cactus' }, { t: 'a medieval peasant' },
  { t: 'the ghost of my ex' }, { t: 'a microwave burrito' }, { t: 'the algorithm' },
];
const VERBS: Verb[] = [
  { s: 'files taxes', base: 'file taxes', ing: 'filing taxes' },
  { s: 'apologises to the toaster', base: 'apologise to the toaster', ing: 'apologising to the toaster' },
  { s: 'buys a boat', base: 'buy a boat', ing: 'buying a boat' },
  { s: 'starts a podcast', base: 'start a podcast', ing: 'starting a podcast' },
  { s: 'runs for mayor', base: 'run for mayor', ing: 'running for mayor' },
  { s: 'learns the recorder', base: 'learn the recorder', ing: 'learning the recorder' },
  { s: 'joins a cult', base: 'join a cult', ing: 'joining a cult' },
  { s: 'unionises', base: 'unionise', ing: 'unionising' },
  { s: 'cries in Excel', base: 'cry in Excel', ing: 'crying in Excel' },
  { s: 'opens a bakery', base: 'open a bakery', ing: 'opening a bakery' },
  { s: 'texts back', base: 'text back', ing: 'texting back' },
  { s: 'declares bankruptcy', base: 'declare bankruptcy', ing: 'declaring bankruptcy' },
  { s: 'goes to therapy', base: 'go to therapy', ing: 'going to therapy' },
  { s: 'moves to Ohio', base: 'move to Ohio', ing: 'moving to Ohio' },
  { s: 'invents a new sin', base: 'invent a new sin', ing: 'inventing a new sin' },
  { s: 'gets a mortgage', base: 'get a mortgage', ing: 'getting a mortgage' },
  { s: 'wins the lottery', base: 'win the lottery', ing: 'winning the lottery' },
  { s: 'forgets its password', base: 'forget its password', ing: 'forgetting its password' },
  { s: 'sues the ocean', base: 'sue the ocean', ing: 'suing the ocean' },
  { s: 'becomes a landlord', base: 'become a landlord', ing: 'becoming a landlord' },
  { s: 'learns Excel', base: 'learn Excel', ing: 'learning Excel' },
  { s: 'eats the evidence', base: 'eat the evidence', ing: 'eating the evidence' },
  { s: 'cancels the meeting', base: 'cancel the meeting', ing: 'cancelling the meeting' },
  { s: 'pays rent in coins', base: 'pay rent in coins', ing: 'paying rent in coins' },
  { s: 'discovers fire again', base: 'discover fire again', ing: 'discovering fire again' },
  { s: 'gets promoted', base: 'get promoted', ing: 'getting promoted' },
  { s: 'joins the navy', base: 'join the navy', ing: 'joining the navy' },
  { s: 'skips leg day', base: 'skip leg day', ing: 'skipping leg day' },
  { s: 'quits mid-shift', base: 'quit mid-shift', ing: 'quitting mid-shift' },
  { s: 'asks for a raise', base: 'ask for a raise', ing: 'asking for a raise' },
  { s: 'writes a memoir', base: 'write a memoir', ing: 'writing a memoir' },
  { s: 'moves in', base: 'move in', ing: 'moving in' },
];
const ADJ = ['financially', 'spiritually', 'legally', 'emotionally', 'politically', 'medically', 'aggressively', 'historically', 'tax-deductibly', 'suspiciously', 'quietly', 'allegedly'];

/** 틀 — n 은 명사, v 는 동사(명사의 수에 맞춘 현재형), a 는 부사. 원형·ing 가 필요한 틀은 따로 받는다 */
type Pick = { n: Noun; v: Verb; a: string };
const is = (n: Noun) => (n.pl ? 'are' : 'is');
const does = (n: Noun) => (n.pl ? 'do' : 'does');
const now = (n: Noun, v: Verb) => (n.pl ? v.base : v.s);
const FRAMES: ((p: Pick) => string)[] = [
  ({ n }) => `nobody:\n${n.t}:`,
  ({ n, v }) => `me explaining why ${n.t} ${now(n, v)}`,
  ({ n, v }) => `when ${n.t} ${now(n, v)} and you have to act normal`,
  ({ n }) => `POV: you are ${n.t}`,
  ({ n }) => `it's giving ${n.t}`,
  ({ n, v }) => `tfw ${n.t} ${now(n, v)} again`,
  ({ n }) => `literally me and ${n.t}`,
  ({ n, v }) => `day 47: ${n.t} still ${now(n, v)}`,
  ({ n }) => `${n.t} (allegedly)`,
  ({ n, v }) => `${n.t} ${now(n, v)}. this is fine.`,
  ({ n }) => `${is(n)} ${n.t} in the room with us right now`,
  ({ n, v }) => `BREAKING: ${n.t} ${now(n, v)}`,
  ({ n, v, a }) => `${n.t} ${is(n)} ${a} ${v.ing}`,
  ({ n }) => `no thoughts. just ${n.t}.`,
  ({ n }) => `the audacity of ${n.t}`,
  ({ n, v }) => `${n.t} said what the hell and ${n.pl ? v.base : v.s}`,
  ({ n }) => `not ${n.t} again`,
  ({ v }) => `bro ${v.s} 💀`,
  ({ n }) => `${n.t} ${n.pl ? 'owe' : 'owes'} me money`,
  ({ n, v }) => `why ${does(n)} ${n.t} always ${v.base}`,
  ({ n }) => `we do not talk about ${n.t}`,
  ({ v }) => `me: i'll be normal today\nalso me: ${v.s}`,
  ({ n }) => `${n.t} core`,
  ({ n, v }) => `imagine ${n.t} ${v.ing}. couldn't be me.`,
  ({ n }) => `HELP ${n.t.toUpperCase()} ${n.pl ? 'ARE' : 'IS'} HERE`,
  ({ n, v }) => `${n.t} ${now(n, v)} and honestly? good for them`,
  ({ n }) => `sir this is ${n.t}`,
  ({ n, v }) => `they said i couldn't ${v.base}. so ${n.t} did.`,
  ({ n }) => `${n.t}. that's it. that's the post.`,
  ({ n, v }) => `shit, ${n.t} ${now(n, v)}`,
];

const pick = <T,>(xs: readonly T[]) => xs[Math.floor(Math.random() * xs.length)];

/** 한 문장 */
export function absurdLine(): string {
  return pick(FRAMES)({ n: pick(NOUNS), v: pick(VERBS), a: pick(ADJ) });
}

export function absurdLines(n: number): string[] {
  const out = new Set<string>();
  for (let i = 0; i < n * 4 && out.size < n; i++) out.add(absurdLine());
  return [...out];
}

/** 테스트용 — 모든 틀 × 대표 명사(단수·복수) 를 돌려 활용 오류를 잡는다 */
export function everyLine(): string[] {
  const out: string[] = [];
  const ns: Noun[] = [{ t: 'a raccoon' }, { t: 'seven geese', pl: true }];
  for (const f of FRAMES) for (const n of ns) for (const v of VERBS.slice(0, 3)) out.push(f({ n, v, a: ADJ[0] }));
  return out;
}
