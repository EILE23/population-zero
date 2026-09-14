import { useEffect, useMemo, useState } from 'react';
import { ActivityIndicator, Animated, Easing, Image, Modal, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { Feather } from '@expo/vector-icons';
import { fetchAlbums, type Album } from '@/api';
import { Tap } from '@/ui/Tap';
import { theme } from '@/theme';

/**
 * 글에 붙일 앨범 고르기 — 내 앨범을 격자로 보여주고 하나를 고른다.
 * 앨범은 독립된 물건이라 글 여러 개가 같은 앨범을 가리킬 수 있다. 여기서는 내 것만 고른다:
 * 남의 앨범 공유는 그 앨범 화면에서 '글로 공유' 로 시작하는 게 맞다(출처가 거기 있으니까).
 */
export function AlbumPicker({ visible, onPick, onClose }: {
  visible: boolean;
  onPick: (album: Album) => void;
  onClose: () => void;
}) {
  const [albums, setAlbums] = useState<Album[] | null>(null);
  const anim = useMemo(() => new Animated.Value(0), []);

  useEffect(() => {
    if (!visible) return;
    anim.setValue(0);
    Animated.timing(anim, { toValue: 1, duration: 240, easing: Easing.out(Easing.cubic), useNativeDriver: true }).start();
    let alive = true;
    (async () => {
      try {
        const mine = await fetchAlbums({ mine: true });
        if (alive) setAlbums(mine);
      } catch {
        if (alive) setAlbums([]);
      }
    })();
    return () => { alive = false; };
  }, [visible, anim]);

  const rise = anim.interpolate({ inputRange: [0, 1], outputRange: [40, 0] });

  return (
    <Modal visible={visible} transparent animationType="none" onRequestClose={onClose}>
      <Pressable style={s.backdropTouch} onPress={onClose}>
        <Animated.View style={[s.backdrop, { opacity: anim }]} />
      </Pressable>
      <Animated.View style={[s.sheet, { opacity: anim, transform: [{ translateY: rise }] }]}>
        <View style={s.head}>
          <Text style={s.title}>Attach an album</Text>
          <Pressable onPress={onClose} hitSlop={12}>
            <Feather name="x" size={20} color={theme.color.inkMid} />
          </Pressable>
        </View>
        {albums == null ? (
          <View style={s.center}><ActivityIndicator color={theme.color.accent} /></View>
        ) : albums.length === 0 ? (
          <View style={s.center}>
            <Text style={s.empty}>No albums yet. Post one from the Album tab first.</Text>
          </View>
        ) : (
          <ScrollView contentContainerStyle={s.grid}>
            {albums.map((a) => (
              <Tap key={a.album_id} onPress={() => onPick(a)} style={s.cell} scale={0.95}>
                {a.cover ? <Image source={{ uri: a.cover }} style={s.thumb} resizeMode="cover" /> : <View style={s.thumb} />}
                {a.shot_count > 1 ? (
                  <View style={s.count}><Text style={s.countText}>{a.shot_count}</Text></View>
                ) : null}
                <Text style={s.caption} numberOfLines={1}>{a.title?.trim() || 'Untitled'}</Text>
              </Tap>
            ))}
          </ScrollView>
        )}
      </Animated.View>
    </Modal>
  );
}

const CELL = '31%';

const s = StyleSheet.create({
  backdropTouch: { position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 },
  backdrop: { flex: 1, backgroundColor: 'rgba(1,0,1,0.45)' },
  sheet: {
    position: 'absolute', left: 0, right: 0, bottom: 0, maxHeight: '72%',
    backgroundColor: theme.color.paper,
    borderTopLeftRadius: theme.radius.lg, borderTopRightRadius: theme.radius.lg,
    paddingBottom: theme.space(6),
  },
  head: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingHorizontal: theme.space(4), paddingVertical: theme.space(3.5),
    borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: theme.color.hairline,
  },
  title: { fontSize: 15, fontWeight: '800', color: theme.color.ink },
  center: { paddingVertical: theme.space(10), alignItems: 'center' },
  empty: { color: theme.color.inkSoft, fontSize: 13, textAlign: 'center', paddingHorizontal: theme.space(6) },
  grid: { flexDirection: 'row', flexWrap: 'wrap', gap: theme.space(2.5), padding: theme.space(4) },
  cell: { width: CELL },
  thumb: { width: '100%', aspectRatio: 1, borderRadius: theme.radius.md, backgroundColor: theme.color.surfaceDeep },
  count: {
    position: 'absolute', top: 6, right: 6, paddingHorizontal: 6, paddingVertical: 2,
    borderRadius: 8, backgroundColor: 'rgba(1,0,1,0.55)',
  },
  countText: { color: theme.color.paper, fontSize: 10, fontWeight: '800' },
  caption: { marginTop: 4, fontSize: 11.5, color: theme.color.inkMid },
});
