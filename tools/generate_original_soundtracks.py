"""Build LOOP's three original, loopable rhythm-game tracks (Python + NumPy only)."""
from pathlib import Path
import math
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "music"
RATE = 22050

CHORDS = {
    "neon_ascent": [([48, 55, 60, 63], [72, 75, 79, 82]), ([44, 51, 56, 60], [68, 72, 75, 80]), ([41, 48, 53, 56], [65, 68, 72, 77]), ([46, 53, 58, 62], [70, 74, 77, 82])],
    "glass_horizon": [([50, 57, 62, 66], [74, 78, 81, 85]), ([45, 52, 57, 61], [69, 73, 76, 80]), ([47, 54, 59, 62], [71, 74, 78, 83]), ([43, 50, 55, 59], [67, 71, 74, 78])],
    "amber_sonata": [([48, 55, 60, 64], [72, 76, 79, 84]), ([45, 52, 57, 60], [69, 72, 76, 81]), ([41, 48, 53, 57], [65, 69, 72, 77]), ([43, 50, 55, 59], [67, 71, 74, 79])],
}


def midi_freq(note):
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


def make_track(name, bpm, style):
    beat = 60.0 / bpm
    duration = beat * 64
    audio = np.zeros(round(duration * RATE), dtype=np.float64)

    def add_note(note, start, length, volume, timbre="sine", decay=4.0):
        offset = round(start * RATE)
        count = min(round(length * RATE), len(audio) - offset)
        if count <= 0:
            return
        t = np.arange(count, dtype=np.float64) / RATE
        freq = midi_freq(note)
        phase = 2.0 * np.pi * freq * t
        attack = np.minimum(1.0, t / (0.008 if style == "piano" else 0.025))
        release = np.minimum(1.0, np.maximum(0.0, (length - t) / max(0.02, length * 0.16)))
        if timbre == "piano":
            wave = (np.sin(phase) + .42*np.sin(2*phase+.1) + .19*np.sin(3*phase+.35) + .07*np.sin(4*phase+.7))
            env = attack * np.exp(-decay*t) * release
        elif timbre == "lead":
            wave = .58*np.sin(phase) + .27*np.sin(2*phase+.12) + .11*np.sin(3*phase+.29)
            wave += .20*np.sin(phase*1.006)
            env = attack * np.exp(-decay*t) * release
        elif timbre == "pad":
            wave = .55*np.sin(phase) + .27*np.sin(phase*1.003) + .18*np.sin(2*phase)
            env = np.minimum(1.0,t/.3) * np.minimum(1.0,np.maximum(0.0,(length-t)/.32))
        else:
            wave = np.sin(phase)
            env = attack * np.exp(-decay*t) * release
        audio[offset:offset+count] += volume * wave * env

    def add_drum(start, kind, volume):
        offset = round(start * RATE)
        count = min(round(.20 * RATE), len(audio) - offset)
        if count <= 0:
            return
        t = np.arange(count, dtype=np.float64) / RATE
        if kind == "kick":
            freq = 52 + 92*np.exp(-t*26)
            phase = 2*np.pi*np.cumsum(freq)/RATE
            sound = np.sin(phase)*np.exp(-t*13)
        elif kind == "snare":
            rng = np.random.default_rng(int(start*1000)+5)
            noise = rng.uniform(-1,1,count)
            sound = (noise*.75 + .25*np.sin(2*np.pi*190*t))*np.exp(-t*21)
        else:
            rng = np.random.default_rng(int(start*1000)+9)
            noise = rng.uniform(-1,1,count)
            sound = (noise - np.roll(noise,1)) * np.exp(-t*56)
        audio[offset:offset+count] += volume * sound

    progression = CHORDS[name]
    if style == "piano":
        melody = [76,79,81,84,81,79,76,72,74,77,81,84,86,84,81,77,72,76,79,84,88,84,79,76,74,77,81,86,84,81,77,74]
    elif style == "rolling":
        melody = [78,81,85,90,85,81,78,74,76,81,85,88,85,81,76,73,74,78,81,86,81,78,74,69,73,78,81,85,81,78,73,69]
    else:
        melody = [75,79,82,87,82,79,75,70,72,77,80,84,80,77,72,68,70,75,79,84,79,75,70,67,74,79,82,86,82,79,74,70]

    for beat_index in range(64):
        chord_i = (beat_index // 16) % 4
        bass, chord = progression[chord_i]
        when = beat_index * beat
        if beat_index % 4 == 0:
            add_note(bass[0] - 12, when, beat*.78, .17 if style == "piano" else .20, "sine", 1.4)
        if style == "piano":
            if beat_index % 2 == 0:
                note = melody[(beat_index // 2) % len(melody)]
                add_note(note, when, beat*1.05, .20, "piano", 3.0)
            if beat_index % 8 == 0:
                for i, n in enumerate(chord):
                    add_note(n, when, beat*3.6, .036, "pad")
            add_drum(when, "kick" if beat_index % 4 == 0 else "hat", .075 if beat_index % 4 == 0 else .012)
        elif style == "rolling":
            for step in range(2):
                n = chord[(beat_index + step) % len(chord)] + 12
                add_note(n, when + step*beat*.5, beat*.36, .055, "lead", 5.5)
            if beat_index % 4 == 0:
                add_note(chord[0]+12, when, beat*3.8, .035, "pad")
            add_drum(when, "kick" if beat_index % 4 == 0 else "hat", .08 if beat_index % 4 == 0 else .010)
        else:
            if beat_index % 2 == 0:
                note = melody[(beat_index//2) % len(melody)]
                add_note(note, when, beat*.46, .09, "lead", 5.0)
                add_note(note-12, when, beat*.7, .065, "sine", 2.2)
            if beat_index % 4 == 0:
                for n in chord:
                    add_note(n, when, beat*3.6, .024, "pad")
            add_drum(when, "kick" if beat_index % 4 == 0 else "snare" if beat_index % 4 == 2 else "hat", .085 if beat_index % 4 in (0,2) else .008)

    peak = float(np.max(np.abs(audio)))
    audio = np.tanh(audio / max(peak, 1e-8) * .78) * .76
    pcm = np.asarray(np.clip(audio * 32767, -32768, 32767), dtype="<i2")
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(pcm.tobytes())
    print(f"{name}: {duration:.1f}s, {len(pcm)*2/1024/1024:.2f} MiB")


if __name__ == "__main__":
    make_track("neon_ascent", 128, "dash")
    make_track("glass_horizon", 112, "rolling")
    make_track("amber_sonata", 120, "piano")
