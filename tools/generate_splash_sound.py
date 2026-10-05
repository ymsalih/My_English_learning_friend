"""Octopus English açılış sesini sentezler (assets/sounds/splash_intro.wav).

Yalnızca numpy gerektirir. Çalıştırma:
    python tools/generate_splash_sound.py

Ses, açılış animasyonunun zamanlamasına göre tasarlanmıştır
(lib/screens/splash_screen.dart ve octopus_scene_painter.dart):

    0.0 - 2.2 sn  ahtapot uzaktan yaklaşır   -> su yatağı, derin zemin, baloncuklar
    1.9 - 3.3 sn  kollar kıvrılıp halka olur -> yükselen "pırıltı" notaları, hışırtı, pad
    3.3 sn        "Octopus English" belirir  -> yumuşak çan akoru + alt vuruş
    3.3 - 5.4 sn  doğal yankı kuyruğu

Dosya önceden hazırlanmış sıkıştırılmamış PCM olduğu için çalarken işlemci
maliyeti yoktur. Sabit tohum kullanıldığından çıktı her çalıştırmada aynıdır.
"""
import os
import wave

import numpy as np

SR = 32000
DURATION = 5.4
N = int(SR * DURATION)
TARGET_PEAK = 0.55  # yaklaşık -5 dBFS: açılışta rahatsız etmez
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sounds', 'splash_intro.wav')

rng = np.random.default_rng(7)


# --- yardımcılar ---------------------------------------------------------------

def smoothstep(x):
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3 - 2 * x)


def ramp(t, a, b):
    """a-b arasında 0 -> 1 yumuşak geçiş."""
    return smoothstep((t - a) / (b - a))


def tv_lowpass(x, fc):
    """Zamanla değişen kesim frekanslı tek kutuplu alçak geçiren filtre."""
    a = 1.0 - np.exp(-2.0 * np.pi * np.asarray(fc, dtype=np.float64) / SR)
    y = np.empty_like(x)
    s = 0.0
    for i in range(len(x)):
        s += a[i] * (x[i] - s)
        y[i] = s
    return y


def lp4(x, fc):
    """Dört kutuplu (dik) alçak geçiren: yüksek frekanslı hışırtıyı bastırır."""
    for _ in range(4):
        x = tv_lowpass(x, fc)
    return x


def unit_rms(x):
    return x / (np.sqrt(np.mean(x ** 2)) + 1e-12)


def pan_gains(pan):
    """-1 (sol) .. 1 (sağ), eşit güç."""
    ang = (pan + 1.0) * np.pi / 4.0
    return np.cos(ang), np.sin(ang)


class Bus:
    def __init__(self):
        self.L = np.zeros(N)
        self.R = np.zeros(N)

    def add(self, sig, start, pan=0.0, gain=1.0):
        i = int(round(start * SR))
        if i >= N:
            return
        seg = sig[: N - i] * gain
        gl, gr = pan_gains(pan)
        self.L[i:i + len(seg)] += seg * gl
        self.R[i:i + len(seg)] += seg * gr

    def add_stereo(self, sl, sr, start=0.0, gain=1.0):
        i = int(round(start * SR))
        n = min(len(sl), N - i)
        self.L[i:i + n] += sl[:n] * gain
        self.R[i:i + n] += sr[:n] * gain


dry = Bus()
send = Bus()  # yankıya gönderilen bölüm

T = np.arange(N) / SR


# --- ses üreteçleri -------------------------------------------------------------

def bubble(f0, dur=0.12):
    """Yükselen perdeli kısa baloncuk: 'blup'."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = f0 * (1.0 + 2.2 * t / dur)
    phase = 2 * np.pi * np.cumsum(f) / SR
    env = (1 - np.exp(-t / 0.004)) * np.exp(-t / 0.032)
    return (np.sin(phase) + 0.28 * np.sin(2 * phase)) * env


def pluck(freq, tau=0.38):
    """Yumuşak, camsı 'pırıltı' notası."""
    n = int(1.6 * SR)
    t = np.arange(n) / SR
    env = (1 - np.exp(-t / 0.002)) * np.exp(-t / tau)
    return (np.sin(2 * np.pi * freq * t) + 0.22 * np.sin(2 * np.pi * freq * 2 * t)
            + 0.06 * np.sin(2 * np.pi * freq * 3 * t)) * env


def bell(freq, tau=1.7):
    """Eşuyumsuz üst seslerle yumuşak çan."""
    n = int(3.4 * SR)
    t = np.arange(n) / SR
    partials = [(1.0, 1.0, 1.0), (2.0, 0.34, 0.62), (2.76, 0.17, 0.38), (5.4, 0.06, 0.22)]
    out = np.zeros(n)
    for ratio, amp, dscale in partials:
        out += amp * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t / (tau * dscale))
    return out * (1 - np.exp(-t / 0.003))


def thump(f_start=118.0, f_end=73.4, tau=0.17):
    """Alt vuruş: perdesi düşen sinüs."""
    n = int(0.9 * SR)
    t = np.arange(n) / SR
    f = f_end + (f_start - f_end) * np.exp(-t / 0.05)
    phase = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(phase) * np.exp(-t / tau) * (1 - np.exp(-t / 0.004))


# --- 1) su yatağı + derin zemin (0 - 3.4 sn) -----------------------------------

# Su yatağı yalnızca arka plan: dik filtre, düşük kesim, düşük seviye.
fc_bed = np.interp(T, [0.0, 2.2, 3.4], [110.0, 520.0, 260.0])
gain_bed = 0.050 * ramp(T, 0.0, 2.0) * (1.0 - ramp(T, 2.7, 3.6))
for ch in (dry.L, dry.R):
    bed = unit_rms(lp4(rng.standard_normal(N), fc_bed))
    ch += bed * gain_bed

drone = (np.sin(2 * np.pi * 73.42 * T) + 0.6 * np.sin(2 * np.pi * 110.0 * T)) * 0.085 * ramp(T, 0.0, 1.9) * (1.0 - ramp(T, 2.8, 3.6))
dry.L += drone
dry.R += drone

# --- 2) baloncuklar (yaklaşırken) ----------------------------------------------

bubble_times = [0.28, 0.55, 0.83, 1.02, 1.31, 1.52, 1.74, 2.02, 2.31, 2.58]
for bt in bubble_times:
    f0 = float(rng.uniform(320, 760))
    pan = float(rng.uniform(-0.7, 0.7))
    g = float(rng.uniform(0.16, 0.26))
    b = bubble(f0, dur=float(rng.uniform(0.09, 0.14)))
    dry.add(b, bt, pan, g)
    send.add(b, bt, pan, g * 0.8)

# --- 3) kollar kıvrılırken: pad + hışırtı + yükselen pırıltılar ----------------

# Pad (D majör), 1.9'dan itibaren yükselir, 3.3'te çanla birleşip sönümlenir.
pad_notes = [146.83, 220.0, 293.66, 369.99]
swell = 0.085 * ramp(T, 1.9, 3.3)
tail = np.exp(-np.clip(T - 3.3, 0, None) / 1.1)
pad_env = swell * np.where(T < 3.3, 1.0, tail)
padL = np.zeros(N)
padR = np.zeros(N)
for f in pad_notes:
    padL += np.sin(2 * np.pi * f * 1.0015 * T) + 0.18 * np.sin(2 * np.pi * f * 2 * T)
    padR += np.sin(2 * np.pi * f * 0.9985 * T) + 0.18 * np.sin(2 * np.pi * f * 2 * T)
padL *= pad_env
padR *= pad_env
dry.L += padL
dry.R += padR
send.L += padL * 0.35
send.R += padR * 0.35

# Hışırtı: yükselen bant geçiren (kollar suyu yararken).
fc_hi = np.interp(T, [1.9, 3.1], [450.0, 3600.0])
whoosh_gain = np.exp(-((T - 2.65) / 0.40) ** 2) * 0.045
for ch, send_ch in ((dry.L, send.L), (dry.R, send.R)):
    n = rng.standard_normal(N)
    band = lp4(n, fc_hi * 1.5) - lp4(n, fc_hi / 1.5)
    sig = unit_rms(band) * whoosh_gain
    ch += sig
    send_ch += sig * 0.30

# Yükselen pentatonik pırıltılar (D majör pentatonik).
sparkle = [587.33, 659.25, 739.99, 880.0, 987.77, 1174.66, 1318.51]
for i, f in enumerate(sparkle):
    start = 1.95 + 0.16 * i
    amp = 0.075 + 0.016 * i
    pan = -0.55 if i % 2 == 0 else 0.55
    p = pluck(f)
    dry.add(p, start, pan, amp)
    send.add(p, start, pan, amp * 0.9)

# --- 4) açılış: "Octopus English" belirir (3.3 sn) ------------------------------

th = thump()
dry.add(th, 3.30, 0.0, 0.50)
send.add(th, 3.30, 0.0, 0.05)

chord = [(293.66, 0.19), (440.0, 0.16), (739.99, 0.14), (880.0, 0.11), (1174.66, 0.075)]
for i, (f, a) in enumerate(chord):
    b = bell(f)
    pan = (-0.35, 0.3, -0.2, 0.4, -0.1)[i]
    dry.add(b, 3.30 + 0.026 * i, pan, a)
    send.add(b, 3.30 + 0.026 * i, pan, a * 0.75)

# --- 5) yankı (stereo, karanlık kuyruklu sentetik oda) -------------------------

IR_LEN = int(1.9 * SR)
ir_t = np.arange(IR_LEN) / SR
ir_fc = np.interp(ir_t, [0.0, 1.9], [9000.0, 1400.0])
ir_env = np.exp(-ir_t / 0.55)
irs = []
for _ in range(2):
    ir = tv_lowpass(rng.standard_normal(IR_LEN), ir_fc) * ir_env
    ir[: int(0.018 * SR)] = 0.0  # ön gecikme
    ir /= np.sqrt(np.sum(ir ** 2))
    irs.append(ir)


def convolve(x, ir):
    size = 1
    while size < len(x) + len(ir):
        size *= 2
    return np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[: len(x)]


wetL = convolve(send.L, irs[0])
wetR = convolve(send.R, irs[1])
WET = 0.62

left = dry.L + wetL * WET
right = dry.R + wetR * WET

# --- 6) mastering --------------------------------------------------------------

# DC engelleme + giriş/çıkış kıvrımları.
for ch in (left, right):
    ch -= ch.mean()
fade_in = np.clip(T / 0.02, 0, 1)
fade_out = 0.5 * (1 + np.cos(np.pi * np.clip((T - 4.7) / (DURATION - 4.7), 0, 1)))
left *= fade_in * fade_out
right *= fade_in * fade_out

# Yumuşak sınırlama, sonra hedef tepe seviyesine normalleme.
left = np.tanh(left * 1.25)
right = np.tanh(right * 1.25)
peak = max(np.abs(left).max(), np.abs(right).max())
left *= TARGET_PEAK / peak
right *= TARGET_PEAK / peak

pcm = np.stack([left, right], axis=1)
pcm16 = np.round(np.clip(pcm, -1, 1) * 32767).astype('<i2')

os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
with wave.open(os.path.abspath(OUT), 'wb') as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm16.tobytes())

print(f'yazıldı: {os.path.abspath(OUT)}  ({os.path.getsize(os.path.abspath(OUT)) / 1024:.0f} KB, {DURATION}s, {SR} Hz stereo)')
