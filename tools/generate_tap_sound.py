"""Octopus English tıklama sesini sentezler (assets/sounds/tap.wav).

Yalnızca numpy gerektirir. Çalıştırma:
    python tools/generate_tap_sound.py

Ses, açılış sesindeki baloncuk motifinin çok kısa, yumuşak bir "blup" hâlidir
(~70 ms, tek kanal). Sıkıştırılmamış PCM olduğu için çalarken kod çözme
maliyeti yoktur; dosya yaklaşık 5 KB'tır.
"""
import os
import wave

import numpy as np

SR = 32000
DUR = 0.075
N = int(SR * DUR)
TARGET_PEAK = 0.40  # yaklaşık -8 dBFS: açılış sesinden daha yumuşak
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sounds', 'tap.wav')

t = np.arange(N) / SR
rng = np.random.default_rng(3)

# Yükselen perdeli baloncuk gövdesi (620 -> 1250 Hz, hızlı sönümlenir).
f = 620.0 * (1250.0 / 620.0) ** np.clip(t / 0.045, 0, 1)
phase = 2 * np.pi * np.cumsum(f) / SR
bubble = (np.sin(phase) + 0.20 * np.sin(2 * phase)) * (1 - np.exp(-t / 0.0015)) * np.exp(-t / 0.016)

# Alt "gövde": dokunuşa ağırlık verir.
body = 0.35 * np.sin(2 * np.pi * 190.0 * t) * (1 - np.exp(-t / 0.002)) * np.exp(-t / 0.012)

# Çok hafif, yumuşatılmış başlangıç tıkı.
click = rng.standard_normal(N) * np.exp(-t / 0.0008)
a = 1 - np.exp(-2 * np.pi * 3500.0 / SR)
s = 0.0
for i in range(N):
    s += a * (click[i] - s)
    click[i] = s
click *= 0.10

x = bubble + body + click
x *= np.clip(t / 0.0005, 0, 1)            # 0,5 ms giriş (sessizlikten ani adım olmasın)
x *= np.clip((DUR - t) / 0.010, 0, 1)  # son 10 ms'de kapanış (pop sesi olmasın)
x -= x.mean()
x *= TARGET_PEAK / np.abs(x).max()

pcm16 = np.round(np.clip(x, -1, 1) * 32767).astype('<i2')
path = os.path.abspath(OUT)
os.makedirs(os.path.dirname(path), exist_ok=True)
with wave.open(path, 'wb') as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm16.tobytes())

print(f'yazıldı: {path}  ({os.path.getsize(path) / 1024:.1f} KB, {DUR * 1000:.0f} ms)')
