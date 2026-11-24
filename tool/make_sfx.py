"""Ripe Rhythm - sound effect and ambience synthesiser.

Synthesises every sound effect and both ambient loops for the game from
scratch with numpy (no samples, no downloaded audio, nothing to license).
The palette is warm, wooden and soft: kalimba/marimba-style plucks, gentle
bells, filtered-noise breezes, synthesised birds and crickets.

Run from the project root:

    python tool/make_sfx.py

Writes into assets/audio/ (mono, 44100 Hz, OGG Vorbis q4):

    tick      beat metronome, soft dry wooden knock (~55 ms)
    rest      "rest beat" cue, muted breathy low hush (~120 ms)
    harvest   good harvest, round wooden pluck on D5 (~250 ms)
    perfect   perfect harvest, brighter pluck + soft bell shimmer (~400 ms)
    bonus     streak bonus, rising 3-note pentatonic kalimba arpeggio (~500 ms)
    bruise    bruised fruit, soft low thud + small squish (~250 ms)
    gust      wind gust, band-passed noise swell/whoosh (~900 ms)
    star      result-screen star pop, bright little chime (~300 ms)
    win       row cleared, 5-note ascending pentatonic kalimba + bell (~1.6 s)
    lose      row failed, soft descending two-note sigh (~1.0 s)
    unlock    achievement / new season, two-note bell (~800 ms)
    buy       seed purchase, seed rattle + low wooden clunk (~350 ms)
    menu      UI tap, tiny high soft wooden tick (~45 ms)
    ambient_day    20 s seamless loop: airy pentatonic pad, breeze, sparse birds
    ambient_night  20 s seamless loop: darker pad, irregular crickets, faint breeze

One-shots are peak-normalised to -3 dBFS; the ambient loops are normalised to
about -18 dBFS RMS so they sit quietly under gameplay. The script prints a
peak/RMS table, checks the loop seams (last vs first 50 ms), converts to OGG
with ffmpeg, re-decodes the OGG files to verify length and clipping, and
deletes the intermediate .wav files. If ffmpeg has no libvorbis encoder it
keeps 22050 Hz mono 16-bit .wav files instead.

Requires: Python 3.13, numpy, ffmpeg/ffprobe on PATH.
"""
import os
import shutil
import subprocess
import wave

import numpy as np

RATE = 44100
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
OUT = os.path.join(ROOT, 'assets', 'audio')
ONESHOT_PEAK_DB = -3.0
LOOP_RMS_DB = -18.0
LOOP_SECONDS = 20.0

rng = np.random.default_rng(20261112)

# D major pentatonic (D E F# A B), equal temperament, A4 = 440.
def note(name_midi):
    return 440.0 * 2 ** ((name_midi - 69) / 12)

D4, E4, FS4, A4, B4 = note(62), note(64), note(66), note(69), note(71)
D5, E5, FS5, A5, B5 = note(74), note(76), note(78), note(81), note(83)
D6, E6, FS6, A6 = note(86), note(88), note(90), note(93)


# ----------------------------------------------------------------- helpers
def tt(dur):
    return np.arange(int(round(RATE * dur))) / RATE


def db(x):
    return 20 * np.log10(max(x, 1e-12))


def fft_filter(x, lo=None, hi=None, order=2, circular=False):
    """Zero-phase Butterworth-shaped band filter in the frequency domain.
    circular=True keeps the signal periodic (used for seamless loops);
    otherwise the signal is zero-padded so nothing wraps around."""
    n = len(x)
    pad = 0 if circular else 8192
    X = np.fft.rfft(np.concatenate([x, np.zeros(pad)]))
    f = np.fft.rfftfreq(n + pad, 1 / RATE)
    g = np.ones_like(f)
    if hi is not None:
        g /= np.sqrt(1 + (f / hi) ** (2 * order))
    if lo is not None:
        with np.errstate(divide='ignore'):
            g /= np.sqrt(1 + (lo / np.maximum(f, 1e-9)) ** (2 * order))
    return np.fft.irfft(X * g, n + pad)[:n]


def noise(dur):
    return rng.standard_normal(int(round(RATE * dur)))


def env_exp(t, attack, tau):
    """Raised-cosine attack then exponential decay (tau seconds)."""
    a = np.where(t < attack, 0.5 - 0.5 * np.cos(np.pi * np.clip(t / attack, 0, 1)), 1.0)
    return a * np.exp(-np.maximum(t - attack, 0) / tau)


def tail_fade(x, ms=12):
    k = min(len(x), int(RATE * ms / 1000))
    x = x.copy()
    x[-k:] *= 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, k))
    return x


def modal(freq, dur, modes, attack=0.002, glide=0.0):
    """Sum of decaying sine modes. modes: (ratio, amp, tau). glide: fractional
    pitch drop at onset (a little drop sounds woody)."""
    t = tt(dur)
    bend = 1 + glide * np.exp(-t / 0.015)
    out = np.zeros_like(t)
    for ratio, amp, tau in modes:
        phase = 2 * np.pi * np.cumsum(freq * ratio * bend) / RATE
        out += amp * env_exp(t, attack, tau) * np.sin(phase)
    return out


def kalimba(freq, dur, bright=0.0):
    """Round tine pluck: strong fundamental, quick inharmonic upper modes,
    plus a tiny soft wooden 'tock' of filtered noise."""
    modes = [(1.0, 1.0, 0.16 * (dur / 0.25) ** 0.5),
             (2.0, 0.10 + 0.10 * bright, 0.05),
             (5.9, 0.07 + 0.10 * bright, 0.012),
             (3.93, 0.05 + 0.06 * bright, 0.025)]
    body = modal(freq, dur, modes, attack=0.0015)
    t = tt(dur)
    tock = fft_filter(noise(dur), lo=200, hi=1800 + 1500 * bright) * env_exp(t, 0.0005, 0.004)
    return body + 0.12 * tock / max(1e-9, np.abs(tock).max())


def bell(freq, dur, tau=0.35, attack=0.004, bright=1.0):
    modes = [(1.0, 1.0, tau), (2.0, 0.22 * bright, tau * 0.6),
             (2.76, 0.16 * bright, tau * 0.45), (5.4, 0.04 * bright, tau * 0.2)]
    return modal(freq, dur, modes, attack=attack)


def mix(dur, *parts):
    """parts: (offset_seconds, samples, gain)"""
    out = np.zeros(int(round(RATE * dur)))
    for off, s, g in parts:
        k = int(round(off * RATE))
        m = min(len(s), len(out) - k)
        out[k:k + m] += g * s[:m]
    return out


def gentle_lowpass(x, hi=7000):
    return fft_filter(x, hi=hi, order=1)


# ---------------------------------------------------------------- one-shots
def make_tick():
    dur = 0.055
    t = tt(dur)
    body = modal(980, dur, [(1.0, 1.0, 0.011), (2.43, 0.35, 0.005), (3.9, 0.10, 0.003)],
                 attack=0.0004, glide=0.06)
    click = fft_filter(noise(dur), lo=900, hi=4000) * env_exp(t, 0.0002, 0.0018)
    x = body + 0.25 * click / np.abs(click).max()
    return tail_fade(gentle_lowpass(x, 6000), 8)


def make_menu():
    dur = 0.045
    t = tt(dur)
    body = modal(1760, dur, [(1.0, 1.0, 0.0065), (2.3, 0.25, 0.003)], attack=0.0006, glide=0.04)
    click = fft_filter(noise(dur), lo=1500, hi=5000) * env_exp(t, 0.0003, 0.0012)
    x = body + 0.15 * click / np.abs(click).max()
    return tail_fade(gentle_lowpass(x, 5000), 8)


def make_rest():
    dur = 0.12
    t = tt(dur)
    hush = fft_filter(noise(dur), lo=220, hi=1300, order=2)
    env = env_exp(t, 0.008, 0.035)
    low = 0.25 * np.sin(2 * np.pi * 170 * t) * env_exp(t, 0.004, 0.025)
    x = hush / np.abs(hush).max() * env + low
    return tail_fade(fft_filter(x, hi=1600, order=1), 20)


def make_harvest():
    return tail_fade(gentle_lowpass(kalimba(D5, 0.25)), 25)


def make_perfect():
    dur = 0.40
    pluck = kalimba(D5, dur, bright=0.8) + 0.35 * kalimba(D6, dur, bright=0.3)
    shimmer = bell(A6, dur, tau=0.18, attack=0.006, bright=0.6) + \
        bell(A6 * 1.003, dur, tau=0.16, attack=0.006, bright=0.6)
    x = mix(dur, (0, pluck, 1.0), (0.03, shimmer, 0.22))
    return tail_fade(gentle_lowpass(x, 8000), 40)


def make_bonus():
    dur = 0.50
    notes = [D5, FS5, A5]
    parts = [(i * 0.075, kalimba(f, 0.32, bright=0.4 + 0.2 * i), 0.8 + 0.1 * i)
             for i, f in enumerate(notes)]
    x = mix(dur, *parts)
    return tail_fade(gentle_lowpass(x, 7500), 60)


def make_bruise():
    dur = 0.25
    t = tt(dur)
    thud = modal(120, dur, [(1.0, 1.0, 0.055), (1.6, 0.3, 0.03)], attack=0.003, glide=0.3)
    sq = fft_filter(noise(dur), lo=300, hi=1100, order=2)
    sq /= np.abs(sq).max()
    squish_env = np.exp(-((t - 0.06) / 0.035) ** 2) * (1 + 0.5 * np.sin(2 * np.pi * 28 * t))
    x = thud + 0.28 * sq * squish_env
    return tail_fade(fft_filter(x, hi=1800, order=1), 40)


def make_gust():
    dur = 0.90
    t = tt(dur)
    n = noise(dur)
    lowb = fft_filter(n, lo=250, hi=800)
    highb = fft_filter(n, lo=600, hi=2200)
    lowb /= np.abs(lowb).max(); highb /= np.abs(highb).max()
    swell = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 2.2          # slow rise and fall
    whoosh = np.sin(np.pi * np.clip((t - 0.15) / 0.55, 0, 1)) ** 2  # brighter in the middle
    x = swell * ((1 - 0.6 * whoosh) * lowb + 0.6 * whoosh * highb)
    return tail_fade(x, 30)


def make_star():
    dur = 0.30
    x = bell(E6, dur, tau=0.09, attack=0.003, bright=0.8) + \
        0.25 * bell(B5 * 2, dur, tau=0.05, attack=0.003, bright=0.4)
    return tail_fade(gentle_lowpass(x, 9000), 30)


def make_win():
    dur = 1.60
    notes = [D5, E5, FS5, A5, D6]
    offs = [0.0, 0.13, 0.26, 0.39, 0.56]
    parts = []
    for i, (f, o) in enumerate(zip(notes, offs)):
        last = i == len(notes) - 1
        parts.append((o, kalimba(f, 1.0 if last else 0.5, bright=0.3), 0.8))
        parts.append((o + 0.01, bell(f * 2, 1.04 if last else 0.5, tau=0.45 if last else 0.18,
                                     attack=0.006, bright=0.5), 0.35 if last else 0.12))
    x = mix(dur, *parts)
    return tail_fade(gentle_lowpass(x, 8000), 150)


def mellow(freq_curve, t, attack, release_t, total):
    phase = 2 * np.pi * np.cumsum(freq_curve) / RATE
    tone = np.sin(phase) + 0.10 * np.sin(3 * phase) + 0.02 * np.sin(5 * phase)
    a = np.clip(t / attack, 0, 1) ** 2
    r = np.clip((total - t) / release_t, 0, 1)
    return tone * a * (0.5 - 0.5 * np.cos(np.pi * r))


def make_lose():
    dur = 1.0
    t1 = tt(0.50)
    f1 = A4 * (1 + 0.004 * np.sin(2 * np.pi * 5 * t1)) * (1 - 0.02 * np.clip((t1 - 0.35) / 0.15, 0, 1))
    n1 = mellow(f1, t1, 0.05, 0.18, 0.50)
    t2 = tt(0.62)
    f2 = FS4 * (1 + 0.004 * np.sin(2 * np.pi * 4.5 * t2)) * (1 - 0.03 * np.clip((t2 - 0.3) / 0.32, 0, 1))
    n2 = mellow(f2, t2, 0.06, 0.40, 0.62) * np.exp(-t2 / 0.6)
    x = mix(dur, (0, n1, 0.9), (0.36, n2, 0.9))
    return tail_fade(fft_filter(x, hi=1600, order=2), 30)


def make_unlock():
    dur = 0.80
    x = mix(dur, (0, bell(A5, 0.8, tau=0.30, attack=0.005), 0.8),
            (0.15, bell(D6, 0.65, tau=0.32, attack=0.005), 0.9))
    return tail_fade(gentle_lowpass(x, 8000), 60)


def make_buy():
    dur = 0.35
    x = np.zeros(int(RATE * dur))
    times = np.sort(rng.uniform(0, 0.18, 14) ** 1.3 / 0.18 ** 0.3)
    for k, ti in enumerate(times):
        g_dur = rng.uniform(0.003, 0.006)
        g = fft_filter(noise(g_dur), lo=1800, hi=5500) * np.hanning(int(round(RATE * g_dur)))
        g /= max(1e-9, np.abs(g).max())
        i = int(ti * RATE)
        x[i:i + len(g)] += g * rng.uniform(0.25, 0.5) * (1 - 0.4 * k / len(times))
    clunk = modal(196, 0.22, [(1.0, 1.0, 0.045), (2.6, 0.3, 0.015), (4.1, 0.08, 0.006)],
                  attack=0.001, glide=0.08)
    x = mix(dur, (0, x, 0.55), (0.10, clunk, 1.0))
    return tail_fade(gentle_lowpass(x, 6000), 40)


# -------------------------------------------------------------- ambient loops
def loop_freq(f, seconds=LOOP_SECONDS):
    """Round a frequency so it completes a whole number of cycles per loop."""
    return round(f * seconds) / seconds


def crossfade_loop(ext, n, fade, power):
    """ext has n + fade samples. Blend the overrun tail into the head so the
    end of the first n samples flows straight into sample 0."""
    y = ext[:n].copy()
    a = np.linspace(0, 1, fade, endpoint=False)
    if power:  # equal-power for uncorrelated material (noise, events)
        win_in, win_out = np.sin(a * np.pi / 2), np.cos(a * np.pi / 2)
    else:      # equal-gain for correlated material (periodic pad)
        win_in, win_out = a, 1 - a
    y[:fade] = ext[:fade] * win_in + ext[n:n + fade] * win_out
    return y


def pad(n_ext, voices, detune=0.10, odd=0.08):
    """Slow soft chord. voices: (freq, amp, lfo_cycles_per_loop, phase).
    All frequencies and LFOs are whole-cycle per loop, so the pad is
    periodic and contains no rhythmic pulse (LFOs are >= 6.7 s long)."""
    t = np.arange(n_ext) / RATE
    out = np.zeros(n_ext)
    for f, amp, cyc, ph in voices:
        lfo = 0.55 + 0.45 * np.sin(2 * np.pi * cyc * t / LOOP_SECONDS + ph)
        for ff in (loop_freq(f), loop_freq(f) + detune):
            p = 2 * np.pi * ff * t
            out += amp * lfo * (np.sin(p) + odd * np.sin(3 * p))  # sine/soft-triangle
    return out


def breeze(n_ext, lo, hi, cycles=(1, 3)):
    t = np.arange(n_ext) / RATE
    b = fft_filter(rng.standard_normal(n_ext), lo=lo, hi=hi, order=2)
    b /= np.sqrt(np.mean(b ** 2))
    gust = 0.6 + 0.25 * np.sin(2 * np.pi * cycles[0] * t / LOOP_SECONDS + 1.3) \
        + 0.15 * np.sin(2 * np.pi * cycles[1] * t / LOOP_SECONDS + 0.4)
    return b * gust


def bird_chirp(f0, f1, dur, curve=1.0):
    t = tt(dur)
    x = (t / dur) ** curve
    f = f0 + (f1 - f0) * x
    phase = 2 * np.pi * np.cumsum(f) / RATE
    env = np.sin(np.pi * t / dur) ** 2
    return env * (np.sin(phase) + 0.08 * np.sin(2 * phase))


def make_bird_call():
    """One varied little call: 2-5 frequency-swept sine chirps."""
    kind = rng.integers(0, 3)
    parts, off = [], 0.0
    base = rng.uniform(2600, 4200)
    count = int(rng.integers(2, 6))
    for i in range(count):
        if kind == 0:     # rising tweets
            c = bird_chirp(base, base * rng.uniform(1.25, 1.5), rng.uniform(0.05, 0.08), 0.7)
        elif kind == 1:   # falling whistles
            c = bird_chirp(base * 1.4, base * rng.uniform(0.85, 1.0), rng.uniform(0.07, 0.12), 1.5)
        else:             # up-down warble
            hi = base * rng.uniform(1.2, 1.35)
            c = np.concatenate([bird_chirp(base, hi, 0.035), bird_chirp(hi, base * 0.95, 0.045)])
        parts.append((off, c, rng.uniform(0.6, 1.0)))
        off += len(c) / RATE + rng.uniform(0.03, 0.09)
    return mix(off + 0.05, *parts)


def scatter(n_ext, events, times):
    out = np.zeros(n_ext)
    for ev, ti, g in zip(events, times, [1.0] * len(events)):
        k = int(ti * RATE)
        m = min(len(ev), n_ext - k)
        if m > 0:
            out[k:k + m] += g * ev[:m]
    return out


def cricket_burst(carrier, pulses, rate_hz):
    pulse_len = 1.0 / rate_hz
    dur = pulses * pulse_len
    t = tt(dur)
    am = np.sin(np.pi * ((t * rate_hz) % 1.0)) ** 3           # amplitude-modulated pulses
    shape = np.sin(np.pi * t / dur) ** 0.5
    return np.sin(2 * np.pi * carrier * t) * am * shape


def finish_loop(pad_ext, rest_ext, n, fade):
    y = crossfade_loop(pad_ext, n, fade, power=False) + crossfade_loop(rest_ext, n, fade, power=True)
    return y


def make_ambient_day():
    n = int(RATE * LOOP_SECONDS)
    fade = int(RATE * 1.0)
    ext = n + fade
    p = pad(ext, [(D4 / 2, 0.30, 1, 0.0), (A4 / 2, 0.22, 2, 1.7), (E4, 0.13, 1, 3.0),
                  (FS4, 0.11, 3, 4.4), (A4, 0.08, 2, 0.9), (B4, 0.05, 3, 2.2)])
    p = fft_filter(p, hi=1500, order=1, circular=True)
    p /= np.sqrt(np.mean(p ** 2))
    br = breeze(ext, 250, 1500)
    # sparse birds: 5 calls, spread out, never near-regular
    times = np.array([1.4, 5.9, 9.3, 13.8, 17.6]) + rng.uniform(-0.5, 0.5, 5)
    calls = [make_bird_call() * rng.uniform(0.6, 1.0) for _ in times]
    birds = fft_filter(scatter(ext, calls, times), hi=6500, order=1)
    rest = 0.30 * br + 0.55 * birds
    return finish_loop(1.0 * p, rest, n, fade)


def make_ambient_night():
    n = int(RATE * LOOP_SECONDS)
    fade = int(RATE * 1.0)
    ext = n + fade
    p = pad(ext, [(D4 / 4, 0.30, 1, 0.5), (A4 / 4, 0.24, 2, 2.0), (D4 / 2, 0.16, 1, 3.6),
                  (FS4 / 2, 0.08, 3, 1.1), (B4 / 2, 0.06, 2, 4.0)], detune=0.05, odd=0.05)
    p = fft_filter(p, hi=600, order=2, circular=True)
    p /= np.sqrt(np.mean(p ** 2))
    br = breeze(ext, 150, 700, cycles=(2, 5))
    # two cricket voices with irregular spacing and occasional long pauses
    crickets = np.zeros(ext)
    for carrier, level in ((4400, 1.0), (5100, 0.6)):
        ti = rng.uniform(0, 0.8)
        evs, ts = [], []
        while ti < ext / RATE:
            evs.append(cricket_burst(carrier * rng.uniform(0.99, 1.01), int(rng.integers(3, 6)),
                                     rng.uniform(26, 34)) * level * rng.uniform(0.6, 1.0))
            ts.append(ti)
            ti += rng.uniform(0.35, 1.3) + (rng.uniform(1.5, 3.0) if rng.random() < 0.15 else 0)
        crickets += scatter(ext, evs, ts)
    rest = 0.18 * br + 0.10 * crickets
    return finish_loop(1.0 * p, rest, n, fade)


# ---------------------------------------------------------------- output
def write_wav(path, x, rate=RATE):
    pcm = np.clip(np.round(x * 32767), -32768, 32767).astype('<i2')
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate)
        w.writeframes(pcm.tobytes())


def stats(x):
    peak = np.abs(x).max()
    rms = np.sqrt(np.mean(x ** 2))
    return db(peak), db(rms), int(np.sum(np.abs(x) >= 32767 / 32768))


def seam_report(name, y):
    k = int(RATE * 0.05)
    head, tail = y[:k], y[-k:]
    # A click at the loop point shows up as a spike in the 2nd difference
    # (deviation from linear extrapolation). Rank the wrap's value among all
    # in-loop values: anything well under ~99.9 means the seam is unremarkable.
    jump = abs(y[0] - (2 * y[-1] - y[-2]))
    steps = np.abs(np.diff(y, 2))
    pct = 100.0 * np.mean(steps < jump)
    # spectral similarity of the two 50 ms windows (1.0 = identical spectra)
    sh = np.abs(np.fft.rfft(head * np.hanning(k)))
    st = np.abs(np.fft.rfft(tail * np.hanning(k)))
    sim = float(np.dot(sh, st) / (np.linalg.norm(sh) * np.linalg.norm(st) + 1e-12))
    print(f'  {name:14s} head RMS {db(np.sqrt(np.mean(head**2))):6.1f} dB | tail RMS '
          f'{db(np.sqrt(np.mean(tail**2))):6.1f} dB | wrap 2nd-diff {jump:.5f} '
          f'(percentile {pct:.1f} in-loop) | spectral sim {sim:.3f}')


def decode(path):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', path, '-f', 's16le', '-ac', '1', '-'],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, '<i2').astype(np.float64) / 32768


def has_libvorbis():
    try:
        enc = subprocess.run(['ffmpeg', '-hide_banner', '-encoders'], capture_output=True, text=True).stdout
        return 'libvorbis' in enc
    except FileNotFoundError:
        return False


def main():
    os.makedirs(OUT, exist_ok=True)
    oneshots = {
        'tick': make_tick, 'rest': make_rest, 'harvest': make_harvest, 'perfect': make_perfect,
        'bonus': make_bonus, 'bruise': make_bruise, 'gust': make_gust, 'star': make_star,
        'win': make_win, 'lose': make_lose, 'unlock': make_unlock, 'buy': make_buy, 'menu': make_menu,
    }
    loops = {'ambient_day': make_ambient_day, 'ambient_night': make_ambient_night}

    rendered = {}
    for name, fn in oneshots.items():
        x = fn()
        rendered[name] = x * (10 ** (ONESHOT_PEAK_DB / 20) / np.abs(x).max())
    for name, fn in loops.items():
        x = fn()
        x = x * (10 ** (LOOP_RMS_DB / 20) / np.sqrt(np.mean(x ** 2)))
        if np.abs(x).max() > 0.89:
            raise SystemExit(f'{name}: loop peak too high ({db(np.abs(x).max()):.1f} dBFS)')
        rendered[name] = x

    vorbis = has_libvorbis()
    rate = RATE
    if not vorbis:
        # fallback: 22050 Hz wav (simple 2:1 decimation after an anti-alias lowpass)
        rate = 22050
        rendered = {k: fft_filter(v, hi=9500, order=4)[::2] for k, v in rendered.items()}

    print(f'\nLevels (pre-conversion, {rate} Hz mono 16-bit wav):')
    print(f'  {"file":14s} {"dur s":>6s} {"peak dBFS":>10s} {"RMS dBFS":>9s} {"clipped":>8s}')
    for name, x in rendered.items():
        wav = os.path.join(OUT, name + '.wav')
        write_wav(wav, x, rate)
        pcm = decode(wav)
        pk, rm, clip = stats(pcm)
        print(f'  {name:14s} {len(pcm)/rate:6.3f} {pk:10.2f} {rm:9.2f} {clip:8d}')

    print('\nLoop seams (last 50 ms vs first 50 ms, wav):')
    for name in loops:
        seam_report(name, decode(os.path.join(OUT, name + '.wav')))

    if not vorbis:
        print('\nlibvorbis NOT available: kept 22050 Hz mono 16-bit .wav files.')
        return

    print('\nConverting to OGG Vorbis (q4)...')
    for name in rendered:
        wav = os.path.join(OUT, name + '.wav')
        ogg = os.path.join(OUT, name + '.ogg')
        subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', wav, '-c:a', 'libvorbis', '-q:a', '4',
                        '-ac', '1', '-ar', str(RATE), ogg], check=True)

    print('\nVerification of final OGG files (ffprobe + re-decode):')
    print(f'  {"file":18s} {"dur s":>7s} {"bytes":>8s} {"Hz":>6s} {"ch":>3s} {"peak dBFS":>10s} {"RMS dBFS":>9s} {"clipped":>8s}')
    for name in rendered:
        ogg = os.path.join(OUT, name + '.ogg')
        probe = subprocess.run(['ffprobe', '-v', 'error', '-show_entries',
                                'format=duration:stream=sample_rate,channels,codec_name',
                                '-of', 'default=nw=1', ogg], capture_output=True, text=True, check=True).stdout
        info = dict(l.split('=', 1) for l in probe.strip().splitlines())
        pcm = decode(ogg)
        pk, rm, clip = stats(pcm)
        print(f'  {name + ".ogg":18s} {float(info["duration"]):7.3f} {os.path.getsize(ogg):8d} '
              f'{info["sample_rate"]:>6s} {info["channels"]:>3s} {pk:10.2f} {rm:9.2f} {clip:8d}')
    print('\nLoop seams (decoded OGG):')
    for name in loops:
        seam_report(name, decode(os.path.join(OUT, name + '.ogg')))

    for name in rendered:
        os.remove(os.path.join(OUT, name + '.wav'))
    print('\nDone. Intermediate .wav files removed.')


if __name__ == '__main__':
    if shutil.which('ffmpeg') is None:
        raise SystemExit('ffmpeg not found on PATH')
    main()
