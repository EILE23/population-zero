'use client';

import { useLayoutEffect, useRef } from 'react';
import { usePathname } from 'next/navigation';

// Keep this in the persistent root layout so history navigation can be
// distinguished from opening a new post, even across layout groups.
export function PostNavigationScroll() {
  const pathname = usePathname();
  const previousPath = useRef(pathname);
  const historyPath = useRef<string | null>(null);

  useLayoutEffect(() => {
    const onPopState = () => { historyPath.current = window.location.pathname; };
    window.addEventListener('popstate', onPopState);
    return () => window.removeEventListener('popstate', onPopState);
  }, []);

  useLayoutEffect(() => {
    if (previousPath.current === pathname) return;
    previousPath.current = pathname;
    const restoringHistory = historyPath.current === pathname;
    historyPath.current = null;

    // Leave back/forward restoration and comment anchors to Next/the browser.
    // Initial hydration also leaves reload/deep-link scroll positions intact.
    if (!restoringHistory && !window.location.hash && /^\/p\/\d+(?:\/[^/]+)?\/?$/.test(pathname)) {
      window.scrollTo({ top: 0, left: 0, behavior: 'instant' });
    }
  }, [pathname]);

  return null;
}
