#!/usr/bin/env python3
"""Synthesise every sound the island needs.

Why this exists: the game shipped with eight sound effects and one piece of
music, and nine gameplay templates need about forty. Downloading them means
forty files by forty people, and a drag sound that does not match the drop
sound is something a six-year-old hears immediately even though they could
never say what is wrong.

Generating them from one file means one hand made all of them: the same
tuning, the same envelope shapes, the same room. It is the audio equivalent
of what `Shapes` does for the drawing.

Everything is built from a handful of primitives -- a tone with an envelope,
a noise burst, a little chord -- and then written as OGG through ffmpeg.

    python3 tools/make_audio.py            # writes assets/audio/**
    python3 tools/make_audio.py --list     # just say what would be written
"""

import argparse
import math
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

RATE = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")

# A pentatonic scale. Nothing built from these notes can sound sour, which
# matters when the sounds fire in an order nobody can predict -- a child
# tapping fast should never produce a chord that makes an adult wince.
PENT = [261.63, 293.66, 329.63, 392.00, 440.00, 523.25, 587.33, 659.25]


def env(n, attack=0.01, decay=0.25, sustain=0.0, release=0.08):
    """An ADSR curve, in samples. Soft attacks: nothing on this island clicks."""
    a = max(int(attack * RATE), 1)
    d = max(int(decay * RATE), 1)
    r = max(int(release * RATE), 1)
    s = max(n - a - d - r, 0)
    return np.concatenate([
        np.linspace(0.0, 1.0, a) ** 0.6,
        np.linspace(1.0, sustain, d),
        np.full(s, sustain),
        np.linspace(sustain, 0.0, r) ** 1.4,
    ])[:n]


def tone(freq, dur, kind="sine", detune=0.0, glide=0.0):
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    f = freq * (1.0 + glide * t / max(dur, 1e-6))
    phase = 2 * np.pi * np.cumsum(f) / RATE
    if kind == "sine":
        w = np.sin(phase)
    elif kind == "tri":
        w = 2.0 / np.pi * np.arcsin(np.sin(phase))
    elif kind == "square":
        w = np.tanh(np.sin(phase) * 3.0)
    else:  # soft saw, rounded so it never rasps
        w = np.tanh(2.0 * (2.0 * (phase / (2 * np.pi) % 1.0) - 1.0))
    if detune:
        w = 0.6 * w + 0.4 * np.sin(phase * (1.0 + detune))
    return w


def noise(dur, colour=1.0):
    """Filtered noise. `colour` below 1 darkens it -- wind rather than hiss."""
    n = int(dur * RATE)
    w = np.random.default_rng(7).standard_normal(n)
    if colour < 1.0:
        k = max(int((1.0 - colour) * 60) + 1, 1)
        w = np.convolve(w, np.ones(k) / k, mode="same")
    return w / (np.abs(w).max() + 1e-9)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    peak = np.abs(out).max()
    return out / peak * 0.82 if peak > 0 else out


def pad(w, seconds):
    n = int(seconds * RATE)
    return np.concatenate([w, np.zeros(max(n - len(w), 0))])[:n]


# --- the sounds ---------------------------------------------------------------
#
# Grouped by what they are FOR, because that is how they have to relate to
# each other: every "yes" in the game is a rising interval and every "not
# that one" is a soft fall, so a child learns the language in about a minute.

def s_pick_up():
    """A piece leaves the ground: short, upward, weightless."""
    return mix(tone(PENT[2], 0.14, "tri", glide=0.5) * env(int(0.14 * RATE), 0.005, 0.12))


def s_snap():
    """A piece clicks into place. The most-heard sound in the whole game."""
    body = tone(PENT[4], 0.18, "tri") * env(int(0.18 * RATE), 0.004, 0.16)
    up = tone(PENT[6], 0.12, "sine") * env(int(0.12 * RATE), 0.004, 0.11)
    tick = noise(0.03, 0.35) * env(int(0.03 * RATE), 0.001, 0.028) * 0.5
    return mix(body, np.concatenate([np.zeros(int(0.04 * RATE)), up]), tick)


def s_bounce_back():
    """A wrong drop floating home. A shrug, not a buzzer."""
    n = int(0.26 * RATE)
    return mix(tone(PENT[3], 0.26, "sine", glide=-0.28) * env(n, 0.01, 0.24))


def s_step_done():
    """One step of a repair finished: a rung climbed."""
    return mix(
        tone(PENT[3], 0.2, "tri") * env(int(0.2 * RATE), 0.005, 0.18),
        tone(PENT[5], 0.22, "sine") * env(int(0.22 * RATE), 0.02, 0.2) * 0.7,
    )


def s_machine():
    """Something mechanical turning over. Wood and brass, not metal and menace."""
    n = int(0.5 * RATE)
    hum = tone(96.0, 0.5, "saw") * env(n, 0.06, 0.3, 0.4, 0.14) * 0.5
    ratchet = np.zeros(n)
    for i in range(7):
        at = int((0.05 + i * 0.06) * RATE)
        click = noise(0.02, 0.5) * env(int(0.02 * RATE), 0.001, 0.018)
        ratchet[at: at + len(click)] += click * 0.4
    return mix(hum, ratchet)


def s_power_on():
    """Lights coming up on something the child just fixed."""
    n = int(0.9 * RATE)
    swell = tone(PENT[0], 0.9, "tri", glide=1.1) * env(n, 0.25, 0.4, 0.5, 0.25)
    shimmer = sum(
        tone(f * 2, 0.9, "sine") * env(n, 0.35 + i * 0.06, 0.5) * 0.3
        for i, f in enumerate(PENT[2:6])
    )
    return mix(swell, shimmer)


def s_water():
    return mix(noise(0.7, 0.25) * env(int(0.7 * RATE), 0.12, 0.45, 0.2, 0.2) * 0.7)


def s_door():
    n = int(0.7 * RATE)
    grind = noise(0.7, 0.2) * env(n, 0.08, 0.4, 0.3, 0.2) * 0.55
    stone = tone(70.0, 0.7, "saw", glide=0.3) * env(n, 0.05, 0.4, 0.3, 0.2) * 0.6
    return mix(grind, stone)


def s_card_flip():
    return mix(noise(0.12, 0.45) * env(int(0.12 * RATE), 0.004, 0.11) * 0.8)


def s_footstep():
    return mix(noise(0.08, 0.18) * env(int(0.08 * RATE), 0.002, 0.07) * 0.6)


def s_shield():
    """A hit stopped. Round and bright: the child did the right thing."""
    n = int(0.4 * RATE)
    ring = sum(tone(f, 0.4, "sine") * env(n, 0.006, 0.34) * 0.4 for f in (PENT[4], PENT[6]))
    return mix(ring, noise(0.06, 0.5) * env(int(0.06 * RATE), 0.002, 0.05) * 0.5)


def s_charge():
    n = int(1.1 * RATE)
    return mix(tone(PENT[0], 1.1, "tri", glide=2.4) * env(n, 0.3, 0.5, 0.6, 0.2))


def s_ultimate():
    n = int(1.0 * RATE)
    beam = tone(PENT[5], 1.0, "saw", detune=0.01, glide=-0.2) * env(n, 0.02, 0.5, 0.35, 0.25)
    air = noise(1.0, 0.5) * env(n, 0.02, 0.4, 0.3, 0.3) * 0.4
    return mix(beam, air)


def s_monster_roar():
    """Grumpy, not frightening. A big animal that has been woken up."""
    n = int(0.8 * RATE)
    growl = tone(78.0, 0.8, "saw", glide=-0.25) * env(n, 0.06, 0.4, 0.4, 0.3)
    wobble = np.sin(2 * np.pi * 6.0 * np.arange(n) / RATE) * 0.35 + 0.65
    return mix(growl * wobble, noise(0.8, 0.15) * env(n, 0.08, 0.5, 0.2, 0.3) * 0.35)


def s_monster_defeat():
    """It sits down and waves. Falling, but warm."""
    n = int(1.0 * RATE)
    slump = tone(PENT[3], 1.0, "tri", glide=-0.45) * env(n, 0.03, 0.5, 0.3, 0.3)
    pat = sum(
        pad(tone(f, 0.2, "sine") * env(int(0.2 * RATE), 0.01, 0.18) * 0.4, 1.0)
        for f in (PENT[5], PENT[4], PENT[2])
    )
    return mix(slump, pat)


def s_warn():
    """Something is about to happen. Two soft knocks, never a klaxon."""
    n = int(0.5 * RATE)
    out = np.zeros(n)
    for i in range(2):
        at = int(i * 0.2 * RATE)
        beep = tone(PENT[1], 0.14, "sine") * env(int(0.14 * RATE), 0.01, 0.12)
        out[at: at + len(beep)] += beep * 0.8
    return mix(out)


def s_found():
    """A hidden thing found. The little rising three that means 'yes, that one'."""
    parts = []
    for i, f in enumerate((PENT[2], PENT[4], PENT[6])):
        parts.append(pad(np.concatenate([
            np.zeros(int(i * 0.07 * RATE)),
            tone(f, 0.22, "tri") * env(int(0.22 * RATE), 0.005, 0.2),
        ]), 0.45))
    return mix(*parts)


## A present opening. Lid off, then the thing inside catching the light.
##
## Deliberately NOT a fanfare: this plays every single time he buys anything,
## and a four-second flourish that a child hears forty times stops being a
## celebration and becomes a wait. Two seconds, and the second half is the
## same sparkle that already means "something good" everywhere else here.
def s_chest_open():
    lid = pad(np.concatenate([
        noise(0.09, 0.55) * env(int(0.09 * RATE), 0.002, 0.06) * 0.5,
        np.zeros(int(0.02 * RATE)),
    ]), 0.5)
    rise = []
    for i, f in enumerate((PENT[1], PENT[3], PENT[5], PENT[7 % len(PENT)])):
        rise.append(pad(np.concatenate([
            np.zeros(int((0.10 + i * 0.075) * RATE)),
            tone(f, 0.30, "tri") * env(int(0.30 * RATE), 0.006, 0.24),
        ]), 0.42))
    shimmer = np.zeros(int(0.9 * RATE))
    rng = np.random.default_rng(17)
    for i in range(6):
        at = int(rng.uniform(0.34, 0.72) * RATE)
        f = PENT[rng.integers(3, len(PENT))] * 2
        g = tone(f, 0.18, "sine") * env(int(0.18 * RATE), 0.004, 0.16) * 0.30
        shimmer[at: at + len(g)] += g
    return mix(lid, *rise, pad(shimmer, 0.5))


def s_sparkle():
    n = int(0.5 * RATE)
    out = np.zeros(n)
    rng = np.random.default_rng(3)
    for i in range(7):
        at = int(rng.uniform(0, 0.28) * RATE)
        f = PENT[rng.integers(3, len(PENT))] * 2
        g = tone(f, 0.16, "sine") * env(int(0.16 * RATE), 0.004, 0.15) * 0.35
        out[at: at + len(g)] += g
    return mix(out)


def s_whoosh():
    n = int(0.35 * RATE)
    return mix(noise(0.35, 0.3) * env(n, 0.04, 0.28) * 0.8)


def s_pop():
    return mix(tone(PENT[5], 0.1, "sine", glide=0.9) * env(int(0.1 * RATE), 0.003, 0.09))


def s_rustle():
    return mix(noise(0.3, 0.12) * env(int(0.3 * RATE), 0.05, 0.24) * 0.5)


def s_hint():
    """The game gently clearing its throat."""
    n = int(0.45 * RATE)
    return mix(
        tone(PENT[4], 0.45, "sine") * env(n, 0.06, 0.36) * 0.6,
        pad(tone(PENT[5], 0.3, "sine") * env(int(0.3 * RATE), 0.06, 0.24) * 0.4, 0.45),
    )


def note(index):
    """The tuned pads of the memory games. Bell-like, long enough to sing back."""
    f = PENT[index % len(PENT)]
    n = int(0.55 * RATE)
    return mix(
        tone(f, 0.55, "sine") * env(n, 0.008, 0.45),
        tone(f * 2, 0.55, "sine") * env(n, 0.008, 0.3) * 0.35,
        tone(f * 3.01, 0.3, "sine") * env(int(0.3 * RATE), 0.006, 0.26) * 0.14,
    )


# --- music --------------------------------------------------------------------
#
# One generator, five moods. Each world gets a different scale root, tempo and
# instrument weighting, so they are recognisably the same island at different
# hours -- exactly the rule the artwork follows.

def music(root, bpm, bars=8, bright=1.0, seed=1):
    rng = np.random.default_rng(seed)
    beat = 60.0 / bpm
    total = int(bars * 4 * beat * RATE)
    out = np.zeros(total)
    scale = [root * r for r in (1.0, 9 / 8, 5 / 4, 3 / 2, 5 / 3, 2.0)]

    # A bass note per bar: the floor the child's ear stands on.
    for bar in range(bars):
        at = int(bar * 4 * beat * RATE)
        f = scale[[0, 3, 4, 2][bar % 4]] / 2
        w = tone(f, beat * 3.6, "tri") * env(int(beat * 3.6 * RATE), 0.05, 1.2, 0.35, 0.5)
        out[at: at + len(w)] += w[: max(total - at, 0)] * 0.34

    # A melody that wanders but always lands home at the end of a phrase.
    step = 0
    for i in range(bars * 4):
        at = int(i * beat * RATE)
        if i % 4 == 0:
            step = 0
        else:
            step = int(np.clip(step + rng.integers(-1, 3), 0, len(scale) - 1))
        f = scale[step] * (2.0 if bright > 1.0 else 1.0)
        dur = beat * (1.5 if i % 4 == 3 else 0.85)
        w = tone(f, dur, "tri") * env(int(dur * RATE), 0.02, dur * 0.8)
        room = len(out) - at
        out[at: at + min(len(w), room)] += w[:room] * 0.3 * bright

    # A soft pulse on the off-beats, so it moves without a drum kit.
    for i in range(bars * 8):
        at = int((i * beat / 2) * RATE)
        if i % 2 == 0:
            continue
        w = noise(0.06, 0.3) * env(int(0.06 * RATE), 0.002, 0.055)
        room = len(out) - at
        out[at: at + min(len(w), room)] += w[:room] * 0.10

    peak = np.abs(out).max()
    return out / peak * 0.62 if peak > 0 else out


SOUNDS = {
    "drag_pick": s_pick_up, "drag_snap": s_snap, "drag_back": s_bounce_back,
    "build_step": s_step_done, "machine": s_machine, "power_on": s_power_on,
    "water": s_water, "door": s_door, "card_flip": s_card_flip,
    "footstep": s_footstep, "shield": s_shield, "charge": s_charge,
    "ultimate": s_ultimate, "monster_roar": s_monster_roar,
    "monster_defeat": s_monster_defeat, "warn": s_warn, "found": s_found,
    "sparkle": s_sparkle, "whoosh": s_whoosh, "pop": s_pop,
    "rustle": s_rustle, "hint": s_hint, "chest_open": s_chest_open,
}

MUSIC = {
    "sunny_park": dict(root=261.63, bpm=96, bright=1.0, seed=11),
    "night_city": dict(root=220.00, bpm=88, bright=1.2, seed=22),
    "monster_valley": dict(root=196.00, bpm=104, bright=0.8, seed=33),
    "sky_base": dict(root=293.66, bpm=92, bright=1.3, seed=44),
    "dark_castle": dict(root=174.61, bpm=84, bright=0.7, seed=55),
    "battle": dict(root=196.00, bpm=124, bright=0.9, seed=66),
    "victory": dict(root=329.63, bpm=112, bright=1.4, seed=77, bars=4),
}


def write_ogg(path, samples, quality=4):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    pcm = np.clip(samples, -1.0, 1.0)
    pcm = (pcm * 32767).astype("<i2")
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        wav_path = tmp.name
    with wave.open(wav_path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path,
         "-c:a", "libvorbis", "-q:a", str(quality), path],
        check=True)
    os.unlink(wav_path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--list", action="store_true")
    args = ap.parse_args()

    jobs = []
    for name, fn in SOUNDS.items():
        jobs.append((os.path.join(OUT, name + ".ogg"), fn, 3))
    for i in range(8):
        jobs.append((os.path.join(OUT, "notes", "note_%d.ogg" % (i + 1)),
                     (lambda k=i: note(k)), 3))
    for name, cfg in MUSIC.items():
        jobs.append((os.path.join(OUT, "music", name + ".ogg"),
                     (lambda c=cfg: music(**c)), 5))

    if args.list:
        for path, _, _ in jobs:
            print(os.path.relpath(path, ROOT))
        print("%d files" % len(jobs))
        return

    for path, fn, q in jobs:
        write_ogg(path, fn(), q)
        print("  %-42s %6.1f KB" % (os.path.relpath(path, ROOT),
                                    os.path.getsize(path) / 1024.0))
    print("%d files written" % len(jobs))


if __name__ == "__main__":
    sys.exit(main())
