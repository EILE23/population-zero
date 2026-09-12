import { Modal, Pressable, ScrollView, Text, View } from 'react-native';
import { theme } from '@/theme';

export function ChoiceSheet({ title, choices, onClose }: {
  title: string; choices: { label: string; action: () => void }[]; onClose: () => void;
}) {
  return <Modal transparent animationType="fade" onRequestClose={onClose}>
    <View style={{ flex: 1, justifyContent: 'center', padding: 24, backgroundColor: '#0008' }}>
      <View accessibilityViewIsModal style={{ backgroundColor: theme.color.paper, borderRadius: 18, padding: 20, maxHeight: '80%' }}>
        <Text style={{ fontSize: 18, fontWeight: '700', color: theme.color.ink, marginBottom: 12 }}>{title}</Text>
        <ScrollView>{choices.map(choice => <Pressable key={choice.label} accessibilityRole="button" onPress={() => { onClose(); choice.action(); }} style={{ paddingVertical: 16 }}>
          <Text style={{ color: theme.color.ink }}>{choice.label}</Text>
        </Pressable>)}</ScrollView>
        <Pressable accessibilityRole="button" onPress={onClose} style={{ paddingVertical: 16 }}><Text style={{ color: theme.color.ink }}>Cancel</Text></Pressable>
      </View>
    </View>
  </Modal>;
}
