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
export function AlbumPicker({ visible, selectedId = null, onPick, onClose }: {
  visible: boolean;
  /** 이미 붙어 있는 앨범 — 격자에서 표시해 준다 */
  selectedId?: number | null;
  onPick: (album: Album) => void;
  onClose: () => void;
}) {
  const [albums, setAlbums] = useState<Album[] | null>(null);
  const [failed, setFailed] = useState(false);
  const [attempt, setAttempt] = useState(0);
  const anim = useMemo(() => new Animated.Value(0), []);

  useEffect(() => {
    if (!visible) return;
    anim.setValue(0);
    Animated.timing(anim, { toValue: 1, duration: 240, easing: Easing.out(Easing.cubic), useNativeDriver: true }).start();
    let alive = true;
    (async () => {
      try {
        const mine = await fetchAlbums({ mine: true });
        if (alive) { setAlbums(mine); setFailed(false); }
      } catch {
        // "앨범이 없다" 와 "못 불러왔다" 는 다른 말이다 — 실패는 다시 시도할 수 있게
        if (alive) { setAlbums(null); setFailed(true); }
      }
    })();
    return () => { alive = false; };
  }, [visible, anim, attempt]);

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
        {failed ? (
          <View style={s.center}>
            <Text style={s.empty}>Could not load your albums.</Text>
            <Tap onPress={() => setAttempt((n) => n + 1)} style={s.retry} scale={0.95}><Text style={s.retryText}>Try again</Text></Tap>
          </View>
        ) : albums == null ? (
          <View style={s.center}><ActivityIndicator color={theme.color.accent} /></View>
        ) : albums.length === 0 ? (
          <View style={s.center}>
            <Text style={s.empty}>No albums yet. Post one from the Album tab first.</Text>
          </View>
        ) : (
          <ScrollView contentContainerStyle={s.grid}>
            {albums.map((a) => {
              const on = a.album_id === selectedId;
              return (
                <Tap key={a.album_id} onPress={() => onPick(a)} style={s.cell} scale={0.95}>
                  <View style={[s.thumbWrap, on && s.thumbOn]}>
                    {a.cover ? <Image source={{ uri: a.cover }} style={s.thumb} resizeMode="cover" /> : <View style={s.thumb} />}
                    {a.shot_count > 1 ? (
                      <View style={s.count}><Text style={s.countText}>{a.shot_count}</Text></View>
                    ) : null}
                    {on ? <View style={s.check}><Feather name="check" size={14} color={theme.color.paper} /></View> : null}
                  </View>
                  <Text style={[s.caption, on && s.captionOn]} numberOfLines={1}>{a.title?.trim() || 'Untitled'}</Text>
                </Tap>
              );
            })}
          </ScrollView>
        )}
        <Text style={s.hint}>Only your own albums. To share someone else’s, open it in the Album tab.</Text>
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
  thumbWrap: { borderRadius: theme.radius.md, overflow: 'hidden', borderWidth: 2, borderColor: 'transparent' },
  thumbOn: { borderColor: theme.color.accent },
  thumb: { width: '100%', aspectRatio: 1, backgroundColor: theme.color.surfaceDeep },
  check: { position: 'absolute', bottom: 6, left: 6, width: 22, height: 22, borderRadius: 11, backgroundColor: theme.color.accent, alignItems: 'center', justifyContent: 'center' },
  captionOn: { color: theme.color.ink, fontWeight: '700' },
  retry: { marginTop: theme.space(3), borderRadius: theme.radius.pill, borderWidth: 1, borderColor: theme.color.hairline, paddingHorizontal: theme.space(4), paddingVertical: theme.space(1.5) },
  retryText: { fontSize: 13, fontWeight: '700', color: theme.color.inkMid },
  hint: { fontSize: 11, color: theme.color.inkSoft, textAlign: 'center', paddingHorizontal: theme.space(6), paddingTop: theme.space(2) },
  count: {
    position: 'absolute', top: 6, right: 6, paddingHorizontal: 6, paddingVertical: 2,
    borderRadius: 8, backgroundColor: 'rgba(1,0,1,0.55)',
  },
  countText: { color: theme.color.paper, fontSize: 10, fontWeight: '800' },
  caption: { marginTop: 4, fontSize: 11.5, color: theme.color.inkMid },
});
