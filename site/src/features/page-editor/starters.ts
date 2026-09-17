/**
 * 시작점 — 빈 화면 앞에서 HTML 을 못 쓰는 사람이 막히지 않게.
 *
 * 일부러 서로 다른 '페이지의 종류'로 넣는다. 예쁜 템플릿 네 개를 주면 네 명 다 같은 집을 짓는다
 * (주민에게 위젯 목록을 표로 줬을 때 넷이 똑같은 뼈대를 만든 것과 같은 실패다).
 * 그래서 여기 있는 것들은 완성된 디자인이 아니라 "이런 것도 페이지다"의 예시다.
 */
export interface Starter { key: string; label: string; hint: string; shape: string; html: string; css: string }

export const STARTERS: Starter[] = [
  {
    key: 'blank',
    label: '빈 종이',
    hint: '아무것도 없는 데서 시작. 태그를 아는 사람에게 제일 좋습니다.',
    shape: '',
    html: '<h1>여기가 내 집</h1>\n<p>아직 아무것도 없음.</p>\n',
    css: 'body{font-family:system-ui,sans-serif;margin:2rem auto;max-width:34rem;padding:0 1rem}\n',
  },
  {
    key: 'note',
    label: '압정으로 박은 쪽지',
    hint: '한 장만 있는 집. 하루에 한 줄씩 붙여나가는 식.',
    shape: '벽에 압정으로 박아둔 쪽지 한 장',
    html: `<div class="card">
  <h1>제목을 여기</h1>
  <p class="by">한 줄 소개</p>
  <p>오늘 쓴 것 하나.</p>
  <poz-posts limit="3"></poz-posts>
</div>
<div class="book">
  <h2>방명록</h2>
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
    label: '장부 한 장',
    hint: '표가 곧 페이지. 숫자나 기록을 쌓는 집.',
    shape: '계속 늘어나는 장부 한 장',
    html: `<h1>장부</h1>
<table>
  <thead><tr><th>날짜</th><th>항목</th><th class="n">값</th></tr></thead>
  <tbody>
    <tr><td>2026-09-17</td><td>첫 줄</td><td class="n">1</td></tr>
  </tbody>
</table>
<h2>쓴 것</h2>
<poz-posts limit="10"></poz-posts>
<h2>방명록</h2>
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
    key: 'links',
    label: '링크 벽',
    hint: '네비게이션 없이 링크만 잔뜩. 모으는 걸 좋아하는 집.',
    shape: '분류도 없이 링크만 붙여둔 벽',
    html: `<h1>내가 모은 것들</h1>
<ul class="wall">
  <li><a href="https://example.com">여기</a> — 왜 좋은지 한 줄</li>
  <li><a href="https://example.org">저기</a> — 한 줄</li>
</ul>
<p class="foot">아래는 내가 쓴 것.</p>
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
