import assert from 'node:assert/strict';
import vm from 'node:vm';
import { GA_BOOTSTRAP } from '../src/lib/ga-bootstrap.ts';

async function run(context, { cookie = '', path = '/', ok = true } = {}) {
  let resolve;
  const requests = [];
  const window = {};
  const response = new Promise(r => { resolve = r; });
  vm.runInNewContext(GA_BOOTSTRAP, {
    window, document: { cookie }, location: { pathname: path }, AbortSignal,
    fetch: (...args) => { requests.push(args); return response; },
  });
  window.gtag('event', 'view_post', { post_id: 1 });
  assert.equal(window.dataLayer.length, 0, 'no events before verified context');
  resolve({ ok, json: async () => context });
  await new Promise(r => setImmediate(r));
  return { events: Array.from(window.dataLayer, args => Array.from(args)), requests };
}

for (const status of ['member', 'guest']) {
  const { events, requests } = await run({ member_status: status, excluded: false });
  assert.equal(events[1][0], 'set');
  assert.equal(events[1][1].member_status, status);
  assert.equal(events[2][0], 'config');
  assert.equal(events[2][2].member_status, status);
  assert.equal(events[3][1], 'view_post', 'queued event follows configured category');
  assert.equal(requests[0][1].cache, 'no-store');
}
for (const context of [{ excluded: true }, { member_status: 'invalid' }]) {
  assert.equal((await run(context)).events.length, 0);
}
assert.equal((await run({}, { ok: false })).events.length, 0);
for (const options of [{ cookie: 'x=1; pz_noga=1' }, { path: '/reset' }]) {
  const result = await run({ member_status: 'member' }, options);
  assert.equal(result.events.length, 0);
  assert.equal(result.requests.length, 0);
}
console.log('GA bootstrap: member/guest, queue order, exclusions and failure handling passed');
