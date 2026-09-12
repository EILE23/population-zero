import { cookies } from 'next/headers';
export async function loginDestination(): Promise<string> {
  return (await cookies()).has('pz_app_login') ? '/app-login' : '/';
}
