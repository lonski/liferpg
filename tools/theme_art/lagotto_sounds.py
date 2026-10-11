"""Cuts the Lagotto theme's sound clips into assets/lagotto/sounds/.

Run from the repo root (needs FFmpeg through PyAV):

    python3 -m venv /tmp/av && /tmp/av/bin/pip install av numpy
    /tmp/av/bin/python tools/theme_art/lagotto_sounds.py

Sources (Wikimedia Commons; public domain or CC0, so no attribution is
required -- credited here anyway). Only recordings of real dogs: never a
pronunciation file ("Dog in Antefasy", "Bark (avk)" are people saying a
word), and not "Dog.ogg" either, whose shaking and paw-licking can't be
told apart without listening.

- "Voice Test Error.wav" (dogs barking) -- by Kineticsquid, CC0. The
  recording repeats itself after 9.6 s; clips come from the first pass.
- "Puppy at a night.ogg" (a crying puppy) -- by Knites, CC0.
- "Jem howls.ogg" (a chihuahua howling) -- by amethysta, public domain.
"""
import os
import urllib.parse
import urllib.request

import av
import numpy as np

OUT = 'assets/lagotto/sounds'
RATE = 44100
COMMONS = 'https://commons.wikimedia.org/wiki/Special:FilePath/'
SOURCES = {
    'barks': 'Voice Test Error.wav',
    'puppy': 'Puppy at a night.ogg',
    'howl': 'Jem howls.ogg',
}


def fetch(title):
    url = COMMONS + urllib.parse.quote(title)
    req = urllib.request.Request(url, headers={'User-Agent': 'liferpg theme_art'})
    path = os.path.join('/tmp', 'lagotto_' + title.replace(' ', '_'))
    if not os.path.exists(path):
        with urllib.request.urlopen(req) as r:
            open(path, 'wb').write(r.read())
    return path


def decode(path):
    with av.open(path) as c:
        stream = next(s for s in c.streams if s.type == 'audio')
        res = av.AudioResampler(format='flt', layout='mono', rate=RATE)
        chunks = [f.to_ndarray().reshape(-1) for fr in c.decode(stream) for f in res.resample(fr)]
        return np.concatenate(chunks).astype(np.float32)


def fade(x, ms=15):
    n = int(RATE * ms / 1000)
    ramp = np.linspace(0, 1, n, dtype=np.float32)
    x = x.copy()
    x[:n] *= ramp
    x[-n:] *= ramp[::-1]
    return x


def normalize(x, peak_db):
    return (x / (np.abs(x).max() + 1e-9) * 10 ** (peak_db / 20)).astype(np.float32)


def encode(x, name):
    path = os.path.join(OUT, name + '.m4a')
    with av.open(path, 'w', format='mp4') as c:
        s = c.add_stream('aac', rate=RATE, layout='mono')
        s.bit_rate = 64000
        for i in range(0, len(x), 1024):
            frame = av.AudioFrame.from_ndarray(x[None, i:i + 1024], format='flt', layout='mono')
            frame.rate = RATE
            for p in s.encode(frame):
                c.mux(p)
        for p in s.encode(None):
            c.mux(p)
    print(f'{name}: {len(x) / RATE:.2f}s {os.path.getsize(path)} B')


def main():
    os.makedirs(OUT, exist_ok=True)
    src = {k: decode(fetch(t)) for k, t in SOURCES.items()}

    def cut(key, a, b):
        return src[key][int(a * RATE):int(b * RATE)]

    clips = {
        # name: (samples, peak dB) -- spans found by RMS onset analysis.
        # A grown dog: single "hau"s and short runs.
        'bark_1': (cut('barks', 2.52, 2.92), -3),
        'bark_2': (cut('barks', 3.68, 4.00), -3),
        'bark_3': (cut('barks', 1.08, 1.65), -3),
        'bark_4': (cut('barks', 6.23, 7.10), -3),
        'bark_5': (cut('barks', 8.27, 8.62), -3),
        # A puppy: short high yips and whines.
        'puppy_1': (cut('puppy', 22.18, 22.52), -4),
        'puppy_2': (cut('puppy', 25.22, 25.62), -4),
        'puppy_3': (cut('puppy', 37.30, 37.68), -4),
        'puppy_4': (cut('puppy', 26.40, 26.88), -4),
        # The dog asleep on the card: a soft whimper, as dogs do dreaming.
        'sleepy': (cut('puppy', 34.20, 35.10), -16),
        # The golden truffle dug up: a howl of triumph.
        'howl': (cut('howl', 0.05, 1.22), -4),
    }
    for name, (x, peak) in clips.items():
        encode(fade(normalize(x, peak)), name)


if __name__ == '__main__':
    main()
