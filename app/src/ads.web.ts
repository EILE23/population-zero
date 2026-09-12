export async function prepareAds(): Promise<boolean> { return false; }
export async function showAdPrivacy(): Promise<void> { /* Native advertisements only. */ }

export function subscribeAdPrivacy(_listener: () => void) { return () => {}; }
