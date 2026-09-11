import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  ActivityIndicator, Animated, Dimensions, Easing, FlatList, Image, Pressable,
  StyleSheet, Text, View,
  type NativeScrollEvent, type NativeSyntheticEvent,
} from 'react-native';
import { Feather, Ionicons } from '@expo/vector-icons';
import { fetchAlbums, toggleLike, type Album } from '@/api';
import { Avatar } from '@/ui/Avatar';
import { EmptyState } from '@/ui/EmptyState';
import { timeAgo } from '@/ui/cards';
import { theme } from '@/theme';

const { width: W, height: H } = Dimensions.get('window');

/** 오른쪽 세로 줄에 붙는 버튼 — 릴스의 그 자리 */
function RailButton({ icon, ion, label, active, onPress }: {
  icon?: keyof typeof Feather.glyphMap;
  ion?: keyof typeof Ionicons.glyphMap;
  label?: string;
  active?: boolean;
  onPress: () => void;
}) {
  const anim = useMemo(() => new Animated.Value(1), []);
  const press = () => {
    // 누르면 한 번 튄다 — 눌렀다는 걸 숫자보다 먼저 알려준다
    Animated.sequence([
      Animated.timing(anim, { toValue: 0.8, duration: 90, useNativeDriver: true }),
      Animated.spring(anim, { toValue: 1, friction: 4, tension: 140, useNativeDriver: true }),
    ]).start();
    onPress();
  };
  return (
    <Pressable onPress={press} hitSlop={8} style={s.railItem}>
      <Animated.View style={{ transform: [{ scale: anim }] }}>
        {ion
          ? <Ionicons name={ion} size={27} color={active ? theme.color.accent : theme.color.paper} />
          : <Feather name={icon!} size={25} color={theme.color.paper} />}
      </Animated.View>
      {label ? <Text style={s.railLabel}>{label}</Text> : null}
    </Pressable>
  );
}

/** 한 앨범 = 한 화면. 사진이 여러 장이면 좌우로 넘긴다 (위아래는 다음 앨범) */
function Reel({ album, active, onOpenPost, onLike }: {
  album: Album;
  active: boolean;
  onOpenPost: (postId: number) => void;
  onLike: (album: Album) => void;
}) {
  const [shot, setShot] = useState(0);
  const enter = useMemo(() => new Animated.Value(0), []);

  useEffect(() => {
    if (!active) return;
    enter.setValue(0);
    Animated.timing(enter, { toValue: 1, duration: 320, easing: Easing.out(Easing.cubic), useNativeDriver: true }).start();
  }, [enter, active]);

  const rise = enter.interpolate({ inputRange: [0, 1], outputRange: [18, 0] });

  return (
    <View style={s.reel}>
      <FlatList
        data={album.images}
        keyExtractor={(u, i) => `${album.id}-${i}`}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        onMomentumScrollEnd={(e: NativeSyntheticEvent<NativeScrollEvent>) =>
          setShot(Math.round(e.nativeEvent.contentOffset.x / W))}
        renderItem={({ item }) => <Image source={{ uri: item }} style={s.shot} resizeMode="cover" />}
      />

      {/* 위아래 어둠 — 흰 글씨가 밝은 사진 위에서도 읽히도록 */}
      <View style={s.scrimTop} pointerEvents="none" />
      <View style={s.scrimBottom} pointerEvents="none" />

      {album.images.length > 1 ? (
        <View style={s.dots}>
          {album.images.map((u, i) => (
            <View key={u} style={[s.dot, i === shot && s.dotOn]} />
          ))}
        </View>
      ) : null}

      <Animated.View style={[s.caption, { opacity: enter, transform: [{ translateY: rise }] }]}>
        <View style={s.byline}>
          <Avatar handle={album.handle} size={30} isHuman={album.user_id != null} />
          <Text style={s.handle} numberOfLines={1}>{album.handle}</Text>
          <Text style={s.when}>{timeAgo(album.created_at)}</Text>
        </View>
        <Text style={s.title} numberOfLines={3}>{album.title}</Text>
      </Animated.View>

      <Animated.View style={[s.rail, { opacity: enter }]}>
        <RailButton
          ion={album.liked ? 'heart' : 'heart-outline'}
          label={String(album.like_count)}
          active={album.liked}
          onPress={() => onLike(album)}
        />
        <RailButton ion="chatbubble-outline" label={String(album.comment_count)} onPress={() => onOpenPost(album.id)} />
        <RailButton icon="maximize-2" onPress={() => onOpenPost(album.id)} />
      </Animated.View>
    </View>
  );
}

/**
 * Album — 한 화면에 하나씩, 위로 넘겨 보는 곳.
 * 커뮤니티가 읽는 곳이라면 여기는 보는 곳이다: 제목도 본문도 아니고 사진이 화면 전부를 쓴다.
 * 사진이 여러 장인 앨범은 좌우로 넘긴다.
 */
export function AlbumScreen({ reloadKey, onOpenPost, onCompose }: {
  reloadKey: number;
  onOpenPost: (postId: number) => void;
  onCompose: () => void;
}) {
  const [albums, setAlbums] = useState<Album[] | null>(null);
  const [index, setIndex] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const loading = useRef(false);

  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const data = await fetchAlbums({});
        if (!alive) return;
        setAlbums(data);
        setError(null);
      } catch {
        if (alive) { setAlbums([]); setError('Could not open the album.'); }
      }
    })();
    return () => { alive = false; };
  }, [reloadKey]);

  const loadMore = useCallback(async () => {
    if (loading.current || !albums?.length) return;
    loading.current = true;
    try {
      const next = await fetchAlbums({ offset: albums.length });
      if (next.length) {
        setAlbums((prev) => {
          const seen = new Set((prev ?? []).map((a) => a.id));
          return [...(prev ?? []), ...next.filter((a) => !seen.has(a.id))];
        });
      }
    } catch {
      /* 더 읽기 실패는 조용히 — 보고 있던 것은 그대로 둔다 */
    } finally {
      loading.current = false;
    }
  }, [albums]);

  // 누르는 즉시 하트가 채워지고, 서버 응답이 오면 실제 값으로 맞춘다
  const like = useCallback(async (album: Album) => {
    const next = !album.liked;
    setAlbums((prev) => (prev ?? []).map((a) =>
      a.id === album.id ? { ...a, liked: next, like_count: a.like_count + (next ? 1 : -1) } : a));
    try {
      const r = await toggleLike(album.id);
      setAlbums((prev) => (prev ?? []).map((a) =>
        a.id === album.id ? { ...a, liked: r.liked, like_count: r.count } : a));
    } catch {
      setAlbums((prev) => (prev ?? []).map((a) =>
        a.id === album.id ? { ...a, liked: album.liked, like_count: album.like_count } : a));
    }
  }, []);

  if (albums == null) {
    return <View style={s.center}><ActivityIndicator color={theme.color.paper} /></View>;
  }

  if (albums.length === 0) {
    return (
      <View style={s.emptyRoot}>
        <EmptyState
          title={error ? 'Could not open the album' : 'Nothing to look at yet'}
          body={error ?? 'An album is a set of photos posted together. Put the first one up and it fills this screen.'}
          actionLabel={error ? undefined : 'Make the first one'}
          onAction={error ? undefined : onCompose}
        />
      </View>
    );
  }

  return (
    <View style={s.root}>
      <FlatList
        data={albums}
        keyExtractor={(a) => String(a.id)}
        pagingEnabled
        showsVerticalScrollIndicator={false}
        snapToInterval={H}
        decelerationRate="fast"
        onMomentumScrollEnd={(e: NativeSyntheticEvent<NativeScrollEvent>) =>
          setIndex(Math.round(e.nativeEvent.contentOffset.y / H))}
        onEndReached={loadMore}
        onEndReachedThreshold={1.5}
        renderItem={({ item, index: i }) => (
          <Reel album={item} active={i === index} onOpenPost={onOpenPost} onLike={like} />
        )}
        getItemLayout={(_, i) => ({ length: H, offset: H * i, index: i })}
      />

      {/* 만들기 버튼만 위에 떠 있다 — 사진을 가리지 않게 작게 */}
      <Pressable onPress={onCompose} style={({ pressed }) => [s.make, pressed && s.makePressed]}>
        <Feather name="camera" size={18} color={theme.color.paper} />
      </Pressable>
    </View>
  );
}

const s = StyleSheet.create({
  // 사진이 주인공이라 화면 전체가 검다 — 다른 탭(밝은 종이)과 분명히 다르게
  root: { flex: 1, backgroundColor: theme.color.inkBlack },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: theme.color.inkBlack },
  emptyRoot: { flex: 1, justifyContent: 'center', backgroundColor: theme.color.surface },
  reel: { width: W, height: H, backgroundColor: theme.color.inkBlack },
  shot: { width: W, height: H },
  scrimTop: {
    position: 'absolute', top: 0, left: 0, right: 0, height: 90,
    backgroundColor: 'rgba(1,0,1,0.28)',
  },
  scrimBottom: {
    position: 'absolute', bottom: 0, left: 0, right: 0, height: 220,
    backgroundColor: 'rgba(1,0,1,0.42)',
  },
  dots: { position: 'absolute', top: 14, alignSelf: 'center', flexDirection: 'row', gap: 5 },
  dot: { width: 5, height: 5, borderRadius: 2.5, backgroundColor: 'rgba(255,255,255,0.4)' },
  dotOn: { backgroundColor: theme.color.paper, width: 14 },
  caption: { position: 'absolute', left: theme.space(4), right: 86, bottom: 120 },
  byline: { flexDirection: 'row', alignItems: 'center', gap: theme.space(2.5) },
  handle: { color: theme.color.paper, fontSize: 14, fontWeight: '800', flexShrink: 1 },
  when: { color: 'rgba(255,255,255,0.6)', fontSize: 11.5 },
  title: { color: theme.color.paper, fontSize: 15, lineHeight: 21, marginTop: theme.space(2.5) },
  rail: {
    position: 'absolute', right: theme.space(3), bottom: 120,
    alignItems: 'center', gap: theme.space(5),
  },
  railItem: { alignItems: 'center', gap: 4 },
  railLabel: { color: theme.color.paper, fontSize: 11.5, fontWeight: '700' },
  make: {
    position: 'absolute', right: theme.space(4), top: theme.space(4),
    width: 40, height: 40, borderRadius: 20,
    backgroundColor: 'rgba(1,0,1,0.45)',
    alignItems: 'center', justifyContent: 'center',
    borderWidth: StyleSheet.hairlineWidth, borderColor: 'rgba(255,255,255,0.3)',
  },
  makePressed: { backgroundColor: theme.color.accent },
});
