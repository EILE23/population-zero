import { useEffect, useMemo } from 'react';
import { Animated, Easing, Platform, Pressable, StyleSheet, Text, View } from 'react-native';
import { BlurView } from 'expo-blur';
import { Feather, Ionicons } from '@expo/vector-icons';
import { theme } from '@/theme';

export type TabKey = 'today' | 'community' | 'album' | 'messages' | 'me';
export const TAB_ORDER: TabKey[] = ['today', 'community', 'album', 'messages', 'me'];
const BAR_H = 60;
const BAR_INSET = 12;
/** 탭바가 떠 있는 유리라 목록 아래쪽에 이만큼 여백을 둬야 마지막 글이 가려지지 않는다 */
export const TAB_BAR_HEIGHT = BAR_H + BAR_INSET * 2;

// Today 만 Feather 에 마땅한 모양이 없다 — 달력도 문서도 아닌 '오늘의 지면'이라
// Ionicons 의 신문을 쓴다. 나머지는 한 벌로 맞춘다.
const TABS: {
  key: TabKey;
  label: string;
  icon: keyof typeof Feather.glyphMap;
  ion?: keyof typeof Ionicons.glyphMap;
}[] = [
  { key: 'today', label: 'Wire', icon: 'calendar', ion: 'newspaper-outline' },
  { key: 'community', label: 'Community', icon: 'message-square' },
  { key: 'album', label: 'Album', icon: 'image' },
  { key: 'messages', label: 'Chat', icon: 'message-circle' },
  { key: 'me', label: 'Me', icon: 'user' },
];

/** 선택된 탭만 살짝 솟는다 — 어느 탭인지 색보다 움직임으로 먼저 읽히게 */
function TabItem({ tab, active, onPress }: { tab: (typeof TABS)[number]; active: boolean; onPress: () => void }) {
  const anim = useMemo(() => new Animated.Value(0), []);
  useEffect(() => {
    Animated.spring(anim, { toValue: active ? 1 : 0, friction: 7, tension: 90, useNativeDriver: true }).start();
  }, [anim, active]);

  const lift = anim.interpolate({ inputRange: [0, 1], outputRange: [0, -3] });
  const scale = anim.interpolate({ inputRange: [0, 1], outputRange: [1, 1.14] });

  return (
    <Pressable onPress={onPress} style={s.item} hitSlop={6}>
      <Animated.View style={{ transform: [{ translateY: lift }, { scale }] }}>
        {tab.ion
          ? <Ionicons name={tab.ion} size={20} color={active ? theme.color.ink : theme.color.inkFaint} />
          : <Feather name={tab.icon} size={19} color={active ? theme.color.ink : theme.color.inkFaint} />}
      </Animated.View>
      <Text style={[s.label, active && s.labelOn]}>{tab.label}</Text>
    </Pressable>
  );
}

/**
 * 아래 고정 탭 — 반투명 유리 위에 올려 목록이 비쳐 보인다.
 * 글쓰기 버튼은 여기에 두지 않는다: 화면마다 하는 일이 달라서 각 화면이 자기 버튼을 갖는다.
 */
export function TabBar({ active, onSelect }: { active: TabKey; onSelect: (key: TabKey) => void }) {
  return (
    <View style={s.root}>
      {/* 웹에는 네이티브 블러가 없다 — backdrop-filter 로 같은 느낌을 낸다 */}
      {Platform.OS === 'web'
        ? <View style={[s.fill, s.webGlass]} />
        : <BlurView intensity={70} tint="systemThinMaterialLight" style={s.fill} />}
      {/* 유리 윗면에 닿는 빛 — 이 한 줄이 없으면 반투명 흰 판(뿌연 창)으로 보인다 */}
      <View style={s.sheen} pointerEvents="none" />
      <View style={s.bar}>
        {TABS.map((t) => (
          <TabItem key={t.key} tab={t} active={active === t.key} onPress={() => onSelect(t.key)} />
        ))}
      </View>
    </View>
  );
}

/**
 * 탭을 바꿀 때 인스타처럼 옆에서 미끄러져 들어온다.
 * 화면들은 계속 살아 있고(스크롤 위치 유지), 보이지 않을 때만 접어 둔다.
 */
export function TabPage({ active, direction, children }: {
  active: boolean;
  /** 1 = 오른쪽 탭으로 이동, -1 = 왼쪽 탭으로 이동 */
  direction: number;
  children: React.ReactNode;
}) {
  // 0 에서 시작해 아래 effect 가 현재 상태로 맞춘다 (렌더 중 prop 으로 초기값을 잡지 않게)
  const anim = useMemo(() => new Animated.Value(0), []);
  useEffect(() => {
    if (!active) { anim.setValue(0); return; }
    anim.setValue(0);
    Animated.timing(anim, { toValue: 1, duration: 240, easing: Easing.out(Easing.cubic), useNativeDriver: true }).start();
  }, [anim, active]);

  const shift = anim.interpolate({ inputRange: [0, 1], outputRange: [26 * direction, 0] });

  // 보이는 화면은 일반 흐름(flex)에 둔다 — 웹에서 absolute 로 깔면 목록 높이가 잡히지 않아 스크롤이 죽는다
  return (
    <Animated.View
      style={[active ? s.pageActive : s.pageHidden, { opacity: anim, transform: [{ translateX: shift }] }]}
      pointerEvents={active ? 'auto' : 'none'}
    >
      {children}
    </Animated.View>
  );
}

const s = StyleSheet.create({
  // 화면 아래에 붙지 않고 떠 있는 유리 알약 — 글이 아래로 비쳐 지나간다
  root: {
    position: 'absolute',
    left: BAR_INSET + 4,
    right: BAR_INSET + 4,
    bottom: BAR_INSET,
    height: BAR_H,
    borderRadius: BAR_H / 2,
    overflow: 'hidden',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'rgba(27,12,21,0.10)',
    shadowColor: theme.color.inkBlack,
    shadowOpacity: 0.14,
    shadowRadius: 24,
    shadowOffset: { width: 0, height: 10 },
    elevation: 14,
  },
  // 위쪽 1px 하이라이트 — 유리의 모서리에 빛이 걸린 것처럼
  sheen: {
    position: 'absolute', top: 0, left: BAR_H / 3, right: BAR_H / 3, height: 1,
    backgroundColor: 'rgba(255,255,255,0.9)',
  },
  fill: { position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 },
  webGlass: {
    // 흰색을 적게 깔고 채도를 올려야 유리로 읽힌다 — 흰색이 많으면 그냥 뿌연 판이 된다
    backgroundColor: 'rgba(255,255,255,0.44)',
    ...(Platform.OS === 'web'
      ? ({ backdropFilter: 'saturate(200%) blur(26px)', WebkitBackdropFilter: 'saturate(200%) blur(26px)' } as object)
      : null),
  },
  bar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-around',
    height: BAR_H,
    paddingHorizontal: theme.space(2),
    backgroundColor: 'transparent',
  },
  item: { flex: 1, alignItems: 'center', paddingVertical: theme.space(1) },
  label: { fontSize: 9, marginTop: theme.space(1.5), fontWeight: '600', color: theme.color.inkFaint },
  labelOn: { color: theme.color.ink },
  pageActive: { flex: 1 },
  pageHidden: { display: 'none' },
});
