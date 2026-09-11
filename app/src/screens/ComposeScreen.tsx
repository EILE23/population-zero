import { useState } from 'react';
import {
  ActivityIndicator, Alert, Image, KeyboardAvoidingView, Platform, Pressable,
  ScrollView, StyleSheet, Text, TextInput, View,
} from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import { ApiError, createPost } from '@/api';
import { theme } from '@/theme';

const TOPICS = ['life', 'tech', 'culture', 'gaming', 'food', 'forum'] as const;

/**
 * 앱의 존재 이유 — 찍어서 바로 올린다.
 * 여기서 올린 글은 같은 DB 라 웹(population.town)에도 즉시 보인다.
 */
export function ComposeScreen({ onPosted, onCancel }: { onPosted: (id: number) => void; onCancel: () => void }) {
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [topic, setTopic] = useState<string>('life');
  const [photo, setPhoto] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function takePhoto() {
    const perm = await ImagePicker.requestCameraPermissionsAsync();
    if (!perm.granted) {
      Alert.alert('Camera access needed', 'Allow camera access to attach a photo to your post.');
      return;
    }
    const res = await ImagePicker.launchCameraAsync({ quality: 0.7, allowsEditing: false });
    if (!res.canceled && res.assets[0]) setPhoto(res.assets[0].uri);
  }

  async function pickPhoto() {
    const res = await ImagePicker.launchImageLibraryAsync({ quality: 0.7, mediaTypes: ['images'] });
    if (!res.canceled && res.assets[0]) setPhoto(res.assets[0].uri);
  }

  async function publish() {
    if (busy) return;
    if (title.trim().length < 4 || body.trim().length < 10) {
      setError('Title needs 4+ characters and the body 10+.');
      return;
    }
    setBusy(true);
    setError(null);
    try {
      const { id } = await createPost({ title: title.trim(), body: body.trim(), topic, photoUri: photo });
      onPosted(id);
    } catch (e) {
      const status = e instanceof ApiError ? e.status : 0;
      setError(
        status === 403 ? 'Verify your email on the web first — posting unlocks after that.'
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
        <Pressable onPress={onCancel} hitSlop={8}><Text style={s.cancel}>Cancel</Text></Pressable>
        <Text style={s.barTitle}>New post</Text>
        <Pressable onPress={publish} disabled={busy} hitSlop={8}>
          {busy ? <ActivityIndicator size="small" color={theme.color.accent} /> : <Text style={s.publish}>Publish</Text>}
        </Pressable>
      </View>

      <ScrollView contentContainerStyle={s.content} keyboardShouldPersistTaps="handled">
        {photo ? (
          <View style={s.photoWrap}>
            <Image source={{ uri: photo }} style={s.photo} resizeMode="cover" />
            <Pressable onPress={() => setPhoto(null)} style={s.photoRemove} hitSlop={8}>
              <Text style={s.photoRemoveText}>Remove</Text>
            </Pressable>
          </View>
        ) : (
          <View style={s.photoButtons}>
            <Pressable onPress={takePhoto} style={({ pressed }) => [s.photoButton, pressed && s.pressed]}>
              <Text style={s.photoButtonText}>Take a photo</Text>
            </Pressable>
            <Pressable onPress={pickPhoto} style={({ pressed }) => [s.photoButton, pressed && s.pressed]}>
              <Text style={s.photoButtonText}>Choose from library</Text>
            </Pressable>
          </View>
        )}

        <TextInput
          value={title}
          onChangeText={setTitle}
          placeholder="Title"
          placeholderTextColor={theme.color.inkSoft}
          style={s.title}
          maxLength={140}
        />
        <TextInput
          value={body}
          onChangeText={setBody}
          placeholder="What happened?"
          placeholderTextColor={theme.color.inkSoft}
          style={s.body}
          multiline
          textAlignVertical="top"
          maxLength={30000}
        />

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
        <Text style={s.hint}>Posted as you — it shows up on population.town right away.</Text>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: theme.color.surface },
  bar: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingHorizontal: theme.space(4), paddingVertical: theme.space(3.5),
    borderBottomWidth: 1, borderBottomColor: theme.color.hairline,
  },
  barTitle: { fontSize: 14, fontWeight: '700', color: theme.color.ink },
  cancel: { fontSize: 13.5, color: theme.color.inkSoft, fontWeight: '600' },
  publish: { fontSize: 13.5, color: theme.color.accent, fontWeight: '800' },
  content: { padding: theme.space(4), paddingBottom: theme.space(12) },
  photoButtons: { flexDirection: 'row', gap: theme.space(2.5), marginBottom: theme.space(5) },
  photoButton: {
    flex: 1, borderWidth: 1, borderStyle: 'dashed', borderColor: theme.color.hairline,
    borderRadius: theme.radius.md, paddingVertical: theme.space(4), alignItems: 'center',
  },
  photoButtonText: { fontSize: 13, fontWeight: '600', color: theme.color.inkMid },
  pressed: { opacity: 0.7 },
  photoWrap: { marginBottom: theme.space(5), borderRadius: theme.radius.lg, overflow: 'hidden' },
  photo: { width: '100%', height: 220, backgroundColor: theme.color.surfaceDeep },
  photoRemove: {
    position: 'absolute', right: theme.space(2.5), top: theme.space(2.5),
    backgroundColor: theme.color.inkBlack, borderRadius: theme.radius.pill,
    paddingHorizontal: theme.space(3), paddingVertical: theme.space(1.5),
  },
  photoRemoveText: { color: theme.color.paper, fontSize: 11.5, fontWeight: '700' },
  title: {
    fontSize: 22, fontWeight: '800', color: theme.color.ink,
    borderBottomWidth: 1, borderBottomColor: theme.color.hairline,
    paddingVertical: theme.space(2.5), marginBottom: theme.space(4),
  },
  body: {
    fontSize: 15.5, color: theme.color.ink, lineHeight: 23,
    minHeight: 160, paddingVertical: theme.space(2),
  },
  topics: { flexDirection: 'row', flexWrap: 'wrap', gap: theme.space(2), marginTop: theme.space(5) },
  topic: {
    borderWidth: 1, borderColor: theme.color.hairline, borderRadius: theme.radius.pill,
    paddingHorizontal: theme.space(3.5), paddingVertical: theme.space(1.5),
  },
  topicOn: { borderColor: theme.color.accent, backgroundColor: theme.color.accent },
  topicText: { fontSize: 12.5, fontWeight: '600', color: theme.color.inkMid },
  topicTextOn: { color: theme.color.paper },
  error: { marginTop: theme.space(4), color: theme.color.accentDeep, fontWeight: '700', fontSize: 13 },
  hint: { marginTop: theme.space(4), fontSize: 12, color: theme.color.inkSoft },
});
