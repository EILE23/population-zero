import { useEffect, useState } from 'react';
import { prepareAds, subscribeAdPrivacy } from '@/ads';
import { Platform, StyleSheet, Text, View } from 'react-native';
import { BannerAd, BannerAdSize, TestIds } from 'react-native-google-mobile-ads';
import { theme } from '@/theme';

// Preview builds use test ads; production uses the platform-specific AdMob unit.
const UNIT_ID = (__DEV__ || process.env.EXPO_PUBLIC_ADMOB_TEST === '1')
  ? TestIds.ADAPTIVE_BANNER
  : (Platform.select({
      ios: process.env.EXPO_PUBLIC_ADMOB_IOS_FEED ?? 'ca-app-pub-8000384176395236/9666245172',
      android: process.env.EXPO_PUBLIC_ADMOB_ANDROID_FEED ?? 'ca-app-pub-8000384176395236/6312965700',
    }) ?? null);

export function AdSlot() {
  // 광고가 안 채워지는 일은 흔하다 — 그때는 빈 줄을 남기지 않고 칸 자체를 지운다
  const [revision, setRevision] = useState(0);
  const [failed, setFailed] = useState(false);
  const [ready, setReady] = useState(false);
  useEffect(() => subscribeAdPrivacy(() => { setReady(false); setFailed(false); setRevision(n => n + 1); }), []);
  useEffect(() => {
    let alive = true;
    if (UNIT_ID) void prepareAds().then(ok => { if (alive) setReady(ok); });
    return () => { alive = false; };
  }, [revision]);
  if (failed || !ready || !UNIT_ID) return null;

  return (
    <View style={s.slot}>
      <Text style={s.label}>SPONSORED</Text>
      <BannerAd
        key={revision}
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
