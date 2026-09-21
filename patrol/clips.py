"""Clip pool — public-domain films from the Internet Archive, cut into shots.

Nothing is generated. Prelinger (1930s-70s educational films, ads, newsreels; ~10k titles) is public domain,
has an mp4 derivative for every film and ffmpeg can read it over HTTP with range requests, so we never host video.
What we add: shot boundaries (PySceneDetect) and one sprite sheet of shot thumbnails per film, so a model
(and later the human editor) can pick shots by looking at them rather than by reading a description.

  python clips.py fetch [--films N]     add N new films (default 2) — download, detect shots, build sheet, insert
Needs: ffmpeg on PATH, pip install scenedetect[opencv] pillow; PZ_ASSETS_PAT for the sheet; D1 via d1.mjs.
"""
import io
import random
import sys
import tempfile
from pathlib import Path

from pzlib import d1, download, esc, http_bytes, http_json, log, run, upload_asset

TAG = 'clips'
COLS = 8
TILE = (240, 135)
MIN_SHOT, MAX_SHOT, MAX_SHOTS = 1.6, 12.0, 48
# Search terms that yield meme-able footage; a film is picked at random from the popular end of the results
QUERIES = ['collection:prelinger AND mediatype:movies',
           'collection:prelinger AND mediatype:movies AND (subject:etiquette OR subject:manners OR subject:dating)',
           'collection:prelinger AND mediatype:movies AND (subject:safety OR subject:accidents OR subject:driving)',
           'collection:prelinger AND mediatype:movies AND (subject:food OR subject:cooking OR subject:kitchen)',
           'collection:prelinger AND mediatype:movies AND (subject:office OR subject:work OR subject:business)',
           'collection:prelinger AND mediatype:movies AND (subject:animals OR subject:cats OR subject:dogs)',
           'collection:prelinger AND mediatype:movies AND (subject:television OR subject:computers OR subject:future)']


def candidates(n):
    have = {r['ident'] for r in d1('SELECT ident FROM clip_films')}
    out = []
    for q in random.sample(QUERIES, len(QUERIES)):
        page = random.randint(1, 6)
        d = http_json('https://archive.org/advancedsearch.php?' + '&'.join([
            f'q={q}'.replace(' ', '+'), 'fl[]=identifier', 'fl[]=title', 'fl[]=description', 'fl[]=year', 'rows=40',
            f'page={page}', 'output=json', 'sort[]=downloads+desc']))
        docs = d.get('response', {}).get('docs', [])
        random.shuffle(docs)
        for doc in docs:
            if doc['identifier'] in have or any(o['identifier'] == doc['identifier'] for o in out):
                continue
            out.append(doc)
            if len(out) >= n:
                return out
    return out


def mp4_of(ident):
    meta = http_json(f'https://archive.org/metadata/{ident}')
    files = meta.get('files', [])
    pick = None
    for want in ('512Kb MPEG4', 'h.264 IA', 'h.264', 'MPEG4'):
        for f in files:
            if f.get('format') == want and f['name'].endswith('.mp4'):
                pick = f
                break
        if pick:
            break
    if not pick:
        return None
    thumb = next((f['name'] for f in files if f.get('format') == 'Thumbnail' and f['name'].endswith('_000030.jpg')), '')
    return {'url': f"https://archive.org/download/{ident}/{pick['name']}", 'dur': float(pick.get('length') or 0),
            'thumb': f'https://archive.org/download/{ident}/{thumb}' if thumb else ''}


def detect_shots(path):
    from scenedetect import ContentDetector, detect
    scenes = detect(str(path), ContentDetector(threshold=27.0, min_scene_len=int(MIN_SHOT * 30)))
    shots = []
    for a, b in scenes:
        s, e = a.get_seconds(), b.get_seconds()
        if e - s < MIN_SHOT:
            continue
        shots.append((round(s, 2), round(min(e - s, MAX_SHOT), 2)))
    if len(shots) > MAX_SHOTS:  # keep an even spread through the film
        step = len(shots) / MAX_SHOTS
        shots = [shots[int(i * step)] for i in range(MAX_SHOTS)]
    return shots


def sheet_of(path, shots):
    from PIL import Image
    rows = (len(shots) + COLS - 1) // COLS
    sheet = Image.new('RGB', (TILE[0] * COLS, TILE[1] * rows), (0, 0, 0))
    with tempfile.TemporaryDirectory() as td:
        for i, (s, dur) in enumerate(shots):
            frame = Path(td) / f'{i}.jpg'
            run(['ffmpeg', '-y', '-loglevel', 'error', '-ss', f'{s + dur / 2:.2f}', '-i', str(path), '-frames:v', '1',
                 '-vf', f'scale={TILE[0]}:{TILE[1]}:force_original_aspect_ratio=decrease,pad={TILE[0]}:{TILE[1]}:(ow-iw)/2:(oh-ih)/2', str(frame)])
            im = Image.open(frame).convert('RGB')
            sheet.paste(im, ((i % COLS) * TILE[0], (i // COLS) * TILE[1]))
    buf = io.BytesIO()
    sheet.save(buf, 'JPEG', quality=72)
    return buf.getvalue()


def add_film(doc):
    ident = doc['identifier']
    src = mp4_of(ident)
    if not src or src['dur'] < 60:
        log(TAG, f'{ident}: no usable mp4')
        return False
    with tempfile.TemporaryDirectory() as td:
        path = Path(td) / 'film.mp4'
        download(src['url'], path)
        shots = detect_shots(path)
        if len(shots) < 6:
            log(TAG, f'{ident}: only {len(shots)} shots — skipped')
            return False
        sheet = upload_asset(f'clips/{ident}.jpg', sheet_of(path, shots), f'clip sheet: {ident}')
    descr = doc.get('description')
    if isinstance(descr, list):
        descr = ' '.join(descr)
    descr = ' '.join(str(descr or '').split())[:600]
    year = doc.get('year')
    try:
        year = int(str(year)[:4])
    except (TypeError, ValueError):
        year = 'NULL'
    d1(f"INSERT INTO clip_films (ident, title, descr, year, dur, url, thumb, sheet, cols) VALUES ('{esc(ident)}', '{esc(doc.get('title', ident))}', "
       f"'{esc(descr)}', {year}, {src['dur']}, '{esc(src['url'])}', '{esc(src['thumb'])}', '{esc(sheet)}', {COLS});")
    film_id = d1(f"SELECT id FROM clip_films WHERE ident = '{esc(ident)}'")[0]['id']
    values = ', '.join(f'({film_id}, {i}, {s}, {dur})' for i, (s, dur) in enumerate(shots))
    d1(f'INSERT INTO clip_shots (film_id, idx, start, dur) VALUES {values};')
    log(TAG, f"+ {ident} — {doc.get('title', '')[:50]} ({src['dur']:.0f}s, {len(shots)} shots)")
    return True


def main():
    n = int(sys.argv[sys.argv.index('--films') + 1]) if '--films' in sys.argv else 2
    added = 0
    for doc in candidates(n * 2):
        if added >= n:
            break
        try:
            added += add_film(doc)
        except Exception as e:  # one bad film must not stop the run
            log(TAG, f"{doc.get('identifier')}: failed — {str(e)[:200]}")
    total = d1('SELECT COUNT(*) AS n FROM clip_films')[0]['n']
    log(TAG, f'{added} added · {total} films in the pool')


if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'fetch':
        main()
    else:
        print(__doc__)
