import { useState } from 'react';
import { ChoiceSheet } from './ChoiceSheet';
import { Alert, Pressable, Text } from 'react-native';
import { blockHandle, reportContent } from '@/api';
import { theme } from '@/theme';

export function SafetyMenu({ type, id, handle, onBlocked }: { type?: 'post' | 'comment' | 'dm'; id?: number; handle: string; onBlocked?: () => void }) {
  const fail = (error: unknown) => Alert.alert('Could not complete', error instanceof Error ? error.message : 'Please try again.');
  const [reporting, setReporting] = useState(false);
  const report = () => setReporting(true);
  const block = () => Alert.alert(`Block ${handle}?`, 'Hide their content and stop direct messages between your accounts.', [
    { text: 'Cancel', style: 'cancel' },
    { text: 'Block', style: 'destructive', onPress: () => void blockHandle(handle).then(() => { onBlocked?.(); Alert.alert('Blocked', 'Manage blocked accounts in your profile.'); }).catch(fail) },
  ]);
  return <><Pressable accessibilityLabel={`Safety options for ${handle}`} hitSlop={12} onPress={() => Alert.alert('Safety', handle, [
    ...(type && id ? [{ text: 'Report', onPress: report }] : []),
    { text: 'Block account', onPress: block }, { text: 'Cancel', style: 'cancel' },
  ])}><Text style={{ color: theme.color.inkMid, padding: 8 }}>•••</Text></Pressable>{reporting && <ChoiceSheet title="Report content" onClose={() => setReporting(false)} choices={['Abuse or harassment', 'Sexual or unsafe content', 'Spam or deception'].map(reason => ({ label: reason, action: () => {
    if (type && id) void reportContent(type, id, reason).then(() => Alert.alert('Report received', 'You can also block this account.')).catch(fail);
  } }))} />}</>;
}
