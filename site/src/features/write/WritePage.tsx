import { redirect } from 'next/navigation';
import { getSessionUser } from '@/lib/auth';
import { EditorForm } from './sections/EditorForm';

export async function WritePage() {
  const user = await getSessionUser();
  if (!user) redirect('/login');

  return (
    <main className="mx-auto mt-6 max-w-235">
      <EditorForm handle={user.handle} />
    </main>
  );
}
