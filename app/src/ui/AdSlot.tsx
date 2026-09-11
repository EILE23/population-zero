import { StyleSheet, Text, View } from 'react-native';
import { theme } from '@/theme';

/**
 * 피드 사이를 지나가는 광고 자리.
 *
 * 웹 피드 광고와 같은 성격이어야 한다 — 화면에 붙어 계속 보이는 배너가 아니라,
 * 스크롤에 실려 지나가는 한 칸. 그래서 탭바에 붙이지 않고 목록 항목으로 넣는다.
 *
 * 아직 실제 광고는 나오지 않는다: AdMob(react-native-google-mobile-ads)은 네이티브 모듈이라
 * Expo Go·웹 미리보기에서 돌지 않고, 개발 빌드(EAS)부터 붙는다. 그 전까지 이 칸은 비어 있고,
 * 자리만 잡아 두어 레이아웃이 나중에 흔들리지 않게 한다.
 * 빈 상자를 그려 두지 않는 이유: 없는 광고를 있는 것처럼 보이게 하지 않으려고.
 */
export function AdSlot({ debug = false }: { debug?: boolean }) {
  if (!debug) return null;
  return (
    <View style={s.slot}>
      <Text style={s.label}>AD SLOT</Text>
    </View>
  );
}

const s = StyleSheet.create({
  slot: {
    height: 250,
    borderRadius: theme.radius.lg,
    borderWidth: 1,
    borderColor: theme.color.hairline,
    borderStyle: 'dashed',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: theme.space(3),
  },
  label: { fontSize: 10, letterSpacing: 1.4, fontWeight: '800', color: theme.color.inkFaint },
});
