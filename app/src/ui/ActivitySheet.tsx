import { useEffect, useMemo, useState } from 'react';
import { ActivityIndicator, Animated, Easing, Modal, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { Feather, Ionicons } from '@expo/vector-icons';
import { fetchNotifications, type Notification } from '@/api';
import { Avatar } from '@/ui/Avatar';
import { timeAgo } from '@/ui/cards';
import { theme } from '@/theme';

/** 알림 종류별로 아이콘과 문장이 다르다 — 무슨 일이 있었는지 한 줄로 읽히게 */
function describe(n: Notification): { icon: keyof typeof Ionicons.glyphMap; line: string } {
  switch (n.type) {
    case 'like': return { icon: 'heart', line: 'liked your post' };
    case 'comment': return { icon: 'chatbubble', line: 'commented on your post' };
    case 'reply': return { icon: 'return-down-forward', line: 'replied to you' };
    case 'follow': return { icon: 'person-add', line: 'followed you' };
  }
}

/**
 * 활동 — 누가 나한테 무엇을 했는지.
 * 커뮤니티가 커뮤니티이려면 이게 있어야 한다: 내 글에 달린 반응이 어딘가 쌓여 있어야
 * 다시 들어올 이유가 생긴다. 여는 순간 서버가 읽음으로 표시한다.
 */
export function ActivitySheet({ visible, onClose, onOpenPost }: {
  visible: boolean;
  onClose: () => void;
  onOpenPost: (postId: number) => void;
}) {
  const [items, setItems] = useState<Notification[] | null>(null);
  const [seenAt, setSeenAt] = useState('');
  const [error, setError] = useState<string | null>(null);

  const anim = useMemo(() => new Animated.Value(0), []);
  useEffect(() => {
    Animated.timing(anim, {
      toValue: visible ? 1 : 0,
      duration: visible ? 260 : 180,
      easing: visible ? Easing.out(Easing.cubic) : Easing.in(Easing.cubic),
      useNativeDriver: true,
    }).start();
  }, [anim, visible]);

  useEffect(() => {
    if (!visible) return;
    let alive = true;
    (async () => {
      try {
        const data = await fetchNotifications();
        if (!alive) return;
        setItems(data.items);
        setSeenAt(data.seenAt);
        setError(null);
      } catch {
        if (alive) setError('Could not load your activity.');
      }
    })();
    return () => { alive = false; };
  }, [visible]);

  const rise = anim.interpolate({ inputRange: [0, 1], outputRange: [700, 0] });

  return (
    <Modal visible={visible} transparent animationType="none" onRequestClose={onClose}>
      <Pressable style={s.backdropTouch} onPress={onClose}>
        <Animated.View style={[s.backdrop, { opacity: anim }]} />
      </Pressable>
      <Animated.View style={[s.sheet, { transform: [{ translateY: rise }] }]}>
        <View style={s.grip} />
        <View style={s.head}>
          <Text style={s.headTitle}>Activity</Text>
          <Pressable onPress={onClose} hitSlop={12}>
            <Feather name="x" size={19} color={theme.color.inkMid} />
          </Pressable>
        </View>

        {items == null ? (
          <View style={s.center}>
            {error ? <Text style={s.error}>{error}</Text> : <ActivityIndicator color={theme.color.accent} />}
          </View>
        ) : items.length === 0 ? (
          <Text style={s.empty}>Nothing yet. Post something and the residents will come to you.</Text>
        ) : (
          <ScrollView contentContainerStyle={s.list}>
            {items.map((n, i) => {
              const { icon, line } = describe(n);
              // 마지막으로 확인한 시각 이후 = 아직 안 본 것
              const fresh = n.created_at > seenAt;
              return (
                <Pressable
                  key={`${n.type}-${n.created_at}-${i}`}
                  onPress={() => { if (n.post_id) { onOpenPost(n.post_id); onClose(); } }}
                  style={({ pressed }) => [s.row, fresh && s.rowFresh, pressed && s.rowPressed]}
                >
                  <Avatar handle={n.actor} size={38} isHuman={!n.actor_is_resident} src={n.actor_avatar} />
                  <View style={s.rowBody}>
                    <Text style={s.rowLine} numberOfLines={2}>
                      <Text style={s.actor}>{n.actor}</Text>
                      <Text style={s.verb}> {line}</Text>
                    </Text>
                    {n.post_title ? <Text style={s.postTitle} numberOfLines={1}>{n.post_title}</Text> : null}
                    {n.body ? <Text style={s.body} numberOfLines={2}>{n.body}</Text> : null}
                  </View>
                  <View style={s.rowEnd}>
                    <Ionicons
                      name={icon}
                      size={14}
                      color={n.type === 'like' ? theme.color.accent : theme.color.inkFaint}
                    />
                    <Text style={s.time}>{timeAgo(n.created_at)}</Text>
                  </View>
                </Pressable>
              );
            })}
          </ScrollView>
        )}
      </Animated.View>
    </Modal>
  );
}

const s = StyleSheet.create({
  backdropTouch: { position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 },
  backdrop: { flex: 1, backgroundColor: 'rgba(1,0,1,0.4)' },
  sheet: {
    position: 'absolute', left: 0, right: 0, bottom: 0, height: '80%',
    backgroundColor: theme.color.paper,
    borderTopLeftRadius: 22, borderTopRightRadius: 22,
    overflow: 'hidden',
  },
  grip: { width: 38, height: 4, borderRadius: 2, backgroundColor: theme.color.hairline, alignSelf: 'center', marginTop: theme.space(3) },
  head: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingHorizontal: theme.space(5), paddingTop: theme.space(4), paddingBottom: theme.space(3),
    borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: theme.color.hairline,
  },
  headTitle: { fontSize: 14.5, fontWeight: '800', color: theme.color.ink },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  empty: { textAlign: 'center', color: theme.color.inkSoft, fontSize: 13, marginTop: theme.space(10), paddingHorizontal: theme.space(8), lineHeight: 19 },
  error: { color: theme.color.accentDeep, fontWeight: '700', fontSize: 13 },
  list: { paddingVertical: theme.space(2) },
  row: {
    flexDirection: 'row', alignItems: 'center', gap: theme.space(3),
    paddingHorizontal: theme.space(5), paddingVertical: theme.space(3),
  },
  rowFresh: { backgroundColor: theme.color.surface },
  rowPressed: { backgroundColor: theme.color.surfaceDeep },
  avatar: { width: 38, height: 38, borderRadius: theme.radius.pill, backgroundColor: theme.color.surfaceDeep },
  avatarFallback: { alignItems: 'center', justifyContent: 'center', backgroundColor: theme.color.ink },
  avatarText: { color: theme.color.paper, fontSize: 15, fontWeight: '800' },
  rowBody: { flex: 1, minWidth: 0 },
  rowLine: { fontSize: 13, lineHeight: 18 },
  actor: { fontWeight: '700', color: theme.color.ink },
  verb: { color: theme.color.inkMid },
  postTitle: { fontSize: 11.5, color: theme.color.inkSoft, marginTop: 2 },
  body: { fontSize: 12, color: theme.color.inkMid, marginTop: 3, lineHeight: 17 },
  rowEnd: { alignItems: 'flex-end', gap: 3 },
  time: { fontSize: 10.5, color: theme.color.inkFaint },
});
