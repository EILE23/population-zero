import { useEffect, useMemo } from 'react';
import { Animated, Dimensions, Easing, Modal, Pressable, StyleSheet, View } from 'react-native';
import { Feather, Ionicons } from '@expo/vector-icons';
import { theme } from '@/theme';

export type MenuAction = {
  key: string;
  /** Feather 기본 — 채워진 하트처럼 Feather 에 없는 모양은 ion 으로 지정한다 */
  icon: keyof typeof Feather.glyphMap;
  ion?: keyof typeof Ionicons.glyphMap;
  label: string;
  danger?: boolean;
  active?: boolean;
  onPress: () => void;
};

/** 길게 누른 지점 — 버튼들을 그 근처에 띄우기 위해 화면 좌표로 받는다 */
export type Anchor = { x: number; y: number };

const SIZE = 38;
const RADIUS = 70;
const EDGE = 12;

/** 동그란 버튼 하나 — 누른 자리에서 순서대로 튀어나온다 */
function Bubble({ action, index, left, top, origin, onClose }: {
  action: MenuAction;
  index: number;
  left: number;
  top: number;
  origin: Anchor;
  onClose: () => void;
}) {
  const anim = useMemo(() => new Animated.Value(0), []);
  useEffect(() => {
    Animated.spring(anim, {
      toValue: 1,
      friction: 6,
      tension: 120,
      delay: index * 45,
      useNativeDriver: true,
    }).start();
  }, [anim, index]);

  // 처음에는 손가락이 닿은 자리에 겹쳐 있다가 제자리로 흩어진다
  const back = anim.interpolate({ inputRange: [0, 1], outputRange: [1, 0] });
  const dx = origin.x - SIZE / 2 - left;
  const dy = origin.y - SIZE / 2 - top;

  return (
    <Animated.View
      style={[
        s.bubbleWrap,
        {
          left, top, width: SIZE, height: SIZE,
          opacity: anim,
          transform: [
            { translateX: Animated.multiply(back, dx) },
            { translateY: Animated.multiply(back, dy) },
            { scale: anim.interpolate({ inputRange: [0, 1], outputRange: [0.3, 1] }) },
          ],
        },
      ]}
    >
      <Pressable
        onPress={() => { action.onPress(); onClose(); }}
        style={({ pressed }) => [
          s.bubble,
          action.danger && s.bubbleDanger,
          action.active && s.bubbleActive,
          pressed && s.bubblePressed,
        ]}
      >
        {action.ion
          ? <Ionicons name={action.ion} size={20} color={action.danger || action.active ? theme.color.paper : theme.color.ink} />
          : <Feather name={action.icon} size={19} color={action.danger || action.active ? theme.color.paper : theme.color.ink} />}
      </Pressable>
    </Animated.View>
  );
}

/**
 * 길게 누른 사진 옆으로 동그란 버튼들이 흩어져 나온다.
 * 아래에서 올라오는 시트가 아니라 손가락이 닿은 자리에서 —
 * 어느 글을 누른 것인지 눈을 옮기지 않고도 알 수 있도록.
 */
export function ActionMenu({ visible, anchor, actions, onClose }: {
  visible: boolean;
  anchor: Anchor | null;
  actions: MenuAction[];
  onClose: () => void;
}) {
  const fade = useMemo(() => new Animated.Value(0), []);
  useEffect(() => {
    Animated.timing(fade, {
      toValue: visible ? 1 : 0,
      duration: visible ? 160 : 120,
      easing: Easing.out(Easing.cubic),
      useNativeDriver: true,
    }).start();
  }, [fade, visible]);

  const { width, height } = Dimensions.get('window');
  const origin: Anchor = anchor ?? { x: width / 2, y: height / 2 };

  // 누른 자리를 중심으로 옆으로 열리는 호(돔)를 그린다.
  // 기본은 왼쪽 — 오른손 엄지로 누르면 손가락에 가리지 않는 쪽이 왼쪽이다.
  // 왼쪽 끝에 너무 붙어 눌렀을 때만 오른쪽으로 연다.
  const openLeft = origin.x > RADIUS + SIZE + EDGE;
  const base = openLeft ? Math.PI : 0;
  const span = Math.PI * 0.72;                        // 호가 벌어지는 각도
  const start = base - span / 2 * (openLeft ? 1 : -1); // 위쪽부터 아래로 내려온다
  const step = (actions.length > 1 ? span / (actions.length - 1) : 0) * (openLeft ? 1 : -1);

  return (
    <Modal visible={visible} transparent animationType="none" onRequestClose={onClose}>
      <Pressable style={s.backdropTouch} onPress={onClose}>
        <Animated.View style={[s.backdrop, { opacity: fade }]} />
      </Pressable>
      <View style={s.layer} pointerEvents="box-none">
        {actions.map((a, i) => {
          const angle = start + i * step;
          const dx = Math.cos(angle) * RADIUS;
          const dy = -Math.sin(angle) * RADIUS; // 화면 좌표는 아래가 +
          const left = Math.min(Math.max(origin.x + dx - SIZE / 2, EDGE), width - SIZE - EDGE);
          const top = Math.min(Math.max(origin.y + dy - SIZE / 2, EDGE), height - SIZE - EDGE);
          return (
            <Bubble key={a.key} action={a} index={i} left={left} top={top} origin={origin} onClose={onClose} />
          );
        })}
      </View>
    </Modal>
  );
}

const s = StyleSheet.create({
  backdropTouch: { position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 },
  backdrop: { flex: 1, backgroundColor: 'rgba(1,0,1,0.3)' },
  layer: { position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 },
  bubbleWrap: { position: 'absolute' },
  bubble: {
    width: SIZE,
    height: SIZE,
    borderRadius: SIZE / 2,
    backgroundColor: theme.color.paper,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: theme.color.inkBlack,
    shadowOpacity: 0.3,
    shadowRadius: 14,
    shadowOffset: { width: 0, height: 5 },
    elevation: 10,
  },
  bubbleActive: { backgroundColor: theme.color.accent },
  bubbleDanger: { backgroundColor: theme.color.accentDeep },
  bubblePressed: { opacity: 0.75 },
});
