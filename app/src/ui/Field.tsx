import { useMemo, useState } from 'react';
import { Animated, Platform, StyleSheet, TextInput, View, type TextInputProps, type TextStyle } from 'react-native';
import { theme } from '@/theme';

// 웹(react-native-web)에서 브라우저 기본 포커스 링(주황 테두리)이 뚫고 나오는 걸 막는다.
// RN 타입에는 없는 웹 전용 속성이라 한 번만 좁혀서 캐스팅한다.
const NO_OUTLINE = Platform.OS === 'web' ? ({ outlineStyle: 'none' } as unknown as TextStyle) : null;

type Props = Omit<TextInputProps, 'placeholder'> & { label: string };

/**
 * 밑줄형 입력 — 포커스하거나 값이 있으면 라벨이 위로 작게 떠오르고,
 * 브랜드 색 밑줄이 좌우로 자라난다. 상자도 배경도 없이 선 하나로 상태를 알린다.
 */
export function Field({ label, style, value, onFocus, onBlur, ...props }: Props) {
  const [focused, setFocused] = useState(false);
  const grow = useMemo(() => new Animated.Value(0), []);   // 밑줄 성장
  const float = useMemo(() => new Animated.Value(0), []);  // 라벨 떠오름

  const hasValue = (value ?? '').length > 0;

  const run = (anim: Animated.Value, to: number, native: boolean) => {
    Animated.timing(anim, { toValue: to, duration: 170, useNativeDriver: native }).start();
  };

  function handleFocus(e: Parameters<NonNullable<TextInputProps['onFocus']>>[0]) {
    setFocused(true);
    run(grow, 1, true);
    run(float, 1, false); // 위치+글자크기 변화라 네이티브 드라이버 불가
    onFocus?.(e);
  }
  function handleBlur(e: Parameters<NonNullable<TextInputProps['onBlur']>>[0]) {
    setFocused(false);
    run(grow, 0, true);
    if (!hasValue) run(float, 0, false); // 값이 있으면 라벨은 위에 머문다
    onBlur?.(e);
  }

  // 값이 채워진 채로 마운트된 경우(자동완성 등) 라벨을 올려둔다
  if (hasValue && !focused) float.setValue(1);

  const labelStyle = {
    top: float.interpolate({ inputRange: [0, 1], outputRange: [theme.space(3.5), 0] }),
    fontSize: float.interpolate({ inputRange: [0, 1], outputRange: [16, 11.5] }),
  };

  return (
    <View style={s.wrap}>
      <Animated.Text
        style={[s.label, labelStyle, focused && s.labelFocused]}
        // 라벨은 장식 — 입력 자체가 접근성 이름을 갖는다
        accessibilityElementsHidden
        importantForAccessibility="no"
      >
        {label}
      </Animated.Text>
      <TextInput
        {...props}
        value={value}
        accessibilityLabel={label}
        onFocus={handleFocus}
        onBlur={handleBlur}
        style={[s.input, NO_OUTLINE, style]}
      />
      <View style={s.line} />
      <Animated.View style={[s.lineActive, { transform: [{ scaleX: grow }] }]} />
    </View>
  );
}

const s = StyleSheet.create({
  wrap: { marginBottom: theme.space(5), paddingTop: theme.space(4) },
  label: { position: 'absolute', left: theme.space(0.5), color: theme.color.inkSoft, fontWeight: '500' },
  labelFocused: { color: theme.color.accent },
  input: {
    paddingVertical: theme.space(2.5),
    paddingHorizontal: theme.space(0.5),
    fontSize: 16,
    color: theme.color.ink,
    borderWidth: 0,
  },
  line: { height: 1, backgroundColor: theme.color.hairline },
  lineActive: { position: 'absolute', left: 0, right: 0, bottom: 0, height: 2, backgroundColor: theme.color.accent },
});
