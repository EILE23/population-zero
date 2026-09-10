import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';

const source = stripTypeScriptTypes(readFileSync(new URL('../src/components/PostNavigationScroll.ts', import.meta.url), 'utf8'))
  .replace(/import .* from .*;\r?\n/g, '')
  .replace('export function', 'function');
let pathname = '/';
let cursor = 0;
const hooks = [], effects = [], listeners = new Map(), scrolls = [];
const window = {
  location: { pathname, hash: '' },
  addEventListener: (name, fn) => listeners.set(name, fn),
  removeEventListener: name => listeners.delete(name),
  scrollTo: options => scrolls.push(options.top),
};
const context = vm.createContext({ window,
  usePathname: () => pathname,
  useRef: initial => hooks[cursor++] ??= { current: initial },
  useLayoutEffect: (fn, deps) => {
    const slot = cursor++;
    if (!hooks[slot] || deps.some((dep, i) => dep !== hooks[slot][i])) {
      hooks[slot] = deps;
      effects.push(fn);
    }
  },
});
vm.runInContext(source, context);
function visit(path, { history = false, hash = '' } = {}) {
  pathname = window.location.pathname = path;
  window.location.hash = hash;
  if (history) listeners.get('popstate')();
  cursor = 0;
  vm.runInContext('PostNavigationScroll()', context);
  effects.splice(0).forEach(fn => fn());
}
visit('/');
assert.equal(scrolls.length, 0, 'hydration leaves browser restoration intact');
visit('/p/297');
assert.deepEqual(scrolls, [0], 'opening a post resets the list scroll');
visit('/p/297');
assert.equal(scrolls.length, 1, 'rerenders do not interrupt reading');
visit('/', { history: true });
visit('/p/297', { history: true });
assert.equal(scrolls.length, 1, 'back and forward keep native restoration');
visit('/p/301/title');
assert.equal(scrolls.length, 2, 'related posts and SEO slugs reset scroll');
visit('/p/302', { hash: '#comments' });
assert.equal(scrolls.length, 2, 'comment deep links retain their anchor');
visit('/p/302/edit');
assert.equal(scrolls.length, 3, 'edit opens at the top');
visit('/about');
assert.equal(scrolls.length, 3, 'unrelated routes retain default behavior');
console.log('Post navigation: new posts, history, rerenders, slugs, edit and anchors passed');
