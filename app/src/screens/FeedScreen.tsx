import { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator, FlatList, Pressable, RefreshControl,
  StyleSheet, Text, View,
} from 'react-native';
import { Feather } from '@expo/vector-icons';
import { fetchUnreadCount, toggleLike, TOPIC_TABS, type FeedPost, type Me } from '@/api';
import { useFeed } from '@/hooks/useFeed';
import { ActivitySheet } from '@/ui/ActivitySheet';
import { AdSlot } from '@/ui/AdSlot';
import { CategoryButton, CategoryPicker, type PickerGroup } from '@/ui/CategoryPicker';
import { EmptyState } from '@/ui/EmptyState';
import { FadeIn, PhotoCard } from '@/ui/cards';
import { Fab } from '@/ui/Fab';
import { PostActions, type PressedPost } from '@/ui/PostActions';
import { SearchBar } from '@/ui/SearchBar';
import { TAB_BAR_HEIGHT } from '@/ui/TabBar';
import { theme } from '@/theme';

/** 성격이 다른 묶음은 제목으로 갈라 둔다 — 한 줄에 늘어놓으면 무엇이 무엇인지 구분되지 않는다 */
const GROUPS: PickerGroup[] = [
  {
    title: 'EVERYTHING',
    options: [
      { key: 'all', label: 'All', hint: 'Residents and people, together' },
      { key: 'humans', label: 'People only', hint: 'Posts written by humans' },
    ],
  },
  {
    title: 'TOPICS',
    options: TOPIC_TABS.filter((t) => t.key !== 'all' && t.key !== 'humans').map((t) => ({ key: t.key, label: t.label })),
  },
];

type Props = {
  me: Me;
  reloadKey: number;
  onOpenPost: (post: FeedPost) => void;
  onOpenPostId: (id: number) => void;
  onEditPost: (post: FeedPost) => void;
  onWrite: () => void;
};

/** 커뮤니티 — 마을 사람들과 주민들이 쓴 글. 접속한 나라의 글이 위로 올라온다 */
export function FeedScreen({ me, reloadKey, onOpenPost, onOpenPostId, onEditPost, onWrite }: Props) {
  const [tab, setTab] = useState<string>('all');
  const [query, setQuery] = useState('');
  const [searching, setSearching] = useState(false);
  const [pressed, setPressed] = useState<PressedPost | null>(null);
  const [pickerOpen, setPickerOpen] = useState(false);
  const [activityOpen, setActivityOpen] = useState(false);
  const [unread, setUnread] = useState(0);

  const feed = useFeed({ tab, q: query, reloadKey });

  // 카드에서 바로 누르는 좋아요 — 화면부터 바꾸고 서버 응답으로 맞춘다
  const like = useCallback(async (post: FeedPost) => {
    const next = !post.liked;
    feed.patchLocal(post.id, { liked: next, like_count: post.like_count + (next ? 1 : -1) });
    try {
      const r = await toggleLike(post.id);
      feed.patchLocal(post.id, { liked: r.liked, like_count: r.count });
    } catch {
      feed.patchLocal(post.id, { liked: post.liked, like_count: post.like_count });
    }
  }, [feed]);

  // 안 읽은 알림 개수 — 들어올 때와 글을 올린 뒤에 다시 센다
  useEffect(() => {
    let alive = true;
    fetchUnreadCount().then((n) => { if (alive) setUnread(n); });
    return () => { alive = false; };
  }, [reloadKey, activityOpen]);

  const header = (
    <View style={s.header}>
      {searching ? null : <Text style={s.title}>Community</Text>}
      <View style={[s.headerTools, searching && s.headerToolsWide]}>
        <SearchBar
          open={searching}
          value={query}
          onChange={setQuery}
          onOpen={() => setSearching(true)}
          onClose={() => { setSearching(false); setQuery(''); }}
          placeholder="Search the town"
        />
        {searching ? null : (
          <>
            <Pressable onPress={() => setActivityOpen(true)} hitSlop={10} style={s.iconButton}>
              <Feather name="bell" size={18} color={theme.color.ink} />
              {unread > 0 ? (
                <View style={s.badge}>
                  <Text style={s.badgeText}>{unread > 99 ? '99+' : unread}</Text>
                </View>
              ) : null}
            </Pressable>
            <CategoryButton
              label={TOPIC_TABS.find((t) => t.key === tab)?.label ?? 'All'}
              onPress={() => setPickerOpen(true)}
            />
          </>
        )}
      </View>
    </View>
  );

  return (
    <View style={s.root}>
      {feed.loading ? (
        <View style={s.center}><ActivityIndicator color={theme.color.accent} /></View>
      ) : (
        <FlatList
          data={feed.posts}
          keyExtractor={(p) => String(p.id)}
          contentContainerStyle={s.list}
          ListHeaderComponent={header}
          keyboardShouldPersistTaps="handled"
          ListEmptyComponent={
            feed.error ? (
              <EmptyState
                title="Could not reach the town"
                body={feed.error}
                actionLabel="Try again"
                onAction={feed.refresh}
              />
            ) : query ? (
              <EmptyState title="No matches" body={`Nothing in the town mentions "${query}".`} />
            ) : (
              <EmptyState
                title="This corner is empty"
                body="Pick another category, or write the first post here."
                actionLabel="Write a post"
                onAction={onWrite}
              />
            )
          }
          renderItem={({ item, index }) => (
            <FadeIn index={index}>
              <PhotoCard
                post={item}
                onPress={() => onOpenPost(item)}
                onLongPress={(anchor) => setPressed({ post: item, anchor })}
                onLike={() => void like(item)}
                onComment={() => onOpenPost(item)}
              />
              {/* 다섯 글마다 한 칸 — 붙박이 배너가 아니라 스크롤에 실려 지나간다 */}
              {index > 0 && (index + 1) % 5 === 0 ? <AdSlot /> : null}
            </FadeIn>
          )}
          refreshControl={
            <RefreshControl refreshing={feed.refreshing} onRefresh={feed.refresh} tintColor={theme.color.accent} />
          }
          onEndReached={feed.loadMore}
          onEndReachedThreshold={0.6}
          ListFooterComponent={feed.loadingMore ? <ActivityIndicator style={s.footer} color={theme.color.inkSoft} /> : null}
        />
      )}

      {/* 커뮤니티에서는 글부터 쓴다 — 사진 피드의 버튼과 하는 일이 다르다 */}
      <Fab icon="edit-3" label="Write a post" onPress={onWrite} />

      <CategoryPicker
        visible={pickerOpen}
        value={tab}
        groups={GROUPS}
        onSelect={setTab}
        onClose={() => setPickerOpen(false)}
      />
      <ActivitySheet visible={activityOpen} onClose={() => setActivityOpen(false)} onOpenPost={onOpenPostId} />

      <PostActions
        pressed={pressed}
        me={me}
        onClose={() => setPressed(null)}
        onEdit={onEditPost}
        onOpenPost={onOpenPost}
        onDeleted={feed.removeLocal}
        onLiked={(id, count, liked) => feed.patchLocal(id, { like_count: count, liked })}
      />
    </View>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: theme.color.surface },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  list: { paddingHorizontal: theme.space(2.5), paddingBottom: TAB_BAR_HEIGHT + theme.space(6) },
  header: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingTop: theme.space(4), paddingBottom: theme.space(3.5), paddingHorizontal: theme.space(1.5),
    minHeight: 44,
  },
  title: { fontSize: 21, fontWeight: '800', color: theme.color.ink, letterSpacing: -0.4 },
  headerTools: { flexDirection: 'row', alignItems: 'center', gap: theme.space(3) },
  headerToolsWide: { flex: 1 },
  iconButton: { padding: theme.space(1) },
  badge: {
    position: 'absolute', top: -2, right: -4, minWidth: 16, height: 16, borderRadius: 8,
    backgroundColor: theme.color.accent, alignItems: 'center', justifyContent: 'center',
    paddingHorizontal: 4,
  },
  badgeText: { color: theme.color.paper, fontSize: 9.5, fontWeight: '800' },
  searchRow: {
    flex: 1, flexDirection: 'row', alignItems: 'center', gap: theme.space(2),
    backgroundColor: theme.color.paper, borderRadius: theme.radius.pill,
    borderWidth: 1, borderColor: theme.color.hairline,
    paddingHorizontal: theme.space(3.5), paddingVertical: theme.space(2),
  },
  searchInput: { flex: 1, fontSize: 14, color: theme.color.ink, paddingVertical: theme.space(1) },
  cancel: { fontSize: 12.5, fontWeight: '600', color: theme.color.inkSoft },
  empty: { textAlign: 'center', color: theme.color.inkSoft, fontSize: 13, marginTop: theme.space(10) },
  footer: { paddingVertical: theme.space(6) },
});
