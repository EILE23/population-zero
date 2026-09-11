import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  ActivityIndicator, FlatList, Image, Pressable, RefreshControl,
  StyleSheet, Text, View,
} from 'react-native';
import * as WebBrowser from 'expo-web-browser';
import { Feather, Ionicons } from '@expo/vector-icons';
import { anonId, fetchToday, sendTrendEvents, type TodayFeed, type TrendItem } from '@/api';
import { AdSlot } from '@/ui/AdSlot';
import { CategoryButton, CategoryPicker, type PickerGroup } from '@/ui/CategoryPicker';
import { EmptyState } from '@/ui/EmptyState';
import { FadeIn, timeAgo } from '@/ui/cards';
import { TAB_BAR_HEIGHT } from '@/ui/TabBar';
import { theme } from '@/theme';

const COUNTRY_NAME: Record<string, string> = {
  US: 'the United States', GB: 'the UK', KR: 'Korea', JP: 'Japan', IN: 'India',
  BR: 'Brazil', DE: 'Germany', FR: 'France', MX: 'Mexico', AU: 'Australia',
  ID: 'Indonesia', NG: 'Nigeria',
};

/** 분류는 성격이 다른 두 묶음이다 — 어디서 온 것인지(종류) 와 무엇에 관한 것인지(주제) */
const GROUPS: PickerGroup[] = [
  {
    title: 'EVERYTHING',
    options: [{ key: '', label: 'All', hint: 'News, searches and video together' }],
  },
  {
    title: 'WHERE IT COMES FROM',
    options: [
      { key: 'kind:news', label: 'News', hint: 'Headlines from publishers' },
      { key: 'kind:keyword', label: 'Searched now', hint: 'What people are typing into search' },
      { key: 'kind:video', label: 'Watched', hint: 'Trending video' },
    ],
  },
  {
    title: 'WHAT IT IS ABOUT',
    options: [
      { key: 'topic:world', label: 'World' },
      { key: 'topic:business', label: 'Business' },
      { key: 'topic:tech', label: 'Technology' },
      { key: 'topic:entertainment', label: 'Entertainment' },
      { key: 'topic:sports', label: 'Sports' },
      { key: 'topic:science', label: 'Science' },
      { key: 'topic:gaming', label: 'Gaming' },
      { key: 'topic:food', label: 'Food' },
      { key: 'topic:culture', label: 'Culture' },
    ],
  },
];

const LABEL_OF = new Map(GROUPS.flatMap((g) => g.options.map((o) => [o.key, o.label] as const)));

/** 종류마다 한 줄로 무엇인지 밝힌다 — 어디서 온 건지 모호한 카드는 올리지 않는다 */
function sourceLine(item: TrendItem): string {
  switch (item.kind) {
    case 'news': return item.source ?? 'News';
    case 'keyword': return 'Searched now';
    case 'video': return 'Trending video';
  }
}

/** 큰 카드 — 사진이 있는 항목. 목록에 리듬을 주려고 세 번째마다 크게 쓴다 */
function LeadCard({ item, onOpen }: { item: TrendItem; onOpen: (i: TrendItem) => void }) {
  return (
    <Pressable onPress={() => onOpen(item)} style={({ pressed }) => [s.lead, pressed && s.pressed]}>
      <Image source={{ uri: item.image! }} style={s.leadImage} resizeMode="cover" />
      <View style={s.leadBody}>
        <View style={s.sourceRow}>
          <Text style={s.source}>{sourceLine(item).toUpperCase()}</Text>
          <Text style={s.dot}>·</Text>
          <Text style={s.time}>{timeAgo(item.collected_at)}</Text>
        </View>
        <Text style={s.leadTitle} numberOfLines={3}>{item.title}</Text>
        {item.summary ? <Text style={s.summary} numberOfLines={2}>{item.summary}</Text> : null}
      </View>
    </Pressable>
  );
}

/** 작은 줄 — 왼쪽 글, 오른쪽 썸네일. 대부분의 항목이 이 모양이라 빠르게 훑힌다 */
function CompactRow({ item, onOpen }: { item: TrendItem; onOpen: (i: TrendItem) => void }) {
  const openable = !!item.url;
  return (
    <Pressable
      onPress={() => openable && onOpen(item)}
      disabled={!openable}
      style={({ pressed }) => [s.row, pressed && openable && s.pressed]}
    >
      <View style={s.rowText}>
        <View style={s.sourceRow}>
          <Text style={s.source}>{sourceLine(item).toUpperCase()}</Text>
          <Text style={s.dot}>·</Text>
          <Text style={s.time}>{timeAgo(item.collected_at)}</Text>
        </View>
        <Text style={s.rowTitle} numberOfLines={3}>{item.title}</Text>
      </View>
      {item.image ? <Image source={{ uri: item.image }} style={s.rowThumb} resizeMode="cover" /> : null}
    </Pressable>
  );
}

type Entry =
  | { type: 'item'; item: TrendItem; lead: boolean }
  | { type: 'ad'; key: string };

/**
 * Today — 지금 이 나라가 어떻게 돌아가고 있는지, 끝없이.
 * 커뮤니티와 성격이 다르다: 의견도 좋아요도 없고 사실·출처·시각만 있다.
 * 전문은 언론사 페이지를 앱 안에서 연다(재게시하지 않는다).
 * 무엇을 보고 눌렀는지는 서버로 보내 다음 순서에 반영된다.
 */
export function TodayScreen() {
  const [feed, setFeed] = useState<TodayFeed | null>(null);
  const [items, setItems] = useState<TrendItem[]>([]);
  const [filter, setFilter] = useState<string>('');
  const [pickerOpen, setPickerOpen] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [anon, setAnon] = useState<string>('');

  // 화면에 보인 항목은 모아 두었다가 한 번에 보낸다 — 스크롤마다 요청하지 않으려고
  const pending = useRef<Map<number, TrendItem>>(new Map());
  const sentViews = useRef<Set<number>>(new Set());

  const kind = filter.startsWith('kind:') ? filter.slice(5) : undefined;
  const topic = filter.startsWith('topic:') ? filter.slice(6) : undefined;

  useEffect(() => { void anonId().then(setAnon); }, []);

  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const data = await fetchToday({ kind, topic, anon: anon || undefined });
        if (!alive) return;
        setFeed(data);
        setItems(data.items);
        setError(null);
      } catch {
        if (alive) { setItems([]); setError('Could not reach the wire.'); }
      }
    })();
    return () => { alive = false; };
  }, [kind, topic, anon]);

  const flush = useCallback(async () => {
    if (!anon || pending.current.size === 0) return;
    const batch = [...pending.current.values()].map((i) => ({
      trend_id: i.id, action: 'view' as const, topic: i.topic, source: i.source, kind: i.kind,
    }));
    pending.current.clear();
    await sendTrendEvents(anon, batch);
  }, [anon]);

  // 화면을 벗어나면 남은 기록을 보낸다
  useEffect(() => () => { void flush(); }, [flush]);

  const refresh = useCallback(async () => {
    setRefreshing(true);
    try {
      const data = await fetchToday({ kind, topic, anon: anon || undefined });
      setFeed(data);
      setItems(data.items);
      setError(null);
    } catch {
      setError('Could not reach the wire.');
    } finally {
      setRefreshing(false);
    }
  }, [kind, topic, anon]);

  const loadMore = useCallback(async () => {
    if (loadingMore || !feed?.hasMore) return;
    setLoadingMore(true);
    try {
      const data = await fetchToday({ offset: items.length, kind, topic, anon: anon || undefined });
      setItems((prev) => {
        const seen = new Set(prev.map((i) => i.id));
        return [...prev, ...data.items.filter((i) => !seen.has(i.id))];
      });
      setFeed(data);
      void flush(); // 한 페이지를 다 본 시점 = 기록을 넘길 좋은 때
    } catch {
      /* 더 읽기 실패는 조용히 — 보고 있던 목록은 그대로 둔다 */
    } finally {
      setLoadingMore(false);
    }
  }, [loadingMore, feed?.hasMore, items.length, kind, topic, anon, flush]);

  // 언론사 페이지를 앱 안에서 연다 — 우리 색으로 칠한 브라우저라 앱을 벗어난 느낌이 없다
  const open = useCallback(async (item: TrendItem) => {
    if (!item.url) return;
    if (anon) {
      void sendTrendEvents(anon, [{
        trend_id: item.id, action: 'open', topic: item.topic, source: item.source, kind: item.kind,
      }]);
    }
    await WebBrowser.openBrowserAsync(item.url, {
      toolbarColor: theme.color.paper,
      controlsColor: theme.color.accent,
      enableBarCollapsing: true,
      dismissButtonStyle: 'close',
    });
  }, [anon]);

  // 사진 있는 항목은 세 번째마다 크게, 그리고 여섯 칸마다 광고 한 칸이 지나간다
  const entries = useMemo<Entry[]>(() => {
    const out: Entry[] = [];
    items.forEach((item, i) => {
      out.push({ type: 'item', item, lead: !!item.image && i % 6 === 0 });
      if ((i + 1) % 6 === 0) out.push({ type: 'ad', key: `ad-${i}` });
    });
    return out;
  }, [items]);

  const where = feed?.region ? (COUNTRY_NAME[feed.region] ?? feed.region) : null;

  if (!feed) {
    return (
      <View style={s.center}>
        {error
          ? <EmptyState title="Could not reach the wire" body={error} actionLabel="Try again" onAction={refresh} />
          : <ActivityIndicator color={theme.color.accent} />}
      </View>
    );
  }

  return (
    <View style={s.root}>
      <FlatList
        data={entries}
        keyExtractor={(e) => (e.type === 'ad' ? e.key : `t-${e.item.id}`)}
        contentContainerStyle={s.content}
        ListHeaderComponent={
          <View style={s.header}>
            <View style={s.headerRow}>
              <Ionicons name="newspaper-outline" size={23} color={theme.color.ink} />
              <CategoryButton label={LABEL_OF.get(filter) ?? 'All'} onPress={() => setPickerOpen(true)} />
            </View>
            {/* 문장으로 늘어놓는 대신 표식으로 — 어디 것인지, 내게 맞춰졌는지만 알면 된다 */}
            <View style={s.subRow}>
              <Feather name="map-pin" size={11} color={theme.color.inkSoft} />
              <Text style={s.sub}>{where ?? 'Worldwide'}</Text>
              {feed.personalized ? (
                <>
                  <Text style={s.subDot}>·</Text>
                  <Feather name="sliders" size={11} color={theme.color.accent} />
                  <Text style={[s.sub, s.subTuned]}>Tuned to you</Text>
                </>
              ) : null}
            </View>
          </View>
        }
        ListEmptyComponent={
          <EmptyState
            title="Nothing here right now"
            body={error ?? 'Try another category, or pull down to check the wire again.'}
            actionLabel="Show everything"
            onAction={() => setFilter('')}
          />
        }
        renderItem={({ item: entry, index }) => {
          if (entry.type === 'ad') return <AdSlot />;
          const { item, lead } = entry;
          // 화면에 그려진 것 = 본 것. 같은 항목을 두 번 세지 않는다
          if (!sentViews.current.has(item.id)) {
            sentViews.current.add(item.id);
            pending.current.set(item.id, item);
          }
          return (
            <FadeIn index={index}>
              {lead ? <LeadCard item={item} onOpen={open} /> : <CompactRow item={item} onOpen={open} />}
            </FadeIn>
          );
        }}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={refresh} tintColor={theme.color.accent} />}
        onEndReached={loadMore}
        onEndReachedThreshold={0.7}
        ListFooterComponent={
          loadingMore ? <ActivityIndicator style={s.footer} color={theme.color.inkSoft} />
          : items.length > 0 && !feed.hasMore ? <Text style={s.end}>That is everything on the wire today.</Text>
          : null
        }
      />

      <CategoryPicker
        visible={pickerOpen}
        value={filter}
        groups={GROUPS}
        onSelect={setFilter}
        onClose={() => setPickerOpen(false)}
      />
    </View>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: theme.color.surface },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: theme.color.surface },
  content: { paddingHorizontal: theme.space(3), paddingBottom: TAB_BAR_HEIGHT + theme.space(6) },
  header: { paddingTop: theme.space(4), paddingBottom: theme.space(3.5), paddingHorizontal: theme.space(1) },
  headerRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  heading: { fontSize: 21, fontWeight: '800', color: theme.color.ink, letterSpacing: -0.4 },
  subRow: { flexDirection: 'row', alignItems: 'center', gap: theme.space(1.5), marginTop: 5 },
  sub: { fontSize: 12, color: theme.color.inkSoft },
  subDot: { fontSize: 11, color: theme.color.inkFaint, marginHorizontal: 2 },
  subTuned: { color: theme.color.accent, fontWeight: '700' },
  pressed: { opacity: 0.9 },
  sourceRow: { flexDirection: 'row', alignItems: 'center', gap: theme.space(1.5) },
  source: { fontSize: 9.5, letterSpacing: 1, fontWeight: '800', color: theme.color.accent },
  dot: { fontSize: 9.5, color: theme.color.inkFaint },
  time: { fontSize: 10, color: theme.color.inkFaint, fontWeight: '600' },
  lead: {
    backgroundColor: theme.color.paper, borderRadius: theme.radius.lg, overflow: 'hidden',
    borderWidth: 1, borderColor: theme.color.hairline, marginBottom: theme.space(3),
  },
  leadImage: { width: '100%', height: 196, backgroundColor: theme.color.surfaceDeep },
  leadBody: { padding: theme.space(4) },
  leadTitle: { fontSize: 17.5, fontWeight: '800', color: theme.color.ink, lineHeight: 24, marginTop: theme.space(2) },
  summary: { fontSize: 13, color: theme.color.inkMid, lineHeight: 19, marginTop: theme.space(2) },
  row: {
    flexDirection: 'row', alignItems: 'center', gap: theme.space(3),
    backgroundColor: theme.color.paper, borderRadius: theme.radius.md,
    borderWidth: 1, borderColor: theme.color.hairline,
    padding: theme.space(3.5), marginBottom: theme.space(2),
  },
  rowText: { flex: 1, minWidth: 0 },
  rowTitle: { fontSize: 14.5, fontWeight: '700', color: theme.color.ink, lineHeight: 20, marginTop: theme.space(1.5) },
  rowThumb: { width: 78, height: 78, borderRadius: theme.radius.sm, backgroundColor: theme.color.surfaceDeep },
  footer: { paddingVertical: theme.space(6) },
  end: {
    textAlign: 'center', fontSize: 11.5, color: theme.color.inkFaint,
    paddingVertical: theme.space(8),
  },
});
