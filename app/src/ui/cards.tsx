import { useEffect, useMemo, type ReactNode } from 'react';
import { Animated, Dimensions, Easing, Image, Pressable, StyleSheet, Text, View, type GestureResponderEvent } from 'react-native';
import { Feather, Ionicons } from '@expo/vector-icons';
import type { FeedPost } from '@/api';
import type { Anchor } from '@/ui/ActionMenu';
import { theme } from '@/theme';

/** 발췌에 남은 마크다운 기호를 걷어낸다 — 카드에는 **굵게** 같은 표시가 글자로 보이면 안 된다 */
export function plain(text: string): string {
  return text
    .replace(/!\[[^\]]*\]\([^)]*\)/g, '')       // ![alt](url)
    .replace(/\[([^\]]+)\]\([^)]*\)/g, '$1')    // [글자](url) → 글자
    .replace(/\*\*(.+?)\*\*/g, '$1')            // **굵게** → 굵게
    .replace(/[*_`>#]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

export function timeAgo(iso: string): string {
  const t = Date.parse(iso.replace(' ', 'T') + (iso.endsWith('Z') ? '' : 'Z'));
  const mins = Math.max(0, Math.round((Date.now() - t) / 60000));
  if (mins < 60) return `${mins}m`;
  const hrs = Math.round(mins / 60);
  if (hrs < 24) return `${hrs}h`;
  return `${Math.round(hrs / 24)}d`;
}

/** 사진이 없는 글도 유튜브 글이면 썸네일이 있다 */
export function thumbOf(post: FeedPost): string | null {
  if (post.og_image) return post.og_image;
  if (post.media_type === 'youtube' && post.media_ref) return `https://i.ytimg.com/vi/${post.media_ref}/hqdefault.jpg`;
  return null;
}

export const GRID_GAP = 10;
export const COL_WIDTH = (Dimensions.get('window').width - GRID_GAP * 3) / 2;
const RATIOS = [1, 1.32, 0.78, 1.55, 1.06, 0.92];
/** 타일 높이는 글 id 로 정한다 — 스크롤해서 다시 그려도 높이가 흔들리지 않게 */
export function tileHeight(post: FeedPost): number {
  return Math.round(COL_WIDTH * RATIOS[post.id % RATIOS.length]);
}

/** 목록이 통째로 튀어나오지 않게 — 순서대로 살짝 떠오른다 */
export function FadeIn({ index, children }: { index: number; children: ReactNode }) {
  const anim = useMemo(() => new Animated.Value(0), []);
  useEffect(() => {
    Animated.timing(anim, {
      toValue: 1,
      duration: 300,
      delay: Math.min(index, 8) * 45,
      easing: Easing.out(Easing.cubic),
      useNativeDriver: true,
    }).start();
  }, [anim, index]);
  const y = anim.interpolate({ inputRange: [0, 1], outputRange: [14, 0] });
  return <Animated.View style={{ opacity: anim, transform: [{ translateY: y }] }}>{children}</Animated.View>;
}

type CardProps = {
  post: FeedPost;
  onPress: () => void;
  /** 길게 누른 지점을 함께 넘긴다 — 메뉴를 손가락이 닿은 자리에 띄우려고 */
  onLongPress: (anchor: Anchor) => void;
  /** 카드 안에서 바로 누르는 좋아요 — 글을 열지 않고 반응할 수 있어야 한다 */
  onLike?: () => void;
  /** 댓글로 바로 가기 */
  onComment?: () => void;
};

function anchorOf(e: GestureResponderEvent): Anchor {
  return { x: e.nativeEvent.pageX, y: e.nativeEvent.pageY };
}

/** 오늘의집식 — 사진이 먼저, 제목·작성자가 아래 붙는 카드 */
export function PhotoCard({ post, onPress, onLongPress, onLike, onComment }: CardProps) {
  const thumb = thumbOf(post);
  return (
    <Pressable
      onPress={onPress}
      onLongPress={(e) => onLongPress(anchorOf(e))}
      delayLongPress={280}
      style={({ pressed }) => [s.card, pressed && s.pressed]}
    >
      {thumb ? <Image source={{ uri: thumb }} style={s.cover} resizeMode="cover" /> : null}
      <View style={s.cardBody}>
        <Text style={s.cardTitle} numberOfLines={2}>{post.title}</Text>
        {post.excerpt ? <Text style={s.cardExcerpt} numberOfLines={2}>{plain(post.excerpt)}</Text> : null}
        <View style={s.metaRow}>
          <Text style={s.handle} numberOfLines={1}>{post.handle}</Text>
          <View style={s.metaSpacer} />
          <Pressable onPress={onLike} disabled={!onLike} hitSlop={10} style={s.metaButton}>
            <Ionicons
              name={post.liked ? 'heart' : 'heart-outline'}
              size={17}
              color={post.liked ? theme.color.accent : theme.color.inkSoft}
            />
            <Text style={[s.meta, post.liked && s.metaOn]}>{post.like_count}</Text>
          </Pressable>
          <Pressable onPress={onComment} disabled={!onComment} hitSlop={10} style={s.metaButton}>
            <Feather name="message-circle" size={16} color={theme.color.inkSoft} />
            <Text style={s.meta}>{post.comment_count}</Text>
          </Pressable>
          <Text style={s.metaTime}>{timeAgo(post.created_at)}</Text>
        </View>
      </View>
    </Pressable>
  );
}

/** 핀터레스트식 — 열마다 따로 쌓여서 높이가 엇갈린다 */
export function MediaTile({ post, onPress, onLongPress }: CardProps) {
  const thumb = thumbOf(post);
  const height = tileHeight(post);
  return (
    <Pressable
      onPress={onPress}
      onLongPress={(e) => onLongPress(anchorOf(e))}
      delayLongPress={280}
      style={({ pressed }) => [s.tile, pressed && s.pressed]}
    >
      {thumb
        ? <Image source={{ uri: thumb }} style={[s.tileImage, { height }]} resizeMode="cover" />
        : <View style={[s.tileImage, { height }]} />}
      {post.media_type === 'youtube' ? (
        <View style={s.play}><Feather name="play" size={11} color={theme.color.paper} /></View>
      ) : null}
      <Text style={s.tileTitle} numberOfLines={2}>{post.title}</Text>
      <Text style={s.tileHandle} numberOfLines={1}>{post.handle}</Text>
    </Pressable>
  );
}

const s = StyleSheet.create({
  pressed: { opacity: 0.88 },
  card: {
    backgroundColor: theme.color.paper,
    borderRadius: theme.radius.lg,
    overflow: 'hidden',
    marginBottom: theme.space(3),
    borderWidth: 1,
    borderColor: theme.color.hairline,
  },
  cover: { width: '100%', height: 190, backgroundColor: theme.color.surfaceDeep },
  cardBody: { padding: theme.space(3.5) },
  cardTitle: { fontSize: 16.5, fontWeight: '700', color: theme.color.ink, lineHeight: 22 },
  cardExcerpt: { fontSize: 13, color: theme.color.inkMid, marginTop: theme.space(1.5), lineHeight: 18 },
  // 글자와 아이콘의 가운데를 맞춘다 — 줄이 어긋나면 카드가 흐트러져 보인다
  metaRow: { flexDirection: 'row', alignItems: 'center', marginTop: theme.space(2.5), gap: theme.space(3) },
  metaButton: { flexDirection: 'row', alignItems: 'center', gap: 4, paddingVertical: 2 },
  metaSpacer: { flex: 1 },
  handle: { fontSize: 12.5, fontWeight: '700', color: theme.color.ink, flexShrink: 1, lineHeight: 17 },
  meta: { fontSize: 12, color: theme.color.inkSoft, lineHeight: 17 },
  metaTime: { fontSize: 11.5, color: theme.color.inkFaint, lineHeight: 17 },
  metaOn: { color: theme.color.accent, fontWeight: '700' },
  tile: { width: COL_WIDTH, marginBottom: theme.space(4) },
  tileImage: { width: '100%', borderRadius: theme.radius.md, backgroundColor: theme.color.surfaceDeep },
  play: {
    position: 'absolute', top: theme.space(2), right: theme.space(2),
    backgroundColor: 'rgba(1,0,1,0.55)', borderRadius: theme.radius.pill,
    paddingHorizontal: theme.space(2), paddingVertical: theme.space(1),
  },
  tileTitle: { fontSize: 12.5, fontWeight: '600', color: theme.color.ink, marginTop: theme.space(1.5), lineHeight: 17 },
  tileHandle: { fontSize: 11, color: theme.color.inkSoft, marginTop: 2 },
});
