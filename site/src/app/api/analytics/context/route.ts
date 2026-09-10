import { getSessionUser } from '@/lib/auth';

// Return only the current login category. Never cache session-dependent data.
export async function GET() {
  const headers = { 'Cache-Control': 'private, no-store', Vary: 'Cookie' };
  try {
    const user = await getSessionUser();
    return Response.json({
      member_status: user ? 'member' : 'guest',
      excluded: Boolean(user?.is_admin),
    }, { headers });
  } catch {
    // An unavailable session store must not misclassify members as guests.
    return Response.json({ excluded: true }, { status: 503, headers });
  }
}
