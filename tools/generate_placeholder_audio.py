#!/usr/bin/env python3
"""Generate quiet procedural placeholder ambience and SFX for Fellwell Island.

Every sound here is synthesised from noise and sine waves by this script, so there
are no licensing concerns. They exist only so the AudioManager hooks can be heard
and tested; replace any of them by dropping a finished file with the same name
(any of .ogg/.mp3/.wav) into the same folder and deleting the placeholder.

No music is generated: music is supplied by the project owner.

Usage (from the repo root):  python3 tools/generate_placeholder_audio.py
Standard library only.
"""
import math
import os
import random
import struct
import wave

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")
random.seed(1066)  # Deterministic output, so regenerating doesn't churn git.


# --------------------------------------------------------------------------- utils

def write_wav(relative_path, samples, rate):
    path = os.path.join(ROOT, relative_path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = 1.0 if peak <= 1.0 else 1.0 / peak
    with wave.open(path, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(rate)
        out.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * scale)) * 32767)) for s in samples))
    print("wrote", os.path.relpath(path, os.path.join(ROOT, "..")))


def noise(n):
    return [random.uniform(-1.0, 1.0) for _ in range(n)]


def lowpass(samples, cutoff, rate):
    alpha = 1.0 - math.exp(-2.0 * math.pi * cutoff / rate)
    out, y = [], 0.0
    for s in samples:
        y += alpha * (s - y)
        out.append(y)
    return out


def highpass(samples, cutoff, rate):
    low = lowpass(samples, cutoff, rate)
    return [s - l for s, l in zip(samples, low)]


def normalise(samples, level):
    peak = max(1e-9, max(abs(s) for s in samples))
    return [s / peak * level for s in samples]


def envelope(n, attack, release, rate):
    a, r = max(1, int(attack * rate)), max(1, int(release * rate))
    return [min(1.0, i / a) * min(1.0, (n - i) / r) for i in range(n)]


def make_loop(samples, overlap):
    """Crossfade the tail into the head so the file loops without a click."""
    body, tail = samples[:-overlap], samples[-overlap:]
    for i in range(overlap):
        t = i / overlap
        body[i] = body[i] * t + tail[i] * (1.0 - t)
    return body


def tone(freq, seconds, rate, decay=8.0, harmonics=(1.0,)):
    n = int(seconds * rate)
    return [sum(h * math.sin(2 * math.pi * freq * (k + 1) * i / rate) for k, h in enumerate(harmonics))
            * math.exp(-decay * i / rate) for i in range(n)]


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] if i < len(t) else 0.0 for t in tracks) for i in range(n)]


def silence(seconds, rate):
    return [0.0] * int(seconds * rate)


# ----------------------------------------------------------------------- ambience

def sea(rate=11025, seconds=12.0):
    n = int((seconds + 1.0) * rate)
    surf = lowpass(lowpass(noise(n), 500, rate), 700, rate)
    hiss = highpass(lowpass(noise(n), 2500, rate), 900, rate)
    out = []
    for i in range(n):
        t = i / rate
        swell = 0.55 + 0.45 * math.sin(2 * math.pi * t / 6.0) ** 2  # Waves every 6 s; 12 s loops cleanly.
        out.append(surf[i] * swell + hiss[i] * 0.25 * swell ** 3)
    return make_loop(normalise(out, 0.6), rate)


def wind(rate=11025, seconds=12.0):
    n = int((seconds + 1.0) * rate)
    base = lowpass(noise(n), 300, rate)
    out = []
    for i in range(n):
        t = i / rate
        gust = 0.5 + 0.3 * math.sin(2 * math.pi * t / 12.0) + 0.2 * math.sin(2 * math.pi * t / 4.0 + 1.3)
        out.append(base[i] * gust)
    return make_loop(normalise(out, 0.5), rate)


def night_insects(rate=22050, seconds=8.0):
    out = [0.0] * int(seconds * rate)
    for voice, (freq, pulse_rate, offset) in enumerate([(4300, 2.0, 0.0), (3900, 1.5, 0.31), (4700, 2.5, 0.77)]):
        for chirp in range(int(seconds * pulse_rate)):
            start = (chirp / pulse_rate + offset) % seconds
            for pulse in range(3):
                p0 = int((start + pulse * 0.035) * rate)
                for i in range(int(0.018 * rate)):
                    j = (p0 + i) % len(out)
                    out[j] += math.sin(2 * math.pi * freq * i / rate) * math.sin(math.pi * i / (0.018 * rate)) * (0.5 - voice * 0.1)
    return normalise(out, 0.25)


def gull(rate=22050):
    out = []
    for call in range(3):
        n = int(0.32 * rate)
        phase = 0.0
        for i in range(n):
            t = i / n
            freq = 1500 + 700 * math.sin(math.pi * t) - 500 * t
            phase += 2 * math.pi * freq / rate
            out.append((math.sin(phase) + 0.35 * math.sin(2 * phase) + 0.15 * math.sin(3 * phase)) * math.sin(math.pi * t) ** 0.6)
        out += silence(0.12, rate)
    return normalise(lowpass(out, 3500, rate), 0.35)


def room_creak(rate=22050, seconds=0.6):
    n = int(seconds * rate)
    out, phase = [], 0.0
    for i in range(n):
        t = i / n
        freq = 90 + 60 * math.sin(math.pi * t * 1.5) + random.uniform(-15, 15)
        phase += 2 * math.pi * freq / rate
        saw = (phase / math.pi) % 2.0 - 1.0
        out.append(saw * math.sin(math.pi * t) * (0.6 + 0.4 * random.random()))
    return normalise(lowpass(out, 900, rate), 0.35)


# --------------------------------------------------------------------------- sfx

def footstep(rate=22050, variant=0):
    n = int(0.09 * rate)
    thump = lowpass(noise(n), 350 + variant * 60, rate)
    env = [math.exp(-38 * i / rate) for i in range(n)]
    return normalise([s * e for s, e in zip(thump, env)], 0.45)


def blip(freqs, seconds_each, rate=22050, level=0.3):
    out = []
    for f in freqs:
        out += tone(f, seconds_each, rate, decay=22.0, harmonics=(1.0, 0.25))
    return normalise(out, level)


def rustle(seconds, rate=22050, level=0.35):
    n = int(seconds * rate)
    base = highpass(lowpass(noise(n), 3000, rate), 500, rate)
    out = []
    for i in range(n):
        t = i / rate
        bumps = abs(math.sin(2 * math.pi * 3.1 * t)) * abs(math.sin(2 * math.pi * 1.3 * t + 0.4))
        out.append(base[i] * bumps)
    return normalise([s * e for s, e in zip(out, envelope(n, 0.05, 0.15, rate))], level)


def slide(seconds, rising, rate=22050):
    n = int(seconds * rate)
    out, y = [], 0.0
    for i, s in enumerate(noise(n)):
        t = i / n
        cutoff = 600 + 2400 * (t if rising else 1.0 - t)
        y += (1.0 - math.exp(-2 * math.pi * cutoff / rate)) * (s - y)
        out.append(y)
    swoosh = [s * e for s, e in zip(out, envelope(n, 0.04, 0.08, rate))]
    click = tone(2200, 0.03, rate, decay=120.0)
    return normalise(swoosh + click if rising else click + swoosh, 0.3)


def knock(rate=22050):
    n = int(0.12 * rate)
    body = tone(180, 0.12, rate, decay=35.0, harmonics=(1.0, 0.5, 0.2))
    tap = [s * math.exp(-80 * i / rate) for i, s in enumerate(lowpass(noise(n), 1500, rate))]
    return mix(body, tap)


def chime(rate=22050):
    notes = [(784, 0.0), (659, 0.28), (523, 0.56)]  # G5 E5 C5, a soft descending close.
    tracks = [silence(start, rate) + tone(f, 1.6, rate, decay=2.2, harmonics=(1.0, 0.3, 0.1)) for f, start in notes]
    return normalise(mix(*tracks), 0.3)


def main():
    write_wav("ambience/sea.wav", sea(), 11025)
    write_wav("ambience/wind.wav", wind(), 11025)
    write_wav("ambience/night_insects.wav", night_insects(), 22050)
    write_wav("ambience/gull_1.wav", gull(), 22050)
    write_wav("ambience/room_creak_1.wav", room_creak(), 22050)
    write_wav("ambience/room_creak_2.wav", room_creak(seconds=0.4), 22050)

    for v in range(4):
        write_wav(f"sfx/footstep_{v + 1}.wav", footstep(variant=v), 22050)
    write_wav("sfx/interact.wav", blip([660, 990], 0.07), 22050)
    write_wav("sfx/ui_confirm.wav", blip([880], 0.08, level=0.22), 22050)
    write_wav("sfx/ui_cancel.wav", blip([660, 440], 0.07, level=0.22), 22050)
    write_wav("sfx/ui_select.wav", blip([1320], 0.035, level=0.15), 22050)
    write_wav("sfx/lemon_pick_up.wav", mix(rustle(0.25, level=0.25), silence(0.12, 22050) + blip([740, 988], 0.06, level=0.2)), 22050)
    write_wav("sfx/lemon_put_down.wav", mix(rustle(0.2, level=0.2), silence(0.1, 22050) + footstep(variant=0)), 22050)
    write_wav("sfx/telescope_open.wav", slide(0.35, rising=True), 22050)
    write_wav("sfx/telescope_close.wav", slide(0.3, rising=False), 22050)
    write_wav("sfx/cupboard_open.wav", normalise(mix(knock(), silence(0.05, 22050) + room_creak(seconds=0.45)), 0.4), 22050)
    write_wav("sfx/bed_rustle.wav", rustle(0.6), 22050)
    write_wav("sfx/sleep_transition.wav", chime(), 22050)


if __name__ == "__main__":
    main()
