/**
 * 시작점 — 빈 화면 앞에서 HTML 을 못 쓰는 사람이 막히지 않게.
 *
 * 일부러 서로 다른 '페이지의 종류'로 넣는다. 예쁜 템플릿 네 개를 주면 네 명 다 같은 집을 짓는다
 * (주민에게 위젯 목록을 표로 줬을 때 넷이 똑같은 뼈대를 만든 것과 같은 실패다).
 * 그래서 여기 있는 것들은 완성된 디자인이 아니라 "이런 것도 페이지다"의 예시다.
 * 뼈대 자체가 첫 선택이라 사이드바·헤더·표·링크벽으로 갈라 둔다.
 */
export interface Starter { key: string; label: string; hint: string; shape: string; html: string; css: string }

export const STARTERS: Starter[] = [
  {
    key: 'blank',
    label: 'Blank paper',
    hint: 'Nothing at all. Best if you know your way around a tag.',
    shape: '',
    html: '<h1>This is my place</h1>\n<p>Nothing here yet.</p>\n',
    css: 'body{font-family:system-ui,sans-serif;margin:2rem auto;max-width:34rem;padding:0 1rem}\n',
  },
  {
    key: 'note',
    label: 'A pinned card',
    hint: 'One card on a wall. You add a line a day.',
    shape: 'a single index card pinned to the wall',
    html: `<div class="card">
  <h1>Your title here</h1>
  <p class="by">one line about you</p>
  <p>The one thing you wrote today.</p>
  <poz-posts limit="3"></poz-posts>
</div>
<div class="book">
  <h2>Guestbook</h2>
  <poz-guestbook></poz-guestbook>
</div>
`,
    css: `body{background:#15121a;margin:0;padding:3rem 1rem;font-family:system-ui,sans-serif;color:#2b2430}
.card{background:#fffdf5;max-width:30rem;margin:0 auto;padding:2rem 1.75rem;border-radius:2px;
  box-shadow:0 18px 40px -20px #000;transform:rotate(-.4deg)}
.card h1{font-size:1.5rem;margin:0}
.by{color:#8a8078;font-size:.9rem;margin:.2rem 0 1.4rem}
.book{max-width:30rem;margin:2rem auto 0;color:#cfc4ca}
.book h2{font-size:.8rem;text-transform:uppercase;letter-spacing:.14em}
`,
  },
  {
    key: 'ledger',
    label: 'A ledger',
    hint: 'The table is the page. For keeping count of something.',
    shape: 'one ledger that keeps getting longer',
    html: `<h1>Ledger</h1>
<table>
  <thead><tr><th>Date</th><th>Item</th><th class="n">Value</th></tr></thead>
  <tbody>
    <tr><td>2026-09-17</td><td>first line</td><td class="n">1</td></tr>
  </tbody>
</table>
<h2>Written</h2>
<poz-posts limit="10"></poz-posts>
<h2>Guestbook</h2>
<poz-guestbook></poz-guestbook>
`,
    css: `body{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;background:#f7f5ef;color:#1d2021;
  margin:0;padding:2.5rem 1rem;max-width:46rem;margin-inline:auto;font-size:14px}
h1{font-size:1.1rem;letter-spacing:.2em;text-transform:uppercase}
h2{font-size:.75rem;letter-spacing:.18em;text-transform:uppercase;color:#6b6b60;margin-top:2.5rem}
table{border-collapse:collapse;width:100%}
th,td{border-bottom:1px solid #d9d5c8;padding:.45rem .5rem;text-align:left}
th{font-weight:700;font-size:.72rem;letter-spacing:.1em;text-transform:uppercase;color:#6b6b60}
.n{text-align:right;font-variant-numeric:tabular-nums}
`,
  },
  {
    key: 'sidebar',
    label: 'A sidebar you never leave',
    hint: 'Everything lives on the left. The page never navigates away.',
    shape: 'a left sidebar you never leave',
    html: `<aside>
  <h1>handle</h1>
  <p class="bio">one line about you</p>
  <h2>Written</h2>
  <poz-posts limit="8"></poz-posts>
  <h2>Guestbook</h2>
  <poz-guestbook></poz-guestbook>
</aside>
<section>
  <h2>Today</h2>
  <p>What you are in the middle of.</p>
</section>
`,
    css: `body{margin:0;display:flex;flex-wrap:wrap;min-height:100vh;
  font-family:Georgia,'Times New Roman',serif;background:#efeae1;color:#2a2622}
aside{flex:0 0 17rem;background:#2a2622;color:#e6ded2;padding:1.75rem 1.4rem}
aside h1{font-size:1.15rem;margin:0 0 .2rem;font-family:ui-monospace,Menlo,monospace}
aside .bio{color:#a99e8f;font-size:.85rem;margin:0 0 1.6rem}
aside h2{font-size:.7rem;letter-spacing:.16em;text-transform:uppercase;color:#a99e8f;margin:1.6rem 0 .5rem}
aside a{color:#e6ded2}
section{flex:1 1 20rem;padding:2.5rem 2rem;max-width:36rem}
section h2{font-size:1rem;letter-spacing:.02em}
`,
  },
  {
    key: 'links',
    label: 'A wall of links',
    hint: 'No navigation, just links. For people who collect.',
    shape: 'a wall of links with no categories',
    html: `<h1>Things I kept</h1>
<ul class="wall">
  <li><a href="https://example.com">this one</a> — one line on why</li>
  <li><a href="https://example.org">that one</a> — one line</li>
</ul>
<p class="foot">Below is what I wrote.</p>
<poz-posts limit="5"></poz-posts>
<poz-guestbook></poz-guestbook>
`,
    css: `body{background:#0d0f0c;color:#d8e0cf;font-family:Verdana,system-ui,sans-serif;margin:0;padding:2rem 1rem;
  max-width:38rem;margin-inline:auto;font-size:14px;line-height:1.8}
h1{font-size:1rem;border-bottom:2px dashed #3b4437;padding-bottom:.6rem}
.wall{list-style:none;padding:0}
.wall li{padding:.3rem 0;border-bottom:1px dotted #2c332a}
a{color:#9fd67a}
.foot{margin-top:2.5rem;color:#7d8875;font-size:.85rem}
`,
  },
];
