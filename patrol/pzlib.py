"""Shared helpers for the Python side of patrol (clips.py, reels.py).

D1 goes through the same door as the JS scripts (d1.mjs → wrangler in CI / your login locally), so the
allowlist, credentials and logging live in one place. Assets go to the public pz-assets repo → jsDelivr.
"""
import base64
import json
import os
import subprocess
import sys
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
CDN = 'https://cdn.jsdelivr.net/gh/EILE23/pz-assets@main/'
UA = 'pz-patrol (population.town)'


def log(tag, msg):
    print(f'[{tag}] {msg}', flush=True)


def esc(s):
    return str(s).replace("'", "''")


def d1(sql):
    """Run SQL through patrol/d1.mjs; returns rows of the first statement (list of dicts)."""
    out = subprocess.run(['node', str(HERE / 'd1.mjs'), '--remote', sql], capture_output=True, text=True, encoding='utf-8')
    if out.returncode != 0:
        raise RuntimeError(f'd1: {out.stderr.strip()[:300]}')
    txt = out.stdout.strip()
    return json.loads(txt) if txt else []


def http_json(url, headers=None, data=None, timeout=60):
    req = urllib.request.Request(url, data=data, headers={'user-agent': UA, **(headers or {})})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode('utf-8'))


def http_bytes(url, timeout=120):
    req = urllib.request.Request(url, headers={'user-agent': UA})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def download(url, dest, timeout=600):
    req = urllib.request.Request(url, headers={'user-agent': UA})
    with urllib.request.urlopen(req, timeout=timeout) as r, open(dest, 'wb') as f:
        while True:
            chunk = r.read(1 << 20)
            if not chunk:
                break
            f.write(chunk)
    return dest


def gh_token():
    tok = os.environ.get('PZ_ASSETS_PAT') or os.environ.get('GITHUB_PAT')
    if not tok:
        try:
            tok = subprocess.run(['gh', 'auth', 'token'], capture_output=True, text=True).stdout.strip()
        except Exception:
            tok = ''
    if not tok:
        raise RuntimeError('no PZ_ASSETS_PAT')
    return tok


def upload_asset(key, data: bytes, message):
    """PUT a file into EILE23/pz-assets; returns its jsDelivr URL."""
    body = json.dumps({'message': message, 'content': base64.b64encode(data).decode('ascii')}).encode('utf-8')
    req = urllib.request.Request(f'https://api.github.com/repos/EILE23/pz-assets/contents/{key}', data=body, method='PUT', headers={
        'authorization': f'Bearer {gh_token()}', 'accept': 'application/vnd.github+json', 'user-agent': UA, 'content-type': 'application/json'})
    with urllib.request.urlopen(req, timeout=120) as r:
        if r.status not in (200, 201):
            raise RuntimeError(f'github upload {r.status}')
    return CDN + key


def run(cmd, timeout=900):
    """Run a subprocess (ffmpeg etc.); raise with the tail of stderr on failure."""
    out = subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=timeout)
    if out.returncode != 0:
        raise RuntimeError(f'{cmd[0]} failed: {out.stderr.strip()[-600:]}')
    return out


def gemini_models():
    """Flash models that can generateContent, newest first (names are not pinned — they rot; the newest is also the busiest)."""
    fixed = os.environ.get('MEME_MODEL')
    if fixed and fixed != 'auto':
        return [fixed]
    d = http_json('https://generativelanguage.googleapis.com/v1beta/models?pageSize=200', headers={'x-goog-api-key': os.environ['GEMINI_API_KEY']})
    import re
    names = []
    for m in d.get('models', []):
        n = m['name'].replace('models/', '')
        if not re.match(r'^gemini-\d', n) or 'flash' not in n:
            continue
        if re.search(r'lite|8b|image|tts|live|audio|preview|exp|thinking|robotics|embedding', n):
            continue
        if 'generateContent' not in m.get('supportedGenerationMethods', []):
            continue
        ver = float(re.search(r'gemini-(\d+(?:\.\d+)?)', n).group(1))
        names.append((-ver, len(n), n))
    if not names:
        raise RuntimeError('no gemini flash model')
    return [n for _, _, n in sorted(names)][:3]


def _gemini_once(model, system, user, images, temperature):
    import time
    parts = [{'text': user}] + [{'inline_data': {'mime_type': m, 'data': base64.b64encode(b).decode('ascii')}} for m, b in images]
    body = json.dumps({
        'systemInstruction': {'parts': [{'text': system}]},
        'contents': [{'role': 'user', 'parts': parts}],
        'generationConfig': {'responseMimeType': 'application/json', 'temperature': temperature},
        'safetySettings': [{'category': c, 'threshold': 'BLOCK_ONLY_HIGH'} for c in
                           ('HARM_CATEGORY_HARASSMENT', 'HARM_CATEGORY_HATE_SPEECH', 'HARM_CATEGORY_SEXUALLY_EXPLICIT', 'HARM_CATEGORY_DANGEROUS_CONTENT')],
    }).encode('utf-8')
    # 503 = 붐빔, 429 = 이 모델의 무료 한도 소진. 두 번 쉬어 보고 안 되면 다음 모델로
    for attempt in range(3):
        req = urllib.request.Request(f'https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent', data=body, method='POST',
                                     headers={'x-goog-api-key': os.environ['GEMINI_API_KEY'], 'content-type': 'application/json', 'user-agent': UA})
        try:
            with urllib.request.urlopen(req, timeout=180) as r:
                d = json.loads(r.read().decode('utf-8'))
            break
        except urllib.error.HTTPError as e:
            if e.code in (503, 429) and attempt < 2:
                time.sleep(5 * 2 ** attempt)
                continue
            raise RuntimeError(f'gemini {model} {e.code}')
    text = ''.join(p.get('text', '') for p in d.get('candidates', [{}])[0].get('content', {}).get('parts', []))
    if not text:
        raise RuntimeError(f"gemini empty ({d.get('candidates', [{}])[0].get('finishReason')})")
    return json.loads(text)


def _openai_once(system, user, images, temperature):
    """Same call through OpenAI (gpt-5-mini reads images too) — the fallback when every Gemini model is busy or capped."""
    content = [{'type': 'text', 'text': user}] + [
        {'type': 'image_url', 'image_url': {'url': f'data:{m};base64,{base64.b64encode(b).decode("ascii")}'}} for m, b in images]
    body = json.dumps({'model': os.environ.get('OPENAI_MEME_MODEL', 'gpt-5-mini'), 'response_format': {'type': 'json_object'},
                       'messages': [{'role': 'system', 'content': system}, {'role': 'user', 'content': content}]}).encode('utf-8')
    req = urllib.request.Request('https://api.openai.com/v1/chat/completions', data=body, method='POST',
                                 headers={'authorization': f"Bearer {os.environ['OPENAI_API_KEY']}", 'content-type': 'application/json', 'user-agent': UA})
    with urllib.request.urlopen(req, timeout=240) as r:
        d = json.loads(r.read().decode('utf-8'))
    return json.loads(d['choices'][0]['message']['content'])


def gemini(system, user, images=(), temperature=1.0):
    """One JSON-mode call: Gemini flash models newest→older (free tier), then OpenAI. Returns (json, model name)."""
    errors = []
    if os.environ.get('GEMINI_API_KEY'):
        for model in gemini_models():
            try:
                return _gemini_once(model, system, user, images, temperature), model
            except Exception as e:  # busy/capped/blocked — next model
                errors.append(str(e)[:80])
    if os.environ.get('OPENAI_API_KEY'):
        try:
            return _openai_once(system, user, images, temperature), 'openai'
        except Exception as e:
            errors.append(f'openai {str(e)[:80]}')
    raise RuntimeError(' | '.join(errors) or 'no model key')


if __name__ == '__main__':
    print(d1(sys.argv[1]))
