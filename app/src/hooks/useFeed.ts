import { useCallback, useEffect, useState } from 'react';
import { fetchFeed, type FeedPost } from '@/api';

type Params = { tab?: string; media?: 'photo' | null; author?: string | null; sort?: 'hot' | 'latest'; q?: string; reloadKey?: number };

/**
 * 목록 하나의 상태 — 커뮤니티 피드·사진 피드·프로필이 각자 자기 것을 들고 따로 돈다.
 * 로딩은 state 가 아니라 "지금 담긴 목록이 어떤 조건 것인지"에서 파생시킨다
 * (조건이 바뀔 때마다 setState 로 렌더를 한 번 더 돌리지 않으려고).
 */
export function useFeed({ tab = 'all', media = null, author = null, sort = 'hot', q = '', reloadKey = 0 }: Params) {
  const [posts, setPosts] = useState<FeedPost[]>([]);
  const [country, setCountry] = useState<string | null>(null);
  const [loadedKey, setLoadedKey] = useState<string | null>(null);
  const [refreshing, setRefreshing] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [done, setDone] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const queryKey = `${tab}|${media ?? ''}|${author ?? ''}|${sort}|${q}|${reloadKey}`;
  const loading = loadedKey !== queryKey;

  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const { posts: next, country: c } = await fetchFeed({ offset: 0, tab, media, author, sort, q });
        if (!alive) return;
        setPosts(next);
        setCountry(c);
        setDone(next.length === 0);
        setError(null);
      } catch {
        if (!alive) return;
        setPosts([]);
        setDone(true);
        setError('Could not reach the town.');
      } finally {
        if (alive) setLoadedKey(queryKey);
      }
    })();
    return () => { alive = false; };
  }, [tab, media, author, sort, q, queryKey]);

  const refresh = useCallback(async () => {
    setRefreshing(true);
    try {
      const { posts: next, country: c } = await fetchFeed({ offset: 0, tab, media, author, sort, q });
      setPosts(next);
      setCountry(c);
      setDone(next.length === 0);
      setError(null);
    } catch {
      setError('Could not reach the town.');
    } finally {
      setRefreshing(false);
    }
  }, [tab, media, author, sort, q]);

  const loadMore = useCallback(async () => {
    if (loading || loadingMore || done) return;
    setLoadingMore(true);
    try {
      const { posts: next } = await fetchFeed({ offset: posts.length, tab, media, author, sort, q });
      setPosts((prev) => {
        // 순위가 바뀌어 겹쳐 오는 글은 버린다 (핫 랭킹은 요청 사이에 순서가 흔들린다)
        const seen = new Set(prev.map((p) => p.id));
        return [...prev, ...next.filter((p) => !seen.has(p.id))];
      });
      if (next.length === 0) setDone(true);
    } catch {
      /* 더 읽기 실패는 조용히 — 이미 보고 있는 목록은 그대로 둔다 */
    } finally {
      setLoadingMore(false);
    }
  }, [loading, loadingMore, done, posts.length, tab, media, author, sort, q]);

  /** 삭제한 글을 목록에서 즉시 뺀다 (다시 읽지 않고) */
  const removeLocal = useCallback((id: number) => {
    setPosts((prev) => prev.filter((p) => p.id !== id));
  }, []);

  /** 좋아요 수를 그 자리에서 반영한다 */
  const patchLocal = useCallback((id: number, patch: Partial<FeedPost>) => {
    setPosts((prev) => prev.map((p) => (p.id === id ? { ...p, ...patch } : p)));
  }, []);

  return { posts, country, loading, refreshing, loadingMore, error, refresh, loadMore, removeLocal, patchLocal };
}
