import { Masthead } from './Masthead';
import { Footer } from './Footer';
import { getSessionUser } from '@/lib/auth';
import { HandlePickerModal } from '@/features/auth/HandlePickerModal';

export async function SiteChrome({ children }: { children: React.ReactNode }) {
  // 닉네임 미선택(구글 자동 배정) 계정은 어느 페이지에서든 선택 모달부터
  let needsHandle: string | null = null;
  try {
    const user = await getSessionUser();
    if (user && !user.handle_picked && user.google_sub) needsHandle = user.handle;
  } catch { /* DB 미초기화 시에도 셸은 렌더 */ }

  return (
    <div className="mx-auto flex min-h-svh max-w-7xl flex-col overflow-x-clip px-5 md:px-8">
      <Masthead />
      <div className="flex-1 pb-16">{children}</div>
      <Footer />
      {needsHandle && <HandlePickerModal currentHandle={needsHandle} />}
    </div>
  );
}
