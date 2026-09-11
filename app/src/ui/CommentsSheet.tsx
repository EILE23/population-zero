import { useEffect, useMemo, useState } from 'react';
import {
  ActivityIndicator, Animated, Easing, KeyboardAvoidingView, Modal, Platform,
  Pressable, ScrollView, StyleSheet, Text, TextInput, View,
} from 'react-native';
import { Feather } from '@expo/vector-icons';
import { addComment, fetchPostDetail, type PostDetail } from '@/api';
import { timeAgo } from '@/ui/cards';
import { theme } from '@/theme';

type Comment = PostDetail['comments'][number] & { depth: number };

/** 대댓글은 깊이만큼 들여쓴다 — 웹에서 39단까지 이어진 논쟁도 그대로 따라간다 */
function thread(comments: PostDetail['comments']): Comment[] {
  const depthOf = new Map<number, number>();
  return comments.map((c) => {
    const depth = c.parent_id == null ? 0 : Math.min((depthOf.get(c.parent_id) ?? 0) + 1, 6);
    depthOf.set(c.id, depth);
    return { ...c, depth };
  });
}

/**
 * 댓글 — 인스타처럼 아래에서 올라온다.
 * 글 본문과 섞지 않는다: 읽는 일과 말 거는 일은 다른 화면이라고 보는 게 맞다.
 */
export function CommentsSheet({ visible, postId, canInteract, onClose, onCountChange }: {
  visible: boolean;
  postId: number;
  canInteract: boolean;
  onClose: () => void;
  onCountChange?: (n: number) => void;
}) {
  const [comments, setComments] = useState<Comment[] | null>(null);
  const [draft, setDraft] = useState('');
  const [replyTo, setReplyTo] = useState<Comment | null>(null);
  const [sending, setSending] = useState(false);
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

  // 열릴 때마다 최신 댓글을 읽는다 — 닫혀 있는 동안 늘었을 수 있으므로
  useEffect(() => {
    if (!visible) return;
    let alive = true;
    (async () => {
      try {
        const d = await fetchPostDetail(postId);
        if (!alive) return;
        setComments(thread(d.comments));
        onCountChange?.(d.comments.length);
        setError(null);
      } catch {
        if (alive) setError('Could not load comments.');
      }
    })();
    return () => { alive = false; };
  }, [visible, postId, onCountChange]);

  async function send() {
    const body = draft.trim();
    if (!body || sending) return;
    setSending(true);
    try {
      await addComment(postId, body, replyTo?.id ?? null);
      setDraft('');
      setReplyTo(null);
      const d = await fetchPostDetail(postId);
      setComments(thread(d.comments));
      onCountChange?.(d.comments.length);
      setError(null);
    } catch {
      setError('Could not post that comment.');
    } finally {
      setSending(false);
    }
  }

  const rise = anim.interpolate({ inputRange: [0, 1], outputRange: [700, 0] });

  return (
    <Modal visible={visible} transparent animationType="none" onRequestClose={onClose}>
      <Pressable style={s.backdropTouch} onPress={onClose}>
        <Animated.View style={[s.backdrop, { opacity: anim }]} />
      </Pressable>
      <Animated.View style={[s.sheet, { transform: [{ translateY: rise }] }]}>
        <KeyboardAvoidingView style={s.fill} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
          <View style={s.grip} />
          <View style={s.head}>
            <Text style={s.headTitle}>Comments</Text>
            <Pressable onPress={onClose} hitSlop={12}>
              <Feather name="x" size={19} color={theme.color.inkMid} />
            </Pressable>
          </View>

          {comments == null ? (
            <View style={s.center}>
              {error ? <Text style={s.error}>{error}</Text> : <ActivityIndicator color={theme.color.accent} />}
            </View>
          ) : (
            <ScrollView contentContainerStyle={s.list} keyboardShouldPersistTaps="handled">
              {comments.length === 0 ? (
                <Text style={s.empty}>No one has said anything yet.</Text>
              ) : comments.map((c) => (
                <View key={c.id} style={[s.comment, { marginLeft: c.depth * theme.space(4) }]}>
                  <View style={s.commentHead}>
                    <Text style={s.commentAuthor}>{c.handle}</Text>
                    <Text style={s.commentTime}>{timeAgo(c.created_at)}</Text>
                  </View>
                  <Text style={s.commentBody}>{c.body}</Text>
                  {canInteract ? (
                    <Pressable onPress={() => setReplyTo(c)} hitSlop={8}>
                      <Text style={s.reply}>Reply</Text>
                    </Pressable>
                  ) : null}
                </View>
              ))}
              {error ? <Text style={s.error}>{error}</Text> : null}
            </ScrollView>
          )}

          {canInteract ? (
            <View style={s.composerWrap}>
              {replyTo ? (
                <View style={s.replyBar}>
                  <Text style={s.replyBarText} numberOfLines={1}>Replying to {replyTo.handle}</Text>
                  <Pressable onPress={() => setReplyTo(null)} hitSlop={10}>
                    <Feather name="x" size={14} color={theme.color.inkSoft} />
                  </Pressable>
                </View>
              ) : null}
              <View style={s.composer}>
                <TextInput
                  value={draft}
                  onChangeText={setDraft}
                  placeholder={replyTo ? `Reply to ${replyTo.handle}` : 'Say something'}
                  placeholderTextColor={theme.color.inkFaint}
                  style={s.input}
                  multiline
                />
                <Pressable onPress={send} disabled={sending || !draft.trim()} style={[s.send, (!draft.trim() || sending) && s.sendOff]}>
                  {sending
                    ? <ActivityIndicator color={theme.color.paper} size="small" />
                    : <Feather name="arrow-up" size={17} color={theme.color.paper} />}
                </Pressable>
              </View>
            </View>
          ) : (
            <Text style={s.signedOut}>Sign in to join the conversation.</Text>
          )}
        </KeyboardAvoidingView>
      </Animated.View>
    </Modal>
  );
}

const s = StyleSheet.create({
  fill: { flex: 1 },
  backdropTouch: { position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 },
  backdrop: { flex: 1, backgroundColor: 'rgba(1,0,1,0.4)' },
  sheet: {
    position: 'absolute', left: 0, right: 0, bottom: 0, height: '82%',
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
  list: { paddingHorizontal: theme.space(5), paddingVertical: theme.space(4) },
  empty: { textAlign: 'center', color: theme.color.inkSoft, fontSize: 13, marginTop: theme.space(8) },
  comment: { marginBottom: theme.space(4) },
  commentHead: { flexDirection: 'row', alignItems: 'center', gap: theme.space(2) },
  commentAuthor: { fontSize: 12.5, fontWeight: '700', color: theme.color.ink },
  commentTime: { fontSize: 11, color: theme.color.inkFaint },
  commentBody: { fontSize: 13.5, lineHeight: 20, color: theme.color.inkMid, marginTop: theme.space(1) },
  reply: { fontSize: 11, fontWeight: '700', color: theme.color.inkSoft, marginTop: theme.space(1.5) },
  error: { color: theme.color.accentDeep, fontWeight: '700', fontSize: 13, marginTop: theme.space(2) },
  composerWrap: { borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: theme.color.hairline },
  replyBar: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingHorizontal: theme.space(5), paddingTop: theme.space(2),
  },
  replyBarText: { fontSize: 11.5, color: theme.color.inkSoft, fontWeight: '600', flex: 1 },
  composer: {
    flexDirection: 'row', alignItems: 'flex-end', gap: theme.space(2),
    paddingHorizontal: theme.space(4), paddingVertical: theme.space(2.5),
  },
  input: {
    flex: 1, maxHeight: 110, fontSize: 14, color: theme.color.ink,
    paddingVertical: theme.space(2), paddingHorizontal: theme.space(1),
  },
  send: {
    width: 36, height: 36, borderRadius: theme.radius.pill, backgroundColor: theme.color.accent,
    alignItems: 'center', justifyContent: 'center',
  },
  sendOff: { backgroundColor: theme.color.inkFaint },
  signedOut: {
    textAlign: 'center', fontSize: 12, color: theme.color.inkSoft, fontWeight: '600',
    paddingVertical: theme.space(5), borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: theme.color.hairline,
  },
});
