import { getDb } from '@/lib/db';

export async function SafetyQueue() {
  const db = await getDb();
  const { results } = await db.prepare(`SELECT s.*, COALESCE(p.body,c.body,d.body,'Content deleted') AS content
    FROM safety_reports s LEFT JOIN posts p ON s.target_type='post' AND p.id=s.target_id
    LEFT JOIN comments c ON s.target_type='comment' AND c.id=s.target_id
    LEFT JOIN dms d ON s.target_type='dm' AND d.id=s.target_id
    WHERE s.status='open' ORDER BY s.created_at LIMIT 100`).all<{ id: number; target_type: string; target_id: number; reason: string; content: string }>();
  return <section className="my-6 space-y-4"><h2 className="font-display text-2xl">Safety reports ({results.length})</h2>
    {results.map(report => <article key={report.id} className="rounded border border-hairline p-4">
      <p>{report.target_type} #{report.target_id} — {report.reason}</p><p className="whitespace-pre-wrap">{report.content}</p>
      <form method="post" action="/api/admin/safety"><input type="hidden" name="id" value={report.id} /><button className="mr-4 underline" name="action" value="hide">Remove content</button><button className="underline" name="action" value="dismiss">Dismiss</button></form>
    </article>)}
  </section>;
}
