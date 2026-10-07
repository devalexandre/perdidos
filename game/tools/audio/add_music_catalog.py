#!/usr/bin/env python3
"""Acrescenta ao catálogo as músicas das capitais, da abertura, do Campo de Treino e o título noturno (28/09/2026)."""
import json
from pathlib import Path

CAT = Path(__file__).with_name("sound_catalog.json")
NO = ("Instrumental only, no vocals, loopable, ends on the tonic. Original composition in the spirit of classic "
      "2000s fantasy MMORPG town themes (warm, melodic, memorable), not imitating any existing game.")

c = json.loads(CAT.read_text())
m = {x["name"]: x for x in c["music"]}
m["mus_title"] = {"name": "mus_title", "length_ms": 120000, "prompt":
    "Mysterious and wondrous title theme for a fantasy MMORPG: moonlit night, a distant world calling. Soft celesta and "
    "harp arpeggios, a lonely bamboo flute melody, warm strings swelling slowly, a viola caipira motif appearing in the "
    "middle like a memory of home, gentle wordless choir pad, subtle shimmering bells like falling golden petals. "
    "Melancholic but hopeful. " + NO}
m["mus_arrival"] = {"name": "mus_arrival", "length_ms": 60000, "prompt":
    "Cinematic 55-second opening for a fantasy game: quiet everyday city dusk with soft piano, a single chime as a golden "
    "petal falls, time stops (sustained strings), a swelling orchestral fall through the stars with harp glissandi and "
    "wordless choir pad, bright reveal of a lush new world with viola caipira and flute, ends softly like a calm river. " + NO}
m["mus_training_field"] = {"name": "mus_training_field", "length_ms": 150000, "prompt":
    "Adventurous yet friendly theme for a training field where travelers from many lands learn to fight: light snare and "
    "hand drums, pizzicato strings, bamboo flute and fiddle trading a cheerful heroic melody, brass hints, positive "
    "energy, not intense. " + NO}
capitals = {
    "mus_city_fiandouro": "Portuguese-inspired medieval port town: Portuguese-guitar-like plucked strings, accordion-like reed pad, gentle saudade melody, sea breeze, warm and nostalgic",
    "mus_city_heptastila": "Ancient-Greek-inspired coastal city of seven columns: lyre and aulos-like double reed, frame drum, sunny Aegean modes, noble and serene",
    "mus_city_seshares": "Ancient-Egyptian-inspired desert city of scribes along a great river: harp, oud-like lute, reed flute, soft frame drum, mysterious modes, golden and calm",
    "mus_city_mil_degraus": "Chinese-inspired misty mountain city of a thousand steps: guzheng and erhu, bamboo flute, soft wind chimes, tranquil and elegant",
    "mus_city_akarimachi": "Japanese-inspired lantern-lit town: koto and shakuhachi, soft taiko, gentle pentatonic melody, peaceful evening feel",
    "mus_city_lumefiorde": "Nordic-inspired fjord town under northern lights: hardanger-fiddle-like strings, drone, deep frame drum, cold air, majestic and cozy by the fire",
    "mus_city_zharogrado": "Slavic-inspired town among birch forests: balalaika and gusli-like plucked strings, accordion, lively folk dance rhythm slowing into a warm melody",
    "mus_city_dunbruma": "Celtic-inspired misty green hills town: celtic harp, tin whistle, fiddle, bodhran, lilting jig feel, cozy tavern warmth",
    "mus_city_itzcalli": "Mesoamerican-inspired jungle city of obsidian and jade: clay ocarina, wooden slit drum, marimba-like mallets, bright and rhythmic",
}
for k, v in capitals.items():
    m[k] = {"name": k, "length_ms": 150000, "prompt": "Instrumental town theme for a fantasy MMORPG capital city. " + v + ". " + NO}
c["music"] = list(m.values())
CAT.write_text(json.dumps(c, indent=1, ensure_ascii=False))
print(len(c["music"]), "músicas:", [x["name"] for x in c["music"]])
