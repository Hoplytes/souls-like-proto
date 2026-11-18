"""Synthesise the game's sound effects (no samples, no licence to track).
Run: python3 tools/make_sfx.py   -> assets/sfx/*.wav (22 kHz, 16-bit, mono)"""
import os, wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")
rng = np.random.default_rng(7)

def t(d): return np.arange(int(SR * d)) / SR
def noise(d): return rng.uniform(-1, 1, int(SR * d))
def env(n, attack=0.005, decay=0.2, curve=4.0):
    x = np.arange(n) / SR
    a = np.clip(x / max(attack, 1e-4), 0, 1)
    return a * np.exp(-curve * np.maximum(x - attack, 0) / max(decay, 1e-4))

def lowpass(x, cutoff):
    """One-pole low-pass; cutoff may be an array (sweeps)."""
    cutoff = np.broadcast_to(np.asarray(cutoff, float), x.shape)
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x); prev = 0.0
    for i in range(len(x)):
        prev = (1 - a[i]) * x[i] + a[i] * prev
        y[i] = prev
    return y

def highpass(x, cutoff): return x - lowpass(x, cutoff)
def bandpass(x, lo, hi): return highpass(lowpass(x, hi), lo)

def tone(freq, d, shape="sine"):
    f = np.broadcast_to(np.asarray(freq, float), t(d).shape)
    ph = 2 * np.pi * np.cumsum(f) / SR
    if shape == "saw": return 2 * ((ph / (2 * np.pi)) % 1) - 1
    if shape == "square": return np.sign(np.sin(ph))
    return np.sin(ph)

def metal(base, d, partials=(1, 2.76, 5.40, 8.93, 13.3), decay=0.5):
    """Inharmonic partials = struck metal (bronze shield)."""
    out = np.zeros(int(SR * d))
    for i, p in enumerate(partials):
        out += tone(base * p * rng.uniform(0.995, 1.005), d) * env(len(out), 0.001, decay / (1 + i * 0.6)) / (1 + i * 0.5)
    return out

def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts: out[:len(p)] += p
    return out

def save(name, x, gain=0.9):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    fade = min(len(x), int(SR * 0.01))
    x[-fade:] *= np.linspace(1, 0, fade)
    data = (x * 32767).astype("<i2").tobytes()
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data)

os.makedirs(OUT, exist_ok=True)

# --- weapons ---------------------------------------------------------------
def whoosh(d, lo, hi, peak=0.4):
    n = noise(d); x = t(d) / d
    sweep = lo + (hi - lo) * np.sin(np.pi * np.clip(x / (peak * 2), 0, 1)) ** 2
    return bandpass(n, sweep * 0.3, sweep) * np.sin(np.pi * x) ** 1.5

save("swing_light", whoosh(0.16, 600, 3800), 0.6)
save("swing_heavy", whoosh(0.32, 300, 2200, 0.5), 0.75)
save("thrust", mix(whoosh(0.14, 900, 4500, 0.3), 0.3 * noise(0.03) * env(661, 0.001, 0.01)), 0.6)

# --- impacts -----------------------------------------------------------------
def thud(d=0.18, f0=140, f1=50):
    body = tone(np.linspace(f0, f1, int(SR * d)), d) * env(int(SR * d), 0.002, d * 0.5)
    crack = lowpass(noise(0.05), 2500) * env(int(SR * 0.05), 0.001, 0.02)
    return mix(body, 0.8 * crack)

save("hit_flesh", thud(), 0.95)
save("hit_heavy", mix(thud(0.3, 110, 35), 0.5 * thud(0.2, 260, 90)), 1.0)
bone = mix(*[np.concatenate([np.zeros(int(SR * k)), bandpass(noise(0.03), 1500, 6000) * env(661, 0.0005, 0.01)]) for k in (0, 0.025, 0.06)])
save("hit_bone", mix(bone, 0.6 * thud(0.12, 220, 120)), 0.85)

# --- shield ----------------------------------------------------------------
save("block", mix(metal(310, 0.45, decay=0.35), 0.5 * thud(0.1, 180, 80), 0.3 * highpass(noise(0.02), 3000)), 0.85)
save("parry", mix(metal(620, 0.9, decay=0.7), 0.6 * metal(930, 0.9, decay=0.5), 0.4 * highpass(noise(0.03), 4000) * env(661, 0.0005, 0.01)), 0.9)
save("guard_break", mix(metal(190, 0.6, decay=0.25), thud(0.3, 120, 40), 0.6 * lowpass(noise(0.25), 1800) * env(5512, 0.001, 0.1)), 1.0)

# --- movement --------------------------------------------------------------
save("roll", lowpass(noise(0.35), np.linspace(900, 300, int(SR * 0.35))) * np.sin(np.pi * t(0.35) / 0.35), 0.55)
for i in range(3):
    step = lowpass(noise(0.07), 900 + 250 * i) * env(int(SR * 0.07), 0.002, 0.02)
    save(f"step_{i}", step, 0.35)

# --- player ----------------------------------------------------------------
def grunt(d, f0, f1):
    f = np.linspace(f0, f1, int(SR * d))
    v = tone(f, d, "saw") * (1 + 0.3 * np.sin(2 * np.pi * 28 * t(d)))
    v = bandpass(v, 300, 1400) + 0.4 * bandpass(noise(d), 500, 2000)
    return v * env(len(v), 0.01, d * 0.6)

save("player_hurt", mix(grunt(0.22, 210, 140), 0.7 * thud(0.12)), 0.8)
save("player_death", mix(grunt(0.6, 180, 70), 0.6 * thud(0.4, 90, 30)), 0.85)
heal = mix(*[np.concatenate([np.zeros(int(SR * 0.08 * i)), tone(f, 0.5) * env(int(SR * 0.5), 0.01, 0.25)]) for i, f in enumerate((523, 659, 784, 1046))])
save("heal", mix(heal, 0.3 * lowpass(noise(0.2), 600) * env(4410, 0.02, 0.08)), 0.5)

# --- enemies ---------------------------------------------------------------
rattle = mix(*[np.concatenate([np.zeros(int(SR * k)), bandpass(noise(0.025), 1200, 5000) * env(551, 0.0005, 0.008)]) for k in np.cumsum(rng.uniform(0.02, 0.06, 14))])
save("skeleton_death", mix(rattle, 0.5 * thud(0.25, 160, 60)), 0.8)
save("skeleton_swing", whoosh(0.18, 700, 3000), 0.5)

def roar(d, f0, f1):
    f = np.linspace(f0, f1, int(SR * d)) * (1 + 0.04 * np.sin(2 * np.pi * 7 * t(d)))
    v = tone(f, d, "saw") + 0.6 * tone(f * 1.5, d, "saw")
    v = lowpass(v, 900) + 0.5 * bandpass(noise(d), 200, 1200)
    return v * env(len(v), 0.12, d * 0.5, 2.5)

save("boss_roar", roar(1.3, 95, 70), 1.0)
save("boss_rage", mix(roar(1.6, 120, 60), 0.5 * roar(1.6, 80, 45)), 1.0)
save("boss_slam", mix(tone(np.linspace(90, 28, int(SR * 0.7)), 0.7) * env(int(SR * 0.7), 0.002, 0.35),
                      lowpass(noise(0.6), 700) * env(int(SR * 0.6), 0.002, 0.25), 0.4 * thud(0.2, 200, 60)), 1.0)
save("boss_leap", mix(whoosh(0.4, 200, 1200, 0.5), 0.5 * grunt(0.25, 120, 160)), 0.7)
save("boss_charge", mix(lowpass(noise(0.8), 250) * np.sin(np.pi * t(0.8) / 0.8), 0.4 * roar(0.8, 85, 95)), 0.85)
save("boss_death", mix(roar(2.2, 100, 40), 0.7 * thud(0.6, 70, 25)), 1.0)
save("telegraph", mix(tone(np.linspace(300, 900, int(SR * 0.25)), 0.25, "square") * 0.25 * env(5512, 0.01, 0.12)), 0.35)

# --- world -----------------------------------------------------------------
save("rocks_fall", mix(*[np.concatenate([np.zeros(int(SR * k)), thud(0.25, rng.uniform(90, 160), 40)]) for k in (0, 0.07, 0.15, 0.26)],
                       lowpass(noise(0.9), 500) * env(int(SR * 0.9), 0.02, 0.4)), 1.0)
fire = lowpass(noise(1.0), 1200) * env(int(SR * 1.0), 0.15, 0.5, 2)
save("bonfire", mix(fire, 0.5 * heal), 0.6)
save("you_died", mix(tone(55, 3.0, "saw") * env(int(SR * 3), 0.3, 1.6, 2), 0.6 * tone(82.4, 3.0, "saw") * env(int(SR * 3), 0.5, 1.6, 2)), 0.7)
vic = mix(*[np.concatenate([np.zeros(int(SR * 0.18 * i)), metal(f, 1.6, (1, 2.0, 3.0), 1.2)]) for i, f in enumerate((262, 330, 392, 523))])
save("victory", vic, 0.7)

# Ambient wind, built to loop seamlessly (cross-faded ends).
d = 8.0
w = lowpass(noise(d + 1), 380 + 220 * np.sin(2 * np.pi * t(d + 1) / (d + 1) * 2) ** 2)
w *= 0.6 + 0.4 * np.sin(2 * np.pi * t(d + 1) / 4.0) ** 2
x = int(SR * 1.0)
loop = w[:int(SR * d)].copy()
loop[:x] = loop[:x] * np.linspace(0, 1, x) + w[int(SR * d):int(SR * d) + x] * np.linspace(1, 0, x)
save("wind_loop", loop, 0.5)
print("sounds written to", os.path.normpath(OUT))
