#!/usr/bin/env python3
"""Gera música e efeitos com ElevenLabs a partir de sound_catalog.json.

Uso: ELEVENLABS_API_KEY=... python3 tools/audio/gen_audio.py [--only nome1,nome2] [--preview DIR] [--install] [--dry-run]
Padrão: gera em --preview (fora do projeto) para ouvir e comparar com a versão CC0 atual.
--install: grava direto em assets/audio/{music,sfx}/ (substitui) e registra em assets/audio/LICENSES.md.
Requer plano PAGO do ElevenLabs (licença comercial). Nunca imprime a chave.
"""
import argparse, datetime, json, os, re, subprocess, sys, tempfile, urllib.request, urllib.error
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CATALOG = Path(__file__).with_name("sound_catalog.json")
MUSIC_DIR, SFX_DIR = ROOT / "assets/audio/music", ROOT / "assets/audio/sfx"
LICENSES = ROOT / "assets/audio/LICENSES.md"
API = "https://api.elevenlabs.io/v1"

def api_key() -> str:
    k = os.environ.get("ELEVENLABS_API_KEY", "")
    secrets = Path.home() / ".config" / "perdidos" / "secrets.env"  # chave do jogo (fora do repositório, chmod 600)
    if not k and secrets.exists():
        m = re.search(r"ELEVENLABS_API_KEY=[\"']?([^\"'\s]+)", secrets.read_text())
        k = m.group(1) if m else ""
    if not k:  # também aceita a variável definida no ~/.zshrc
        rc = Path.home() / ".zshrc"
        if rc.exists():
            m = re.search(r"ELEVENLABS_API_KEY=[\"']?([^\"'\s]+)", rc.read_text())
            k = m.group(1) if m else ""
    if not k:  # chave da Emma (~/.emma/config.json → voice.elevenlabs_api_key); nunca copiada para o repo
        cfg = Path.home() / ".emma" / "config.json"
        if cfg.exists():
            try:
                k = (json.loads(cfg.read_text()).get("voice", {}).get("elevenlabs_api_key") or "").strip()
            except (ValueError, OSError):
                k = ""
    if not k:
        sys.exit("ELEVENLABS_API_KEY não definida")
    return k

def post(path: str, body: dict, key: str) -> bytes:
    req = urllib.request.Request(API + path, data=json.dumps(body).encode(),
                                 headers={"xi-api-key": key, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=600) as r:
            return r.read()
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"HTTP {e.code}: {e.read()[:300]!r}")

def to_ogg(mp3: bytes, out: Path, quality: int) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".mp3") as tmp:
        tmp.write(mp3); tmp.flush()
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name, "-c:a", "libvorbis",
                        "-q:a", str(quality), str(out)], check=True)

SECTION = "## Gerado com ElevenLabs"

def record(name: str, kind: str, prompt: str) -> None:
    # remove a linha antiga desse arquivo (CC0 ou ElevenLabs) e registra na seção do ElevenLabs
    lines = [l for l in (LICENSES.read_text().splitlines() if LICENSES.exists() else ["# Licenças de áudio"])
             if not l.startswith(f"| {name}.ogg ")]
    if SECTION not in lines:
        lines += ["", SECTION, "", "| Arquivo | Fonte | Licença | Data | Prompt |", "|---|---|---|---|---|"]
    lines.append(f"| {name}.ogg | ElevenLabs ({kind}) | Plano pago — licença comercial, sem atribuição | "
                 f"{datetime.date.today()} | {prompt.replace('|', '/')} |")
    LICENSES.write_text("\n".join(lines) + "\n")

def jobs(cat: dict, phase: str = ""):
    for m in cat["music"]:
        if phase and phase != "city":
            break
        yield m["name"], "music", MUSIC_DIR, m["prompt"], {"prompt": m["prompt"], "music_length_ms": m["length_ms"], "force_instrumental": True}
    for s in cat["sfx"]:
        if phase and s.get("phase", "city") != phase:
            continue
        yield s["name"], "sfx", SFX_DIR, s["prompt"], {"text": s["prompt"], "duration_seconds": s["seconds"], "loop": s.get("loop", False), "prompt_influence": 0.5}
    fs = cat["footsteps"]
    if phase and phase != "city":
        return
    for surf, desc in fs["surfaces"].items():
        for i in range(1, fs["variants"] + 1):
            p = desc + fs["prompt_suffix"]
            yield f"sfx_step_{surf}_{i}", "sfx", SFX_DIR, p, {"text": p, "duration_seconds": fs["seconds"], "prompt_influence": 0.6}

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default=""); ap.add_argument("--phase", default="", help="city, combat, cutscene, f3 ou f4 (vazio = todas)"); ap.add_argument("--install", action="store_true"); ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--preview", default=str(Path(tempfile.gettempdir()) / "elevenlabs_preview"))
    a = ap.parse_args()
    only = set(filter(None, a.only.split(",")))
    cat = json.loads(CATALOG.read_text())
    todo = [j for j in jobs(cat, a.phase) if not only or j[0] in only]
    print(f"{len(todo)} arquivo(s) a gerar")
    if a.dry_run:
        for j in todo:
            print(" -", j[0])
        return
    key = api_key()
    for name, kind, out_dir, prompt, body in todo:
        try:
            audio = post("/music" if kind == "music" else "/sound-generation", body, key)
            dest = (out_dir if a.install else Path(a.preview)) / f"{name}.ogg"
            to_ogg(audio, dest, 5 if kind == "music" else 4)
            if a.install:
                record(name, kind, prompt)
            print("ok ", name)
        except Exception as e:
            print("ERRO", name, e)

if __name__ == "__main__":
    main()
