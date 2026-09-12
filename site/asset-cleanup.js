// Bounded retries for public uploads removed during account deletion.
export async function cleanupAssets(env) {
  if (!env.PZ_ASSETS_PAT) return;
  const { results } = await env.DB.prepare('SELECT path FROM asset_removals ORDER BY created_at LIMIT 10').all();
  const headers = { authorization: `Bearer ${env.PZ_ASSETS_PAT}`, accept: 'application/vnd.github+json', 'user-agent': 'poz-cleanup' };
  for (const { path } of results) {
    if (!/^uploads\/(cover|inline|avatar)-u\d+-[a-z0-9]+\.(png|jpg|webp|gif)$/.test(path)) continue;
    const url = `https://api.github.com/repos/EILE23/pz-assets/contents/${path}`;
    const current = await fetch(url, { headers, signal: AbortSignal.timeout(8000) });
    let removed = current.status === 404;
    if (current.ok) {
      const { sha } = await current.json();
      const response = await fetch(url, { method: 'DELETE', headers: { ...headers, 'content-type': 'application/json' },
        body: JSON.stringify({ sha, message: 'Remove upload following account deletion' }), signal: AbortSignal.timeout(8000) });
      removed = response.ok;
    }
    if (!removed) continue;
    const purge = await fetch(`https://purge.jsdelivr.net/gh/EILE23/pz-assets@main/${path}`, { signal: AbortSignal.timeout(8000) });
    if (purge.ok) await env.DB.prepare('DELETE FROM asset_removals WHERE path=?').bind(path).run();
  }
}
