/**
 * 시작점 — 스킨 다섯 장. 블로그 기능은 그대로고 겉모습만 바뀐다.
 *
 * 일부러 '잘 만든 템플릿'을 넣지 않는다. 좋은 템플릿 네 개를 주면 네 명 다 같은 블로그가 된다
 * (주민에게 위젯 목록을 표로 줬을 때 넷이 똑같은 뼈대를 만든 실패와 같다).
 * 그래서 서로 다른 '뼈대의 선택'으로 갈라 둔다 — 사이드바냐 두꺼운 헤더냐 표냐.
 * 겨냥하는 고리는 data-pz 계약이다(Tailwind 클래스는 언제든 바뀐다).
 */
export interface Starter { key: string; label: string; hint: string; shape: string; html: string; css: string }

export const STARTERS: Starter[] = [
  {
    key: 'paper',
    label: 'Newsprint',
    hint: 'Warm paper, serif, flat cards with rules instead of shadows.',
    shape: 'a newspaper page on warm paper',
    html: '',
    css: `body{background:#f4efe6;color:#191512;font-family:Georgia,'Times New Roman',serif}
[data-pz="masthead"]{border-bottom-width:4px;border-color:#191512}
[data-pz="title"]{letter-spacing:-.03em}
[data-pz="topics"] a{border-radius:0}
[data-pz="cards"]{gap:0;border-top:1px solid #cdc2b2}
[data-pz="card"]{border-radius:0;box-shadow:none;background:transparent;border-bottom:1px solid #cdc2b2;
  padding-bottom:1rem;transform:none!important}
[data-pz="card"] img{filter:grayscale(1) contrast(1.05)}
[data-pz="guestbook"]{border-top:4px double #191512}
`,
  },
  {
    key: 'sidebar',
    label: 'Sidebar',
    hint: 'The header becomes a column on the left and stays there.',
    shape: 'a left column that never scrolls away',
    html: '',
    css: `body{background:#eceae4;color:#22201d}
@media(min-width:1024px){
  #pz-skin{display:grid;grid-template-columns:16rem minmax(0,1fr);gap:2.5rem;align-items:start}
  [data-pz="masthead"]{position:static;border:0;padding-top:2rem}
  [data-pz="body"]{padding-top:2rem}
}
[data-pz="masthead"]{background:#22201d;color:#e9e3d8;margin-inline:-1.25rem;padding:1.5rem 1.25rem}
[data-pz="title"]{font-size:1.4rem!important;line-height:1.2}
[data-pz="cards"]{grid-template-columns:minmax(0,1fr)}
[data-pz="card"]{box-shadow:none;border:1px solid #d2cec5;border-radius:4px}
`,
  },
  {
    key: 'list',
    label: 'Just a list',
    hint: 'No cover images, no cards. Titles in a column, like a table of contents.',
    shape: 'a table of contents, nothing else',
    html: '',
    css: `body{background:#fbfbfa;color:#1a1a19;font-family:ui-monospace,SFMono-Regular,Menlo,monospace}
[data-pz="cards"]{display:block!important}
[data-pz="card"]{box-shadow:none;background:none;border-radius:0;border-bottom:1px dotted #bdbdb8;
  transform:none!important;padding:.15rem 0}
[data-pz="card"] img{display:none}
[data-pz="card"] > a{flex-direction:row!important;align-items:baseline;gap:.75rem}
[data-pz="topics"] a{border-radius:2px;font-size:11px}
`,
  },
  {
    key: 'dark',
    label: 'Night shift',
    hint: 'Dark, tight, one accent colour. For people who post at 3am.',
    shape: 'a dark room with one lamp on',
    html: '<p style="font-family:ui-monospace,monospace;font-size:12px;letter-spacing:.14em;text-transform:uppercase;opacity:.65">open 01:00 — 05:00</p>',
    css: `body{background:#0e0d12;color:#d7d2de}
[data-pz="masthead"]{border-color:#2a2733}
[data-pz="title"]{color:#f3eefb}
[data-pz="banner"]{border-left:2px solid #8f7bd4;padding-left:.75rem}
[data-pz="card"]{background:#171520;box-shadow:none;border:1px solid #262231}
[data-pz="card"]:hover{border-color:#8f7bd4;transform:none!important}
[data-pz="topics"] a{border-color:#2a2733;color:#a49dba}
[data-pz="guestbook"]{border-color:#2a2733}
a{color:#b6a6ec}
`,
  },
  {
    key: 'loud',
    label: 'Loud header',
    hint: 'A fat coloured band at the top, quiet everything else.',
    shape: 'one fat banner and then silence',
    html: '<h2 style="margin:0;font-size:1.05rem">What this blog is about — say it in one line.</h2>',
    css: `body{background:#fffdf8;color:#151515}
[data-pz="masthead"]{background:#ff5a2b;color:#fff;margin-inline:-1.25rem;padding:2rem 1.25rem;border:0}
[data-pz="title"]{color:#fff;font-size:2.6rem!important;text-transform:uppercase;letter-spacing:-.04em}
[data-pz="masthead"] a{color:#fff}
[data-pz="banner"]{background:#151515;color:#fff;padding:1rem 1.15rem;margin-inline:-1.25rem}
[data-pz="card"]{border-radius:0;box-shadow:none;border:2px solid #151515}
[data-pz="card"]:hover{transform:none!important;background:#ffeee8}
`,
  },
];
