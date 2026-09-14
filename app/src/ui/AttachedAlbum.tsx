import { useState } from 'react';
import { Dimensions, FlatList, Image, Modal, Pressable, StyleSheet, Text, View } from 'react-native';
import { Feather } from '@expo/vector-icons';
import { theme } from '@/theme';

const { width: W, height: H } = Dimensions.get('window');

/**
 * 글에 붙어 온 앨범 — 본문 사이에 사진을 늘어놓지 않는다.
 * 앨범은 글의 일부가 아니라 '딸려 온 물건' 이다: 본문 아래 카드 하나로 떼어 두고, 누르면 전체화면으로 넘겨 본다.
 * 웹(AttachedAlbum.tsx)과 같은 모양 — 카드 → 열기 → 한 장씩.
 */
export function AttachedAlbum({ images, owner, originPostId, onOpenPost }: {
  images: string[];
  owner: string | null;
  originPostId: number | null;
  onOpenPost?: (id: number) => void;
}) {
  const [open, setOpen] = useState(false);
  const [shot, setShot] = useState(0);
  if (!images.length) return null;
  const label = `Album · ${images.length} ${images.length === 1 ? 'shot' : 'shots'}`;

  return (
    <View style={s.wrap}>
      <Text style={s.overline}>ATTACHED ALBUM</Text>
      <Pressable onPress={() => { setShot(0); setOpen(true); }} style={({ pressed }) => [s.card, pressed && s.cardPressed]}>
        <View style={s.thumbWrap}>
          <Image source={{ uri: images[0] }} style={s.thumb} resizeMode="cover" />
          {images.length > 1 ? <View style={s.count}><Text style={s.countText}>{images.length}</Text></View> : null}
        </View>
        <View style={s.meta}>
          <View style={s.titleRow}><Feather name="image" size={14} color={theme.color.ink} /><Text style={s.title}>{label}</Text></View>
          <Text style={s.sub} numberOfLines={1}>by {owner ?? 'someone'}</Text>
        </View>
        <View style={s.open}><Text style={s.openText}>Open</Text></View>
      </Pressable>

      <Modal visible={open} animationType="fade" onRequestClose={() => setOpen(false)} statusBarTranslucent>
        <View style={s.viewer}>
          <View style={s.viewerBar}>
            <Text style={s.viewerLabel}>{label}{owner ? ` · ${owner}` : ''}{images.length > 1 ? `  ${shot + 1}/${images.length}` : ''}</Text>
            <Pressable accessibilityLabel="Close" onPress={() => setOpen(false)} hitSlop={12} style={s.close}>
              <Feather name="x" size={22} color={theme.color.paper} />
            </Pressable>
          </View>
          <FlatList
            data={images}
            keyExtractor={(u) => u}
            horizontal
            pagingEnabled
            showsHorizontalScrollIndicator={false}
            onMomentumScrollEnd={(e) => setShot(Math.round(e.nativeEvent.contentOffset.x / W))}
            renderItem={({ item }) => <Image source={{ uri: item }} style={s.shot} resizeMode="contain" />}
          />
          {originPostId && onOpenPost ? (
            <Pressable onPress={() => { setOpen(false); onOpenPost(originPostId); }} style={s.originBtn}>
              <Text style={s.originText}>Open original post →</Text>
            </Pressable>
          ) : <View style={s.originBtn} />}
        </View>
      </Modal>
    </View>
  );
}

const s = StyleSheet.create({
  wrap: { marginTop: theme.space(6), paddingTop: theme.space(4), borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: theme.color.hairline },
  overline: { fontSize: 10.5, fontWeight: '700', letterSpacing: 1.2, color: theme.color.inkSoft, marginBottom: theme.space(2.5) },
  card: { flexDirection: 'row', alignItems: 'center', gap: theme.space(3.5), padding: theme.space(3), borderRadius: theme.radius.lg, borderWidth: 1, borderColor: theme.color.hairline, backgroundColor: theme.color.paper },
  cardPressed: { backgroundColor: theme.color.surface },
  thumbWrap: { width: 76, height: 76, borderRadius: theme.radius.md, overflow: 'hidden', backgroundColor: theme.color.surfaceDeep },
  thumb: { width: '100%', height: '100%' },
  count: { position: 'absolute', right: 4, bottom: 4, paddingHorizontal: 6, paddingVertical: 2, borderRadius: 6, backgroundColor: 'rgba(1,0,1,0.6)' },
  countText: { color: theme.color.paper, fontSize: 10, fontWeight: '800' },
  meta: { flex: 1, minWidth: 0 },
  titleRow: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  title: { fontSize: 14, fontWeight: '800', color: theme.color.ink },
  sub: { marginTop: 3, fontSize: 12.5, color: theme.color.inkSoft },
  open: { borderRadius: theme.radius.pill, borderWidth: 1, borderColor: theme.color.hairline, paddingHorizontal: theme.space(3.5), paddingVertical: theme.space(1.5) },
  openText: { fontSize: 12.5, fontWeight: '700', color: theme.color.inkMid },
  viewer: { flex: 1, backgroundColor: theme.color.inkBlack },
  viewerBar: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingTop: 48, paddingHorizontal: theme.space(4), paddingBottom: theme.space(2) },
  viewerLabel: { color: theme.color.paper, fontSize: 11, letterSpacing: 1, textTransform: 'uppercase' },
  close: { padding: 4 },
  shot: { width: W, height: H - 160 },
  originBtn: { alignItems: 'center', paddingVertical: theme.space(4) },
  originText: { color: theme.color.paper, fontSize: 13, fontWeight: '700', textDecorationLine: 'underline' },
});
