import { useEffect, useState } from 'react';
import { ActivityIndicator, Image, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { Feather } from '@expo/vector-icons';
import { fetchPostDetail, toggleLike, type PostDetail } from '@/api';
import { AdSlot } from '@/ui/AdSlot';
import { timeAgo } from '@/ui/cards';
import { CommentsSheet } from '@/ui/CommentsSheet';
import { theme } from '@/theme';

/** 본문 한 줄을 어떤 모양으로 그릴지 — 무거운 마크다운 파서 없이 글의 골격만 살린다 */
type Block = { kind: 'h2' | 'h3' | 'quote' | 'bullet' | 'p'; text: string };

function toBlocks(body: string): Block[] {
  return body
    .split('\n')
    .map((raw) => raw.trim())
    .filter((line) => line.length > 0 && !line.startsWith('!['))
    .map<Block>((line) => {
      if (line.startsWith('### ')) return { kind: 'h3', text: line.slice(4) };
      if (line.startsWith('## ')) return { kind: 'h2', text: line.slice(3) };
      if (line.startsWith('# ')) return { kind: 'h2', text: line.slice(2) };
      if (line.startsWith('> ')) return { kind: 'quote', text: line.slice(2) };
      if (/^([-*]|\d+[.)])\s+/.test(line)) return { kind: 'bullet', text: line.replace(/^([-*]|\d+[.)])\s+/, '') };
      return { kind: 'p', text: line };
    })
    // 굵게·기울임·링크 표시는 글자만 남긴다
    .map((b) => ({ ...b, text: b.text.replace(/\*\*(.+?)\*\*/g, '$1').replace(/\[(.+?)\]\((.+?)\)/g, '$1') }));
}

export function PostScreen({ postId, onBack, onEdit }: {
  postId: number;
  onBack: () => void;
  onEdit: (detail: PostDetail) => void;
}) {
  const [detail, setDetail] = useState<PostDetail | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [liked, setLiked] = useState(false);
  const [likeCount, setLikeCount] = useState(0);
  const [commentCount, setCommentCount] = useState(0);
  const [commentsOpen, setCommentsOpen] = useState(false);

  // 처음 열 때 — 화면을 닫고 응답이 도착해도 아무것도 건드리지 않도록 가드를 둔다
  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const d = await fetchPostDetail(postId);
        if (!alive) return;
        setDetail(d);
        setLiked(d.myLike);
        setLikeCount(d.post.like_count);
        setCommentCount(d.comments.length);
        setError(null);
      } catch {
        if (alive) setError('Could not open this post.');
      }
    })();
    return () => { alive = false; };
  }, [postId]);

  async function onLike() {
    // 먼저 화면을 바꾸고 서버에 맡긴다 — 탭이 즉시 반응하도록
    const next = !liked;
    setLiked(next);
    setLikeCount((c) => c + (next ? 1 : -1));
    try {
      const r = await toggleLike(postId);
      setLiked(r.liked);
      setLikeCount(r.count);
    } catch {
      setLiked(!next);
      setLikeCount((c) => c + (next ? -1 : 1));
    }
  }

  if (!detail) {
    return (
      <View style={s.center}>
        {error ? <Text style={s.error}>{error}</Text> : <ActivityIndicator color={theme.color.accent} />}
        <Pressable onPress={onBack} hitSlop={12} style={s.backLink}><Text style={s.backLinkText}>Back</Text></Pressable>
      </View>
    );
  }

  const { post } = detail;
  const cover = post.og_image
    ?? (post.media_type === 'youtube' && post.media_ref ? `https://i.ytimg.com/vi/${post.media_ref}/hqdefault.jpg` : null);

  return (
    <View style={s.root}>
      <View style={s.bar}>
        <Pressable onPress={onBack} hitSlop={12} style={s.barButton}>
          <Feather name="chevron-left" size={22} color={theme.color.ink} />
        </Pressable>
        {detail.isMine ? (
          <Pressable onPress={() => onEdit(detail)} hitSlop={12} style={s.barButton}>
            <Feather name="edit-2" size={17} color={theme.color.ink} />
          </Pressable>
        ) : <View style={s.barButton} />}
      </View>

      <ScrollView contentContainerStyle={s.content}>
        {cover ? <Image source={{ uri: cover }} style={s.cover} resizeMode="cover" /> : null}
        <Text style={s.title}>{post.title}</Text>
        <View style={s.byline}>
          <Text style={s.author}>{post.handle}</Text>
          <Text style={s.dateline}>
            {timeAgo(post.created_at)} ago{post.topic ? ` · ${post.topic}` : ''} · {post.view_count} views
          </Text>
        </View>

        {toBlocks(post.body).map((b, i) => (
          <Text
            key={i}
            style={[s.p, b.kind === 'h2' && s.h2, b.kind === 'h3' && s.h3, b.kind === 'quote' && s.quote, b.kind === 'bullet' && s.bullet]}
          >
            {b.kind === 'bullet' ? `·  ${b.text}` : b.text}
          </Text>
        ))}

        {error ? <Text style={s.error}>{error}</Text> : null}

        {/* 다 읽은 자리 — 본문을 가로막지 않고, 스크롤을 끝까지 내린 사람에게만 보인다 */}
        <View style={s.adSlot}><AdSlot /></View>
      </ScrollView>

      {/* 읽는 화면과 말 거는 화면을 나눈다 — 댓글은 아래에서 올라온다 */}
      <View style={s.actionBar}>
        <Pressable onPress={onLike} style={({ pressed }) => [s.action, pressed && s.actionPressed]}>
          <Feather name="heart" size={18} color={liked ? theme.color.accent : theme.color.ink} />
          <Text style={[s.actionText, liked && s.actionTextOn]}>{likeCount}</Text>
        </Pressable>
        <Pressable onPress={() => setCommentsOpen(true)} style={({ pressed }) => [s.commentsButton, pressed && s.actionPressed]}>
          <Feather name="message-circle" size={16} color={theme.color.inkMid} />
          <Text style={s.commentsText}>
            {commentCount === 0 ? 'Say something' : `${commentCount} comments`}
          </Text>
        </Pressable>
      </View>

      <CommentsSheet
        visible={commentsOpen}
        postId={postId}
        canInteract={detail.canInteract}
        onClose={() => setCommentsOpen(false)}
        onCountChange={setCommentCount}
      />
    </View>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: theme.color.paper },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: theme.color.paper },
  backLink: { marginTop: theme.space(4) },
  backLinkText: { color: theme.color.inkMid, fontWeight: '600', fontSize: 13 },
  bar: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingHorizontal: theme.space(2), paddingVertical: theme.space(2),
  },
  barButton: { width: 40, height: 34, alignItems: 'center', justifyContent: 'center' },
  content: { paddingHorizontal: theme.space(5), paddingBottom: theme.space(10) },
  cover: { width: '100%', height: 210, borderRadius: theme.radius.md, backgroundColor: theme.color.surfaceDeep, marginBottom: theme.space(4) },
  title: { fontSize: 24, fontWeight: '800', color: theme.color.ink, lineHeight: 31, letterSpacing: -0.5 },
  byline: { marginTop: theme.space(3), marginBottom: theme.space(5) },
  author: { fontSize: 13.5, fontWeight: '700', color: theme.color.ink },
  dateline: { fontSize: 11.5, color: theme.color.inkSoft, marginTop: 2 },
  p: { fontSize: 15, lineHeight: 24, color: theme.color.inkMid, marginBottom: theme.space(3) },
  h2: { fontSize: 19, fontWeight: '800', color: theme.color.ink, lineHeight: 26, marginTop: theme.space(4) },
  h3: { fontSize: 16, fontWeight: '700', color: theme.color.ink, lineHeight: 23, marginTop: theme.space(3) },
  quote: {
    borderLeftWidth: 2, borderLeftColor: theme.color.accent, paddingLeft: theme.space(3),
    fontStyle: 'italic', color: theme.color.inkSoft,
  },
  bullet: { marginBottom: theme.space(2) },
  error: { color: theme.color.accentDeep, fontWeight: '700', fontSize: 13, marginTop: theme.space(3) },
  adSlot: { marginTop: theme.space(8) },
  actionBar: {
    flexDirection: 'row', alignItems: 'center', gap: theme.space(3),
    borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: theme.color.hairline,
    paddingHorizontal: theme.space(4), paddingVertical: theme.space(3),
    backgroundColor: theme.color.paper,
  },
  action: { flexDirection: 'row', alignItems: 'center', gap: theme.space(2), paddingHorizontal: theme.space(2), paddingVertical: theme.space(2) },
  actionPressed: { opacity: 0.6 },
  actionText: { fontSize: 13, fontWeight: '700', color: theme.color.ink },
  actionTextOn: { color: theme.color.accent },
  commentsButton: {
    flex: 1, flexDirection: 'row', alignItems: 'center', gap: theme.space(2),
    backgroundColor: theme.color.surface, borderRadius: theme.radius.pill,
    paddingHorizontal: theme.space(4), paddingVertical: theme.space(3),
  },
  commentsText: { fontSize: 13, color: theme.color.inkMid, fontWeight: '600' },
});
