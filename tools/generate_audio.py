"""Original synthesised UI and game sounds. No third-party audio samples."""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / 'audio'
OUT.mkdir(exist_ok=True)
rng = random.Random(20261003)

def write(name, duration, tones, noise=0):
    samples = [0.0] * int(duration * RATE)
    for start, frequency, length, gain in tones:
        for i in range(int(length * RATE)):
            offset = int(start * RATE) + i
            if offset >= len(samples):
                break
            t = i / RATE
            attack = min(1, t / .007)
            envelope = attack * math.exp(-5 * t / length) * min(1, (length - t) / .02)
            tone = math.sin(2 * math.pi * frequency * t) + .22 * math.sin(2 * math.pi * frequency * 2 * t)
            samples[offset] += gain * envelope * tone
    if noise:
        for i in range(min(len(samples), int(.09 * RATE))):
            samples[i] += rng.uniform(-1, 1) * noise * math.exp(-i / (RATE * .015))
    with wave.open(str(OUT / (name + '.wav')), 'wb') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(b''.join(struct.pack('<h', int(max(-.95, min(.95, value)) * 32767)) for value in samples))

write('drop', .28, [(0, 330, .20, .40), (.035, 165, .18, .18)], .14)
write('click', .09, [(0, 880, .08, .12)])
write('start', .65, [(0, 392, .3, .2), (.13, 523.25, .3, .2), (.26, 659.25, .36, .23)])
write('connect', .4, [(0, 659.25, .25, .2), (.12, 880, .27, .2)])
write('victory', 1.65, [(0, 523.25, .38, .25), (.2, 659.25, .38, .25), (.4, 783.99, .38, .25), (.64, 1046.5, .9, .3), (.64, 659.25, .9, .12), (.64, 783.99, .9, .12)])
write('defeat', .95, [(0, 392, .4, .22), (.22, 329.63, .4, .2), (.44, 261.63, .48, .22)])
write('draw', .9, [(0, 523.25, .4, .2), (.25, 587.33, .4, .18), (.5, 523.25, .38, .18)])
print('Generated 7 original sound effects')
