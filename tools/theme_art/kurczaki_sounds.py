"""Cuts the Kurczaki theme's sound clips into assets/kurczaki/sounds/.

Run from the repo root (needs FFmpeg through PyAV):

    python3 -m venv /tmp/av && /tmp/av/bin/pip install av numpy
    /tmp/av/bin/python tools/theme_art/kurczaki_sounds.py

Sources (Wikimedia Commons; public domain or CC0, so no attribution is
required -- credited here anyway):

- "Medium rooster crowing.ogg", "Small rooster crowing.ogg",
  "Hen announcing shes lain an egg.ogg" -- by alys, public domain.
- "Chicken in Vezo.ogg" -- by Gasybeaugosse2020, CC0.
- "মুরগির বাচ্চার ডাক.oga" (chick calls) -- by Md. Tahmid Hossain, CC0.
"""
import os
import urllib.parse
import urllib.request

import av
import numpy as np

OUT = 'assets/kurczaki/sounds'
RATE = 44100
COMMONS = 'https://commons.wikimedia.org/wiki/Special:FilePath/'
SOURCES = {
    'rooster': 'Medium rooster crowing.ogg',
    'rooster_small': 'Small rooster crowing.ogg',
    'hen_egg': 'Hen announcing shes lain an egg.ogg',
    'hen_vezo': 'Chicken in Vezo.ogg',
    'chicks': 'মুরগির বাচ্চার ডাক.oga',
}


def fetch(title):
    url = COMMONS + urllib.parse.quote(title)
    req = urllib.request.Request(url, headers={'User-Agent': 'liferpg theme_art'})
    path = os.path.join('/tmp', 'kurczaki_' + title.replace(' ', '_'))
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


def highpass(x, cutoff):
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / RATE)
    ramp = np.clip((freqs - cutoff * 0.7) / (cutoff * 0.3), 0, 1)
    return np.fft.irfft(spec * ramp, len(x)).astype(np.float32)


def gate(x, floor_db=-30):
    """Pulls the hiss between calls down (kept gentle: no pumping)."""
    hop = int(RATE * 0.01)
    env = np.array([np.sqrt(np.mean(x[i:i + hop] ** 2) + 1e-12) for i in range(0, len(x), hop)])
    thr = np.percentile(env, 60)
    gain = np.where(env > thr, 1.0, 10 ** (floor_db / 20))
    gain = np.convolve(gain, np.ones(5) / 5, mode='same')  # 50 ms smoothing
    return (x * np.repeat(gain, hop)[: len(x)]).astype(np.float32)


def fade(x, ms=20):
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
        'rooster_1': (cut('rooster', 2.80, 5.55), -4),
        'rooster_2': (cut('rooster_small', 2.55, 4.20), -4),
        'hen_1': (cut('hen_vezo', 0.08, 0.78), -3),
        'hen_2': (cut('hen_egg', 0.52, 1.36), -3),
        'hen_3': (cut('hen_egg', 1.42, 2.40), -3),
        'egg': (cut('hen_egg', 3.40, 5.62), -3),
        # The chick recording has room hiss: high-pass + a soft gate.
        'chick_1': (gate(highpass(cut('chicks', 1.56, 2.18), 1800)), -3),
        'chick_2': (gate(highpass(cut('chicks', 11.44, 12.36), 1800)), -3),
        'chick_3': (gate(highpass(cut('chicks', 7.24, 7.92), 1800)), -3),
    }
    for name, (x, peak) in clips.items():
        encode(fade(normalize(x, peak)), name)


if __name__ == '__main__':
    main()
