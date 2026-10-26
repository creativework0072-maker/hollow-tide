"""Generates all Hollow Tide sound effects and the background music (Week 3).
Run:  python tools/make_audio.py   (needs NumPy)
Everything is synthesised from sine/saw waves and filtered noise, then written
as 16-bit mono WAV files."""
import os, wave
import numpy as np

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(5)

def write(name, data, sr, peak=0.8):
    data = data / (np.max(np.abs(data)) + 1e-9) * peak
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
        w.writeframes((data * 32767).astype("<i2").tobytes())

def lowpass(x, k):                       # simple moving-average low-pass
    return np.convolve(x, np.ones(k)/k, mode="same")

def tone(freq, dur, sr, decay=6.0, harm=0.25):
    t = np.arange(int(dur*sr))/sr
    f = freq if np.ndim(freq) else np.full_like(t, freq)
    ph = 2*np.pi*np.cumsum(f)/sr
    return (np.sin(ph) + harm*np.sin(2*ph)) * np.exp(-decay*t)

SR = 22050

# --- Jump: quick rising sweep ---
t = np.linspace(0, 1, int(.18*SR)); write("sfx_jump.wav", tone(280+300*t, .18, SR, decay=9), SR)

# --- Pearl pickup: two bright chime notes ---
a = tone(1318.5, .35, SR, decay=9); b = tone(1975.5, .35, SR, decay=9)
pearl = np.zeros(int(.5*SR)); pearl[:len(a)] += a*.8; s = int(.1*SR); pearl[s:s+len(b)] += b
write("sfx_pearl.wav", pearl, SR)

# --- Splash: filtered noise burst + bubble blip ---
n = int(.45*SR); tt = np.arange(n)/SR
splash = lowpass(rng.standard_normal(n), 6) * np.exp(-9*tt) * (1 - np.exp(-200*tt))
bub = np.zeros(n); blip = tone(np.linspace(400, 900, int(.12*SR)), .12, SR, decay=18); bub[int(.05*SR):int(.05*SR)+len(blip)] = blip*.4
write("sfx_splash.wav", splash + bub, SR)

# --- Tide change: deep swelling rumble ---
n = int(1.6*SR); tt = np.arange(n)/SR
swell = np.sin(np.pi*tt/1.6)**2
rumble = lowpass(rng.standard_normal(n), 110)*6 + np.sin(2*np.pi*np.cumsum(55+30*tt/1.6)/SR)
write("sfx_tide.wav", rumble*swell, SR, 0.7)

# --- Hurt: descending buzzy saw ---
n = int(.4*SR); tt = np.arange(n)/SR; f = 420 - 300*tt/.4
saw = 2*((np.cumsum(f)/SR) % 1) - 1
write("sfx_hurt.wav", lowpass(saw, 3)*np.exp(-5*tt), SR)

# --- Level complete: rising arpeggio ---
notes = [523.25, 659.25, 783.99, 1046.5]; win = np.zeros(int(1.7*SR))
for i, fq in enumerate(notes):
    d = tone(fq, 1.0 if i == 3 else .3, SR, decay=3 if i == 3 else 8); s = int(i*.14*SR); win[s:s+len(d)] += d
write("sfx_win.wav", win, SR)

# --- Background music: 32 s ambient loop (Am - F - C - G), seamless ---
MR = 16000; DUR = 32; N = DUR*MR; music = np.zeros(N)
chords = [([220, 261.63, 329.63], 55, [440, 523.25, 659.25, 880]),
          ([174.61, 220, 261.63], 43.65, [349.23, 440, 523.25, 698.46]),
          ([261.63, 329.63, 392], 65.41, [523.25, 659.25, 784, 1046.5]),
          ([196, 246.94, 293.66], 49, [392, 493.88, 587.33, 783.99])]

def add(sig, start):                      # add with wrap-around so the loop is seamless
    idx = (start + np.arange(len(sig))) % N; np.add.at(music, idx, sig)

for ci, (pad, bass, plucks) in enumerate(chords):
    start = int((ci*8 - 1)*MR); L = 10*MR; tt = np.arange(L)/MR
    env = np.sin(np.pi*tt/10)**1.5
    for fq in pad:
        for det in (0.997, 1.003):
            add(np.sin(2*np.pi*fq*det*tt)*env*0.10, start)
    add(np.sin(2*np.pi*bass*tt)*env*0.22, start)
    for k in range(8):                    # one soft pluck per second
        fq = plucks[int(rng.integers(0, 4))]; p = tone(fq, 2.0, MR, decay=2.6, harm=0.1)
        add(p*0.07, int((ci*8 + k)*MR + rng.integers(0, int(.15*MR))))

# slow "ocean" noise swell, period = 8 s
noise = lowpass(rng.standard_normal(N), 44)*3
music += noise*(0.5+0.5*np.sin(2*np.pi*np.arange(N)/(8*MR)))*0.05
# wrap-around echoes give a cheap reverb without breaking the loop
music = music + 0.35*np.roll(music, int(.37*MR)) + 0.25*np.roll(music, int(.53*MR))
write("music_theme.wav", music, MR, 0.6)
print("audio done:", sorted(os.listdir(OUT)))
