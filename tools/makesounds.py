import sys
import wave
import numpy as np

SR = 44100
OUT = sys.argv[1]


def t(dur):
    return np.arange(int(SR * dur)) / SR


def env(x, attack=0.002, decay=0.1):
    tt = np.arange(len(x)) / SR
    a = np.clip(tt / attack, 0, 1)
    return x * a * np.exp(-tt / decay)


def fade(x, ms=10):
    n = min(len(x), int(SR * ms / 1000))
    x[-n:] *= np.linspace(1, 0, n)
    return x


def mix(length, *parts):
    out = np.zeros(int(SR * length))
    for start, sig in parts:
        i = int(SR * start)
        j = min(len(out), i + len(sig))
        out[i:j] += sig[:j - i]
    return out


def knock(freq, dur=0.12, decay=0.025, noise=0.6, seed=1):
    tt = t(dur)
    rng = np.random.default_rng(seed)
    body = (np.sin(2 * np.pi * freq * tt)
            + 0.5 * np.sin(2 * np.pi * freq * 2.31 * tt)
            + 0.25 * np.sin(2 * np.pi * freq * 3.89 * tt))
    body = env(body, 0.0005, decay)
    n = rng.standard_normal(len(tt))
    n = np.convolve(n, np.ones(6) / 6, mode='same')
    click = env(n, 0.0002, 0.004) * noise
    return body + click


def note(freq, dur, decay=0.25, kind='soft'):
    tt = t(dur)
    if kind == 'bell':
        x = (np.sin(2 * np.pi * freq * tt)
             + 0.4 * np.sin(2 * np.pi * freq * 2.76 * tt) * np.exp(-tt / (decay / 3))
             + 0.2 * np.sin(2 * np.pi * freq * 5.4 * tt) * np.exp(-tt / (decay / 6)))
    else:
        x = sum(np.sin(2 * np.pi * freq * k * tt) / k ** 1.6 for k in (1, 3, 5, 7))
    return env(x, 0.004, decay)


def hz(n):
    names = {'C': -9, 'D': -7, 'E': -5, 'F': -4, 'G': -2, 'A': 0, 'B': 2}
    semis = names[n[0]] + (1 if '#' in n else -1 if 'b' in n[1:] else 0)
    octave = int(n[-1])
    return 440 * 2 ** ((semis + 12 * (octave - 4)) / 12)


def save(name, x, peak_db=-6):
    x = fade(x.copy())
    x = x / np.max(np.abs(x)) * 10 ** (peak_db / 20)
    data = (x * 32767).astype('<i2').tobytes()
    with wave.open(f'{OUT}/{name}.wav', 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


save('move', knock(820, 0.12, 0.022, 0.5, 1))
save('capture', mix(0.2, (0, knock(560, 0.16, 0.03, 0.9, 2)),
                    (0.045, 0.7 * knock(740, 0.12, 0.02, 0.6, 3))), -4)
save('check', mix(0.55, (0, note(hz('E6'), 0.4, 0.15, 'bell')),
                  (0.12, note(hz('A6'), 0.43, 0.18, 'bell'))), -7)
save('victory', mix(1.1, *[(i * 0.11, note(hz(n), 0.9 - i * 0.11, 0.18 if i < 3 else 0.35))
                           for i, n in enumerate(['C5', 'E5', 'G5', 'C6'])]), -7)
save('defeat', mix(1.2, *[(i * 0.22, note(hz(n), 1.2 - i * 0.22, 0.22 if i < 2 else 0.4))
                          for i, n in enumerate(['G4', 'Eb4', 'C4'])]), -7)
save('draw', mix(0.8, (0, note(hz('G4'), 0.8, 0.2)), (0.2, note(hz('C5'), 0.6, 0.25))), -7)
