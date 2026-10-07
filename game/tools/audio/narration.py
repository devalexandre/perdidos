#!/usr/bin/env python3
"""Narração da abertura (ElevenLabs TTS, modelo multilíngue) a partir de localization/cutscene.csv.

Uso:
  python3 tools/audio/narration.py --samples DIR          # amostras pt-BR com as vozes candidatas
  python3 tools/audio/narration.py --narrator ID --boatman ID [--langs pt_BR,en,es,fr,de,ja]
Saída: assets/cutscenes/arrival/voice/<idioma>/<CHAVE>.ogg (uma fala por legenda).
Chave: ELEVENLABS_API_KEY, ~/.zshrc ou ~/.emma/config.json (nunca impressa, nunca copiada para o repo).
"""
import argparse, csv, json, subprocess, sys, tempfile, urllib.request, urllib.error
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from gen_audio import api_key  # mesma busca de chave

ROOT = Path(__file__).resolve().parents[2]
CSV = ROOT / "localization/cutscene.csv"
OUT = ROOT / "assets/cutscenes/arrival/voice"
MODEL = "eleven_multilingual_v2"
BOATMAN_KEYS = {"CUTSCENE_ARRIVAL_13"}
# Vozes pré-prontas da biblioteca pública do ElevenLabs (IDs públicos, não são segredo).
NARRATORS = {"george": "JBFqnCBsd6RMkjVDRZzb", "brian": "nPczCjzI2devNBz1zQrb",
             "alice": "Xb7hH8MSUJpSbSDYk0k2", "matilda": "XrExE9yKIg1WjnLlVkGX"}
BOATMEN = {"bill": "pqHfZKP75CyOMGZ6Nk2i", "clyde": "2EiwWnXFnvU5JabPnv8n"}
SETTINGS = {"stability": 0.55, "similarity_boost": 0.75, "style": 0.35, "use_speaker_boost": True}
# Narrador = o deus supremo deste mundo contando a história (voz velha, lenta e solene). Decisão do dono, 27/09/2026.
NARRATOR_SETTINGS = {"stability": 0.7, "similarity_boost": 0.8, "style": 0.45, "use_speaker_boost": True, "speed": 0.88}

def tts(key: str, voice: str, text: str, lang: str, settings: dict = SETTINGS) -> bytes:
    body = {"text": text.lstrip("— ").strip(), "model_id": MODEL, "voice_settings": settings}
    req = urllib.request.Request(f"https://api.elevenlabs.io/v1/text-to-speech/{voice}?output_format=mp3_44100_128",
                                 data=json.dumps(body).encode(),
                                 headers={"xi-api-key": key, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()

def to_ogg(mp3: bytes, out: Path) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".mp3") as t:
        t.write(mp3); t.flush()
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", t.name, "-ac", "1", "-c:a", "libvorbis", "-q:a", "5", str(out)], check=True)

def lines() -> dict:
    rows = list(csv.reader(CSV.open(encoding="utf-8")))
    langs = rows[0][1:]
    return {r[0]: dict(zip(langs, r[1:])) for r in rows[1:] if r[0].startswith("CUTSCENE_ARRIVAL_")}

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--samples"); ap.add_argument("--narrator"); ap.add_argument("--boatman")
    ap.add_argument("--langs", default="pt_BR,en,es,fr,de,ja")
    a = ap.parse_args()
    key, L = api_key(), lines()
    if a.samples:
        d = Path(a.samples)
        intro = L["CUTSCENE_ARRIVAL_01"]["pt_BR"] + " " + L["CUTSCENE_ARRIVAL_02"]["pt_BR"] + " " + L["CUTSCENE_ARRIVAL_05"]["pt_BR"]
        for name, vid in NARRATORS.items():
            try: to_ogg(tts(key, vid, intro, "pt_BR"), d / f"narrador_{name}.ogg"); print("ok narrador", name)
            except urllib.error.HTTPError as e: print("ERRO narrador", name, e.code)
        for name, vid in BOATMEN.items():
            try: to_ogg(tts(key, vid, L["CUTSCENE_ARRIVAL_13"]["pt_BR"], "pt_BR"), d / f"barqueiro_{name}.ogg"); print("ok barqueiro", name)
            except urllib.error.HTTPError as e: print("ERRO barqueiro", name, e.code)
        return
    narrator = NARRATORS.get(a.narrator, a.narrator); boatman = BOATMEN.get(a.boatman, a.boatman)
    for lang in a.langs.split(","):
        for k, texts in sorted(L.items()):
            text = texts.get(lang, "")
            if not text:
                continue
            is_boat = k in BOATMAN_KEYS
            to_ogg(tts(key, boatman if is_boat else narrator, text, lang, SETTINGS if is_boat else NARRATOR_SETTINGS),
                   OUT / lang / f"{k}.ogg")
            print("ok", lang, k)

if __name__ == "__main__":
    main()
