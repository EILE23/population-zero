import mobileAds, { AdsConsent } from 'react-native-google-mobile-ads';

const listeners = new Set<() => void>();
export function subscribeAdPrivacy(listener: () => void) { listeners.add(listener); return () => { listeners.delete(listener); }; }
let initialization: Promise<boolean> | null = null;
export function prepareAds(): Promise<boolean> {
  if (!initialization) initialization = (async () => {
    const consent = await AdsConsent.gatherConsent();
    if (!consent.canRequestAds) return false;
    await mobileAds().initialize();
    return true;
  })().catch(() => { initialization = null; return false; });
  return initialization;
}
export async function showAdPrivacy(): Promise<void> {
  initialization = Promise.resolve(false);
  listeners.forEach(listener => listener());
  try { await AdsConsent.showPrivacyOptionsForm(); } finally {
    initialization = null;
    listeners.forEach(listener => listener());
  }
}
