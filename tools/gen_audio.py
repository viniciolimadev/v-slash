#!/usr/bin/env python3
"""Sintetiza os sons e as músicas do jogo (Fase 4, RF-4.07) em assets/audio/**/*.ogg.

Python puro (sem numpy) + ffmpeg com libvorbis. Determinístico: sementes fixas, rodar de novo
gera os mesmos arquivos. Uso, na raiz do projeto:

    python3 tools/gen_audio.py            # tudo
    python3 tools/gen_audio.py spike_perfect menu   # só alguns

Depois: godot --headless --import
"""

import math
import os
import random
import struct
import subprocess
import sys
import tempfile
import wave

SR = 44100
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")


# ------------------------------------------------------------------ blocos básicos

def silence(sec):
    return [0.0] * int(sec * SR)


def mix_into(dst, src, at=0.0, gain=1.0):
    i0 = int(at * SR)
    need = i0 + len(src)
    if need > len(dst):
        dst.extend([0.0] * (need - len(dst)))
    for i, v in enumerate(src):
        dst[i0 + i] += v * gain
    return dst


def env_exp(n, decay, attack=0.002):
    """Envelope: sobe em `attack` s e cai exponencialmente (decay = s até ~37%)."""
    a = max(1, int(attack * SR))
    out = []
    for i in range(n):
        t = i / SR
        e = math.exp(-t / decay) if decay > 0 else 1.0
        if i < a:
            e *= i / a
        out.append(e)
    return out


def tone(sec, f0, f1=None, decay=0.1, wave_kind="sine", attack=0.002, harmonics=None):
    """Oscilador com glide de f0 para f1 (exponencial) e envelope exponencial."""
    n = int(sec * SR)
    f1 = f0 if f1 is None else f1
    e = env_exp(n, decay, attack)
    ph = 0.0
    out = []
    for i in range(n):
        u = i / max(n - 1, 1)
        f = f0 * (f1 / f0) ** u
        ph += 2 * math.pi * f / SR
        if wave_kind == "sine":
            v = math.sin(ph)
        elif wave_kind == "tri":
            v = 2 / math.pi * math.asin(math.sin(ph))
        elif wave_kind == "saw":
            v = ((ph / math.pi) % 2.0) - 1.0
        else:
            v = 1.0 if math.sin(ph) >= 0 else -1.0
        if harmonics:
            for k, g in harmonics:
                v += g * math.sin(ph * k)
        out.append(v * e[i])
    return out


def noise(sec, rng, decay=0.1, attack=0.001):
    n = int(sec * SR)
    e = env_exp(n, decay, attack)
    return [rng.uniform(-1, 1) * e[i] for i in range(n)]


def lowpass(x, cutoff):
    a = 1 - math.exp(-2 * math.pi * cutoff / SR)
    y, out = 0.0, []
    for v in x:
        y += a * (v - y)
        out.append(y)
    return out


def highpass(x, cutoff):
    lp = lowpass(x, cutoff)
    return [v - l for v, l in zip(x, lp)]


def bandpass(x, lo, hi):
    return lowpass(highpass(x, lo), hi)


def resonator(x, freq, q):
    """Filtro ressonante de 2 polos (formantes da torcida)."""
    w = 2 * math.pi * freq / SR
    r = math.exp(-w / (2 * q))
    a1, a2 = -2 * r * math.cos(w), r * r
    y1 = y2 = 0.0
    out = []
    g = (1 - r)
    for v in x:
        y = g * v - a1 * y1 - a2 * y2
        y2, y1 = y1, y
        out.append(y)
    return out


def scale(x, g):
    return [v * g for v in x]


def fade(x, fin=0.0, fout=0.01):
    n = len(x)
    a, b = int(fin * SR), int(fout * SR)
    for i in range(a):
        x[i] *= i / a
    for i in range(b):
        x[n - 1 - i] *= i / b
    return x


def normalize(x, peak=0.89):
    m = max(1e-9, max(abs(v) for v in x))
    return [v * peak / m for v in x]


# ------------------------------------------------------------------ efeitos (mono)

def thump(rng, f0, f1, dur, body_decay, click_gain, bright):
    s = tone(dur, f0, f1, decay=body_decay)
    c = highpass(noise(dur, rng, decay=0.012), bright)
    return mix_into(s, c, 0, click_gain)


def sfx_bank():
    rng = random.Random(42)
    b = {}
    grades = {"perfect": (1.0, 1.25, 1.0), "good": (0.8, 1.0, 0.75), "bad": (0.6, 0.85, 0.45)}
    for g, (gain, pitch, click) in grades.items():
        # manchete: batida grave e abafada nos antebraços
        b["bump_" + g] = scale(thump(rng, 170 * pitch, 95, 0.22, 0.05, 0.6 * click, 900), gain)
        # toque: pancadinha curta com os dedos
        b["set_" + g] = scale(mix_into(tone(0.12, 420 * pitch, 300, decay=0.03),
                                       highpass(noise(0.05, rng, decay=0.008), 2500), 0, 0.5 * click), gain)
        # cortada: estalo forte + corpo
        crack = highpass(noise(0.15, rng, decay=0.02 + 0.02 * click), 1800)
        b["spike_" + g] = scale(mix_into(thump(rng, 220 * pitch, 60, 0.3, 0.07, 0.4, 600), crack, 0, 1.2 * click), gain)
    b["serve"] = mix_into(thump(rng, 200, 70, 0.28, 0.06, 0.5, 900), highpass(noise(0.1, rng, decay=0.02), 1500), 0, 0.7)
    blk = mix_into(highpass(noise(0.12, rng, decay=0.015), 1200), highpass(noise(0.1, rng, decay=0.015), 1500), 0.03, 0.8)
    b["block"] = mix_into(blk, tone(0.25, 150, 70, decay=0.06), 0, 0.8)
    b["dink"] = mix_into(tone(0.15, 620, 380, decay=0.04), highpass(noise(0.04, rng, decay=0.006), 3000), 0, 0.3)
    swish = bandpass(noise(0.5, rng, decay=0.25, attack=0.05), 800, 4000)
    b["dive"] = mix_into(scale(swish, 1.5), lowpass(noise(0.3, rng, decay=0.06), 300), 0.12, 2.0)
    wh = bandpass(noise(0.3, rng, decay=0.12, attack=0.08), 400, 2500)
    b["whiff"] = scale(wh, 0.8)
    rat = noise(0.45, rng, decay=0.14)
    rat = [v * (0.5 + 0.5 * math.sin(2 * math.pi * 28 * i / SR)) for i, v in enumerate(rat)]
    b["net"] = mix_into(bandpass(rat, 300, 3000), tone(0.3, 110, 70, decay=0.08), 0, 0.7)
    b["antenna"] = mix_into(mix_into(tone(0.4, 1250, decay=0.12), tone(0.4, 1873, decay=0.09), 0, 0.6),
                            tone(0.4, 2711, decay=0.06), 0, 0.4)
    b["land"] = mix_into(lowpass(noise(0.3, rng, decay=0.07), 700), tone(0.25, 90, 50, decay=0.06), 0, 0.9)
    b["whistle"] = whistle(rng, 0.42)
    b["whistle_long"] = mix_into(whistle(rng, 0.25), whistle(rng, 0.7), 0.35)
    b["crowd_loop"] = crowd_loop(rng, 4.0)
    b["cheer"] = applause(rng, 2.6, 1.0)
    b["applause"] = applause(rng, 1.6, 0.6)
    b["ohh"] = ohh(rng, 1.3)
    b["ui_click"] = tone(0.06, 950, 1100, decay=0.02, wave_kind="tri")
    b["ui_back"] = tone(0.07, 700, 560, decay=0.025, wave_kind="tri")
    b["perfect"] = mix_into(tone(0.5, 1318.5, decay=0.15, harmonics=[(2.0, 0.2)]),
                            tone(0.45, 1975.5, decay=0.14, harmonics=[(2.0, 0.15)]), 0.07, 0.8)
    win = []
    for k, f in enumerate([523.25, 659.25, 783.99, 1046.5]):
        mix_into(win, tone(0.5, f, decay=0.18, wave_kind="tri"), k * 0.11)
    b["match_win"] = win
    lose = []
    for k, f in enumerate([392.0, 349.23, 311.13, 261.63]):
        mix_into(lose, tone(0.55, f, decay=0.22, wave_kind="tri"), k * 0.16)
    b["match_lose"] = lose
    return b


def whistle(rng, dur):
    n = int(dur * SR)
    out, ph = [], 0.0
    for i in range(n):
        t = i / SR
        f = 2900 + 60 * math.sin(2 * math.pi * 6 * t)
        ph += 2 * math.pi * f / SR
        trill = 0.65 + 0.35 * math.sin(2 * math.pi * 34 * t)
        e = min(1.0, t / 0.015) * min(1.0, (dur - t) / 0.04)
        out.append((math.sin(ph) + 0.25 * math.sin(2 * ph)) * trill * e)
    breath = bandpass(noise(dur, rng, decay=10), 2000, 6000)
    return mix_into(out, breath, 0, 0.15)


def crowd_loop(rng, dur):
    """Murmúrio contínuo: muitas "vozes" (ruído filtrado em formantes) com volume oscilando devagar."""
    n = int(dur * SR)
    out = [0.0] * n
    for _v in range(10):
        f1 = rng.uniform(350, 750)
        src = noise(dur, rng, decay=100)
        voice = resonator(src, f1, 6)
        rate = rng.uniform(0.6, 2.2)
        ph = rng.uniform(0, 2 * math.pi)
        for i in range(n):
            # período inteiro dentro do loop: emenda sem estalo
            k = round(rate * dur) / dur
            out[i] += voice[i] * (0.55 + 0.45 * math.sin(2 * math.pi * k * i / SR + ph))
    out = lowpass(out, 2500)
    # emenda: as pontas se cruzam (o loop não "estala")
    x = int(0.25 * SR)
    for i in range(x):
        a = i / x
        out[i] = out[i] * a + out[n - x + i] * (1 - a)
    return normalize(out[: n - x], 0.6)


def applause(rng, dur, density):
    n = int(dur * SR)
    out = [0.0] * n
    claps = int(260 * dur * density)
    for _ in range(claps):
        t = rng.random() * dur * 0.85
        c = bandpass(noise(0.03, rng, decay=0.006), 900, 5000)
        mix_into(out, c, t, rng.uniform(0.2, 0.6))
    out = out[:n]
    env = [min(1.0, (i / SR) / 0.25) * min(1.0, (dur - i / SR) / (dur * 0.5)) for i in range(n)]
    cheer = resonator(noise(dur, rng, decay=100), 650, 3)
    return normalize([out[i] * env[i] + 0.5 * cheer[i] * env[i] for i in range(n)], 0.8)


def ohh(rng, dur):
    """Torcida fazendo "ôôô": várias vozes (dente de serra) por formantes de "o", tom caindo."""
    n = int(dur * SR)
    out = [0.0] * n
    for _ in range(9):
        f0 = rng.uniform(140, 260)
        src = tone(dur, f0, f0 * 0.82, decay=100, wave_kind="saw", attack=0.12)
        v = mix_into(resonator(src, 480, 8), resonator(src, 850, 8), 0, 0.5)
        mix_into(out, v, rng.uniform(0, 0.08), 1.0)
    out = out[:n]
    env = [min(1.0, (dur - i / SR) / 0.5) for i in range(n)]
    return normalize([out[i] * env[i] for i in range(n)], 0.75)


# ------------------------------------------------------------------ música (estéreo)

NOTE = {n: i for i, n in enumerate(["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"])}


def hz(name):
    """'A4' → 440 Hz."""
    p, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((NOTE[p] + 12 * (octave + 1) - 69) / 12)


def chord_notes(root, minor, octave):
    r = NOTE[root] + 12 * (octave + 1)
    third = 3 if minor else 4
    return [440.0 * 2 ** ((m - 69) / 12) for m in (r, r + third, r + 7)]


def song(bpm, bars, prog, lead, pad_gain, lead_gain, rng, swing_hat=True):
    beat = 60.0 / bpm
    total = bars * 4 * beat
    L = silence(total + 2.0)
    R = silence(total + 2.0)

    def put(sig, at, pan=0.0, gain=1.0):
        mix_into(L, sig, at, gain * (1 - max(0.0, pan)))
        mix_into(R, sig, at, gain * (1 + min(0.0, pan)))

    kick = tone(0.3, 120, 45, decay=0.07)
    snare = mix_into(bandpass(noise(0.2, rng, decay=0.05), 900, 6000), tone(0.15, 210, 160, decay=0.04), 0, 0.5)
    for bar in range(bars):
        root, minor = prog[bar % len(prog)]
        t0 = bar * 4 * beat
        for k in range(4):
            put(kick, t0 + k * beat, 0, 0.55 if k % 2 == 0 else 0.35)
            if k % 2 == 1:
                put(snare, t0 + k * beat, 0, 0.32)
            for h in range(2):
                hat = highpass(noise(0.05, rng, decay=0.012), 7000)
                off = (0.58 if (swing_hat and h == 1) else 0.5 * h) * beat
                put(hat, t0 + k * beat + off, 0.3 if h else -0.3, 0.16)
        # baixo: tônica e quinta
        for k, interval in enumerate([0, 0, 7, 0]):
            f = hz(root + "2") * 2 ** (interval / 12)
            put(tone(beat * 0.9, f, decay=beat * 0.6, wave_kind="tri", harmonics=[(2.0, 0.3)]), t0 + k * beat, 0, 0.5)
        # acorde no contratempo ("skank" de praia) + pad
        notes = chord_notes(root, minor, 4)
        for k in range(4):
            for j, f in enumerate(notes):
                put(tone(beat * 0.35, f, decay=0.08, wave_kind="saw"), t0 + (k + 0.5) * beat, -0.4 + 0.4 * j, 0.07)
        for j, f in enumerate(notes):
            pad = lowpass(tone(4 * beat, f / 2, decay=100, wave_kind="saw", attack=0.4), 900)
            put(fade(pad, 0, 0.4), t0, 0.5 - 0.5 * j, pad_gain)
    # melodia (marimba): lista de (compasso, tempo, nota, duração em tempos)
    for bar, pos, name, dur in lead:
        f = hz(name)
        m = tone(dur * beat + 0.3, f, decay=0.22, harmonics=[(4.0, 0.25), (10.0, 0.05)])
        put(m, bar * 4 * beat + pos * beat, 0.15, lead_gain)
    # loop sem emenda: o rabo que passou do fim volta para o começo
    n = int(total * SR)
    for ch in (L, R):
        for i in range(n, len(ch)):
            ch[i - n] += ch[i]
        del ch[n:]
    m = max(max(abs(v) for v in L), max(abs(v) for v in R), 1e-9)
    return [v * 0.85 / m for v in L], [v * 0.85 / m for v in R]


def music_bank():
    rng = random.Random(7)
    # menu: animado, C – G – Am – F
    prog = [("C", False), ("G", False), ("A", True), ("F", False)]
    motif = [(0, "E5", 1), (1, "G5", 0.5), (1.5, "A5", 0.5), (2, "G5", 1), (3, "E5", 1)]
    answer = [(0, "D5", 1), (1, "E5", 0.5), (1.5, "D5", 0.5), (2, "C5", 1.5), (3.5, "G4", 0.5)]
    lead = []
    for bar in range(16):
        if bar % 4 in (0, 2):
            src = motif if bar % 8 < 4 else answer
            for pos, note, dur in src:
                lead.append((bar, pos, note, dur))
        elif bar % 4 == 1:
            lead.append((bar, 0, "B4" if bar % 8 < 4 else "C5", 2))
            lead.append((bar, 2.5, "D5", 0.5))
        else:
            lead.append((bar, 0, "C5", 1))
            lead.append((bar, 1, "A4", 1))
            lead.append((bar, 2, "C5", 2))
    menu = song(112, 16, prog, lead, 0.05, 0.22, rng)
    # partida: mais calmo, Am – F – C – G, quase sem melodia (não compete com os efeitos)
    prog2 = [("A", True), ("F", False), ("C", False), ("G", False)]
    lead2 = [(b, 0, n, 3) for b, n in [(3, "E5"), (7, "D5"), (11, "E5"), (15, "G5")]]
    match = song(96, 16, prog2, lead2, 0.08, 0.12, rng, swing_hat=False)
    return {"menu": menu, "match": match}


# ------------------------------------------------------------------ saída

def write_wav(path, chans):
    with wave.open(path, "wb") as w:
        w.setnchannels(len(chans))
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for i in range(len(chans[0])):
            for ch in chans:
                v = max(-1.0, min(1.0, ch[i]))
                frames += struct.pack("<h", int(v * 32767))
        w.writeframes(bytes(frames))


def to_ogg(chans, out, quality):
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "x.wav")
        write_wav(wav, chans)
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", wav, "-map_metadata", "-1",
                        "-fflags", "+bitexact", "-c:a", "libvorbis", "-q:a", str(quality), out], check=True)


def main(only):
    for name, x in sfx_bank().items():
        if only and name not in only:
            continue
        to_ogg([normalize(fade(x, 0, 0.01))], os.path.join(ROOT, "sfx", name + ".ogg"), 4)
        print("sfx  ", name)
    if only and not any(n in only for n in ("menu", "match")):
        return
    for name, (left, right) in music_bank().items():
        if only and name not in only:
            continue
        to_ogg([left, right], os.path.join(ROOT, "music", name + ".ogg"), 3)
        print("music", name)


if __name__ == "__main__":
    main(set(sys.argv[1:]))
