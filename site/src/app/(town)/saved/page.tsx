import { redirect } from 'next/navigation';

/** 이름을 Bookmarks 로 바꿨다 — 옛 주소는 새 주소로 */
export default function Page() {
  redirect('/bookmarks');
}
