import { Fragment, type ReactNode } from 'react';
import { Alert, Image, Linking, ScrollView, StyleSheet, Text, View } from 'react-native';
import { marked, type Token } from 'marked';
import { theme } from '@/theme';

function safeUrl(raw: string): string | null {
  try { const url = new URL(raw, 'https://population.town'); return ['https:', 'http:'].includes(url.protocol) ? url.href : null; }
  catch { return null; }
}
function inline(tokens: Token[] = []): ReactNode[] {
  return tokens.map((token, key) => {
    if (token.type === 'br') return '\n';
    if (token.type === 'html') return null;
    if (token.type === 'link') {
      const href = safeUrl(token.href);
      return <Text key={key} accessibilityRole="link" style={s.link} onPress={href ? () => void Linking.openURL(href).catch(() => Alert.alert('Could not open link')) : undefined}>{inline(token.tokens)}</Text>;
    }
    if (token.type === 'image') {
      const uri = safeUrl(token.href);
      return uri ? <Image key={key} accessibilityLabel={token.text} source={{ uri }} style={s.image} resizeMode="contain" /> : null;
    }
    const text = 'tokens' in token && token.tokens ? inline(token.tokens) : ('text' in token ? token.text : token.raw);
    return <Text key={key} style={token.type === 'strong' ? s.bold : token.type === 'em' ? s.italic : token.type === 'codespan' ? s.code : token.type === 'del' ? s.strike : undefined}>{text}</Text>;
  });
}
function blocks(tokens: Token[] = []): ReactNode[] {
  return tokens.map((token, key) => {
    switch (token.type) {
      case 'space': case 'def': case 'html': return null;
      case 'heading': return <Text key={key} accessibilityRole="header" style={[s.p, s.bold, { fontSize: token.depth <= 2 ? 23 : 19 }]}>{inline(token.tokens)}</Text>;
      case 'code': return <ScrollView horizontal key={key}><Text selectable style={[s.p, s.code]}>{token.text}</Text></ScrollView>;
      case 'blockquote': return <View key={key} style={s.quote}>{blocks(token.tokens)}</View>;
      case 'list': return <View key={key}>{token.items.map((item: { tokens: Token[] }, index: number) => <View key={index} style={s.row}><Text style={s.p}>{token.ordered ? `${Number(token.start) + index}. ` : '• '}</Text><View style={s.flex}>{blocks(item.tokens)}</View></View>)}</View>;
      case 'table': return <ScrollView horizontal key={key}><View>{[token.header, ...token.rows].map((row: { tokens: Token[] }[], index: number) => <View key={index} style={s.row}>{row.map((cell, column) => <Text key={column} style={[s.cell, index === 0 && s.bold]}>{inline(cell.tokens)}</Text>)}</View>)}</View></ScrollView>;
      case 'hr': return <View key={key} style={s.hr} />;
      default: return <Text selectable key={key} style={s.p}>{'tokens' in token && token.tokens ? inline(token.tokens) : ('text' in token ? token.text : token.raw)}</Text>;
    }
  });
}
export function MarkdownBody({ body }: { body: string }) { return <Fragment>{blocks(marked.lexer(body, { gfm: true }))}</Fragment>; }
const s = StyleSheet.create({
  p: { fontSize: 16, lineHeight: 25, color: theme.color.ink, marginBottom: 14 },
  link: { color: theme.color.accentDeep, textDecorationLine: 'underline' }, bold: { fontWeight: '700' }, italic: { fontStyle: 'italic' }, strike: { textDecorationLine: 'line-through' },
  code: { fontFamily: 'monospace', backgroundColor: theme.color.surfaceDeep, padding: 8 },
  image: { width: 280, height: 220 }, quote: { borderLeftWidth: 3, borderLeftColor: theme.color.hairline, paddingLeft: 12 },
  row: { flexDirection: 'row' }, flex: { flex: 1 }, cell: { width: 160, padding: 8, color: theme.color.ink, borderWidth: 1, borderColor: theme.color.hairline },
  hr: { height: 1, backgroundColor: theme.color.hairline, marginVertical: 12 },
});
