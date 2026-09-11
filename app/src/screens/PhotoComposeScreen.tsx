import { useEffect, useState } from 'react';
import {
  ActivityIndicator, Alert, Image, KeyboardAvoidingView, Platform, Pressable,
  ScrollView, StyleSheet, Text, TextInput, View, type TextStyle,
} from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import { Feather } from '@expo/vector-icons';
import { ApiError, createPost } from '@/api';
import { PressableScale } from '@/ui/PressableScale';
import { theme } from '@/theme';

const TOPICS = ['life', 'food', 'culture', 'gaming', 'tech', 'world'] as const;
const MAX_SHOTS = 10;
const NO_OUTLINE = Platform.OS === 'web' ? ({ outlineStyle: 'none' } as unknown as TextStyle) : null;

/**
 * 앨범 만들기 — 글쓰기와 아예 다른 흐름이다.
 * 카메라가 먼저 열리고, 사진을 여러 장 모아 한 묶음으로 올린다.
 * 캡션 첫 줄이 제목이 된다 (목록에는 제목이 필요하므로 — 숨기지 않고 화면에 밝혀 둔다).
 */
export function PhotoComposeScreen({ onPosted, onCancel }: { onPosted: (id: number) => void; onCancel: () => void }) {
  const [shots, setShots] = useState<string[]>([]);
  const [caption, setCaption] = useState('');
  const [topic, setTopic] = useState<string>('life');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const addShots = (uris: string[]) =>
    setShots((prev) => [...prev, ...uris].slice(0, MAX_SHOTS));

  // 들어오자마자 카메라 — 한 번 닫으면 다시 열지 않는다
  useEffect(() => {
    let alive = true;
    (async () => {
      const perm = await ImagePicker.requestCameraPermissionsAsync();
      if (!perm.granted) return;
      const res = await ImagePicker.launchCameraAsync({ quality: 0.7 });
      if (alive && !res.canceled && res.assets[0]) addShots([res.assets[0].uri]);
    })();
    return () => { alive = false; };
  }, []);

  async function shoot() {
    const perm = await ImagePicker.requestCameraPermissionsAsync();
    if (!perm.granted) {
      Alert.alert('Camera access needed', 'Allow camera access to shoot for your album.');
      return;
    }
    const res = await ImagePicker.launchCameraAsync({ quality: 0.7 });
    if (!res.canceled && res.assets[0]) addShots([res.assets[0].uri]);
  }

  async function pick() {
    const res = await ImagePicker.launchImageLibraryAsync({
      quality: 0.7,
      mediaTypes: ['images'],
      allowsMultipleSelection: true,
      selectionLimit: MAX_SHOTS - shots.length,
    });
    if (!res.canceled) addShots(res.assets.map((a) => a.uri));
  }

  const lines = caption.trim().split('\n');
  const title = lines[0].slice(0, 140).trim();
  // 사진만 올려도 된다 — 사진이 곧 내용이다. 모자란 건 사진이 없을 때뿐.
  const missing = shots.length === 0 ? 'Add a photo first.' : null;

  async function publish() {
    if (busy) return;
    if (missing) { setError(missing); return; }
    setBusy(true);
    setError(null);
    try {
      const { id } = await createPost({ title, body: caption.trim(), topic, photoUris: shots });
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
        <Pressable onPress={onCancel} hitSlop={10}>
          <Feather name="x" size={21} color={theme.color.paper} />
        </Pressable>
        <Text style={s.barTitle}>New album</Text>
        <PressableScale onPress={publish} disabled={busy || !!missing} style={[s.post, (busy || !!missing) && s.postOff]}>
          {busy ? <ActivityIndicator size="small" color={theme.color.paper} /> : <Text style={s.postText}>Share</Text>}
        </PressableScale>
      </View>

      <ScrollView contentContainerStyle={s.content} keyboardShouldPersistTaps="handled">
        <View style={s.stage}>
          {shots[0] ? (
            <Image source={{ uri: shots[0] }} style={s.hero} resizeMode="cover" />
          ) : (
            <Pressable onPress={shoot} style={s.emptyStage}>
              <Feather name="camera" size={30} color={theme.color.inkFaint} />
              <Text style={s.emptyText}>Tap to shoot</Text>
            </Pressable>
          )}
        </View>

        {/* 모은 사진들 — 탭하면 그 장을 뺀다 */}
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={s.strip}>
          {shots.map((uri, i) => (
            <Pressable key={`${uri}-${i}`} onPress={() => setShots((p) => p.filter((_, j) => j !== i))}>
              <Image source={{ uri }} style={s.thumb} resizeMode="cover" />
              <View style={s.thumbX}><Feather name="x" size={10} color={theme.color.paper} /></View>
            </Pressable>
          ))}
          {shots.length < MAX_SHOTS ? (
            <>
              <Pressable onPress={shoot} style={[s.thumb, s.addTile]}>
                <Feather name="camera" size={16} color={theme.color.inkFaint} />
              </Pressable>
              <Pressable onPress={pick} style={[s.thumb, s.addTile]}>
                <Feather name="image" size={16} color={theme.color.inkFaint} />
              </Pressable>
            </>
          ) : null}
        </ScrollView>
        <Text style={s.hint}>{shots.length}/{MAX_SHOTS} shots · tap a frame to remove it</Text>

        <TextInput
          value={caption}
          onChangeText={setCaption}
          placeholder="Say what this is…"
          placeholderTextColor={theme.color.inkFaint}
          style={[s.caption, NO_OUTLINE]}
          multiline
          textAlignVertical="top"
          maxLength={30000}
        />
        <Text style={[s.hint, !!missing && s.hintWarn]}>
          {missing ?? (title ? `Title: ${title}` : 'No caption — the photo speaks for itself.')}
        </Text>

        <View style={s.topics}>
          {TOPICS.map((t) => {
            const on = topic === t;
            return (
              <Pressable key={t} onPress={() => setTopic(t)} style={[s.topic, on && s.topicOn]}>
                <Text style={[s.topicText, on && s.topicTextOn]}>{t}</Text>
              </Pressable>
            );
          })}
        </View>

        {error ? <Text style={s.error}>{error}</Text> : null}
        <Text style={s.note}>Shared to the town — it shows up on population.town too.</Text>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const s = StyleSheet.create({
  // 사진이 주인공이라 어두운 바탕 — 글쓰기 화면(밝은 종이)과 분명히 다르게
  root: { flex: 1, backgroundColor: theme.color.inkStrong },
  bar: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingHorizontal: theme.space(4), paddingVertical: theme.space(3),
  },
  barTitle: { fontSize: 13.5, fontWeight: '700', color: theme.color.paper },
  post: {
    backgroundColor: theme.color.accent, borderRadius: theme.radius.pill,
    paddingHorizontal: theme.space(5), paddingVertical: theme.space(2),
    minWidth: 72, alignItems: 'center',
  },
  postOff: { opacity: 0.6 },
  postText: { color: theme.color.paper, fontWeight: '700', fontSize: 13 },
  content: { paddingBottom: theme.space(14) },
  stage: { width: '100%', aspectRatio: 1, backgroundColor: theme.color.inkBlack },
  hero: { width: '100%', height: '100%' },
  emptyStage: { flex: 1, alignItems: 'center', justifyContent: 'center', gap: theme.space(3) },
  emptyText: { color: theme.color.inkFaint, fontSize: 13, fontWeight: '600' },
  strip: { gap: theme.space(2), paddingHorizontal: theme.space(4), paddingTop: theme.space(3) },
  thumb: { width: 58, height: 58, borderRadius: theme.radius.sm, backgroundColor: 'rgba(255,255,255,0.08)' },
  thumbX: {
    position: 'absolute', top: 3, right: 3, width: 16, height: 16, borderRadius: 8,
    backgroundColor: 'rgba(1,0,1,0.65)', alignItems: 'center', justifyContent: 'center',
  },
  addTile: {
    alignItems: 'center', justifyContent: 'center',
    borderWidth: 1, borderColor: 'rgba(255,255,255,0.22)', borderStyle: 'dashed',
  },
  caption: {
    color: theme.color.paper, fontSize: 15.5, lineHeight: 23, minHeight: 100,
    paddingHorizontal: theme.space(4), marginTop: theme.space(3),
  },
  hint: { color: theme.color.inkFaint, fontSize: 11.5, paddingHorizontal: theme.space(4), marginTop: theme.space(2) },
  hintWarn: { color: theme.color.accent, fontWeight: '700' },

  topics: { flexDirection: 'row', flexWrap: 'wrap', gap: theme.space(2), padding: theme.space(4) },
  topic: {
    borderRadius: theme.radius.pill, borderWidth: 1, borderColor: 'rgba(255,255,255,0.25)',
    paddingHorizontal: theme.space(3.5), paddingVertical: theme.space(1.5),
  },
  topicOn: { backgroundColor: theme.color.accent, borderColor: theme.color.accent },
  topicText: { fontSize: 12.5, fontWeight: '600', color: theme.color.inkFaint },
  topicTextOn: { color: theme.color.paper },
  error: { color: theme.color.accent, fontWeight: '700', fontSize: 13, paddingHorizontal: theme.space(4) },
  note: {
    fontSize: 11, color: theme.color.inkFaint, textAlign: 'center',
    paddingHorizontal: theme.space(6), marginTop: theme.space(4),
  },
});
