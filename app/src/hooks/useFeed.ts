import { useCallback, useEffect, useRef, useState } from 'react';
import { fetchFeed, type FeedPost } from '@/api';

type Params = { tab?: string; media?: 'photo' | null; author?: string | null; sort?: 'hot' | 'latest'; q?: string; reloadKey?: number };

/**
 * 목록 하나의 상태 — 커뮤니티 피드·사진 피드·프로필이 각자 자기 것을 들고 따로 돈다.
 * 로딩은 state 가 아니라 "지금 담긴 목록이 어떤 조건 것인지"에서 파생시킨다
 * (조건이 바뀔 때마다 setState 로 렌더를 한 번 더 돌리지 않으려고).
 *
 * 모든 요청은 시작할 때의 queryKey 를 들고 간다. 응답이 왔을 때 키가 바뀌어 있으면 버린다 —
 * 예전엔 All 에서 새로고침 중에 People only 로 바꾸면 늦게 온 All 응답이 새 목록을 덮었다.
 */
export function useFeed({ tab = 'all', media = null, author = null, sort = 'hot', q = '', reloadKey = 0 }: Params) {
  const [posts, setPosts] = useState<FeedPost[]>([]);
  const [country, setCountry] = useState<string | null>(null);
  const [loadedKey, setLoadedKey] = useState<string | null>(null);
  // 새로고침·더 보기 표시도 "어느 조건의 것인지" 로 든다 — 조건이 바뀌면 저절로 꺼진다(effect 로 끄지 않는다)
  const [refreshingKey, setRefreshingKey] = useState<string | null>(null);
  const [loadingMoreKey, setLoadingMoreKey] = useState<string | null>(null);
  const [done, setDone] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const queryKey = `${tab}|${media ?? ''}|${author ?? ''}|${sort}|${q}|${reloadKey}`;
  const keyRef = useRef(queryKey);
  useEffect(() => { keyRef.current = queryKey; }, [queryKey]);
  const loading = loadedKey !== queryKey;
  const refreshing = refreshingKey === queryKey;
  const loadingMore = loadingMoreKey === queryKey;

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
    const mine = keyRef.current;
    setRefreshingKey(mine);
    try {
      const { posts: next, country: c } = await fetchFeed({ offset: 0, tab, media, author, sort, q });
      if (keyRef.current !== mine) return; // 그새 조건이 바뀌었다 — 이 응답은 다른 목록의 것
      setPosts(next);
      setCountry(c);
      setDone(next.length === 0);
      setError(null);
    } catch {
      if (keyRef.current === mine) setError('Could not reach the town.');
    } finally {
      setRefreshingKey((k) => (k === mine ? null : k));
    }
  }, [tab, media, author, sort, q]);

  const loadMore = useCallback(async () => {
    if (loading || loadingMore || done) return;
    const mine = keyRef.current;
    setLoadingMoreKey(mine);
    try {
      const { posts: next } = await fetchFeed({ offset: posts.length, tab, media, author, sort, q });
      if (keyRef.current !== mine) return; // 옛 조건의 다음 장을 새 목록 뒤에 붙이지 않는다
      setPosts((prev) => {
        // 순위가 바뀌어 겹쳐 오는 글은 버린다 (핫 랭킹은 요청 사이에 순서가 흔들린다)
        const seen = new Set(prev.map((p) => p.id));
        return [...prev, ...next.filter((p) => !seen.has(p.id))];
      });
      if (next.length === 0) setDone(true);
    } catch {
      /* 더 읽기 실패는 조용히 — 이미 보고 있는 목록은 그대로 둔다 */
    } finally {
      setLoadingMoreKey((k) => (k === mine ? null : k));
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
