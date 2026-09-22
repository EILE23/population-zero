// 짤 규칙 — 무작위 문장의 영어 활용, 긴 낱말 줄바꿈, 글자 맞춤(fit), 릴 정의 저장/복원.
// 저장소 루트에서: node --experimental-strip-types site/tests/meme-rules.test.mjs
import assert from 'node:assert/strict';

const lines = await import('../src/lib/meme-lines.ts');
const draw = await import('../src/lib/meme-draw.ts');
const memes = await import('../src/lib/memes.ts');

// ── 영어 활용: 모든 틀 × 단수/복수 명사 × 동사 셋 — 예전의 "files taxeing", "crie", "seven geese files" 가 나오면 실패
const all = lines.everyLine();
assert.ok(all.length > 100);
for (const l of all) {
  assert.doesNotMatch(l, /\w+eing\b/, `bad gerund: ${l}`);
  assert.doesNotMatch(l, /\bcrie\b|\bcrys\b|\bapologis\b|\bunionis\b/, `chopped verb: ${l}`);
  assert.doesNotMatch(l, /seven geese (is|files|buys|apologises|owes|does)\b/, `plural noun with singular verb: ${l}`);
  assert.doesNotMatch(l, /a raccoon (are|file|buy|apologise|owe|do)\b/, `singular noun with plural verb: ${l}`);
}
const sample = lines.absurdLines(20);
assert.ok(sample.length >= 10 && sample.every((s) => s.length > 3));
console.log(`PASS absurd lines: ${all.length} frame×noun×verb combinations, no conjugation errors`);

// ── 글자 폭·맞춤: 폭이 글자 수에 비례하는 가짜 measureText
const px = { v: 10 };
const ctx = {
  font: '', textAlign: '', textBaseline: '', lineJoin: '',
  set fontPx(n) { px.v = n; },
  measureText: (s) => ({ width: s.length * px.v * 0.6, actualBoundingBoxLeft: (s.length * px.v * 0.6) / 2, actualBoundingBoxRight: (s.length * px.v * 0.6) / 2, actualBoundingBoxAscent: px.v * 0.8, actualBoundingBoxDescent: px.v * 0.2 }),
};
// setFont 가 ctx.font 에 "bold 72px …" 를 쓰면 거기서 px 를 읽는다
Object.defineProperty(ctx, 'font', { set(v) { const m = String(v).match(/(\d+(?:\.\d+)?)px/); if (m) px.v = Number(m[1]); }, get() { return ''; } });

const W = 900, H = 600;
const base = { x: 0.5, y: 0.5, size: 0.1, color: '#fff', stroke: '#000', rot: 0, font: 'impact', bg: 'none' };

// 긴 낱말 하나(공백 없음)는 글자 단위로 쪼개져 폭 안에 들어간다 — 예전엔 한 줄로 남아 가장자리를 넘었다
{
  const t = { ...base, t: 'supercalifragilisticexpialidociousandthensome' };
  draw.setFont(ctx, t, t.size * H); // 그리기 코드가 늘 먼저 하는 일 — 60px 글자, 폭 36px/글자 → maxW 864px → 24글자/줄
  const rows = draw.wrapRows(ctx, t, W);
  assert.ok(rows.length >= 2, `long word not broken: ${rows.length} row(s)`);
  for (const r of rows) assert.ok(ctx.measureText(r).width <= 0.96 * W + 1, `row wider than picture: "${r}"`);
}
// 가장자리에 가까운 글자는 폭이 좁아지고, 넘치면 fit 이 크기를 줄이거나 안으로 민다
{
  const t = { ...base, t: 'a raccoon is financially filing taxes and buying a boat', x: 0.9, y: 0.05, size: 0.12 };
  const f = draw.fitMemeText(ctx, t, W, H);
  const bb = (() => { draw.setFont(ctx, f, f.size * H); return draw.textBounds(ctx, draw.wrapRows(ctx, f, W), f.size * H); })();
  const left = f.x * W + bb.x, right = f.x * W + bb.x + bb.w, top = f.y * H + bb.y, bottom = f.y * H + bb.y + bb.h;
  assert.ok(left >= -1 && right <= W + 1, `fit left/right ${left.toFixed(0)}..${right.toFixed(0)} of ${W}`);
  assert.ok(top >= -1 && bottom <= H + 1, `fit top/bottom ${top.toFixed(0)}..${bottom.toFixed(0)} of ${H}`);
  assert.ok(f.size <= t.size);
}
// 이미 안에 있는 글자는 손대지 않는다
{
  const t = { ...base, t: 'ok', x: 0.5, y: 0.5, size: 0.08 };
  assert.deepEqual(draw.fitMemeText(ctx, t, W, H), t);
}
console.log('PASS wrap + fit: long words break, overflowing text shrinks and moves inside, fitting text untouched');

// ── 릴 정의는 style 에 남는다 — 예전엔 cleanStyle 이 texts/panels/stickers 만 남겨 릴은 리믹스가 불가능했다
{
  const reel = { title: 'test', scenes: [
    { film: 'night_of_the_living_dead', shot: 3, off: 1.2, dur: 2.5, caption: 'me at 3am', pos: 'bottom', font: 'impact', fx: ['zoom', 'shake', 'bw'] },
    { film: 'bad film!!', shot: 0, off: 0, dur: 3, caption: '', pos: 'top', font: 'comic', fx: [] },
    { film: 'ok', shot: -4, off: 99999, dur: 0.1, caption: 'x'.repeat(200), pos: 'sideways', font: 'papyrus', fx: ['nope'] },
  ] };
  const s = memes.cleanStyle({ reel });
  assert.ok(s.reel, 'reel kept');
  assert.equal(s.reel.scenes.length, 2, 'bad film ident dropped, others kept');
  assert.deepEqual(s.reel.scenes[0].fx, ['zoom', 'shake'], 'two effects at most');
  const odd = s.reel.scenes[1];
  assert.equal(odd.shot, 0); assert.equal(odd.off, 3600); assert.equal(odd.dur, 0.5); assert.equal(odd.caption.length, 80); assert.equal(odd.pos, 'bottom'); assert.equal(odd.font, 'impact'); assert.deepEqual(odd.fx, []);
  // 왕복: 저장한 것을 다시 넣어도 같다
  assert.deepEqual(memes.cleanStyle(JSON.parse(JSON.stringify(s))).reel, s.reel);
  assert.equal(memes.cleanStyle({ texts: [] }).reel, undefined, 'no reel → no key');
}
console.log('PASS reel style: kept, validated, round-trips');
