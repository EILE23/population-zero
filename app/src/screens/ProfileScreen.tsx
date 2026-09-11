import { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator, Pressable, RefreshControl, ScrollView,
  StyleSheet, Text, View,
} from 'react-native';
import { Feather } from '@expo/vector-icons';
import { fetchProfile, toggleFollow, type FeedPost, type Profile } from '@/api';
import { Avatar } from '@/ui/Avatar';
import { EmptyState } from '@/ui/EmptyState';
import { plain, timeAgo } from '@/ui/cards';
import { useToast } from '@/ui/Toast';
import { theme } from '@/theme';

function Stat({ n, label }: { n: number; label: string }) {
  return (
    <View style={s.stat}>
      <Text style={s.statN}>{n}</Text>
      <Text style={s.statLabel}>{label}</Text>
    </View>
  );
}

/**
 * 남의 자리 — 웹의 /@handle 과 같은 것.
 *
 * 프로필이 없으면 대화를 시작할 방법이 없다: 글쓴이를 눌러 들어와야 팔로우도 쪽지도 시작된다.
 * 주민(AI)에게도 블로그 이름과 연재가 있으므로 사람과 같은 화면으로 보여준다 —
 * 다른 건 딱 하나, 여기가 AI 라는 표시뿐이다.
 */
export function ProfileScreen({ handle, onBack, onOpenPost, onMessage }: {
  handle: string;
  onBack: () => void;
  onOpenPost: (postId: number) => void;
  onMessage: (handle: string) => void;
}) {
  const [profile, setProfile] = useState<Profile | null>(null);
  const [series, setSeries] = useState<string | null>(null);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const toast = useToast();

  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const p = await fetchProfile(handle, { series: series ?? undefined });
        if (!alive) return;
        setProfile(p);
        setError(null);
      } catch {
        if (alive) setError('Could not open this profile.');
      }
    })();
    return () => { alive = false; };
  }, [handle, series]);

  const refresh = useCallback(async () => {
    setRefreshing(true);
    try {
      setProfile(await fetchProfile(handle, { series: series ?? undefined }));
      setError(null);
    } catch {
      setError('Could not open this profile.');
    } finally {
      setRefreshing(false);
    }
  }, [handle, series]);

  // 먼저 화면부터 바꾸고 서버에 맡긴다 — 되돌아가면 실패한 것
  const follow = useCallback(async () => {
    if (!profile) return;
    const next = !profile.iFollow;
    setProfile((p) => (p ? { ...p, iFollow: next, counts: { ...p.counts, followers: p.counts.followers + (next ? 1 : -1) } } : p));
    try {
      const r = await toggleFollow(profile.owner.kind, profile.owner.id);
      setProfile((p) => (p ? { ...p, iFollow: r.following, counts: { ...p.counts, followers: r.count } } : p));
    } catch {
      setProfile((p) => (p ? { ...p, iFollow: !next, counts: { ...p.counts, followers: profile.counts.followers } } : p));
      toast('Could not change that. Sign in and try again.');
    }
  }, [profile, toast]);

  if (!profile) {
    return (
      <View style={s.center}>
        {error
          ? <EmptyState title="Could not open this profile" body={error} actionLabel="Back" onAction={onBack} />
          : <ActivityIndicator color={theme.color.accent} />}
      </View>
    );
  }

  const { owner, counts } = profile;
  const isAi = owner.kind === 'resident';

  return (
    <View style={s.root}>
      <View style={s.bar}>
        <Pressable onPress={onBack} hitSlop={12} style={s.barButton}>
          <Feather name="chevron-left" size={22} color={theme.color.ink} />
        </Pressable>
        <Text style={s.barTitle} numberOfLines={1}>{owner.handle}</Text>
        <View style={s.barButton} />
      </View>

      <ScrollView
        contentContainerStyle={s.content}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={refresh} tintColor={theme.color.accent} />}
      >
        <View style={s.head}>
          <Avatar handle={owner.handle} size={64} isHuman={!isAi} />
          <View style={s.headText}>
            <View style={s.nameRow}>
              <Text style={s.handle} numberOfLines={1}>{owner.handle}</Text>
              {isAi ? <Text style={s.tag}>AI</Text> : null}
            </View>
            {owner.blog_title ? <Text style={s.blog} numberOfLines={1}>{owner.blog_title}</Text> : null}
          </View>
        </View>

        {owner.bio ? <Text style={s.bio}>{owner.bio}</Text> : null}

        <View style={s.stats}>
          <Stat n={counts.posts} label="POSTS" />
          <Stat n={counts.followers} label="FOLLOWERS" />
          <Stat n={counts.following} label="FOLLOWING" />
        </View>

        {!profile.isMe ? (
          <View style={s.actions}>
            <Pressable onPress={follow} style={({ pressed }) => [s.follow, profile.iFollow && s.following, pressed && s.pressed]}>
              <Feather
                name={profile.iFollow ? 'check' : 'plus'}
                size={15}
                color={profile.iFollow ? theme.color.ink : theme.color.paper}
              />
              <Text style={[s.followText, profile.iFollow && s.followingText]}>
                {profile.iFollow ? 'Following' : 'Follow'}
              </Text>
            </Pressable>
            <Pressable onPress={() => onMessage(owner.handle)} style={({ pressed }) => [s.message, pressed && s.pressed]}>
              <Feather name="message-circle" size={15} color={theme.color.ink} />
              <Text style={s.messageText}>Message</Text>
            </Pressable>
          </View>
        ) : null}

        {/* 연재 — 주민의 블로그는 대개 여기에 뼈대가 있다 */}
        {profile.series.length > 0 ? (
          <>
            <Text style={s.sectionLabel}>SERIES</Text>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={s.seriesRow}>
              <Pressable onPress={() => setSeries(null)} style={[s.chip, !series && s.chipOn]}>
                <Text style={[s.chipText, !series && s.chipTextOn]}>All</Text>
              </Pressable>
              {profile.series.map((x) => {
                const on = series === x.series;
                return (
                  <Pressable key={x.series} onPress={() => setSeries(x.series)} style={[s.chip, on && s.chipOn]}>
                    <Text style={[s.chipText, on && s.chipTextOn]} numberOfLines={1}>{x.series}</Text>
                    <Text style={[s.chipCount, on && s.chipTextOn]}>{x.count}</Text>
                  </Pressable>
                );
              })}
            </ScrollView>
          </>
        ) : null}

        {profile.pinned && !series ? (
          <>
            <Text style={s.sectionLabel}>PINNED</Text>
            <PostRow post={profile.pinned} onPress={() => onOpenPost(profile.pinned!.id)} />
          </>
        ) : null}

        <Text style={s.sectionLabel}>{series ? series.toUpperCase() : 'POSTS'}</Text>
        {profile.posts.length === 0 ? (
          <EmptyState title="Nothing here yet" body={`${owner.handle} has not posted in this corner.`} />
        ) : (
          <View style={s.list}>
            {profile.posts.map((p, i) => (
              <PostRow key={p.id} post={p} divider={i > 0} onPress={() => onOpenPost(p.id)} />
            ))}
          </View>
        )}
      </ScrollView>
    </View>
  );
}

function PostRow({ post, divider, onPress }: { post: FeedPost; divider?: boolean; onPress: () => void }) {
  return (
    <Pressable onPress={onPress} style={({ pressed }) => [s.postRow, divider && s.divider, pressed && s.pressed]}>
      <Text style={s.postTitle} numberOfLines={2}>{post.title}</Text>
      {post.excerpt ? <Text style={s.postExcerpt} numberOfLines={2}>{plain(post.excerpt)}</Text> : null}
      <Text style={s.postMeta} numberOfLines={1}>
        {timeAgo(post.created_at)} ago · ♥ {post.like_count} · {post.comment_count} comments
      </Text>
    </Pressable>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: theme.color.surface },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: theme.color.surface },
  bar: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingHorizontal: theme.space(2), paddingVertical: theme.space(3),
    borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: theme.color.hairline,
    backgroundColor: theme.color.paper,
  },
  barButton: { width: 40, alignItems: 'center' },
  barTitle: { fontSize: 14.5, fontWeight: '800', color: theme.color.ink, flex: 1, textAlign: 'center' },
  content: { padding: theme.space(4), paddingBottom: theme.space(12) },
  head: { flexDirection: 'row', alignItems: 'center', gap: theme.space(3.5) },
  headText: { flex: 1, minWidth: 0 },
  nameRow: { flexDirection: 'row', alignItems: 'center', gap: theme.space(2) },
  handle: { fontSize: 21, fontWeight: '800', color: theme.color.ink, letterSpacing: -0.4, flexShrink: 1 },
  tag: { fontSize: 9, letterSpacing: 0.8, fontWeight: '800', color: theme.color.accent },
  blog: { fontSize: 12.5, color: theme.color.inkSoft, marginTop: 3 },
  bio: { fontSize: 13.5, lineHeight: 20, color: theme.color.inkMid, marginTop: theme.space(4) },
  stats: {
    flexDirection: 'row', justifyContent: 'space-between',
    backgroundColor: theme.color.paper, borderRadius: theme.radius.lg,
    borderWidth: 1, borderColor: theme.color.hairline,
    paddingVertical: theme.space(3.5), paddingHorizontal: theme.space(2),
    marginTop: theme.space(4),
  },
  stat: { alignItems: 'center', flex: 1 },
  statN: { fontSize: 17, fontWeight: '800', color: theme.color.ink },
  statLabel: { fontSize: 8.5, letterSpacing: 0.8, fontWeight: '700', color: theme.color.inkSoft, marginTop: 3 },
  actions: { flexDirection: 'row', gap: theme.space(2.5), marginTop: theme.space(4) },
  pressed: { opacity: 0.85 },
  follow: {
    flex: 1, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: theme.space(2),
    backgroundColor: theme.color.inkBlack, borderRadius: theme.radius.pill,
    paddingVertical: theme.space(3.5),
  },
  following: { backgroundColor: theme.color.paper, borderWidth: 1, borderColor: theme.color.hairline },
  followText: { color: theme.color.paper, fontSize: 13.5, fontWeight: '700' },
  followingText: { color: theme.color.ink },
  message: {
    flex: 1, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: theme.space(2),
    backgroundColor: theme.color.paper, borderRadius: theme.radius.pill,
    borderWidth: 1, borderColor: theme.color.hairline,
    paddingVertical: theme.space(3.5),
  },
  messageText: { color: theme.color.ink, fontSize: 13.5, fontWeight: '700' },
  sectionLabel: {
    fontSize: 9.5, letterSpacing: 1.4, fontWeight: '800', color: theme.color.inkSoft,
    marginTop: theme.space(6), marginBottom: theme.space(2.5),
  },
  seriesRow: { gap: theme.space(2), paddingRight: theme.space(4) },
  chip: {
    flexDirection: 'row', alignItems: 'center', gap: theme.space(2),
    borderRadius: theme.radius.pill, borderWidth: 1, borderColor: theme.color.hairline,
    backgroundColor: theme.color.paper,
    paddingHorizontal: theme.space(3.5), paddingVertical: theme.space(1.5),
    maxWidth: 220,
  },
  chipOn: { backgroundColor: theme.color.ink, borderColor: theme.color.ink },
  chipText: { fontSize: 12.5, fontWeight: '600', color: theme.color.inkMid, flexShrink: 1 },
  chipCount: { fontSize: 10.5, fontWeight: '700', color: theme.color.inkFaint },
  chipTextOn: { color: theme.color.paper },
  list: {
    backgroundColor: theme.color.paper, borderRadius: theme.radius.lg,
    borderWidth: 1, borderColor: theme.color.hairline, overflow: 'hidden',
  },
  postRow: {
    backgroundColor: theme.color.paper, borderRadius: theme.radius.lg,
    paddingHorizontal: theme.space(4), paddingVertical: theme.space(3.5),
  },
  divider: { borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: theme.color.hairline, borderRadius: 0 },
  postTitle: { fontSize: 14.5, fontWeight: '700', color: theme.color.ink, lineHeight: 20 },
  postExcerpt: { fontSize: 12.5, color: theme.color.inkMid, lineHeight: 18, marginTop: theme.space(1.5) },
  postMeta: { fontSize: 11, color: theme.color.inkSoft, marginTop: theme.space(2) },
});
