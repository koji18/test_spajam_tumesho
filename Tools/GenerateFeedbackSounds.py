"""標準ライブラリだけで、短いオリジナルの効果音を生成する。"""

import math
from pathlib import Path
import random
import struct
import wave

OUTPUT = Path(__file__).resolve().parent.parent / "Tsumesho" / "Sounds"
SAMPLE_RATE = 22_050


def render(name, notes, duration, click=False):
    rng = random.Random(18)
    frames = bytearray()
    for index in range(int(SAMPLE_RATE * duration)):
        time = index / SAMPLE_RATE
        value = 0.0
        for start, frequency, amplitude, decay in notes:
            local = time - start
            if local >= 0:
                envelope = min(1, local / 0.004) * math.exp(-local * decay)
                phase = 2 * math.pi * frequency * local
                value += amplitude * envelope * (math.sin(phase) + 0.22 * math.sin(phase * 2))
        if click:
            value += rng.uniform(-1, 1) * 0.28 * math.exp(-time * 95) * min(1, time / 0.001)
        value *= min(1, (duration - time) / 0.035)
        frames.extend(struct.pack("<h", int(max(-0.95, min(0.95, value)) * 32767)))
    with wave.open(str(OUTPUT / f"{name}.wav"), "wb") as sound:
        sound.setnchannels(1)
        sound.setsampwidth(2)
        sound.setframerate(SAMPLE_RATE)
        sound.writeframes(frames)


def main():
    OUTPUT.mkdir(exist_ok=True)
    render("piece-land", [(0, 1120, 0.25, 48), (0, 570, 0.18, 60)], 0.12, click=True)
    for tier in range(1, 5):
        base = 440 * 2 ** ((tier - 1) * 2 / 12)
        notes = [(0, base, 0.22, 9), (0.08, base * 1.25, 0.2, 9), (0.16, base * 1.5, 0.2, 8)]
        if tier >= 3:
            notes += [(0.27, base * 2, 0.2, 6), (0.27, base * 2.5, 0.12, 6)]
        render(f"mate-{tier}", notes, 0.8 if tier >= 3 else 0.55)
    render("rank-up", [(0, 523.25, 0.2, 7), (0.1, 659.25, 0.2, 7),
                       (0.2, 783.99, 0.2, 7), (0.34, 1046.5, 0.23, 5),
                       (0.34, 1318.5, 0.12, 5)], 1.1)
    render("score-arrive", [(0, 1318.5, 0.12, 22), (0.045, 1760, 0.1, 24)], 0.2)


if __name__ == "__main__":
    main()
