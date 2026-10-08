#!/usr/bin/env python3
"""Sons de energia das skills (08/10/2026): carga em laço por escola, liberação e impacto forte.

Espírito "anime de luta" (zumbido elétrico com grave rugindo e crepitar; estouro com whoosh;
estalo seco com grave), mas tudo é síntese original do projeto. As únicas amostras externas são
CC0 da Kenney (Impact Sounds e Sci-Fi Sounds), passadas como camada de ataque nos disparos e
impactos — ver assets/audio/LICENSES.md.

Uso (precisa de numpy; ffmpeg no PATH):
    python3 tools/audio/gen_skill_energy.py --kenney <pasta com os zips da Kenney extraídos>
Sem --kenney, gera só as cargas (100% síntese).
"""
import argparse
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

SR = 44100
PEAK = 10 ** (-3.3 / 20)  # −3 dBFS com folga para o arredondamento do Vorbis
OUT = Path(__file__).resolve().parents[2] / "assets/audio/sfx"
LOOP_SEC = 2.0  # frequências múltiplas de 1/LOOP_SEC = 0,5 Hz fecham o laço sem emenda


# ---------------------------------------------------------------- utilidades

def to_ogg(x: np.ndarray, name: str, out_dir: Path) -> Path:
    x = np.clip(x, -1.0, 1.0)
    pcm = (x * 32767).round().astype("<i2")
    out = out_dir / f"{name}.ogg"
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = Path(tmp) / "a.wav"
        with wave.open(str(wav_path), "wb") as f:
            f.setparams((1, 2, SR, 0, "NONE", "not compressed"))
            f.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path), "-ar", str(SR), "-ac", "1",
                        "-c:a", "libvorbis", "-q:a", "6", str(out)], check=True)
    return out


def load(path: Path) -> np.ndarray:
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", str(path), "-ac", "1", "-ar", str(SR),
                          "-f", "f32le", "-"], check=True, capture_output=True).stdout
    return np.frombuffer(raw, np.float32).astype(np.float64)


def normalize(x: np.ndarray) -> np.ndarray:
    x = x - x.mean()
    return x * (PEAK * 0.93 / np.max(np.abs(x)))  # o Vorbis estoura uns décimos de dB


def fades(x: np.ndarray, attack: float = 0.003, release: float = 0.03) -> np.ndarray:
    """Sem clique: rampa cosseno no começo e no fim."""
    a, r = int(attack * SR), int(release * SR)
    x = x.copy()
    x[:a] *= 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, a))
    x[-r:] *= 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, r))
    return x


def spectral(x: np.ndarray, gain_fn) -> np.ndarray:
    """Filtro circular no domínio da frequência (mantém o laço periódico)."""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(spec * gain_fn(f), len(x))


def band(lo: float, hi: float, soft: float = 0.25):
    def g(f):
        f = np.maximum(f, 1e-3)
        low = 1 / (1 + (lo / f) ** (2 / soft)) if lo > 0 else 1.0
        high = 1 / (1 + (f / hi) ** (2 / soft))
        return low * high
    return g


def sat(x: np.ndarray, drive: float) -> np.ndarray:
    return np.tanh(drive * x) / np.tanh(drive)


def noise(n: int, rng) -> np.ndarray:
    return rng.standard_normal(n)


def env_exp(n: int, tau: float, attack: float = 0.002) -> np.ndarray:
    t = np.arange(n) / SR
    e = np.exp(-t / tau)
    a = int(attack * SR)
    if a > 0:
        e[:a] *= np.linspace(0, 1, a)
    return e


def sweep_tone(n: int, f0: float, f1: float, curve: float, harmonics=(1.0,)) -> np.ndarray:
    """Seno com frequência indo de f0 a f1 (exponencial)."""
    t = np.linspace(0, 1, n)
    freq = f0 * (f1 / f0) ** (t ** curve)
    phase = 2 * np.pi * np.cumsum(freq) / SR
    return sum(a * np.sin((k + 1) * phase) for k, a in enumerate(harmonics))


def sweeping_noise(n: int, rng, f_start: float, f_end: float, q: float = 1.2) -> np.ndarray:
    """Ruído num passa-faixa (SVF) cuja frequência desliza — o "whoosh"."""
    x = noise(n, rng)
    t = np.linspace(0, 1, n)
    fc = f_start * (f_end / f_start) ** t
    g = np.tan(np.pi * np.minimum(fc, SR * 0.45) / SR)
    k = 1 / q
    out = np.empty(n)
    ic1 = ic2 = 0.0
    for i in range(n):
        gi = g[i]
        a1 = 1 / (1 + gi * (gi + k))
        v3 = x[i] - ic2
        v1 = a1 * ic1 + gi * a1 * v3
        v2 = ic2 + gi * v1
        ic1 = 2 * v1 - ic1
        ic2 = 2 * v2 - ic2
        out[i] = v1  # passa-faixa
    return out


def short_reverb(x: np.ndarray, rng, tail: float = 0.12, wet: float = 0.18) -> np.ndarray:
    n = int(tail * SR)
    ir = noise(n, rng) * np.exp(-np.arange(n) / (SR * tail / 5))
    ir = spectral(np.pad(ir, (0, len(x))), band(150, 6000))[:n]
    y = np.convolve(x, ir)[: len(x)]
    y *= wet * np.max(np.abs(x)) / (np.max(np.abs(y)) + 1e-9)
    return x + y


def fit(x: np.ndarray, n: int) -> np.ndarray:
    return x[:n] if len(x) >= n else np.pad(x, (0, n - len(x)))


# ---------------------------------------------------------------- carga (laço)

def periodic_buzz(n: int, f0: float, vib_rate: float, vib_depth: float, max_hz: float = 7000) -> np.ndarray:
    """Dente-de-serra limitada em banda, com vibrato; f0 e vib_rate múltiplos de 0,5 Hz."""
    t = np.arange(n) / SR
    phase = 2 * np.pi * f0 * t + vib_depth * np.sin(2 * np.pi * vib_rate * t)
    out = np.zeros(n)
    k = 1
    while k * f0 < max_hz:
        out += np.sin(k * phase) / k
        k += 1
    return out


def periodic_crackle(n: int, rng, count: int, lo: float, hi: float, decay_ms: float) -> np.ndarray:
    """Faíscas: impulsos esparsos com decaimento, filtrados em circular (cabem no laço)."""
    x = np.zeros(n)
    pos = rng.integers(0, n, count)
    x[pos] = rng.choice([-1, 1], count) * rng.uniform(0.2, 1.0, count) ** 2
    k = np.exp(-np.arange(n) / (SR * decay_ms / 1000))
    x = np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(k), n)
    return spectral(x, band(lo, hi))


def pulse_lfo(n: int, rate: float, sharp: float) -> np.ndarray:
    t = np.arange(n) / SR
    return (0.5 + 0.5 * np.sin(2 * np.pi * rate * t)) ** sharp


def charge_loop(school: str, rng) -> np.ndarray:
    n = int(LOOP_SEC * SR)
    t = np.arange(n) / SR
    p = {
        #            f0     vib  rumble wah_lo wah_hi wah_rate crackle crk_lo  whine
        "generic": (82.0, 5.5, 1.00, 2200, 4200, 3.0, 220, 2500, 0.10),
        "blade":   (55.0, 4.0, 1.60, 1100, 2600, 2.5, 140, 1200, 0.00),
        "arcane":  (110.0, 7.0, 0.55, 3000, 6500, 4.0, 420, 3500, 0.22),
        "support": (220.0, 3.0, 0.25, 2000, 6000, 1.0, 60, 4000, 0.0),
    }[school]
    f0, vib, rumble_amt, wah_lo, wah_hi, wah_rate, crackles, crk_lo, whine_amt = p

    # Grave rugindo: ruído 25–220 Hz com "respiração" lenta + sub distorcido.
    rumble = spectral(noise(n, rng), band(25, 220, 0.4))
    rumble /= np.std(rumble)
    rumble *= 0.75 + 0.25 * np.sin(2 * np.pi * 1.5 * t + 0.7)
    sub = sat(np.sin(2 * np.pi * (f0 / 2 if f0 > 60 else f0) * t) * 0.8
              + 0.2 * np.sin(2 * np.pi * f0 * t), 2.5)
    low = rumble_amt * (0.22 * rumble + 0.30 * sub)

    # Zumbido elétrico: serra com vibrato + leve distorção.
    buzz = periodic_buzz(n, f0, vib, 0.6 if school != "support" else 0.15)
    buzz = sat(buzz * 0.6, 2.0 if school in ("blade", "generic") else 1.4)
    buzz = spectral(buzz, band(40, 6000))
    buzz /= np.max(np.abs(buzz))

    # Banda pulsante "uá-uá" nos agudos (aura), como o pulso de ~3 Hz da referência.
    wah = spectral(noise(n, rng), band(wah_lo, wah_hi, 0.3))
    wah /= np.std(wah)
    wah *= pulse_lfo(n, wah_rate, 3.0)

    crack = periodic_crackle(n, rng, int(crackles * LOOP_SEC), crk_lo, 14000, 1.5)
    crack /= np.max(np.abs(crack)) + 1e-9

    whine = np.sin(2 * np.pi * 1760 * t + 0.8 * np.sin(2 * np.pi * 6.0 * t)) * whine_amt

    if school == "support":
        # Suave: acorde de senos (lá maior aberto) com respiração lenta e brilho de ar.
        chord = sum(a * np.sin(2 * np.pi * f * t + 0.3 * np.sin(2 * np.pi * 1.0 * t + i))
                    for i, (f, a) in enumerate([(220, 0.5), (330, 0.35), (440, 0.3), (660, 0.15), (880, 0.1)]))
        chord *= 0.8 + 0.2 * np.sin(2 * np.pi * 0.5 * t)
        x = 0.55 * chord + 0.12 * buzz + 0.07 * wah + 0.06 * crack + low
    else:
        x = low + 0.33 * buzz + 0.10 * wah + 0.20 * crack + whine
        if school == "blade":
            x = sat(x / np.max(np.abs(x)) * 1.4, 1.3)
    # Laços com a mesma intensidade média (−12 dBFS RMS): o jogo controla o volume pela carga.
    x = x - x.mean()
    x *= 10 ** (-12 / 20) / np.sqrt(np.mean(x ** 2))
    return PEAK * np.tanh(x / PEAK)  # limitador suave: pico nunca passa de −3 dBFS


# ---------------------------------------------------------------- liberação e impacto

def release(variant: str, rng, kenney: Path) -> np.ndarray:
    n = int({"generic": 0.95, "heavy": 1.15, "support": 0.9}[variant] * SR)
    if variant == "support":
        shimmer = sweep_tone(n, 520, 1900, 0.6, (1.0, 0.25, 0.1)) * env_exp(n, 0.28, 0.01)
        air = sweeping_noise(n, rng, 1500, 6000, 0.9) * env_exp(n, 0.22, 0.02)
        ff = fit(load(kenney / "scifi/Audio/forceField_001.ogg"), n) * env_exp(n, 0.3)
        x = 0.5 * shimmer + 0.5 * air / np.max(np.abs(air)) + 0.35 * ff / np.max(np.abs(ff))
        return normalize(fades(short_reverb(x, rng, 0.25, 0.25), 0.004, 0.06))

    heavy = variant == "heavy"
    src = "scifi/Audio/explosionCrunch_000.ogg" if heavy else "scifi/Audio/lowFrequency_explosion_001.ogg"
    blast = fit(load(kenney / src), n)
    blast = blast / np.max(np.abs(blast)) * env_exp(n, 0.35 if heavy else 0.25)
    whoosh = sweeping_noise(n, rng, 5500, 350 if heavy else 600, 1.4) * env_exp(n, 0.32, 0.012)
    whoosh /= np.max(np.abs(whoosh))
    zap = sweep_tone(n, 1100 if not heavy else 700, 140, 0.45, (1.0, 0.5, 0.3, 0.2)) * env_exp(n, 0.18, 0.003)
    boom = sweep_tone(n, 85, 38, 0.5) * env_exp(n, 0.33 if heavy else 0.22, 0.004)
    crack = spectral(noise(n, rng) * env_exp(n, 0.012, 0.0005), band(2500, 15000))
    x = 0.55 * blast + 0.55 * whoosh + 0.25 * zap + (0.9 if heavy else 0.65) * boom \
        + 0.4 * crack / np.max(np.abs(crack))
    x = sat(x, 1.8)
    return normalize(fades(short_reverb(x, rng, 0.16), 0.002, 0.05))


def impact(idx: int, rng, kenney: Path) -> np.ndarray:
    n = int(0.48 * SR)
    src, thump_hz, crack_amt = [("impactPunch_heavy_001", 95, 0.55),
                                ("impactPunch_heavy_003", 80, 0.65),
                                ("impactPunch_heavy_004", 110, 0.5)][idx]
    punch = fit(load(kenney / f"impact/Audio/{src}.ogg"), n)
    punch /= np.max(np.abs(punch))
    thump = sweep_tone(n, thump_hz, 42, 0.4, (1.0, 0.3)) * env_exp(n, 0.11, 0.001)
    crack = spectral(noise(n, rng) * env_exp(n, 0.008, 0.0003), band(1800, 14000))
    crack /= np.max(np.abs(crack))
    body = spectral(noise(n, rng) * env_exp(n, 0.04, 0.001), band(150, 1200))
    body /= np.max(np.abs(body))
    x = 0.7 * punch + 0.85 * thump + crack_amt * crack + 0.25 * body
    x = sat(x, 2.2)
    return normalize(fades(short_reverb(x, rng, 0.1, 0.14), 0.0015, 0.04))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--kenney", type=Path, help="pasta com impact/ e scifi/ (zips da Kenney extraídos)")
    ap.add_argument("--out", type=Path, default=OUT)
    args = ap.parse_args()
    rng = np.random.default_rng(8102026)
    for school in ("generic", "blade", "arcane", "support"):
        name = "sfx_skill_charge_loop" + ("" if school == "generic" else f"_{school}")
        print(to_ogg(charge_loop(school, rng), name, args.out))
    if args.kenney is None:
        return
    for variant, name in (("generic", "sfx_skill_release"), ("heavy", "sfx_skill_release_2"),
                          ("support", "sfx_skill_release_support")):
        print(to_ogg(release(variant, rng, args.kenney), name, args.out))
    for i, name in enumerate(("sfx_skill_impact", "sfx_skill_impact_2", "sfx_skill_impact_3")):
        print(to_ogg(impact(i, rng, args.kenney), name, args.out))


if __name__ == "__main__":
    main()
