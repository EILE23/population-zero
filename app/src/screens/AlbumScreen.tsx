import { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator, Dimensions, Image, Pressable, RefreshControl,
  ScrollView, StyleSheet, Text, View,
} from 'react-native';
import { Feather } from '@expo/vector-icons';
import { fetchAlbums, type Album } from '@/api';
import { FadeIn, timeAgo } from '@/ui/cards';
import { EmptyState } from '@/ui/EmptyState';
import { Fab } from '@/ui/Fab';
import { TAB_BAR_HEIGHT } from '@/ui/TabBar';
import { theme } from '@/theme';

const W = Dimensions.get('window').width;
const PAD = 12;
const COVER = W - PAD * 2;

/**
 * 앨범 한 묶음 — 표지 한 장 크게, 나머지는 아래 작은 줄로.
 * 사진 한 장짜리 글은 여기 오지 않는다: 앨범은 묶음이라는 뜻이라서.
 */
function AlbumCard({ album, onOpen }: { album: Album; onOpen: (album: Album) => void }) {
  const [cover, ...rest] = album.images;
  return (
    <Pressable onPress={() => onOpen(album)} style={({ pressed }) => [s.card, pressed && s.pressed]}>
      <View style={s.coverWrap}>
        {cover ? <Image source={{ uri: cover }} style={s.cover} resizeMode="cover" /> : <View style={s.cover} />}
        <View style={s.count}>
          <Feather name="layers" size={11} color={theme.color.paper} />
          <Text style={s.countText}>{album.shot_count}</Text>
        </View>
      </View>

      {rest.length > 0 ? (
        <View style={s.strip}>
          {rest.slice(0, 3).map((src) => (
            <Image key={src} source={{ uri: src }} style={s.thumb} resizeMode="cover" />
          ))}
          {album.shot_count > 4 ? (
            <View style={[s.thumb, s.more]}>
              <Text style={s.moreText}>+{album.shot_count - 4}</Text>
            </View>
          ) : null}
        </View>
      ) : null}

      <View style={s.meta}>
        <Text style={s.title} numberOfLines={2}>{album.title}</Text>
        <Text style={s.by}>{album.handle} · {timeAgo(album.created_at)} ago</Text>
      </View>
    </Pressable>
  );
}

/**
 * Album — 말 그대로 사진첩.
 * 커뮤니티는 글, 여기는 사진 묶음. 커뮤니티에 글을 쓸 때 이 앨범을 붙여 공유한다.
 */
export function AlbumScreen({ reloadKey, onOpenPost, onCompose }: {
  reloadKey: number;
  onOpenPost: (postId: number) => void;
  onCompose: () => void;
}) {
  const [albums, setAlbums] = useState<Album[] | null>(null);
  const [mineOnly, setMineOnly] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const data = await fetchAlbums({ mine: mineOnly });
        if (!alive) return;
        setAlbums(data);
        setError(null);
      } catch {
        if (alive) { setAlbums([]); setError('Could not open the album.'); }
      }
    })();
    return () => { alive = false; };
  }, [mineOnly, reloadKey]);

  const refresh = useCallback(async () => {
    setRefreshing(true);
    try {
      setAlbums(await fetchAlbums({ mine: mineOnly }));
      setError(null);
    } catch {
      setError('Could not open the album.');
    } finally {
      setRefreshing(false);
    }
  }, [mineOnly]);

  return (
    <View style={s.root}>
      {albums == null ? (
        <View style={s.center}><ActivityIndicator color={theme.color.accent} /></View>
      ) : (
        <ScrollView
          contentContainerStyle={s.content}
          refreshControl={<RefreshControl refreshing={refreshing} onRefresh={refresh} tintColor={theme.color.accent} />}
        >
          <View style={s.header}>
            <Text style={s.heading}>Album</Text>
            <View style={s.toggle}>
              {[{ k: false, l: 'Everyone' }, { k: true, l: 'Mine' }].map((o) => (
                <Pressable
                  key={o.l}
                  onPress={() => setMineOnly(o.k)}
                  style={[s.toggleItem, mineOnly === o.k && s.toggleOn]}
                >
                  <Text style={[s.toggleText, mineOnly === o.k && s.toggleTextOn]}>{o.l}</Text>
                </Pressable>
              ))}
            </View>
          </View>

          {albums.length === 0 ? (
            error ? (
              <EmptyState icon="wifi-off" title="Could not open the album" body={error} actionLabel="Try again" onAction={refresh} />
            ) : mineOnly ? (
              <EmptyState
                icon="camera"
                title="Your album is empty"
                body="Shoot a few frames and they become one album — it shows up on population.town too."
                actionLabel="Make an album"
                onAction={onCompose}
              />
            ) : (
              <EmptyState
                icon="image"
                title="No albums in the town yet"
                body="An album is a set of photos posted together. Be the first to put one up."
                actionLabel="Make the first one"
                onAction={onCompose}
              />
            )
          ) : (
            albums.map((a, i) => (
              <FadeIn key={a.id} index={i}>
                <AlbumCard album={a} onOpen={() => onOpenPost(a.id)} />
              </FadeIn>
            ))
          )}
        </ScrollView>
      )}

      {/* 앨범에서는 사진부터 — 커뮤니티의 글쓰기 버튼과 하는 일이 다르다 */}
      <Fab icon="camera" label="New album" onPress={onCompose} />
    </View>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: theme.color.surface },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  content: { paddingHorizontal: PAD, paddingBottom: TAB_BAR_HEIGHT + theme.space(6) },
  header: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingTop: theme.space(4), paddingBottom: theme.space(3.5),
  },
  heading: { fontSize: 21, fontWeight: '800', color: theme.color.ink, letterSpacing: -0.4 },
  toggle: {
    flexDirection: 'row', backgroundColor: theme.color.surfaceDeep,
    borderRadius: theme.radius.pill, padding: 2,
  },
  toggleItem: { paddingHorizontal: theme.space(3.5), paddingVertical: theme.space(1.5), borderRadius: theme.radius.pill },
  toggleOn: { backgroundColor: theme.color.paper },
  toggleText: { fontSize: 12, fontWeight: '600', color: theme.color.inkSoft },
  toggleTextOn: { color: theme.color.ink, fontWeight: '700' },
  pressed: { opacity: 0.9 },
  card: { marginBottom: theme.space(6) },
  coverWrap: { borderRadius: theme.radius.lg, overflow: 'hidden' },
  cover: { width: COVER, height: COVER * 0.72, backgroundColor: theme.color.surfaceDeep },
  count: {
    position: 'absolute', right: theme.space(2.5), top: theme.space(2.5),
    flexDirection: 'row', alignItems: 'center', gap: 4,
    backgroundColor: 'rgba(1,0,1,0.55)', borderRadius: theme.radius.pill,
    paddingHorizontal: theme.space(2.5), paddingVertical: theme.space(1),
  },
  countText: { color: theme.color.paper, fontSize: 11, fontWeight: '700' },
  strip: { flexDirection: 'row', gap: 6, marginTop: 6 },
  thumb: { flex: 1, height: 62, borderRadius: theme.radius.sm, backgroundColor: theme.color.surfaceDeep },
  more: { alignItems: 'center', justifyContent: 'center', backgroundColor: theme.color.ink },
  moreText: { color: theme.color.paper, fontSize: 12, fontWeight: '800' },
  meta: { marginTop: theme.space(2.5) },
  title: { fontSize: 15.5, fontWeight: '700', color: theme.color.ink, lineHeight: 21 },
  by: { fontSize: 11.5, color: theme.color.inkSoft, marginTop: 3 },
});
