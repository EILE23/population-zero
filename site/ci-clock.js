/**
 * CI 시계 — GitHub 크론은 이 레포에서 1.5~3시간씩 늦게 뜨고 어떤 날은 안 뜬다(2026-09-22 확인). Cloudflare 크론(매시 17분)은 정확하므로
 * 여기서 GitHub Actions 를 직접 깨운다. 마을이 스스로 자라는 데 필요한 세 잡:
 *   grow-code   6시간 간격  — 엔진·광장·Climb 코드 성장
 *   build-game  8시간 간격  — 사람이 낸 게임(큐가 비면 잡이 바로 끝난다)
 *   patrol      2시간 넘게 조용하면 — 순찰 사슬(repository_dispatch)이 끊긴 것
 * 돌고 있거나 대기 중이면 건드리지 않는다. 토큰: GH_DISPATCH_TOKEN(Actions read/write 세밀 PAT), 없으면 PZ_ASSETS_PAT 로 시도.
 */
const REPO = 'EILE23/population-zero';
const JOBS = [
  { file: 'grow-code.yml', hours: 6 },
  { file: 'build-game.yml', hours: 8 },
  { file: 'patrol.yml', hours: 2 },
];

export async function runCiClock(env) {
  const token = env.GH_DISPATCH_TOKEN || env.PZ_ASSETS_PAT;
  if (!token) { console.log('ci-clock: no token'); return; }
  const headers = { authorization: `Bearer ${token}`, accept: 'application/vnd.github+json', 'user-agent': 'pz-ci-clock', 'x-github-api-version': '2022-11-28' };
  for (const job of JOBS) {
    try {
      const res = await fetch(`https://api.github.com/repos/${REPO}/actions/workflows/${job.file}/runs?per_page=5`, { headers });
      if (!res.ok) { console.log(`ci-clock: ${job.file} list ${res.status}`); continue; }
      const { workflow_runs: runs = [] } = await res.json();
      const active = runs.some((r) => r.status === 'in_progress' || r.status === 'queued' || r.status === 'waiting' || r.status === 'pending');
      const last = runs[0] ? Date.parse(runs[0].created_at) : 0;
      const ageH = (Date.now() - last) / 3600e3;
      if (active || ageH < job.hours) { console.log(`ci-clock: ${job.file} active=${active} age=${ageH.toFixed(1)}h — leave`); continue; }
      const d = await fetch(`https://api.github.com/repos/${REPO}/actions/workflows/${job.file}/dispatches`, { method: 'POST', headers, body: JSON.stringify({ ref: 'main' }) });
      console.log(`ci-clock: ${job.file} age=${ageH.toFixed(1)}h — dispatch ${d.status}`);
    } catch (e) { console.log(`ci-clock: ${job.file} error ${String(e).slice(0, 80)}`); }
  }
}
