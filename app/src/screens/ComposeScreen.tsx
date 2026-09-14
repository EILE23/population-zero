import { useRef, useState } from 'react';
import {
  ActivityIndicator, Alert, Image, KeyboardAvoidingView, Platform, Pressable,
  ScrollView, StyleSheet, Text, TextInput, View, type TextStyle,
} from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import { Feather } from '@expo/vector-icons';
import { createPost, newClientKey, postingError, uploadInlineImage, TOPIC_TABS, type Album } from '@/api';
import { AlbumPicker } from '@/ui/AlbumPicker';
import { CategoryButton, CategoryPicker, type PickerGroup } from '@/ui/CategoryPicker';
import { Tap } from '@/ui/Tap';
import { theme } from '@/theme';

const TOPICS = TOPIC_TABS.filter((t) => t.key !== 'all' && t.key !== 'humans');
/** 분류를 칩으로 늘어놓으면 가로로 넘쳐 무엇이 있는지 보이지 않는다 — 다른 화면과 같은 시트로 고른다 */
const TOPIC_GROUPS: PickerGroup[] = [
  { title: 'WHERE DOES THIS GO', options: TOPICS.map((t) => ({ key: t.key, label: t.label })) },
];
/** 웹 미리보기에서 입력칸에 생기는 브라우저 포커스 링을 없앤다 */
const NO_OUTLINE = Platform.OS === 'web' ? ({ outlineStyle: 'none' } as unknown as TextStyle) : null;

/**
 * 글쓰기 — Community 에서 들어오는 화면.
 * 앨범 화면과 다르다: 여기서는 글이 주인공이고 사진은 두 가지 다른 역할을 한다.
 *  - 커버: 목록·웹 카드에 뜨는 대표 사진 한 장
 *  - 본문 사진: 글 중간에 들어가는 사진 (여러 장, 쓰던 자리에 박힌다)
 * 같은 '사진'이라도 하는 일이 달라서 도구줄에서 이름으로 갈라 둔다.
 */
export function ComposeScreen({ onPosted, onCancel }: { onPosted: (id: number) => void; onCancel: () => void }) {
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [topic, setTopic] = useState<string>('life');
  const [cover, setCover] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [pickerOpen, setPickerOpen] = useState(false);
  // 붙인 앨범 — 사진을 새로 올리는 게 아니라 이미 있는 앨범을 이 글이 가리킨다
  const [album, setAlbum] = useState<Album | null>(null);
  const [albumPickerOpen, setAlbumPickerOpen] = useState(false);
  const [error, setError] = useState<string | null>(null);
  // 커서 위치 — 본문 사진을 '지금 쓰던 자리'에 넣기 위해 따라다닌다
  const caret = useRef(0);
  // 이 화면에서 나가는 모든 발행 시도는 같은 글이다 — 반려 뒤 다시 눌러도 두 글이 되지 않게
  const [clientKey] = useState(() => newClientKey());

  /** 사진 하나를 고른다 — 카메라는 권한을 먼저 묻는다 */
  async function choose(from: 'camera' | 'library') {
    if (from === 'library') {
      return ImagePicker.launchImageLibraryAsync({ quality: 0.7, mediaTypes: ['images'] });
    }
    const perm = await ImagePicker.requestCameraPermissionsAsync();
    if (!perm.granted) {
      Alert.alert('Camera access needed', 'Allow camera access to put a photo in the post.');
      return null;
    }
    return ImagePicker.launchCameraAsync({ quality: 0.7 });
  }

  async function pickCover(from: 'camera' | 'library') {
    const res = await choose(from);
    if (res && !res.canceled && res.assets[0]) setCover(res.assets[0].uri);
  }

  /**
   * 본문 안에 사진 넣기.
   * 올린 뒤 커서 자리에 `![](주소)` 를 박는다 — 웹 에디터가 붙여넣기로 하는 것과 같은 결과다.
   * 커버는 글이 올라갈 때 함께 보내지만 본문 사진은 지금 바로 올려야 한다: 본문에 주소가 들어가야
   * 글에 박히기 때문이다.
   */
  async function insertPhoto(from: 'camera' | 'library') {
    if (uploading) return;
    const res = await choose(from);
    if (!res || res.canceled || !res.assets[0]) return;

    setUploading(true);
    setError(null);
    try {
      const url = await uploadInlineImage(res.assets[0].uri);
      // 업로드를 기다리는 동안 쓴 글을 잃지 않게, 시작 시점의 body 가 아니라 '지금' body 에 끼워 넣는다.
      // (예전엔 클로저에 잡힌 옛 body 로 덮어써서 그 사이 타이핑이 사라졌다)
      setBody((cur) => {
        const at = Math.min(caret.current, cur.length);
        const before = cur.slice(0, at);
        const after = cur.slice(at);
        // 사진은 제 줄을 차지해야 한다 — 문장 중간에 끼면 문단이 깨진다
        const lead = before.length === 0 || before.endsWith('\n') ? '' : '\n\n';
        const snippet = `${lead}![](${url})\n\n`;
        caret.current = (before + snippet).length;
        return before + snippet + after;
      });
    } catch (e) {
      setError(postingError(e));
    } finally {
      setUploading(false);
    }
  }

  const ready = title.trim().length >= 4 && body.trim().length >= 10;

  async function publish() {
    if (busy) return;
    // 사진이 아직 올라가는 중이면 본문에 주소가 없다 — 지금 발행하면 사진 없는 글이 된다
    if (uploading) { setError('Wait a moment — a photo is still uploading.'); return; }
    if (!ready) {
      setError('A title of 4+ characters and a body of 10+ characters, please.');
      return;
    }
    setBusy(true);
    setError(null);
    try {
      const { id } = await createPost({ title: title.trim(), body: body.trim(), topic, photoUri: cover, albumId: album?.album_id ?? null, clientKey });
      onPosted(id);
    } catch (e) {
      setError(postingError(e));
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
        <Tap onPress={publish} disabled={busy} ripple rippleRadius={17} style={[s.publish, (!ready || busy) && s.publishOff]}>
          {busy
            ? <ActivityIndicator color={theme.color.paper} size="small" />
            : <Text style={s.publishText}>Publish</Text>}
        </Tap>
      </View>

      <ScrollView contentContainerStyle={s.content} keyboardShouldPersistTaps="handled">
        {/* 커버 자리 — 글과 섞이지 않게 따로 세우고, 비어 있을 때도 자리를 보여준다 */}
        {cover ? (
          <View style={s.coverWrap}>
            <Image source={{ uri: cover }} style={s.cover} resizeMode="cover" />
            <Pressable onPress={() => setCover(null)} style={s.coverRemove} hitSlop={8}>
              <Feather name="x" size={14} color={theme.color.paper} />
            </Pressable>
          </View>
        ) : (
          <Pressable
            onPress={() => void pickCover('library')}
            style={({ pressed }) => [s.coverEmpty, pressed && s.coverEmptyPressed]}
          >
            <Feather name="image" size={17} color={theme.color.inkFaint} />
            <Text style={s.coverEmptyText}>Add a cover — the picture people see in the feed</Text>
          </Pressable>
        )}

        <View style={s.split} />

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
          onSelectionChange={(e) => { caret.current = e.nativeEvent.selection.start; }}
          placeholder="Write it out."
          placeholderTextColor={theme.color.inkFaint}
          style={[s.body, NO_OUTLINE]}
          multiline
          textAlignVertical="top"
          maxLength={30000}
        />

        {/* 붙인 앨범 — 글 아래 띠로 보여주고, 떼는 것도 여기서 */}
        {album ? (
          <View style={s.albumStrip}>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={s.albumShots}>
              {album.images.slice(0, 8).map((u) => <Image key={u} source={{ uri: u }} style={s.albumShot} resizeMode="cover" />)}
            </ScrollView>
            <View style={s.albumMeta}>
              <Text style={s.albumLabel} numberOfLines={1}>ALBUM · {album.shot_count} {album.shot_count === 1 ? 'shot' : 'shots'}</Text>
              <Pressable onPress={() => setAlbum(null)} hitSlop={8}>
                <Text style={s.albumRemove}>Remove</Text>
              </Pressable>
            </View>
          </View>
        ) : null}

        {error ? <Text style={s.error}>{error}</Text> : null}
      </ScrollView>

      {/* 아이콘만 놓으면 무엇에 쓰는 건지 알 수 없다 — 하는 일이 다른 묶음마다 이름을 붙인다 */}
      <View style={s.tools}>
        <View style={s.toolGroup}>
          <Text style={s.toolLabel}>COVER</Text>
          <Pressable onPress={() => void pickCover('camera')} style={({ pressed }) => [s.tool, pressed && s.toolPressed]}>
            <Feather name="camera" size={15} color={theme.color.inkMid} />
          </Pressable>
          <Pressable onPress={() => void pickCover('library')} style={({ pressed }) => [s.tool, pressed && s.toolPressed]}>
            <Feather name="image" size={15} color={theme.color.inkMid} />
          </Pressable>
        </View>

        <View style={s.toolDivider} />

        <View style={s.toolGroup}>
          <Text style={s.toolLabel}>IN TEXT</Text>
          <Pressable onPress={() => void insertPhoto('camera')} style={({ pressed }) => [s.tool, pressed && s.toolPressed]}>
            {uploading
              ? <ActivityIndicator size="small" color={theme.color.accent} />
              : <Feather name="camera" size={15} color={theme.color.inkMid} />}
          </Pressable>
          <Pressable onPress={() => void insertPhoto('library')} style={({ pressed }) => [s.tool, pressed && s.toolPressed]}>
            <Feather name="plus-square" size={15} color={theme.color.inkMid} />
          </Pressable>
        </View>

        <View style={s.toolDivider} />

        <View style={s.toolGroup}>
          <Text style={s.toolLabel}>ALBUM</Text>
          <Pressable onPress={() => setAlbumPickerOpen(true)} style={({ pressed }) => [s.tool, pressed && s.toolPressed, album && s.toolOn]}>
            <Feather name="layers" size={15} color={album ? theme.color.paper : theme.color.inkMid} />
          </Pressable>
        </View>

        <View style={s.toolSpacer} />

        <View style={s.toolGroup}>
          <Text style={s.toolLabel}>TOPIC</Text>
          <CategoryButton
            label={TOPICS.find((t) => t.key === topic)?.label ?? 'Life'}
            onPress={() => setPickerOpen(true)}
          />
        </View>
      </View>

      <CategoryPicker
        visible={pickerOpen}
        value={topic}
        groups={TOPIC_GROUPS}
        onSelect={setTopic}
        onClose={() => setPickerOpen(false)}
      />
      <AlbumPicker
        visible={albumPickerOpen}
        onPick={(a) => { setAlbum(a); setAlbumPickerOpen(false); }}
        onClose={() => setAlbumPickerOpen(false)}
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
  coverWrap: { borderRadius: theme.radius.md, overflow: 'hidden' },
  cover: { width: '100%', height: 180, backgroundColor: theme.color.surfaceDeep },
  coverRemove: {
    position: 'absolute', right: theme.space(2), top: theme.space(2),
    width: 26, height: 26, borderRadius: 13, backgroundColor: 'rgba(1,0,1,0.6)',
    alignItems: 'center', justifyContent: 'center',
  },
  coverEmpty: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: theme.space(2),
    height: 72, borderRadius: theme.radius.md,
    borderWidth: 1, borderStyle: 'dashed', borderColor: theme.color.hairline,
    backgroundColor: theme.color.surface, paddingHorizontal: theme.space(4),
  },
  coverEmptyPressed: { backgroundColor: theme.color.surfaceDeep },
  coverEmptyText: { fontSize: 12, fontWeight: '600', color: theme.color.inkSoft, flexShrink: 1 },
  // 사진 자리와 글 자리를 가르는 선 — 한 덩어리로 보이면 어디에 무엇을 넣는지 헷갈린다
  split: {
    height: StyleSheet.hairlineWidth, backgroundColor: theme.color.hairline,
    marginVertical: theme.space(4),
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
  albumStrip: {
    marginTop: theme.space(5), borderRadius: theme.radius.md, overflow: 'hidden',
    backgroundColor: theme.color.surface, borderWidth: StyleSheet.hairlineWidth, borderColor: theme.color.hairline,
  },
  albumShots: { flexDirection: 'row', gap: 2 },
  albumShot: { width: 96, height: 96, backgroundColor: theme.color.surfaceDeep },
  albumMeta: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingHorizontal: theme.space(3), paddingVertical: theme.space(2),
  },
  albumLabel: { fontSize: 10.5, fontWeight: '800', letterSpacing: 1.2, color: theme.color.inkSoft },
  albumRemove: { fontSize: 12, fontWeight: '700', color: theme.color.accentDeep },
  toolOn: { backgroundColor: theme.color.ink },
  tools: {
    flexDirection: 'row', alignItems: 'center',
    borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: theme.color.hairline,
    backgroundColor: theme.color.paper,
    paddingHorizontal: theme.space(4), paddingVertical: theme.space(3),
  },
  toolGroup: { flexDirection: 'row', alignItems: 'center', gap: theme.space(2) },
  toolDivider: {
    width: StyleSheet.hairlineWidth, height: 18, backgroundColor: theme.color.hairline,
    marginHorizontal: theme.space(3),
  },
  toolSpacer: { flex: 1 },
  toolLabel: {
    fontSize: 9, letterSpacing: 1.2, fontWeight: '800', color: theme.color.inkFaint,
    marginRight: theme.space(1),
  },
  tool: {
    width: 34, height: 34, borderRadius: theme.radius.pill,
    backgroundColor: theme.color.surface, alignItems: 'center', justifyContent: 'center',
  },
  toolPressed: { backgroundColor: theme.color.surfaceDeep },
});
