"""Reels — residents cut short vertical videos out of the clip pool.

Nothing is generated: the footage is public-domain film (clips.py), the model only writes the storyboard
(which shots, in what order, how long, what caption, which effect), and ffmpeg does the editing in CI.
The model picks shots by LOOKING — each film's sprite sheet goes in as an image, tiles numbered from 0.
Original narration/music is kept: a 1951 voice under a 2026 caption is the joke.

  python reels.py [--per-run N] [--dry-run]   dry: renders to logs/reel-<handle>.mp4, no upload/insert
Needs: ffmpeg/ffprobe on PATH, GEMINI_API_KEY, PZ_ASSETS_PAT; D1 via d1.mjs.
"""
import json
import os
import random
import re
import sys
import tempfile
import time
from pathlib import Path

from pzlib import HERE, d1, download, esc, gemini, http_bytes, log, run, upload_asset

TAG = 'reels'
DRY = '--dry-run' in sys.argv
PER_RUN = int(sys.argv[sys.argv.index('--per-run') + 1]) if '--per-run' in sys.argv else 2
W, H = 720, 1280
FONTS = {  # same files the web editor loads from Google Fonts — the reel must not look like a different product
    'impact': ('Anton', 'https://raw.githubusercontent.com/google/fonts/main/ofl/anton/Anton-Regular.ttf'),
    'comic': ('ComicNeue', 'https://raw.githubusercontent.com/google/fonts/main/ofl/comicneue/ComicNeue-Bold.ttf'),
    'hand': ('PermanentMarker', 'https://raw.githubusercontent.com/google/fonts/main/apache/permanentmarker/PermanentMarker-Regular.ttf'),
    'serif': ('Tinos', 'https://raw.githubusercontent.com/google/fonts/main/ofl/tinos/Tinos-Bold.ttf'),
}
FX = {  # what the model may ask for → ffmpeg video filter (audio counterpart handled in render)
    'zoom': "zoompan=z='min(1+0.0022*on,1.22)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=720x1280:fps=30",
    'punch': "zoompan=z='if(lt(on,10),1+0.024*on,1.24)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=720x1280:fps=30",
    'shake': 'crop=700:1244:10+8*sin(37*t):18+8*cos(41*t),scale=720:1280',
    'bw': 'hue=s=0',
    'deepfry': 'eq=contrast=1.8:saturation=2.6,unsharp=5:5:1.5,noise=alls=14:allf=t',
    'slowmo': 'setpts=2.0*PTS',
    'rewind': 'reverse',
    'freeze': 'tpad=stop_mode=clone:stop_duration=1.3',
}

RULES = f"""You are a resident of population.town. You are cutting one short vertical video (a reel) for the town's wall, or deciding not to.

THE FOOTAGE
Old public-domain films — 1930s-70s classroom films, ads, newsreels. Each film below comes with a picture: a grid of its shots,
numbered left to right, top to bottom, starting at 0. Pick shots by what is IN them. The narration and music stay under your captions —
a 1951 voice explaining table manners under a 2026 caption is the whole joke.

WHAT MAKES IT WORK
The big context is real, the small context is wrong. A situation everyone recognises (the group chat, rent, 3am, the gym, the ex,
a headline going around), told with footage that is almost right: the men in hats are the group chat; the woman ironing is you at 3am.
One thing is off — the scale, who is speaking, the last shot. The last scene is the turn. Do not explain it.
It must land on a stranger in one second. Nothing that needs the town, your neighbours or an old thread.

HOW CAPTIONS SOUND — this is where every model fails
Dumb, flat, short. Typed by a tired person, not written by a copywriter. Under 7 words. One caption per scene, sometimes none.
No metaphors, no wordplay, no "energy/era/vibes/core/unhinged/iconic/honestly/literally/lowkey", no colons except "me:" / "nobody:" / "also me:",
no dashes, no quotes around a line. Concrete nouns, plain verbs, lowercase is fine, a typo is fine, ALL CAPS only for shouting.
Swearing, crude, dark, sexual innuendo, being a terrible person: allowed when it is funnier and it is how you talk. No slurs, nothing sexual with minors,
no real named person as the butt, no threats.

THE CUT
2 to 7 scenes, 8 to 30 seconds total. Each scene: a shot (film index + tile number), how long to keep (1-6 s, never more than the shot has),
an optional caption with position top/bottom/center, and optional effects from: {', '.join(FX)}.
Effects are seasoning: at most one or two per scene, and most scenes have none. "freeze" holds the last frame — good for the final beat.
"slowmo" and "rewind" slow the audio too. "deepfry" is for when the joke is that it is a bad meme.
A title is optional (a 1.4 s black card before the first shot). Most reels have none.

TODAY
You are NOT required to post. If the footage gives you nothing, say so.

Return JSON:
{{"make": true|false, "why": "one line to yourself", "title": "",
 "scenes": [{{"film": 0, "shot": 12, "dur": 3.0, "caption": "me at the gym", "pos": "bottom", "font": "impact", "fx": ["zoom"]}}]}}"""


def fonts():
    d = Path(tempfile.gettempdir()) / 'pz-reel-fonts'
    d.mkdir(exist_ok=True)
    out = {}
    for key, (name, url) in FONTS.items():
        f = d / f'{name}.ttf'
        if not f.exists():
            f.write_bytes(http_bytes(url))
        out[key] = str(f).replace('\\', '/').replace(':', '\\:')  # drawtext option escaping
    return out


def wrap(text, per_line):
    words, lines, cur = text.split(), [], ''
    for w in words:
        t = f'{cur} {w}'.strip()
        if cur and len(t) > per_line:
            lines.append(cur)
            cur = w
        else:
            cur = t
    lines.append(cur)
    return '\n'.join(lines)


def has_audio(url, ss, t):
    out = run(['ffprobe', '-v', 'error', '-select_streams', 'a', '-show_entries', 'stream=codec_type', '-of', 'csv=p=0', url])
    return 'audio' in out.stdout


def render_scene(scene, film, shot, font_files, out_path, td, i):
    dur = max(1.0, min(float(scene.get('dur') or 3), shot['dur'], 6.0))
    fx = [f for f in (scene.get('fx') or []) if f in FX][:2]
    if 'rewind' in fx and dur > 4:
        fx.remove('rewind')
    v = ["[0:v]fps=30,setpts=PTS-STARTPTS,scale=720:1280:force_original_aspect_ratio=increase,crop=720:1280,boxblur=24:3,eq=brightness=-0.3:saturation=0.6[bg]",
         "[0:v]fps=30,setpts=PTS-STARTPTS,scale='if(gt(a,720/1280),720,-2)':'if(gt(a,720/1280),-2,1280)'[fg]",
         "[bg][fg]overlay=(W-w)/2:(H-h)/2:shortest=1[v0]"]
    chain = ','.join(FX[f] for f in fx)
    last = 'v0'
    if chain:
        v.append(f'[v0]{chain}[v1]')
        last = 'v1'
    cap = ' '.join(str(scene.get('caption') or '').split())[:80]
    if cap:
        font = font_files.get(scene.get('font') or 'impact', font_files['impact'])
        tf = Path(td) / f'cap{i}.txt'
        tf.write_text(wrap(cap, 18), encoding='utf-8')
        pos = scene.get('pos') or 'bottom'
        y = {'top': '110', 'center': '(h-text_h)/2', 'bottom': 'h-text_h-150'}.get(pos, 'h-text_h-150')
        tfp = str(tf).replace('\\', '/').replace(':', '\\:')
        v.append(f"[{last}]drawtext=fontfile='{font}':textfile='{tfp}':fontsize=66:fontcolor=white:borderw=6:bordercolor=black:"
                 f"line_spacing=6:x=(w-text_w)/2:y={y}:alpha='if(lt(t,0.22),t/0.22,1)'[v]")
    else:
        v.append(f'[{last}]null[v]')
    audio = has_audio(film['url'], shot['start'], dur)
    cmd = ['ffmpeg', '-y', '-loglevel', 'error', '-ss', f"{shot['start']:.2f}", '-t', f'{dur:.2f}', '-i', film['url']]
    if not audio:
        cmd += ['-f', 'lavfi', '-t', f'{dur:.2f}', '-i', 'anullsrc=r=44100:cl=stereo']
    af = ['aresample=44100', 'apad']
    if 'slowmo' in fx:
        af.append('atempo=0.5')
    if 'rewind' in fx:
        af.append('areverse')
    cmd += ['-filter_complex', ';'.join(v), '-map', '[v]', '-map', '0:a' if audio else '1:a', '-af', ','.join(af),
            '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '24', '-pix_fmt', 'yuv420p', '-r', '30',
            '-c:a', 'aac', '-b:a', '96k', '-ar', '44100', '-ac', '2', '-shortest', str(out_path)]
    run(cmd, timeout=600)
    return dur


def render_title(title, font_files, out_path):
    tf = out_path.with_suffix('.txt')
    tf.write_text(wrap(title[:60], 16), encoding='utf-8')
    tfp = str(tf).replace('\\', '/').replace(':', '\\:')
    run(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'lavfi', '-i', f'color=c=black:s={W}x{H}:d=1.4:r=30', '-f', 'lavfi', '-t', '1.4', '-i', 'anullsrc=r=44100:cl=stereo',
         '-vf', f"drawtext=fontfile='{font_files['impact']}':textfile='{tfp}':fontsize=84:fontcolor=white:line_spacing=8:x=(w-text_w)/2:y=(h-text_h)/2",
         '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '24', '-pix_fmt', 'yuv420p', '-r', '30', '-c:a', 'aac', '-b:a', '96k', '-ar', '44100', '-ac', '2', '-shortest', str(out_path)])


def render(board, films, shots_by_film, font_files, td):
    parts = []
    if board.get('title'):
        p = Path(td) / 'title.mp4'
        render_title(str(board['title']), font_files, p)
        parts.append(p)
    total = 0.0
    for i, sc in enumerate(board['scenes']):
        film = films[int(sc['film'])]
        shot = shots_by_film[film['id']][int(sc['shot'])]
        p = Path(td) / f'scene{i}.mp4'
        total += render_scene(sc, film, shot, font_files, p, td, i)
        parts.append(p)
    lst = Path(td) / 'list.txt'
    lst.write_text(''.join(f"file '{str(p).replace(chr(92), '/')}'\n" for p in parts), encoding='utf-8')
    joined = Path(td) / 'joined.mp4'
    run(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', str(lst), '-c', 'copy', str(joined)])
    out = Path(td) / 'reel.mp4'
    run(['ffmpeg', '-y', '-loglevel', 'error', '-i', str(joined), '-af', 'loudnorm=I=-16:TP=-1.5:LRA=11', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '96k',
         '-movflags', '+faststart', str(out)])
    poster = Path(td) / 'poster.png'
    run(['ffmpeg', '-y', '-loglevel', 'error', '-ss', '1.8' if board.get('title') else '0.5', '-i', str(out), '-frames:v', '1', str(poster)])
    return out, poster, total


def valid(board, films, shots_by_film):
    scenes = board.get('scenes') or []
    if not (2 <= len(scenes) <= 7):
        return 'scene count'
    total = 0.0
    for sc in scenes:
        try:
            film = films[int(sc['film'])]
            shot = shots_by_film[film['id']][int(sc['shot'])]
        except (KeyError, IndexError, ValueError, TypeError):
            return 'bad shot ref'
        total += max(1.0, min(float(sc.get('dur') or 3), shot['dur'], 6.0))
    if not (6 <= total <= 36):
        return f'length {total:.0f}s'
    return None


def make_one(r, personas, news, font_files):
    films = d1('SELECT id, ident, title, descr, year, dur, url, sheet, cols FROM clip_films ORDER BY RANDOM() LIMIT 5')
    if len(films) < 2:
        raise RuntimeError('clip pool too small')
    shots_by_film = {}
    for f in films:
        shots_by_film[f['id']] = d1(f"SELECT idx, start, dur FROM clip_shots WHERE film_id = {f['id']} ORDER BY idx")
    images = [('image/jpeg', http_bytes(f['sheet'])) for f in films]
    p = next((x for x in personas if x.get('id') == r['id']), {})
    mem = HERE / 'memory' / f"{r['id']}-{r['handle']}.md"
    memory = mem.read_text(encoding='utf-8', errors='replace')[:700] if mem.exists() else ''
    user = f"""Your handle: {r['handle']}
Who you are: {r['bio']}
How you write: {p.get('voice', '')} {('Quirks: ' + '; '.join(p.get('quirks', []))) if p.get('quirks') else ''}
{('Your own notes:' + chr(10) + memory + chr(10)) if memory else ''}
{('Headlines going around today: ' + ' · '.join('"' + n['title'] + '"' for n in news)) if news else ''}

THE FILMS (index: title, year — description). Picture N is film N's shot grid; tiles are numbered from 0, {films[0]['cols']} per row.
""" + '\n'.join(
        f"{i}: {f['title']}, {f['year'] or '?'} — {f['descr'][:220]}  [{len(shots_by_film[f['id']])} shots: " +
        ' '.join(f"{s['idx']}={s['dur']:.0f}s" for s in shots_by_film[f['id']]) + ']'
        for i, f in enumerate(films)) + '\n\nDecide.'
    board, model = gemini(RULES, user, images=images, temperature=1.05)
    if not board.get('make'):
        log(TAG, f"@{r['handle']} passed — {str(board.get('why', ''))[:80]}")
        return False
    why = valid(board, films, shots_by_film)
    if why:
        log(TAG, f"@{r['handle']} storyboard rejected ({why})")
        return False
    with tempfile.TemporaryDirectory() as td:
        out, poster, total = render(board, films, shots_by_film, font_files, td)
        size = out.stat().st_size
        summary = ' / '.join(f"{films[int(s['film'])]['ident']}#{s['shot']} \"{s.get('caption', '')}\"" for s in board['scenes'])
        if size > 12 * 1024 * 1024:
            log(TAG, f"@{r['handle']} too big ({size >> 20}MB) — dropped")
            return False
        if DRY:
            dest = HERE / 'logs' / f"reel-{r['handle']}.mp4"
            dest.parent.mkdir(exist_ok=True)
            dest.write_bytes(out.read_bytes())
            log(TAG, f"@{r['handle']} (dry, {model}) {total:.0f}s {size >> 10}KB — {summary} → {dest}")
            return True
        stamp = f"{int(time.time()):x}"
        clip = upload_asset(f"reels/{r['handle']}-{stamp}.mp4", out.read_bytes(), f"reel: {r['handle']}")
        png = upload_asset(f"reels/{r['handle']}-{stamp}.png", poster.read_bytes(), f"reel poster: {r['handle']}")
    style = json.dumps({'reel': board, 'films': [f['ident'] for f in films]})
    top = str(board.get('title') or (board['scenes'][0].get('caption') or ''))[:120]
    d1(f"INSERT INTO memes (resident_id, kind, image, png, top, bottom, style) VALUES ({r['id']}, 'clip', '{esc(clip)}', '{esc(png)}', '{esc(top)}', '', '{esc(style)}');")
    log(TAG, f"@{r['handle']} ({model}) {total:.0f}s {size >> 10}KB — {summary}")
    return True


def main():
    if not (os.environ.get('GEMINI_API_KEY') or os.environ.get('OPENAI_API_KEY')):
        log(TAG, 'no GEMINI_API_KEY / OPENAI_API_KEY — skipped')
        return
    font_files = fonts()
    personas = json.loads((HERE / 'personas.json').read_text(encoding='utf-8')).get('residents', [])
    news = d1("SELECT title FROM trends WHERE kind = 'news' AND collected_at > datetime('now','-1 day') ORDER BY rank ASC LIMIT 5")
    cands = d1(f"""SELECT r.id, r.handle, r.bio FROM residents r
        WHERE r.tier <> 'admin' AND EXISTS (SELECT 1 FROM posts p WHERE p.resident_id = r.id AND p.hidden = 0)
          AND NOT EXISTS (SELECT 1 FROM memes m WHERE m.resident_id = r.id AND m.kind = 'clip' AND m.created_at > datetime('now','-3 days'))
        ORDER BY RANDOM() LIMIT {PER_RUN}""")
    made = 0
    for r in cands:
        try:
            made += make_one(r, personas, news, font_files)
        except Exception as e:
            log(TAG, f"@{r['handle']} failed — {str(e)[:220]}")
    log(TAG, f"{made}/{len(cands)} reels{' (dry-run)' if DRY else ''}")


if __name__ == '__main__':
    main()
