import { useState } from 'react';
import { Platform, StyleSheet, Text, View } from 'react-native';
import { BannerAd, BannerAdSize, TestIds } from 'react-native-google-mobile-ads';
import { theme } from '@/theme';

/**
 * 피드 사이를 지나가는 광고 한 칸.
 *
 * 화면에 붙어 계속 보이는 배너가 아니라 스크롤에 실려 지나가는 항목이다 — 그래서 탭바가 아니라
 * 목록 중간에 들어간다. 웹의 피드 광고와 같은 성격.
 *
 * 광고 단위 ID 는 app.json 의 extra.admob 에서 온다. 아직 없으면 구글 공식 테스트 단위를 쓴다:
 * 실서비스 ID 없이도 개발 빌드에서 실제로 뜨는지 확인할 수 있고, 테스트 광고는 수익에 잡히지 않아
 * 계정이 정지될 위험도 없다. (자기 광고를 자기가 누르는 것이 정지 사유 1번이다.)
 */
const UNIT_ID = __DEV__
  ? TestIds.ADAPTIVE_BANNER
  : (Platform.select({
      ios: process.env.EXPO_PUBLIC_ADMOB_IOS_FEED,
      android: process.env.EXPO_PUBLIC_ADMOB_ANDROID_FEED,
    }) ?? TestIds.ADAPTIVE_BANNER);

export function AdSlot() {
  // 광고가 안 채워지는 일은 흔하다 — 그때는 빈 줄을 남기지 않고 칸 자체를 지운다
  const [failed, setFailed] = useState(false);
  if (failed) return null;

  return (
    <View style={s.slot}>
      <Text style={s.label}>SPONSORED</Text>
      <BannerAd
        unitId={UNIT_ID}
        size={BannerAdSize.MEDIUM_RECTANGLE}
        onAdFailedToLoad={() => setFailed(true)}
      />
    </View>
  );
}

const s = StyleSheet.create({
  slot: {
    alignItems: 'center',
    backgroundColor: theme.color.paper,
    borderRadius: theme.radius.lg,
    borderWidth: 1,
    borderColor: theme.color.hairline,
    paddingVertical: theme.space(3),
    marginBottom: theme.space(3),
    overflow: 'hidden',
  },
  label: {
    fontSize: 9,
    letterSpacing: 1.4,
    fontWeight: '800',
    color: theme.color.inkFaint,
    marginBottom: theme.space(2),
  },
});
