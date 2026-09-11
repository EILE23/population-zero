import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  ActivityIndicator, Animated, Easing, FlatList, Image, KeyboardAvoidingView, Platform,
  Pressable, StyleSheet, Text, TextInput, View, type TextStyle,
} from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import { Feather } from '@expo/vector-icons';
import { fetchThread, sendDm, type DmMessage, type DmThread } from '@/api';
import { Avatar } from '@/ui/Avatar';
import { theme } from '@/theme';

const NO_OUTLINE = Platform.OS === 'web' ? ({ outlineStyle: 'none' } as unknown as TextStyle) : null;
/** 자주 쓰는 것만 — 이모지 키보드를 따로 열지 않고 한 번에 닿게 */
const QUICK = ['😂', '👍', '🥹', '🔥', '😮', '😭', '🙏', '❤️', '👀', '💀', '🤔', '🎉'];

function clock(iso: string): string {
  const d = new Date(iso.replace(' ', 'T') + (iso.endsWith('Z') ? '' : 'Z'));
  return `${d.getHours()}:${String(d.getMinutes()).padStart(2, '0')}`;
}

/** 말풍선 하나 — 들어올 때 아래에서 살짝 떠오른다 */
function Bubble({ message }: { message: DmMessage }) {
  const anim = useMemo(() => new Animated.Value(0), []);
  useEffect(() => {
    Animated.timing(anim, { toValue: 1, duration: 220, easing: Easing.out(Easing.cubic), useNativeDriver: true }).start();
  }, [anim]);
  const rise = anim.interpolate({ inputRange: [0, 1], outputRange: [10, 0] });

  return (
    <Animated.View
      style={[s.row, message.mine && s.rowMine, { opacity: anim, transform: [{ translateY: rise }] }]}
    >
      <View style={[s.bubble, message.mine ? s.bubbleMine : s.bubbleTheirs]}>
        {message.image ? (
          <Image source={{ uri: message.image }} style={s.photo} resizeMode="cover" />
        ) : null}
        {message.body ? (
          <Text style={[s.body, message.mine && s.bodyMine]}>{message.body}</Text>
        ) : null}
      </View>
      <Text style={s.time}>
        {clock(message.created_at)}{message.mine && message.read ? ' · read' : ''}
      </Text>
    </Animated.View>
  );
}

/**
 * 채팅 — 사람과는 살아 있는 대화, 주민과는 기다리는 대화.
 *
 * 열려 있는 동안만 "마지막 id 뒤"를 짧게 되묻는다. 새 말이 없으면 빈 응답 하나로 끝나므로
 * 값이 싸고, 전송 방식을 웹소켓으로 바꿔도 이 화면은 fetchThread 만 보므로 그대로 둘 수 있다.
 * 상대가 주민이면 답장이 순찰 때 오므로 화면이 그 사실을 밝힌다 — 숨기면 고장 난 앱으로 보인다.
 */
export function ChatScreen({ thread, other, onBack }: {
  thread: string;
  other: DmThread['other'];
  onBack: () => void;
}) {
  const [messages, setMessages] = useState<DmMessage[]>([]);
  const [live, setLive] = useState(other.kind === 'user');
  const [draft, setDraft] = useState('');
  const [photo, setPhoto] = useState<string | null>(null);
  const [emojiOpen, setEmojiOpen] = useState(false);
  const [sending, setSending] = useState(false);
  const [loaded, setLoaded] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const lastId = useRef(0);
  const list = useRef<FlatList<DmMessage>>(null);

  const absorb = useCallback((incoming: DmMessage[]) => {
    if (!incoming.length) return;
    lastId.current = Math.max(lastId.current, ...incoming.map((m) => m.id));
    setMessages((prev) => {
      const seen = new Set(prev.map((m) => m.id));
      return [...prev, ...incoming.filter((m) => !seen.has(m.id))];
    });
  }, []);

  // 처음 열기 + 열려 있는 동안 되묻기
  useEffect(() => {
    let alive = true;
    let timer: ReturnType<typeof setTimeout>;

    const tick = async () => {
      try {
        const data = await fetchThread(thread, lastId.current);
        if (!alive) return;
        absorb(data.messages);
        setLive(data.live);
        setError(null);
      } catch {
        if (alive) setError('Could not reach the conversation.');
      } finally {
        if (alive) {
          setLoaded(true);
          // 사람과의 대화만 빠르게 — 주민은 순찰 때만 답하므로 자주 물을 이유가 없다
          timer = setTimeout(tick, live ? 2500 : 20000);
        }
      }
    };
    void tick();
    return () => { alive = false; clearTimeout(timer); };
  }, [thread, absorb, live]);

  async function pickPhoto() {
    const res = await ImagePicker.launchImageLibraryAsync({ quality: 0.7, mediaTypes: ['images'] });
    if (!res.canceled && res.assets[0]) setPhoto(res.assets[0].uri);
  }

  async function send() {
    const body = draft.trim();
    if ((!body && !photo) || sending) return;
    setSending(true);
    try {
      await sendDm(other.handle, body, photo);
      setDraft('');
      setPhoto(null);
      setEmojiOpen(false);
      // 보낸 것이 바로 보이도록 곧장 한 번 더 읽는다
      const data = await fetchThread(thread, lastId.current);
      absorb(data.messages);
      setError(null);
    } catch {
      setError('Could not send that.');
    } finally {
      setSending(false);
    }
  }

  return (
    <KeyboardAvoidingView style={s.root} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <View style={s.bar}>
        <Pressable onPress={onBack} hitSlop={12} style={s.barButton}>
          <Feather name="chevron-left" size={22} color={theme.color.ink} />
        </Pressable>
        <Avatar handle={other.handle} size={30} isHuman={other.kind === 'user'} src={other.avatar} />
        <View style={s.barText}>
          <Text style={s.barTitle} numberOfLines={1}>{other.handle}</Text>
          <Text style={s.barHint}>{live ? 'Live' : 'A resident — replies on the next patrol'}</Text>
        </View>
      </View>

      {!loaded ? (
        <View style={s.center}><ActivityIndicator color={theme.color.accent} /></View>
      ) : (
        <FlatList
          ref={list}
          data={messages}
          keyExtractor={(m) => String(m.id)}
          contentContainerStyle={s.list}
          renderItem={({ item }) => <Bubble message={item} />}
          onContentSizeChange={() => list.current?.scrollToEnd({ animated: true })}
          ListEmptyComponent={
            <Text style={s.empty}>
              {other.kind === 'resident'
                ? `Say something to ${other.handle}. They answer when the patrol comes round.`
                : `No messages yet. Say hello.`}
            </Text>
          }
        />
      )}

      {error ? <Text style={s.error}>{error}</Text> : null}

      {photo ? (
        <View style={s.pending}>
          <Image source={{ uri: photo }} style={s.pendingPhoto} resizeMode="cover" />
          <Pressable onPress={() => setPhoto(null)} hitSlop={8} style={s.pendingX}>
            <Feather name="x" size={12} color={theme.color.paper} />
          </Pressable>
        </View>
      ) : null}

      {emojiOpen ? (
        <View style={s.emojiRow}>
          {QUICK.map((e) => (
            <Pressable key={e} onPress={() => setDraft((d) => d + e)} hitSlop={4} style={s.emoji}>
              <Text style={s.emojiText}>{e}</Text>
            </Pressable>
          ))}
        </View>
      ) : null}

      <View style={s.composer}>
        <Pressable onPress={pickPhoto} hitSlop={8} style={s.tool}>
          <Feather name="image" size={19} color={theme.color.inkMid} />
        </Pressable>
        <Pressable onPress={() => setEmojiOpen((v) => !v)} hitSlop={8} style={s.tool}>
          <Feather name="smile" size={19} color={emojiOpen ? theme.color.accent : theme.color.inkMid} />
        </Pressable>
        <TextInput
          value={draft}
          onChangeText={setDraft}
          placeholder="Message"
          placeholderTextColor={theme.color.inkFaint}
          style={[s.input, NO_OUTLINE]}
          multiline
        />
        <Pressable
          onPress={send}
          disabled={sending || (!draft.trim() && !photo)}
          style={[s.send, (sending || (!draft.trim() && !photo)) && s.sendOff]}
        >
          {sending
            ? <ActivityIndicator color={theme.color.paper} size="small" />
            : <Feather name="arrow-up" size={17} color={theme.color.paper} />}
        </Pressable>
      </View>
    </KeyboardAvoidingView>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: theme.color.surface },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  bar: {
    flexDirection: 'row', alignItems: 'center', gap: theme.space(2.5),
    paddingHorizontal: theme.space(2), paddingVertical: theme.space(2.5),
    borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: theme.color.hairline,
    backgroundColor: theme.color.paper,
  },
  barButton: { width: 32, alignItems: 'center' },
  barText: { flex: 1, minWidth: 0 },
  barTitle: { fontSize: 14.5, fontWeight: '800', color: theme.color.ink },
  barHint: { fontSize: 10.5, color: theme.color.inkSoft, marginTop: 1 },
  list: { padding: theme.space(4), paddingBottom: theme.space(6) },
  empty: { textAlign: 'center', color: theme.color.inkSoft, fontSize: 13, marginTop: theme.space(12), lineHeight: 19 },
  row: { alignItems: 'flex-start', marginBottom: theme.space(3), maxWidth: '82%' },
  rowMine: { alignSelf: 'flex-end', alignItems: 'flex-end' },
  bubble: { borderRadius: 16, overflow: 'hidden' },
  bubbleTheirs: { backgroundColor: theme.color.paper, borderWidth: 1, borderColor: theme.color.hairline },
  bubbleMine: { backgroundColor: theme.color.accent },
  body: {
    fontSize: 14.5, lineHeight: 20, color: theme.color.ink,
    paddingHorizontal: theme.space(3.5), paddingVertical: theme.space(2.5),
  },
  bodyMine: { color: theme.color.paper },
  photo: { width: 220, height: 220, backgroundColor: theme.color.surfaceDeep },
  time: { fontSize: 10, color: theme.color.inkFaint, marginTop: 3, marginHorizontal: theme.space(1) },
  error: { color: theme.color.accentDeep, fontSize: 12.5, fontWeight: '700', textAlign: 'center', paddingBottom: theme.space(2) },
  pending: { alignSelf: 'flex-start', marginLeft: theme.space(4), marginBottom: theme.space(2) },
  pendingPhoto: { width: 72, height: 72, borderRadius: theme.radius.md, backgroundColor: theme.color.surfaceDeep },
  pendingX: {
    position: 'absolute', top: -6, right: -6, width: 20, height: 20, borderRadius: 10,
    backgroundColor: theme.color.inkBlack, alignItems: 'center', justifyContent: 'center',
  },
  emojiRow: {
    flexDirection: 'row', flexWrap: 'wrap', gap: theme.space(2),
    paddingHorizontal: theme.space(4), paddingBottom: theme.space(2),
  },
  emoji: { padding: theme.space(1) },
  emojiText: { fontSize: 22 },
  composer: {
    flexDirection: 'row', alignItems: 'flex-end', gap: theme.space(2),
    borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: theme.color.hairline,
    paddingHorizontal: theme.space(3), paddingVertical: theme.space(2.5),
    backgroundColor: theme.color.paper,
  },
  tool: { padding: theme.space(2) },
  input: {
    flex: 1, maxHeight: 110, fontSize: 14.5, color: theme.color.ink,
    paddingVertical: theme.space(2), paddingHorizontal: theme.space(2),
  },
  send: {
    width: 36, height: 36, borderRadius: theme.radius.pill, backgroundColor: theme.color.accent,
    alignItems: 'center', justifyContent: 'center',
  },
  sendOff: { backgroundColor: theme.color.inkFaint },
});
