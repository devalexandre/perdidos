import json
import os
import subprocess
import tempfile
from pathlib import Path
from urllib.request import Request, urlopen


API_URL = "https://api.elevenlabs.io/v1/music?output_format=mp3_44100_128"
PROMPT = (
    "Original instrumental tragic folk-fantasy game score for the death of a kind, "
    "cursed Brazilian countryside man. Slow 58 BPM, intimate and restrained. "
    "A plaintive Brazilian viola caipira motif over soft cello and sparse wooden flute, "
    "warm organic room tone, grief without melodrama, a small unresolved final phrase. "
    "No vocals, no percussion, no modern synths, no bombastic orchestral hits, "
    "no reference to existing songs or artists."
)


def main() -> None:
    api_key = os.environ.get("ELEVENLABS_API_KEY")
    if not api_key:
        raise SystemExit("Set ELEVENLABS_API_KEY in the environment and rerun this script.")

    payload = json.dumps({
        "prompt": PROMPT,
        "music_length_ms": 45000,
        "model_id": "music_v2_5",
        "force_instrumental": True,
    }).encode("utf-8")
    request = Request(API_URL, data=payload, headers={
        "Content-Type": "application/json",
        "xi-api-key": api_key,
    })

    project_root = Path(__file__).resolve().parents[2]
    output_path = project_root / "assets/audio/music/mus_werewolf_death.ogg"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with urlopen(request, timeout=180) as response, tempfile.NamedTemporaryFile(suffix=".mp3") as source:
        source.write(response.read())
        source.flush()
        subprocess.run([
            "ffmpeg", "-y", "-i", source.name, "-c:a", "libvorbis", "-q:a", "5",
            str(output_path),
        ], check=True)
    print(f"Generated {output_path}")


if __name__ == "__main__":
    main()