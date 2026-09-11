import { useEffect, useMemo } from 'react';
import { Animated, Easing, Modal, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { Feather } from '@expo/vector-icons';
import { theme } from '@/theme';

export type PickerOption = { key: string; label: string; hint?: string };
export type PickerGroup = { title: string; options: PickerOption[] };

/** 제목 줄 오른쪽 버튼 — 지금 보고 있는 분류를 보여주고, 누르면 목록이 열린다 */
export function CategoryButton({ label, onPress }: { label: string; onPress: () => void }) {
  return (
    <Pressable onPress={onPress} hitSlop={8} style={({ pressed }) => [s.button, pressed && s.buttonPressed]}>
      <Text style={s.buttonText} numberOfLines={1}>{label}</Text>
      <Feather name="sliders" size={13} color={theme.color.ink} />
    </Pressable>
  );
}

/**
 * 분류 고르기 — 칩을 줄줄이 늘어놓지 않는다.
 * 분류가 수십 개라 한 줄에 담기지 않고, 담아도 무엇이 무엇인지 구분되지 않는다.
 * 그래서 필요할 때만 열리는 목록으로 두고, 성격이 다른 묶음은 제목으로 확실히 갈라 놓는다.
 */
export function CategoryPicker({ visible, value, groups, onSelect, onClose }: {
  visible: boolean;
  value: string;
  groups: PickerGroup[];
  onSelect: (key: string) => void;
  onClose: () => void;
}) {
  const anim = useMemo(() => new Animated.Value(0), []);
  useEffect(() => {
    Animated.timing(anim, {
      toValue: visible ? 1 : 0,
      duration: visible ? 240 : 150,
      easing: visible ? Easing.out(Easing.cubic) : Easing.in(Easing.cubic),
      useNativeDriver: true,
    }).start();
  }, [anim, visible]);

  const rise = anim.interpolate({ inputRange: [0, 1], outputRange: [420, 0] });

  return (
    <Modal visible={visible} transparent animationType="none" onRequestClose={onClose}>
      <Pressable style={s.backdropTouch} onPress={onClose}>
        <Animated.View style={[s.backdrop, { opacity: anim }]} />
      </Pressable>
      <Animated.View style={[s.sheet, { transform: [{ translateY: rise }] }]}>
        <View style={s.grip} />
        <View style={s.head}>
          <Text style={s.headTitle}>Choose what you see</Text>
          <Pressable onPress={onClose} hitSlop={12}>
            <Feather name="x" size={19} color={theme.color.inkMid} />
          </Pressable>
        </View>

        <ScrollView contentContainerStyle={s.list}>
          {groups.map((g) => (
            <View key={g.title} style={s.group}>
              <Text style={s.groupTitle}>{g.title}</Text>
              <View style={s.groupCard}>
                {g.options.map((o, i) => {
                  const on = value === o.key;
                  return (
                    <Pressable
                      key={o.key}
                      onPress={() => { onSelect(o.key); onClose(); }}
                      style={({ pressed }) => [s.row, i > 0 && s.rowBorder, pressed && s.rowPressed]}
                    >
                      <View style={s.rowText}>
                        <Text style={[s.rowLabel, on && s.rowLabelOn]}>{o.label}</Text>
                        {o.hint ? <Text style={s.rowHint}>{o.hint}</Text> : null}
                      </View>
                      {on ? <Feather name="check" size={17} color={theme.color.accent} /> : null}
                    </Pressable>
                  );
                })}
              </View>
            </View>
          ))}
        </ScrollView>
      </Animated.View>
    </Modal>
  );
}

const s = StyleSheet.create({
  button: {
    flexDirection: 'row', alignItems: 'center', gap: theme.space(2),
    borderRadius: theme.radius.pill, borderWidth: 1, borderColor: theme.color.hairline,
    backgroundColor: theme.color.paper,
    paddingLeft: theme.space(3.5), paddingRight: theme.space(3), paddingVertical: theme.space(1.5),
    maxWidth: 170,
  },
  buttonPressed: { backgroundColor: theme.color.surfaceDeep },
  buttonText: { fontSize: 12.5, fontWeight: '700', color: theme.color.ink, flexShrink: 1 },
  backdropTouch: { position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 },
  backdrop: { flex: 1, backgroundColor: 'rgba(1,0,1,0.38)' },
  sheet: {
    position: 'absolute', left: 0, right: 0, bottom: 0, maxHeight: '82%',
    backgroundColor: theme.color.surface,
    borderTopLeftRadius: 22, borderTopRightRadius: 22,
    paddingBottom: theme.space(6),
  },
  grip: { width: 38, height: 4, borderRadius: 2, backgroundColor: theme.color.hairline, alignSelf: 'center', marginTop: theme.space(3) },
  head: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingHorizontal: theme.space(5), paddingTop: theme.space(4), paddingBottom: theme.space(3),
  },
  headTitle: { fontSize: 15, fontWeight: '800', color: theme.color.ink },
  list: { paddingHorizontal: theme.space(4), paddingBottom: theme.space(4) },
  group: { marginBottom: theme.space(5) },
  groupTitle: {
    fontSize: 9.5, letterSpacing: 1.4, fontWeight: '800', color: theme.color.inkSoft,
    marginBottom: theme.space(2), marginLeft: theme.space(1),
  },
  groupCard: {
    backgroundColor: theme.color.paper, borderRadius: theme.radius.lg,
    borderWidth: 1, borderColor: theme.color.hairline, overflow: 'hidden',
  },
  row: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingHorizontal: theme.space(4), paddingVertical: theme.space(3.5),
  },
  rowBorder: { borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: theme.color.hairline },
  rowPressed: { backgroundColor: theme.color.surfaceDeep },
  rowText: { flex: 1, minWidth: 0 },
  rowLabel: { fontSize: 14.5, color: theme.color.inkMid, fontWeight: '600' },
  rowLabelOn: { color: theme.color.ink, fontWeight: '800' },
  rowHint: { fontSize: 11.5, color: theme.color.inkSoft, marginTop: 2 },
});
