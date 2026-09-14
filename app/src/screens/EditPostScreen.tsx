import { useEffect, useState } from 'react';
import {
  ActivityIndicator, KeyboardAvoidingView, Platform, Pressable,
  ScrollView, StyleSheet, Text, TextInput, View,
} from 'react-native';
import { Feather } from '@expo/vector-icons';
import { editPost, fetchPostDetail, TOPIC_TABS } from '@/api';
import { Tap } from '@/ui/Tap';
import { theme } from '@/theme';

const TOPICS = TOPIC_TABS.filter((t) => t.key !== 'all' && t.key !== 'humans');

/** 내 글 고치기 — 제목·본문·주제. 썸네일 교체는 파일 업로드가 붙어야 해서 웹 에디터에 둔다 */
export function EditPostScreen({ postId, onCancel, onSaved }: {
  postId: number;
  onCancel: () => void;
  onSaved: () => void;
}) {
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [topic, setTopic] = useState<string | null>(null);
  const [series, setSeries] = useState('');
  const [loaded, setLoaded] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const d = await fetchPostDetail(postId);
        if (!alive) return;
        setTitle(d.post.title);
        setBody(d.post.body);
        setTopic(d.post.topic);
        setSeries(d.post.series ?? '');
      } catch {
        if (alive) setError('Could not load this post.');
      } finally {
        if (alive) setLoaded(true);
      }
    })();
    return () => { alive = false; };
  }, [postId]);

  async function save() {
    if (busy) return;
    if (title.trim().length < 4 || body.trim().length < 10) {
      setError('A title of 4+ characters and a body of 10+ characters, please.');
      return;
    }
    setBusy(true);
    setError(null);
    try {
      await editPost(postId, { title: title.trim(), body: body.trim(), topic, series: series.trim() });
      onSaved();
    } catch {
      setError('Could not save. Check your connection.');
    } finally {
      setBusy(false);
    }
  }

  if (!loaded) return <View style={s.center}><ActivityIndicator color={theme.color.accent} /></View>;

  return (
    <KeyboardAvoidingView style={s.root} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <View style={s.bar}>
        <Pressable onPress={onCancel} hitSlop={12}>
          <Feather name="x" size={21} color={theme.color.ink} />
        </Pressable>
        <Text style={s.barTitle}>Edit</Text>
        <Tap onPress={save} disabled={busy} ripple rippleRadius={17} style={s.save}>
          {busy ? <ActivityIndicator color={theme.color.paper} size="small" /> : <Text style={s.saveText}>Save</Text>}
        </Tap>
      </View>

      <ScrollView contentContainerStyle={s.content} keyboardShouldPersistTaps="handled">
        <TextInput
          value={title}
          onChangeText={setTitle}
          placeholder="Title"
          placeholderTextColor={theme.color.inkFaint}
          style={s.title}
          multiline
        />
        {/* 연재 — 같은 이름을 붙인 글끼리 프로필에서 한 묶음이 되고 글에 이전/다음 편이 붙는다. 비우면 연재에서 빠진다 */}
        <View style={s.seriesRow}>
          <Text style={s.seriesLabel}>SERIES</Text>
          <TextInput
            value={series}
            onChangeText={setSeries}
            maxLength={60}
            placeholder="Optional — name it and parts link to each other"
            placeholderTextColor={theme.color.inkFaint}
            style={s.seriesInput}
          />
        </View>
        <View style={s.chips}>
          {TOPICS.map((t) => {
            const on = topic === t.key;
            return (
              <Pressable key={t.key} onPress={() => setTopic(on ? null : t.key)} style={[s.chip, on && s.chipOn]}>
                <Text style={[s.chipText, on && s.chipTextOn]}>{t.label}</Text>
              </Pressable>
            );
          })}
        </View>
        <TextInput
          value={body}
          onChangeText={setBody}
          placeholder="Write it out."
          placeholderTextColor={theme.color.inkFaint}
          style={s.body}
          multiline
          textAlignVertical="top"
        />
        {error ? <Text style={s.error}>{error}</Text> : null}
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: theme.color.paper },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: theme.color.paper },
  bar: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingHorizontal: theme.space(4), paddingVertical: theme.space(3),
    borderBottomWidth: 1, borderBottomColor: theme.color.hairline,
  },
  barTitle: { fontSize: 13, fontWeight: '700', color: theme.color.ink },
  save: {
    backgroundColor: theme.color.inkBlack, borderRadius: theme.radius.pill,
    paddingHorizontal: theme.space(5), paddingVertical: theme.space(2),
    minWidth: 68, alignItems: 'center',
  },
  saveText: { color: theme.color.paper, fontWeight: '700', fontSize: 13 },
  content: { padding: theme.space(5), paddingBottom: theme.space(16) },
  title: { fontSize: 23, fontWeight: '800', color: theme.color.ink, lineHeight: 30, letterSpacing: -0.4 },
  seriesRow: { flexDirection: 'row', alignItems: 'center', gap: theme.space(3), marginTop: theme.space(4), borderBottomWidth: 1, borderBottomColor: theme.color.hairline, paddingBottom: theme.space(2) },
  seriesLabel: { fontSize: 10.5, fontWeight: '700', letterSpacing: 1.2, color: theme.color.inkSoft },
  seriesInput: { flex: 1, fontSize: 13, color: theme.color.ink, paddingVertical: theme.space(1) },
  chips: { flexDirection: 'row', flexWrap: 'wrap', gap: theme.space(2), marginTop: theme.space(4), marginBottom: theme.space(4) },
  chip: {
    borderRadius: theme.radius.pill, borderWidth: 1, borderColor: theme.color.hairline,
    paddingHorizontal: theme.space(3), paddingVertical: theme.space(1.5),
  },
  chipOn: { backgroundColor: theme.color.ink, borderColor: theme.color.ink },
  chipText: { fontSize: 12, fontWeight: '600', color: theme.color.inkMid },
  chipTextOn: { color: theme.color.paper },
  body: { fontSize: 15, lineHeight: 24, color: theme.color.inkMid, minHeight: 260 },
  error: { color: theme.color.accentDeep, fontWeight: '700', fontSize: 13, marginTop: theme.space(3) },
});
