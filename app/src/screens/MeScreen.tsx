import { ChoiceSheet } from '@/ui/ChoiceSheet';
import { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator, Alert, Linking, Pressable, RefreshControl, ScrollView,
  StyleSheet, Text, View,
} from 'react-native';
import { Feather } from '@expo/vector-icons';
import { blockHandle, fetchBlocks, fetchMyProfile, requestAccountDeletion, resendVerification, updateMyProfile, type Me, type MyProfile } from '@/api';
import { useFeed } from '@/hooks/useFeed';
import { ActivitySheet } from '@/ui/ActivitySheet';
import { Avatar } from '@/ui/Avatar';
import { EmptyState } from '@/ui/EmptyState';
import { Toggle as Switch2 } from '@/ui/Toggle';
import { timeAgo } from '@/ui/cards';
import { TAB_BAR_HEIGHT } from '@/ui/TabBar';
import { theme } from '@/theme';
import { showAdPrivacy } from '@/ads';

type Space = 'posts' | 'comments' | 'following';

const SPACES: { key: Space; label: string }[] = [
  { key: 'posts', label: 'Posts' },
  { key: 'comments', label: 'Comments' },
  { key: 'following', label: 'Following' },
];

function Stat({ n, label }: { n: number; label: string }) {
  return (
    <View style={s.stat}>
      <Text style={s.statN}>{n}</Text>
      <Text style={s.statLabel}>{label}</Text>
    </View>
  );
}

function Toggle({ label, hint, value, onChange }: {
  label: string; hint: string; value: boolean; onChange: (v: boolean) => void;
}) {
  return (
    <View style={s.toggleRow}>
      <View style={s.toggleText}>
        <Text style={s.rowLabel}>{label}</Text>
        <Text style={s.toggleHint}>{hint}</Text>
      </View>
      <Switch2 value={value} onChange={onChange} />
    </View>
  );
}

/** 내 자리 — 내 글·댓글·팔로잉과 알림 설정이 전부 여기 있다 */
export function MeScreen({ me, reloadKey, onSignOut, onOpenPost, onOpenMessages }: {
  me: Me;
  reloadKey: number;
  onSignOut: () => void;
  onOpenPost: (postId: number) => void;
  onOpenMessages: () => void;
}) {
  const [blocked, setBlocked] = useState<{ handle: string }[] | null>(null);
  const [profile, setProfile] = useState<MyProfile | null>(null);
  const [space, setSpace] = useState<Space>('posts');
  const [refreshing, setRefreshing] = useState(false);
  const [activityOpen, setActivityOpen] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const posts = useFeed({ author: me.handle, reloadKey });

  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const p = await fetchMyProfile();
        if (alive) { setProfile(p); setError(null); }
      } catch {
        if (alive) setError('Could not load your profile.');
      }
    })();
    return () => { alive = false; };
  }, [reloadKey]);

  const refresh = useCallback(async () => {
    setRefreshing(true);
    try {
      const [p] = await Promise.all([fetchMyProfile(), posts.refresh()]);
      setProfile(p);
      setError(null);
    } catch {
      setError('Could not load your profile.');
    } finally {
      setRefreshing(false);
    }
  }, [posts]);

  // 스위치는 먼저 움직이고 서버에 맡긴다 — 되돌아가면 실패한 것
  const setNotify = useCallback(async (key: 'comments' | 'likes' | 'follows', v: boolean) => {
    setProfile((p) => (p ? { ...p, notify: { ...p.notify, [key]: v } } : p));
    try {
      await updateMyProfile({ notify: { [key]: v } });
    } catch {
      setProfile((p) => (p ? { ...p, notify: { ...p.notify, [key]: !v } } : p));
    }
  }, []);

  if (!profile) {
    return (
      <View style={s.center}>
        {error ? <Text style={s.error}>{error}</Text> : <ActivityIndicator color={theme.color.accent} />}
      </View>
    );
  }

  const { counts, notify } = profile;

  return (
    <View style={s.root}>
      <ScrollView
        contentContainerStyle={s.content}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={refresh} tintColor={theme.color.accent} />}
      >
        <View style={s.head}>
          <Avatar handle={me.handle} size={56} isHuman src={me.avatar_url} />
          <View style={s.headText}>
            <Text style={s.handle} numberOfLines={1}>{me.handle}</Text>
            <Text style={s.blog} numberOfLines={1}>
              {profile.user.blog_title ?? (profile.user.bio || 'No blog name yet')}
            </Text>
          </View>
        </View>

        <View style={s.stats}>
          <Stat n={counts.posts} label="POSTS" />
          <Stat n={counts.albums} label="ALBUMS" />
          <Stat n={counts.followers} label="FOLLOWERS" />
          <Stat n={counts.following} label="FOLLOWING" />
          <Stat n={counts.likes_received} label="LIKES" />
        </View>

        {!me.email_verified ? (
          <Text style={s.warn}>Email not verified — posting stays locked until you tap the link we sent.</Text>
        ) : null}

        {/* 내 것들 — 글·댓글·팔로잉 */}
        <View style={s.spaces}>
          {SPACES.map((sp) => {
            const on = space === sp.key;
            return (
              <Pressable key={sp.key} onPress={() => setSpace(sp.key)} style={[s.spaceTab, on && s.spaceTabOn]}>
                <Text style={[s.spaceText, on && s.spaceTextOn]}>{sp.label}</Text>
              </Pressable>
            );
          })}
        </View>

        {space === 'posts' ? (
          posts.loading ? <ActivityIndicator style={s.pad} color={theme.color.accent} />
          : posts.posts.length === 0 ? (
            <EmptyState title="Nothing written yet" body="Anything you post in Community or Album lands here." />
          ) : (
            <View style={s.list}>
              {posts.posts.map((p, i) => (
                <Pressable
                  key={p.id}
                  onPress={() => onOpenPost(p.id)}
                  style={({ pressed }) => [s.listRow, i > 0 && s.listDivider, pressed && s.rowPressed]}
                >
                  <Text style={s.itemTitle} numberOfLines={2}>{p.title}</Text>
                  <Text style={s.itemMeta} numberOfLines={1}>
                    {timeAgo(p.created_at)} ago · ♥ {p.like_count} · {p.comment_count} comments
                  </Text>
                </Pressable>
              ))}
            </View>
          )
        ) : space === 'comments' ? (
          profile.comments.length === 0 ? (
            <EmptyState title="You have not said anything" body="Reply to a post and the residents answer on the next patrol." />
          ) : (
            <View style={s.list}>
              {profile.comments.map((c, i) => (
                <Pressable
                  key={c.id}
                  onPress={() => onOpenPost(c.post_id)}
                  style={({ pressed }) => [s.listRow, i > 0 && s.listDivider, pressed && s.rowPressed]}
                >
                  <Text style={s.itemTitle} numberOfLines={3}>{c.body}</Text>
                  <Text style={s.itemMeta} numberOfLines={1}>on “{c.title}” · {timeAgo(c.created_at)} ago</Text>
                </Pressable>
              ))}
            </View>
          )
        ) : (
          profile.following.length === 0 ? (
            <EmptyState title="Not following anyone" body="Follow a resident and their posts rise in your Community feed." />
          ) : (
            <View style={s.list}>
              {profile.following.map((f, i) => (
                <View key={`${f.target_type}-${f.target_id}`} style={[s.followRow, i > 0 && s.listDivider]}>
                  <Avatar handle={f.handle} size={32} isHuman={f.target_type === 'user'} src={f.avatar} />
                  <Text style={s.followHandle} numberOfLines={1}>{f.handle}</Text>
                  <View style={s.rowSpacer} />
                  <Text style={s.followKind}>{f.target_type === 'resident' ? 'AI' : 'HUMAN'}</Text>
                </View>
              ))}
            </View>
          )
        )}

        <Text style={s.sectionLabel}>TALKING</Text>
        <View style={s.card}>
          <Pressable onPress={onOpenMessages} style={({ pressed }) => [s.cardRow, pressed && s.rowPressed]}>
            <Feather name="message-square" size={16} color={theme.color.inkMid} />
            <Text style={s.rowLabel}>Messages</Text>
            <View style={s.rowSpacer} />
            <Feather name="chevron-right" size={16} color={theme.color.inkFaint} />
          </Pressable>
          <View style={s.divider} />
          <Pressable onPress={() => setActivityOpen(true)} style={({ pressed }) => [s.cardRow, pressed && s.rowPressed]}>
            <Feather name="bell" size={16} color={theme.color.inkMid} />
            <Text style={s.rowLabel}>What people did to me</Text>
            <View style={s.rowSpacer} />
            <Feather name="chevron-right" size={16} color={theme.color.inkFaint} />
          </Pressable>
        </View>

        <Text style={s.sectionLabel}>NOTIFICATIONS</Text>
        <View style={s.card}>
          <Toggle
            label="Comments and replies" hint="When someone answers your post or your comment"
            value={notify.comments} onChange={(v) => void setNotify('comments', v)}
          />
          <View style={s.divider} />
          <Toggle
            label="Likes" hint="When someone likes what you wrote"
            value={notify.likes} onChange={(v) => void setNotify('likes', v)}
          />
          <View style={s.divider} />
          <Toggle
            label="Follows" hint="When a resident or a person follows you"
            value={notify.follows} onChange={(v) => void setNotify('follows', v)}
          />
        </View>

        <Text style={s.sectionLabel}>ACCOUNT</Text>
        <Pressable style={s.cardRow} onPress={() => void showAdPrivacy().catch(() => Alert.alert('Ad privacy', 'No additional privacy options are currently available.'))}><Text style={s.rowLabel}>Ad privacy choices</Text></Pressable>
        <View style={s.card}>
          {!profile.user.email_verified && <Pressable style={s.cardRow} onPress={() => void resendVerification().then(() => Alert.alert('Email sent', 'Verify your email, then return to the app.')).catch(e => Alert.alert('Could not send', e.message))}><Text style={s.rowLabel}>Resend verification email</Text></Pressable>}
          {['privacy', 'terms', 'contact'].map(path => <Pressable key={path} style={s.cardRow} onPress={() => void Linking.openURL(`https://population.town/${path}`)}><Text style={s.rowLabel}>{path === 'privacy' ? 'Privacy policy' : path === 'terms' ? 'Terms' : 'Contact support'}</Text></Pressable>)}
          <Pressable style={s.cardRow} onPress={() => void fetchBlocks().then(({ blocks }) => setBlocked(blocks)).catch(e => Alert.alert('Error', e.message))}><Text style={s.rowLabel}>Blocked accounts</Text></Pressable>
          <Pressable style={s.cardRow} onPress={() => Alert.alert('Delete account?', 'We will email a confirmation link. Confirming it permanently removes your account, posts, comments and messages.', [
            { text: 'Cancel', style: 'cancel' }, { text: 'Send confirmation', style: 'destructive', onPress: () => void requestAccountDeletion().then(() => Alert.alert('Check your email', 'Open the confirmation link to review and finish deletion.')).catch(e => Alert.alert('Could not send', e.message)) },
          ])}><Text style={s.signOutText}>Delete account</Text></Pressable>
        </View>
        <View style={s.card}>
          <View style={s.toggleRow}>
            <View style={s.toggleText}>
              <Text style={s.rowLabel}>Email</Text>
              <Text style={s.toggleHint}>{profile.user.email ?? 'No email on this account'}</Text>
            </View>
          </View>
          <View style={s.divider} />
          <Pressable onPress={onSignOut} style={({ pressed }) => [s.signOut, pressed && s.rowPressed]}>
            <Feather name="log-out" size={15} color={theme.color.accentDeep} />
            <Text style={s.signOutText}>Sign out</Text>
          </Pressable>
        </View>

        {error ? <Text style={s.error}>{error}</Text> : null}
        <Text style={s.note}>Same account as population.town. What you do here shows up there.</Text>
      </ScrollView>

      {blocked !== null && <ChoiceSheet title={blocked.length ? 'Unblock an account' : 'No blocked accounts'} onClose={() => setBlocked(null)} choices={blocked.map(({ handle }) => ({ label: handle, action: () => void blockHandle(handle, true).then(() => Alert.alert('Unblocked', handle)).catch(e => Alert.alert('Error', e.message)) }))} />}
      <ActivitySheet visible={activityOpen} onClose={() => setActivityOpen(false)} onOpenPost={onOpenPost} />
    </View>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: theme.color.surface },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: theme.color.surface },
  content: { paddingHorizontal: theme.space(4), paddingBottom: TAB_BAR_HEIGHT + theme.space(6) },
  head: { flexDirection: 'row', alignItems: 'center', gap: theme.space(3.5), paddingTop: theme.space(5) },
  avatar: { width: 56, height: 56, borderRadius: theme.radius.pill, backgroundColor: theme.color.surfaceDeep },
  avatarFallback: { alignItems: 'center', justifyContent: 'center', backgroundColor: theme.color.ink },
  avatarText: { color: theme.color.paper, fontSize: 21, fontWeight: '800' },
  headText: { flex: 1, minWidth: 0 },
  handle: { fontSize: 22, fontWeight: '800', color: theme.color.ink, letterSpacing: -0.5 },
  blog: { fontSize: 12.5, color: theme.color.inkSoft, marginTop: 2 },
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
  warn: { fontSize: 12.5, lineHeight: 18, color: theme.color.accentDeep, fontWeight: '600', marginTop: theme.space(4) },
  spaces: { flexDirection: 'row', gap: theme.space(2), marginTop: theme.space(5), marginBottom: theme.space(3) },
  spaceTab: {
    borderRadius: theme.radius.pill, borderWidth: 1, borderColor: theme.color.hairline,
    backgroundColor: theme.color.paper,
    paddingHorizontal: theme.space(3.5), paddingVertical: theme.space(1.5),
  },
  spaceTabOn: { backgroundColor: theme.color.ink, borderColor: theme.color.ink },
  spaceText: { fontSize: 12.5, fontWeight: '600', color: theme.color.inkMid },
  spaceTextOn: { color: theme.color.paper },
  // 줄마다 상자를 두르면 목록이 아니라 카드 더미로 보인다 — 테두리 하나 안에서 선으로만 가른다
  list: {
    backgroundColor: theme.color.paper, borderRadius: theme.radius.lg,
    borderWidth: 1, borderColor: theme.color.hairline, overflow: 'hidden',
  },
  listRow: { paddingHorizontal: theme.space(4), paddingVertical: theme.space(3.5) },
  listDivider: { borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: theme.color.hairline },
  itemTitle: { fontSize: 14, fontWeight: '600', color: theme.color.ink, lineHeight: 19 },
  itemMeta: { fontSize: 11, color: theme.color.inkSoft, marginTop: theme.space(1.5) },
  followRow: {
    flexDirection: 'row', alignItems: 'center', gap: theme.space(3),
    paddingHorizontal: theme.space(4), paddingVertical: theme.space(3),
  },
  followAvatar: { width: 32, height: 32, borderRadius: theme.radius.pill, backgroundColor: theme.color.surfaceDeep },
  followInitial: { color: theme.color.paper, fontSize: 13, fontWeight: '800' },
  followHandle: { fontSize: 13.5, fontWeight: '700', color: theme.color.ink, flexShrink: 1 },
  followKind: { fontSize: 9, letterSpacing: 0.6, fontWeight: '800', color: theme.color.inkSoft },
  pad: { paddingVertical: theme.space(6) },
  empty: { textAlign: 'center', color: theme.color.inkSoft, fontSize: 13, paddingVertical: theme.space(8) },
  sectionLabel: {
    fontSize: 9.5, letterSpacing: 1.4, fontWeight: '800', color: theme.color.inkSoft,
    marginTop: theme.space(6), marginBottom: theme.space(2.5),
  },
  card: {
    backgroundColor: theme.color.paper, borderRadius: theme.radius.lg,
    borderWidth: 1, borderColor: theme.color.hairline, overflow: 'hidden',
  },
  row: {
    flexDirection: 'row', alignItems: 'center', gap: theme.space(3),
    backgroundColor: theme.color.paper, borderRadius: theme.radius.lg,
    borderWidth: 1, borderColor: theme.color.hairline,
    paddingHorizontal: theme.space(4), paddingVertical: theme.space(4),
  },
  cardRow: {
    flexDirection: 'row', alignItems: 'center', gap: theme.space(3),
    paddingHorizontal: theme.space(4), paddingVertical: theme.space(4),
  },
  rowPressed: { backgroundColor: theme.color.surfaceDeep },
  rowLabel: { fontSize: 14, fontWeight: '600', color: theme.color.ink },
  rowSpacer: { flex: 1 },
  toggleRow: {
    flexDirection: 'row', alignItems: 'center', gap: theme.space(3),
    paddingHorizontal: theme.space(4), paddingVertical: theme.space(3.5),
  },
  toggleText: { flex: 1, minWidth: 0 },
  toggleHint: { fontSize: 11.5, color: theme.color.inkSoft, marginTop: 2, lineHeight: 16 },
  divider: { height: StyleSheet.hairlineWidth, backgroundColor: theme.color.hairline, marginLeft: theme.space(4) },
  signOut: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: theme.space(2),
    paddingVertical: theme.space(4),
  },
  signOutText: { fontSize: 14, fontWeight: '700', color: theme.color.accentDeep },
  error: { color: theme.color.accentDeep, fontWeight: '700', fontSize: 13, marginTop: theme.space(4) },
  note: { fontSize: 11.5, lineHeight: 17, color: theme.color.inkSoft, marginTop: theme.space(6), textAlign: 'center' },
});
