import { useState } from 'react';
import { Alert, Platform } from 'react-native';
import { deletePost, toggleLike, type FeedPost, type Me } from '@/api';
import { ActionMenu, type Anchor, type MenuAction } from '@/ui/ActionMenu';

/** 길게 누른 글과 누른 자리 */
export type PressedPost = { post: FeedPost; anchor: Anchor };

/**
 * 카드를 꾹 눌렀을 때의 동작을 한곳에 모은다.
 * 내 글이면 수정·삭제, 남의 글이면 좋아요·댓글로 바로 가기.
 */
export function PostActions({ pressed, me, onClose, onEdit, onOpenPost, onDeleted, onLiked }: {
  pressed: PressedPost | null;
  me: Me;
  onClose: () => void;
  onEdit: (post: FeedPost) => void;
  onOpenPost: (post: FeedPost) => void;
  onDeleted: (id: number) => void;
  onLiked: (id: number, count: number, liked: boolean) => void;
}) {
  const [busy, setBusy] = useState(false);
  const post = pressed?.post ?? null;
  const mine = post != null && post.user_id === me.id;

  async function confirmDelete(target: FeedPost) {
    if (busy) return;
    // 웹에는 브라우저 confirm, 네이티브에는 시스템 경고창 — 실수로 지우는 일이 없게
    const ok = Platform.OS === 'web'
      ? globalThis.confirm?.(`Delete "${target.title}"? This cannot be undone.`) ?? false
      : await new Promise<boolean>((resolve) => {
        Alert.alert('Delete this post?', 'This cannot be undone.', [
          { text: 'Cancel', style: 'cancel', onPress: () => resolve(false) },
          { text: 'Delete', style: 'destructive', onPress: () => resolve(true) },
        ]);
      });
    if (!ok) return;
    setBusy(true);
    try {
      await deletePost(target.id);
      onDeleted(target.id);
    } catch {
      Alert.alert('Could not delete', 'Check your connection and try again.');
    } finally {
      setBusy(false);
    }
  }

  async function like(target: FeedPost) {
    // 먼저 화면부터 바꾼다 — 누른 즉시 하트가 채워지도록. 서버 응답이 오면 실제 값으로 맞춘다.
    const next = !target.liked;
    onLiked(target.id, target.like_count + (next ? 1 : -1), next);
    try {
      const { count, liked } = await toggleLike(target.id);
      onLiked(target.id, count, liked);
    } catch {
      onLiked(target.id, target.like_count, !!target.liked); // 실패하면 되돌린다
    }
  }

  const actions: MenuAction[] = post == null ? [] : mine
    ? [
      { key: 'edit', icon: 'edit-2', label: 'Edit', onPress: () => onEdit(post) },
      { key: 'open', icon: 'book-open', label: 'Read', onPress: () => onOpenPost(post) },
      { key: 'delete', icon: 'trash-2', label: 'Delete', danger: true, onPress: () => void confirmDelete(post) },
    ]
    : [
      {
        key: 'like',
        icon: 'heart',
        ion: post.liked ? 'heart' : 'heart-outline',
        label: post.liked ? 'Unlike' : 'Like',
        active: true,
        onPress: () => void like(post),
      },
      { key: 'comment', icon: 'message-circle', label: 'Comment', onPress: () => onOpenPost(post) },
      { key: 'open', icon: 'book-open', label: 'Read', onPress: () => onOpenPost(post) },
    ];

  return (
    <ActionMenu visible={pressed != null} anchor={pressed?.anchor ?? null} actions={actions} onClose={onClose} />
  );
}
