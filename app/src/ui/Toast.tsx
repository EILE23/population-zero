import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { Animated, Easing, Pressable, StyleSheet, Text, View } from 'react-native';
import { Feather } from '@expo/vector-icons';
import { TAB_BAR_HEIGHT } from '@/ui/TabBar';
import { theme } from '@/theme';

type Tone = 'info' | 'error';
type Toast = { id: number; text: string; tone: Tone; action?: { label: string; onPress: () => void } };

type Show = (text: string, opts?: { tone?: Tone; action?: Toast['action'] }) => void;

const ToastContext = createContext<Show>(() => {});

/** 화면 어디서든 한 줄 알림을 띄운다 — `const toast = useToast()` */
export function useToast(): Show {
  return useContext(ToastContext);
}

/**
 * 아래에서 올라오는 한 줄 알림.
 *
 * 오류를 화면 한구석에 붉은 글씨로 심어 두면 스크롤 밖에 있을 때 아무도 못 본다.
 * (앨범 Share 가 왜 안 눌리는지 몰랐던 것이 정확히 그 경우였다.)
 * 그래서 알림은 늘 같은 자리 — 손가락이 있는 아래쪽 — 에서 올라오고, 할 일이 있으면 버튼을 같이 준다.
 */
export function ToastProvider({ children }: { children: ReactNode }) {
  const [toast, setToast] = useState<Toast | null>(null);
  const anim = useMemo(() => new Animated.Value(0), []);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const seq = useRef(0);

  const show = useCallback<Show>((text, opts) => {
    seq.current += 1;
    setToast({ id: seq.current, text, tone: opts?.tone ?? 'error', action: opts?.action });
  }, []);

  useEffect(() => {
    if (!toast) return;
    if (timer.current) clearTimeout(timer.current);
    Animated.timing(anim, { toValue: 1, duration: 240, easing: Easing.out(Easing.cubic), useNativeDriver: true }).start();
    // 할 일이 붙은 알림은 조금 더 머문다 — 읽고 누를 시간이 필요하다
    timer.current = setTimeout(() => {
      Animated.timing(anim, { toValue: 0, duration: 200, easing: Easing.in(Easing.cubic), useNativeDriver: true })
        .start(({ finished }) => { if (finished) setToast(null); });
    }, toast.action ? 6000 : 3200);
    return () => { if (timer.current) clearTimeout(timer.current); };
  }, [anim, toast]);

  const rise = anim.interpolate({ inputRange: [0, 1], outputRange: [80, 0] });

  return (
    <ToastContext.Provider value={show}>
      {children}
      {toast ? (
        <Animated.View
          style={[s.wrap, { opacity: anim, transform: [{ translateY: rise }] }]}
          pointerEvents="box-none"
        >
          <View style={[s.bar, toast.tone === 'error' && s.barError]}>
            <Feather
              name={toast.tone === 'error' ? 'alert-circle' : 'check-circle'}
              size={16}
              color={theme.color.paper}
            />
            <Text style={s.text} numberOfLines={2}>{toast.text}</Text>
            {toast.action ? (
              <Pressable
                onPress={() => { toast.action?.onPress(); setToast(null); }}
                hitSlop={8}
                style={s.action}
              >
                <Text style={s.actionText}>{toast.action.label}</Text>
              </Pressable>
            ) : null}
          </View>
        </Animated.View>
      ) : null}
    </ToastContext.Provider>
  );
}

const s = StyleSheet.create({
  wrap: {
    position: 'absolute',
    left: theme.space(4),
    right: theme.space(4),
    bottom: TAB_BAR_HEIGHT + theme.space(2),
  },
  bar: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: theme.space(3),
    backgroundColor: theme.color.inkBlack,
    borderRadius: theme.radius.lg,
    paddingHorizontal: theme.space(4),
    paddingVertical: theme.space(3.5),
    shadowColor: theme.color.inkBlack,
    shadowOpacity: 0.3,
    shadowRadius: 18,
    shadowOffset: { width: 0, height: 8 },
    elevation: 14,
  },
  barError: { backgroundColor: theme.color.accentDeep },
  text: { flex: 1, color: theme.color.paper, fontSize: 13.5, lineHeight: 19, fontWeight: '600' },
  action: { paddingHorizontal: theme.space(1) },
  actionText: { color: theme.color.paper, fontSize: 13, fontWeight: '800', textDecorationLine: 'underline' },
});
