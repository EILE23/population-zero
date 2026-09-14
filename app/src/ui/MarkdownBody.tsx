import { Fragment, useEffect, useState, type ReactNode } from 'react';
import { Alert, Image, Linking, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { Feather } from '@expo/vector-icons';
import { parseMarkdown, parseInline, type Block, type Inline, type ListBlock } from '@/markdown-ast';
import { theme } from '@/theme';

/**
 * 글 본문 — 웹과 **같은 파서**(markdown-ast)의 블록을 네이티브로 그린다.
 * 그래서 같은 글은 같은 구조로 보인다: 웹이 임베드하는 유튜브 줄은 여기서 썸네일 카드가 되고,
 * 웹의 한 줄바꿈은 여기서도 줄바꿈이며, 웹이 그리지 않는 표·HTML 은 여기서도 그리지 않는다.
 * (예전엔 범용 파서를 써서 이 셋이 전부 달랐다.)
 */
function open(url: string) { void Linking.openURL(url).catch(() => Alert.alert('Could not open link')); }

/** 본문 이미지 — 실제 비율로 화면 너비에 맞춘다. 재기 전엔 16:10 자리로 두어 레이아웃이 튀지 않게 */
function BodyImage({ src, alt }: { src: string; alt: string }) {
  const [ratio, setRatio] = useState(1.6);
  useEffect(() => {
    let alive = true;
    Image.getSize(src, (w, h) => { if (alive && w > 0 && h > 0) setRatio(w / h); }, () => {});
    return () => { alive = false; };
  }, [src]);
  return <Image accessibilityLabel={alt} source={{ uri: src }} style={[s.image, { aspectRatio: ratio }]} resizeMode="cover" />;
}

/** 인라인 토큰들을 Text 런과 이미지 블록으로 — 이미지는 글자 사이에 끼울 수 없으니 따로 세운다 */
function InlineRuns({ tokens, style }: { tokens: Inline[]; style?: object }) {
  const out: ReactNode[] = [];
  let run: ReactNode[] = [];
  const flush = () => { if (run.length) { out.push(<Text key={`t${out.length}`} selectable style={[s.p, style]}>{run}</Text>); run = []; } };
  tokens.forEach((tok, i) => {
    switch (tok.t) {
      case 'img': flush(); out.push(<BodyImage key={`i${i}`} src={tok.src} alt={tok.alt} />); break;
      case 'link': run.push(<Text key={i} accessibilityRole="link" style={s.link} onPress={() => open(tok.href)}>{tok.text}</Text>); break;
      case 'code': run.push(<Text key={i} style={s.codeInline}>{tok.v}</Text>); break;
      case 'strong': run.push(<Text key={i} style={s.bold}>{tok.v}</Text>); break;
      case 'em': run.push(<Text key={i} style={s.italic}>{tok.v}</Text>); break;
      default: run.push(tok.v);
    }
  });
  flush();
  return <Fragment>{out}</Fragment>;
}

function List({ node, depth = 0 }: { node: ListBlock; depth?: number }) {
  return (
    <View style={{ marginLeft: depth ? 16 : 0 }}>
      {node.items.map((it, i) => (
        <View key={i}>
          <View style={s.row}>
            <Text style={[s.p, s.bullet]}>{node.ordered ? `${i + 1}.` : '•'}</Text>
            <View style={s.flex}><InlineRuns tokens={parseInline(it.text)} /></View>
          </View>
          {it.children && <List node={it.children} depth={depth + 1} />}
        </View>
      ))}
    </View>
  );
}

function BlockView({ b }: { b: Block }) {
  switch (b.type) {
    case 'heading': return <Text accessibilityRole="header" style={[s.heading, { fontSize: [24, 20, 17][b.level - 1] }]}>{parseInline(b.text).map((t) => t.t === 'text' ? t.v : 'v' in t ? t.v : 'text' in t ? t.text : '').join('')}</Text>;
    case 'paragraph': return <InlineRuns tokens={parseInline(b.text)} />;
    case 'list': return <View style={s.block}><List node={b} /></View>;
    case 'code': return <ScrollView horizontal style={s.block}><Text selectable style={s.codeBlock}>{b.text}</Text></ScrollView>;
    case 'quote': return <View style={[s.block, s.quote]}><InlineRuns tokens={parseInline(b.text)} style={s.quoteText} /></View>;
    case 'youtube': return (
      // 웹은 iframe 임베드, 앱은 썸네일 카드 → 유튜브로 — 같은 자리, 같은 영상
      <Pressable accessibilityRole="link" onPress={() => open(`https://www.youtube.com/watch?v=${b.id}`)} style={[s.block, s.video]}>
        <Image source={{ uri: `https://i.ytimg.com/vi/${b.id}/hqdefault.jpg` }} style={s.videoThumb} resizeMode="cover" />
        <View style={s.play}><Feather name="play" size={22} color={theme.color.paper} /></View>
      </Pressable>
    );
  }
}

export function MarkdownBody({ body }: { body: string }) {
  return <Fragment>{parseMarkdown(body).map((b, i) => <BlockView key={i} b={b} />)}</Fragment>;
}

const s = StyleSheet.create({
  p: { fontSize: 16, lineHeight: 26, color: theme.color.ink, marginBottom: 14 },
  heading: { fontWeight: '800', color: theme.color.ink, marginTop: 18, marginBottom: 8, letterSpacing: -0.3 },
  block: { marginBottom: 14 },
  link: { color: theme.color.accentDeep, textDecorationLine: 'underline' },
  bold: { fontWeight: '700' },
  italic: { fontStyle: 'italic' },
  codeInline: { fontFamily: 'monospace', backgroundColor: theme.color.surfaceDeep, fontSize: 14 },
  codeBlock: { fontFamily: 'monospace', fontSize: 13, lineHeight: 20, color: theme.color.paper, backgroundColor: theme.color.inkBlack, padding: 14, borderRadius: theme.radius.md, minWidth: '100%' },
  quote: { borderLeftWidth: 2, borderLeftColor: theme.color.ink, paddingLeft: 14 },
  quoteText: { color: theme.color.inkMid },
  image: { width: '100%', borderRadius: theme.radius.md, marginBottom: 14, backgroundColor: theme.color.surfaceDeep },
  row: { flexDirection: 'row', gap: 8 },
  bullet: { width: 22, textAlign: 'right' },
  flex: { flex: 1 },
  video: { width: '100%', aspectRatio: 16 / 9, borderRadius: theme.radius.lg, overflow: 'hidden', backgroundColor: theme.color.surfaceDeep, alignItems: 'center', justifyContent: 'center' },
  videoThumb: { position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 },
  play: { width: 54, height: 54, borderRadius: 27, backgroundColor: 'rgba(0,0,0,0.55)', alignItems: 'center', justifyContent: 'center', paddingLeft: 3 },
});
