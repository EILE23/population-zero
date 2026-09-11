import { useEffect, useMemo, useRef, useState } from 'react';
import { Animated, Easing, Pressable, StyleSheet, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { theme } from '@/theme';

/**
 * 흩어질 하트 한 조각의 궤적.
 * 누르는 순간에 정한다 — 렌더 중에 뽑으면 화면이 다시 그려질 때마다 길이 바뀐다.
 */
type Spark = { id: number; drift: number; rise: number; spin: number; delay: number };

function makeSparks(seed: number): Spark[] {
  return Array.from({ length: 5 }, (_, i) => ({
    id: seed * 10 + i,
    drift: (i - 2) * 11 + (Math.random() - 0.5) * 10,
    rise: 32 + Math.random() * 28,
    spin: (Math.random() - 0.5) * 44,
    delay: i * 45,
  }));
}

/** 터져 나가는 작은 하트 하나 — 위로 떠오르며 사라진다 */
function Piece({ spark, size, onDone }: { spark: Spark; size: number; onDone: () => void }) {
  const anim = useMemo(() => new Animated.Value(0), []);

  useEffect(() => {
    Animated.timing(anim, {
      toValue: 1,
      duration: 620,
      delay: spark.delay,
      easing: Easing.out(Easing.cubic),
      useNativeDriver: true,
    }).start(({ finished }) => { if (finished) onDone(); });
  }, [anim, spark.delay, onDone]);

  return (
    <Animated.View
      pointerEvents="none"
      style={{
        position: 'absolute',
        opacity: anim.interpolate({ inputRange: [0, 0.15, 1], outputRange: [0, 1, 0] }),
        transform: [
          { translateY: anim.interpolate({ inputRange: [0, 1], outputRange: [0, -spark.rise] }) },
          { translateX: anim.interpolate({ inputRange: [0, 1], outputRange: [0, spark.drift] }) },
          { scale: anim.interpolate({ inputRange: [0, 0.3, 1], outputRange: [0.4, 1, 0.7] }) },
          { rotate: anim.interpolate({ inputRange: [0, 1], outputRange: ['0deg', `${spark.spin}deg`] }) },
        ],
      }}
    >
      <Ionicons name="heart" size={size} color={theme.color.accent} />
    </Animated.View>
  );
}

/**
 * 좋아요 — 누르면 하트가 한 번 부풀고, 작은 하트들이 위로 흩어진다.
 *
 * 숫자만 조용히 바뀌면 눌렀는지 알 수 없다. 취소할 때는 터뜨리지 않는다:
 * 되돌리는 동작에 축하를 붙이면 무슨 일이 일어났는지 헷갈린다.
 */
export function LikeButton({ liked, count, size = 17, onPress }: {
  liked: boolean;
  count: number;
  size?: number;
  onPress: () => void;
}) {
  const pop = useMemo(() => new Animated.Value(1), []);
  const [sparks, setSparks] = useState<Spark[]>([]);
  const seq = useRef(0);

  function press() {
    Animated.sequence([
      Animated.timing(pop, { toValue: 0.72, duration: 90, useNativeDriver: true }),
      Animated.spring(pop, { toValue: 1, friction: 3.5, tension: 160, useNativeDriver: true }),
    ]).start();
    if (!liked) {
      seq.current += 1;
      setSparks((prev) => [...prev, ...makeSparks(seq.current)]);
    }
    onPress();
  }

  return (
    <Pressable onPress={press} hitSlop={10} style={s.root}>
      <View style={s.heart}>
        {sparks.map((sp) => (
          <Piece
            key={sp.id}
            spark={sp}
            size={size * 0.8}
            onDone={() => setSparks((prev) => prev.filter((x) => x.id !== sp.id))}
          />
        ))}
        <Animated.View style={{ transform: [{ scale: pop }] }}>
          <Ionicons
            name={liked ? 'heart' : 'heart-outline'}
            size={size}
            color={liked ? theme.color.accent : theme.color.inkSoft}
          />
        </Animated.View>
      </View>
      <Text style={[s.count, { fontSize: size * 0.72 }, liked && s.countOn]}>{count}</Text>
    </Pressable>
  );
}

const s = StyleSheet.create({
  root: { flexDirection: 'row', alignItems: 'center', gap: 4, paddingVertical: 2 },
  heart: { alignItems: 'center', justifyContent: 'center' },
  count: { color: theme.color.inkSoft, lineHeight: 17 },
  countOn: { color: theme.color.accent, fontWeight: '700' },
});
