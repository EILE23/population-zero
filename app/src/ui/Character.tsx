import { memo, useEffect, useMemo, useState } from 'react';
import { AccessibilityInfo, Animated, AppState, Easing, Image, StyleSheet, type ImageSourcePropType } from 'react-native';

export type CharacterName = 'iris' | 'bracket' | 'cache' | 'null';
export type CharacterPose = 'base' | 'alternate';
// 기본·추가 포즈 PNG 8종이 assets/characters에 포함되어 있다.
// Metro가 모든 오프라인 리소스를 찾을 수 있도록 require 경로를 명시한다.
const sources: Record<CharacterName, Record<CharacterPose, ImageSourcePropType>> = {
  iris: { base: require('../../assets/characters/iris.png'), alternate: require('../../assets/characters/iris-welcome.png') },
  bracket: { base: require('../../assets/characters/bracket.png'), alternate: require('../../assets/characters/bracket-thinking.png') },
  cache: { base: require('../../assets/characters/cache.png'), alternate: require('../../assets/characters/cache-receipt.png') },
  null: { base: require('../../assets/characters/null.png'), alternate: require('../../assets/characters/null-sleeping.png') },
};

/** A short, UI-thread cutout gesture. Reduced motion and backgrounding stop it. */
export const Character = memo(function Character({ name, pose = 'base', size = 128, animate = true }: {
  name: CharacterName; pose?: CharacterPose; size?: number; animate?: boolean;
}) {
  const progress = useMemo(() => new Animated.Value(0), []);
  const [reduced, setReduced] = useState(true);
  const [loaded, setLoaded] = useState(false);
  useEffect(() => {
    let alive = true;
    void AccessibilityInfo.isReduceMotionEnabled().then(value => { if (alive) setReduced(value); }).catch(() => {});
    const subscription = AccessibilityInfo.addEventListener('reduceMotionChanged', setReduced);
    return () => { alive = false; subscription.remove(); };
  }, []);
  useEffect(() => {
    progress.setValue(0);
    if (reduced || !animate || !loaded || AppState.currentState === 'background' || AppState.currentState === 'inactive') return;
    const animation = Animated.timing(progress, {
      toValue: 1, duration: name === 'null' ? 3200 : 2400,
      easing: Easing.linear, useNativeDriver: true, isInteraction: false,
    });
    animation.start();
    const subscription = AppState.addEventListener('change', state => {
      if (state !== 'active') { animation.stop(); progress.setValue(0); }
    });
    return () => { animation.stop(); subscription.remove(); };
  }, [animate, loaded, name, pose, progress, reduced]);
  const rotate = progress.interpolate({
    inputRange: [0, 0.25, 0.5, 0.75, 1],
    outputRange: name === 'iris' ? ['0deg', '-3deg', '2deg', '-1deg', '0deg']
      : name === 'bracket' ? ['0deg', '1deg', '2.5deg', '1deg', '0deg'] : ['0deg', '0deg', '0deg', '0deg', '0deg'],
  });
  const translateY = progress.interpolate({ inputRange: [0, 0.4, 0.65, 1], outputRange: name === 'cache' ? [0, -4, -2, 0] : [0, 0, 0, 0] });
  const scaleY = progress.interpolate({ inputRange: [0, 0.5, 1], outputRange: name === 'null' ? [1, 1.025, 1] : [1, 1, 1] });
  return (
    <Animated.View accessible={false} accessibilityElementsHidden importantForAccessibility="no-hide-descendants"
      pointerEvents="none" style={{ width: size, height: size, transform: [{ rotate }, { translateY }, { scaleY }] }}>
      <Image source={sources[name][pose]} style={s.image} resizeMode="contain" onLoad={() => setLoaded(true)} />
    </Animated.View>
  );
});
const s = StyleSheet.create({ image: { width: '100%', height: '100%' } });
