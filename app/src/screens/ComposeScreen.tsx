import { useState } from 'react';
import {
  ActivityIndicator, Alert, Image, KeyboardAvoidingView, Platform, Pressable,
  ScrollView, StyleSheet, Text, TextInput, View, type TextStyle,
} from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import { Feather } from '@expo/vector-icons';
import { ApiError, createPost, TOPIC_TABS } from '@/api';
import { CategoryButton, CategoryPicker, type PickerGroup } from '@/ui/CategoryPicker';
import { PressableScale } from '@/ui/PressableScale';
import { theme } from '@/theme';

const TOPICS = TOPIC_TABS.filter((t) => t.key !== 'all' && t.key !== 'humans');
/** 분류를 칩으로 늘어놓으면 가로로 넘쳐 무엇이 있는지 보이지 않는다 — 다른 화면과 같은 시트로 고른다 */
const TOPIC_GROUPS: PickerGroup[] = [{ title: 'WHERE DOES THIS GO', options: TOPICS.map((t) => ({ key: t.key, label: t.label })) }];
/** 웹 미리보기에서 입력칸에 생기는 브라우저 포커스 링을 없앤다 */
const NO_OUTLINE = Platform.OS === 'web' ? ({ outlineStyle: 'none' } as unknown as TextStyle) : null;

/**
 * 글쓰기 — 홈(Community)에서 들어오는 화면.
 * 사진 피드의 화면과 다르다: 여기서는 글이 주인공이고 커버 사진은 거들 뿐.
 */
export function ComposeScreen({ onPosted, onCancel }: { onPosted: (id: number) => void; onCancel: () => void }) {
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [topic, setTopic] = useState<string>('life');
  const [cover, setCover] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [pickerOpen, setPickerOpen] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function pickCover() {
    const res = await ImagePicker.launchImageLibraryAsync({ quality: 0.7, mediaTypes: ['images'] });
    if (!res.canceled && res.assets[0]) setCover(res.assets[0].uri);
  }

  async function shootCover() {
    const perm = await ImagePicker.requestCameraPermissionsAsync();
    if (!perm.granted) {
      Alert.alert('Camera access needed', 'Allow camera access to attach a photo.');
      return;
    }
    const res = await ImagePicker.launchCameraAsync({ quality: 0.7 });
    if (!res.canceled && res.assets[0]) setCover(res.assets[0].uri);
  }

  const ready = title.trim().length >= 4 && body.trim().length >= 10;

  async function publish() {
    if (busy) return;
    if (!ready) {
      setError('A title of 4+ characters and a body of 10+ characters, please.');
      return;
    }
    setBusy(true);
    setError(null);
    try {
      const { id } = await createPost({ title: title.trim(), body: body.trim(), topic, photoUri: cover });
      onPosted(id);
    } catch (e) {
      const status = e instanceof ApiError ? e.status : 0;
      setError(
        status === 403 ? 'Verify your email first — posting unlocks after that.'
        : status === 401 ? 'Session expired. Sign in again.'
        : status === 429 ? 'Slow down a moment and try again.'
        : 'Could not publish. Check your connection.',
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <KeyboardAvoidingView style={s.root} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <View style={s.bar}>
        <Pressable onPress={onCancel} hitSlop={12}>
          <Feather name="x" size={21} color={theme.color.ink} />
        </Pressable>
        <Text style={s.barTitle}>Write</Text>
        <PressableScale onPress={publish} disabled={busy} style={[s.publish, (!ready || busy) && s.publishOff]}>
          {busy
            ? <ActivityIndicator color={theme.color.paper} size="small" />
            : <Text style={s.publishText}>Publish</Text>}
        </PressableScale>
      </View>

      <ScrollView contentContainerStyle={s.content} keyboardShouldPersistTaps="handled">
        {cover ? (
          <View style={s.coverWrap}>
            <Image source={{ uri: cover }} style={s.cover} resizeMode="cover" />
            <Pressable onPress={() => setCover(null)} style={s.coverRemove} hitSlop={8}>
              <Feather name="x" size={14} color={theme.color.paper} />
            </Pressable>
          </View>
        ) : null}

        <TextInput
          value={title}
          onChangeText={setTitle}
          placeholder="Title"
          placeholderTextColor={theme.color.inkFaint}
          style={[s.title, NO_OUTLINE]}
          multiline
          maxLength={140}
        />

        <TextInput
          value={body}
          onChangeText={setBody}
          placeholder="Write it out. Headings with # become a table of contents on the web."
          placeholderTextColor={theme.color.inkFaint}
          style={[s.body, NO_OUTLINE]}
          multiline
          textAlignVertical="top"
          maxLength={30000}
        />

        {error ? <Text style={s.error}>{error}</Text> : null}
      </ScrollView>

      {/* 아래 도구줄 — 커버 사진과 분류. 본문에서 눈을 떼지 않아도 닿는 자리에 둔다 */}
      <View style={s.tools}>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={s.toolsInner}>
          <Pressable onPress={shootCover} style={({ pressed }) => [s.tool, pressed && s.toolPressed]}>
            <Feather name="camera" size={15} color={theme.color.inkMid} />
          </Pressable>
          <Pressable onPress={pickCover} style={({ pressed }) => [s.tool, pressed && s.toolPressed]}>
            <Feather name="image" size={15} color={theme.color.inkMid} />
          </Pressable>
          <View style={s.toolDivider} />
          <CategoryButton
            label={TOPICS.find((t) => t.key === topic)?.label ?? 'Life'}
            onPress={() => setPickerOpen(true)}
          />
        </ScrollView>
      </View>

      <CategoryPicker
        visible={pickerOpen}
        value={topic}
        groups={TOPIC_GROUPS}
        onSelect={setTopic}
        onClose={() => setPickerOpen(false)}
      />
    </KeyboardAvoidingView>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: theme.color.paper },
  bar: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingHorizontal: theme.space(4), paddingVertical: theme.space(3),
    borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: theme.color.hairline,
  },
  barTitle: { fontSize: 13, fontWeight: '700', color: theme.color.ink },
  publish: {
    backgroundColor: theme.color.inkBlack, borderRadius: theme.radius.pill,
    paddingHorizontal: theme.space(5), paddingVertical: theme.space(2),
    minWidth: 82, alignItems: 'center',
  },
  publishOff: { backgroundColor: theme.color.inkFaint },
  publishText: { color: theme.color.paper, fontWeight: '700', fontSize: 13 },
  content: { paddingHorizontal: theme.space(5), paddingTop: theme.space(4), paddingBottom: theme.space(10) },
  coverWrap: { marginBottom: theme.space(4), borderRadius: theme.radius.md, overflow: 'hidden' },
  cover: { width: '100%', height: 180, backgroundColor: theme.color.surfaceDeep },
  coverRemove: {
    position: 'absolute', right: theme.space(2), top: theme.space(2),
    width: 26, height: 26, borderRadius: 13, backgroundColor: 'rgba(1,0,1,0.6)',
    alignItems: 'center', justifyContent: 'center',
  },
  title: {
    fontSize: 25, fontWeight: '800', color: theme.color.ink, lineHeight: 32,
    letterSpacing: -0.5, borderWidth: 0, padding: 0,
  },
  body: {
    fontSize: 15.5, lineHeight: 24, color: theme.color.inkMid, minHeight: 240,
    marginTop: theme.space(4), borderWidth: 0, padding: 0,
  },
  error: { color: theme.color.accentDeep, fontWeight: '700', fontSize: 13, marginTop: theme.space(4) },
  tools: {
    borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: theme.color.hairline,
    backgroundColor: theme.color.paper,
  },
  toolsInner: { alignItems: 'center', gap: theme.space(2), paddingHorizontal: theme.space(4), paddingVertical: theme.space(3) },
  tool: {
    width: 34, height: 34, borderRadius: theme.radius.pill,
    backgroundColor: theme.color.surface, alignItems: 'center', justifyContent: 'center',
  },
  toolPressed: { backgroundColor: theme.color.surfaceDeep },
  toolDivider: { width: StyleSheet.hairlineWidth, height: 20, backgroundColor: theme.color.hairline, marginHorizontal: theme.space(1) },
  chip: {
    borderRadius: theme.radius.pill, borderWidth: 1, borderColor: theme.color.hairline,
    paddingHorizontal: theme.space(3.5), paddingVertical: theme.space(1.5),
  },
  chipOn: { backgroundColor: theme.color.ink, borderColor: theme.color.ink },
  chipText: { fontSize: 12, fontWeight: '600', color: theme.color.inkMid },
  chipTextOn: { color: theme.color.paper },
});
