#!/usr/bin/env python3
"""Static validation of map scenes (scenes/maps) and zones (data/zones), no Godot needed.

Mirrors the map rules of tests/beta/test_content_links.gd so a generator fails before Godot does:
  - root is a GameMap (res://scripts/shared/map.gd) with map_id == file name; every res:// exists;
  - every zone has a scene and vice versa; zone name_key has a pt_BR translation;
  - grid navmesh (2 m quads): SpawnPoint walkable; portals, arrival markers, packs and lairs are
    reachable from the SpawnPoint; packs sit on walkable ground (warning if not fully inside);
  - Spawns/: monster exists, stage 1-2 (stage 3/4 only in BossLairs/), level near the zone range;
  - BossLairs/: monster exists and has a boss stage (3); the zone allows bosses;
  - portals: destination exists and is in connected_maps; arrival marker exists in the destination;
    two-way portals have a portal back and the destination lists this map; one-way portals are the
    boss escape (requires_boss_victory + BossLairs/); no portal to the map itself;
  - connected_maps entries exist, are used by a portal and list this map back;
  - interact_id unique in the map (error); portal interact_id unique in the world (warning).

Usage: python3 tools/world/validate_world.py [map_id ...]   (no args = every map; exit 1 on errors)
Reads through worldgen (so a generator in --check mode validates what it would write).
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import worldgen as wg  # noqa: E402

MAP_DIR = wg.GAME_DIR / "scenes/maps"
ZONE_DIR = wg.GAME_DIR / "data/zones"
MONSTER_DIR = wg.GAME_DIR / "data/monsters"
LOC_DIR = wg.GAME_DIR / "localization"
PLANNED_PORTALS = {"arena_burning"}
TRAINING_MAP = "training_field"
STAGE_BOSS = 3
## Spawn level vs. zone range: dungeon trash may sit below the recommended range (bosses and
## stage 2 carry the top end), never far above it.
LEVEL_BELOW = 10
LEVEL_ABOVE = 5

DEFAULT_MAP_ID = "city_awakening"  # GameMap.map_id default

_cache: dict = {}


def _is_game_map_script(res_path: str) -> bool:
    """map.gd itself or a script that extends GameMap (e.g. cave_level.gd)."""
    if res_path == wg.MAP_SCRIPT:
        return True
    p = wg.res_to_path(res_path) if res_path.startswith("res://") else None
    return p is not None and wg.exists(p) and re.search(r"(?m)^extends GameMap\b", wg.read_text(p)) is not None


# ---------------------------------------------------------------------------
# Parsing
# ---------------------------------------------------------------------------
def _ids(directory: Path, ext: str) -> set:
    out = {p.stem for p in directory.glob("*" + ext)}
    out |= {p.stem for p in wg.OVERLAY if p.parent == directory and p.suffix == ext}
    return out


def _props(block: str) -> dict:
    out = {}
    for line in block.split("\n")[1:]:
        m = re.match(r"^([\w/]+) = (.*)$", line)
        if m:
            out[m.group(1)] = m.group(2).strip()
    return out


def _sn(v) -> str:
    """&"x" / "x" -> x"""
    if v is None:
        return ""
    m = re.match(r'^&?"(.*)"$', v)
    return m.group(1) if m else v


def _vec(v):
    nums = [float(x) for x in re.findall(r"-?\d+(?:\.\d+)?", re.sub(r"^\w+\(", "", v or ""))]
    return tuple(nums[:3]) if len(nums) >= 3 else None


def parse_scene(map_id: str) -> dict:
    text = wg.read_text(MAP_DIR / f"{map_id}.tscn")
    ext = {m.group(2): m.group(1) for m in re.finditer(r'\[ext_resource [^\]]*path="([^"]+)" id="([^"]+)"\]', text)}
    blocks = re.split(r"(?m)^(?=\[)", text)
    nodes = []
    navmesh = {}
    for b in blocks:
        h = re.match(r'\[node name="([^"]+)" type="([^"]+)"(?: parent="([^"]+)")?', b)
        if h:
            nodes.append({"name": h.group(1), "type": h.group(2), "parent": h.group(3), "props": _props(b)})
            continue
        s = re.match(r'\[sub_resource type="NavigationMesh" id="([^"]+)"\]', b)
        if s:
            navmesh[s.group(1)] = b
    root = next((n for n in nodes if n["parent"] is None), None)
    return {"text": text, "ext": ext, "nodes": nodes, "root": root, "navmesh": navmesh}


def grid_cells(scene: dict):
    """Cells of a 2 m quad navmesh, or None when the navmesh is not grid based (baked in Godot)."""
    region = next((n for n in scene["nodes"] if n["name"] == "NavigationRegion3D" and n["parent"] == "."), None)
    if region is None:
        return None
    m = re.search(r'SubResource\("([^"]+)"\)', region["props"].get("navigation_mesh", ""))
    block = scene["navmesh"].get(m.group(1)) if m else None
    if block is None:
        return None
    vm = re.search(r"vertices = PackedVector3Array\(([^)]*)\)", block)
    if vm is None or not vm.group(1).strip():
        return set()
    v = [float(x) for x in vm.group(1).split(",")]
    verts = [(v[i], v[i + 2]) for i in range(0, len(v), 3)]
    cells = set()
    for poly in re.findall(r"PackedInt32Array\(([^)]*)\)", block):
        pts = [verts[int(i)] for i in poly.split(",")]
        xs = sorted({p[0] for p in pts})
        zs = sorted({p[1] for p in pts})
        if len(pts) != 4 or len(xs) != 2 or len(zs) != 2 or xs[1] - xs[0] != wg.CELL or zs[1] - zs[0] != wg.CELL:
            return None
        cells.add((int(xs[0]), int(zs[0])))
    return cells


def parse_zone(map_id: str) -> dict | None:
    p = ZONE_DIR / f"{map_id}.tres"
    if not wg.exists(p):
        return None
    t = wg.read_text(p)
    g = lambda k: (re.search(rf"(?m)^{k} = (.*)$", t) or [None, None])[1]  # noqa: E731
    conn = re.findall(r'&"([^"]+)"', g("connected_maps") or "")
    return {
        "kind": int(g("kind") or 0),
        "name_key": _sn(g("name_key")),
        "min": int(g("recommended_level_min") or 0),
        "max": int(g("recommended_level_max") or 0),
        "bosses_allowed": (g("bosses_allowed") or "false") == "true",
        "stage_cap": int(g("monster_stage_cap") or 0),
        "connected": conn,
    }


def monsters() -> dict:
    if "monsters" in _cache:
        return _cache["monsters"]
    out = {}
    for mid in _ids(MONSTER_DIR, ".tres"):
        t = wg.read_text(MONSTER_DIR / f"{mid}.tres")
        subs = {}
        for b in re.split(r"(?m)^(?=\[)", t):
            s = re.match(r'\[sub_resource type="Resource" id="([^"]+)"\]', b)
            if s:
                subs[s.group(1)] = _props(b)
        res = _props(re.split(r"(?m)^(?=\[resource\])", t)[-1])
        order = re.findall(r'SubResource\("([^"]+)"\)', res.get("stages", ""))
        stages = {}
        for i, sid in enumerate(order):
            p = subs.get(sid, {})
            stages[int(p.get("stage", i + 1))] = int(p.get("level", 0))
        out[_sn(res.get("id", f'"{mid}"'))] = {"stages": stages, "base": _sn(res.get("base_species"))}
    _cache["monsters"] = out
    return out


def translations() -> set:
    if "tr" in _cache:
        return _cache["tr"]
    keys = set()
    for p in list(LOC_DIR.glob("*.csv")) + [p for p in wg.OVERLAY if p.parent == LOC_DIR and p.suffix == ".csv"]:
        for line in wg.read_text(p).splitlines()[1:]:
            k = line.split(",", 1)[0]
            if k:
                keys.add(k)
    _cache["tr"] = keys
    return keys


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
def _children(scene, parent):
    return [n for n in scene["nodes"] if n["parent"] == parent]


def _portals(scene):
    out = []
    for n in _children(scene, "Interactables"):
        p = n["props"]
        if _sn(p.get("metadata/interact_type")) != "portal":
            continue
        pos = _vec(p.get("position"))
        appr = _vec(p.get("metadata/approach_position")) or pos
        out.append({
            "node": n["name"], "id": _sn(p.get("metadata/interact_id")), "pos": pos, "approach": appr,
            "dest": _sn(p.get("metadata/target_map")), "spawn": _sn(p.get("metadata/target_spawn")) or "SpawnPoint",
            "one_way": p.get("metadata/one_way") == "true",
            "boss": p.get("metadata/requires_boss_victory") == "true",
            "training_exit": p.get("metadata/training_exit") == "true",
        })
    return out


def validate(map_ids=None):
    _cache.clear()
    errors: list[str] = []
    warnings: list[str] = []
    all_maps = sorted(_ids(MAP_DIR, ".tscn"))
    all_zones = _ids(ZONE_DIR, ".tres")
    scope = sorted(map_ids) if map_ids else all_maps
    scenes = {m: parse_scene(m) for m in all_maps}
    zones = {m: parse_zone(m) for m in all_zones}
    mons = monsters()
    tr = translations()

    def err(m, msg):
        errors.append(f"[{m}] {msg}")

    def warn(m, msg):
        warnings.append(f"[{m}] {msg}")

    if not map_ids:
        for z in sorted(all_zones - set(all_maps)):
            err(z, "data/zones/%s.tres has no scene" % z)

    portal_ids: dict = {}
    for m in all_maps:
        for p in _portals(scenes[m]):
            portal_ids.setdefault(p["id"], []).append(m)

    for m in scope:
        if m not in scenes:
            err(m, "scene scenes/maps/%s.tscn does not exist" % m)
            continue
        sc = scenes[m]
        zone = zones.get(m)
        root = sc["root"]
        # Root / resources
        script_id = re.search(r'ExtResource\("([^"]+)"\)', (root or {}).get("props", {}).get("script", "") or "")
        if not script_id or not _is_game_map_script(sc["ext"].get(script_id.group(1), "")):
            err(m, "root is not a GameMap (%s)" % wg.MAP_SCRIPT)
        if (_sn(root["props"].get("map_id")) or DEFAULT_MAP_ID) != m:
            err(m, "root map_id is '%s', expected '%s'" % (_sn(root["props"].get("map_id")), m))
        for path in sc["ext"].values():
            if path.startswith("res://") and not wg.exists(wg.res_to_path(path)):
                err(m, "missing resource %s" % path)
        if zone is None:
            err(m, "data/zones/%s.tres does not exist" % m)
            zone = {"kind": 0, "name_key": "", "min": 0, "max": 0, "bosses_allowed": False, "stage_cap": 0, "connected": []}
        elif zone["name_key"] and zone["name_key"] not in tr:
            err(m, "zone name_key %s has no pt_BR translation" % zone["name_key"])

        markers = {n["name"]: _vec(n["props"].get("position")) for n in _children(sc, ".") if n["type"] == "Marker3D"}
        if "SpawnPoint" not in markers:
            err(m, "no SpawnPoint")
        cells = grid_cells(sc)
        reach = None
        if cells is not None:
            if not cells:
                err(m, "navigation mesh is empty")
            elif "SpawnPoint" in markers:
                sp = markers["SpawnPoint"]
                reach = wg.component(cells, wg.cell_of(sp[0], sp[2]))
                if not reach:
                    err(m, "SpawnPoint %s is not walkable" % (sp,))

        def walk(what, pos, strict=True):
            if reach is None or pos is None:
                return
            c = wg.cell_of(pos[0], pos[2])
            if c not in cells:
                (err if strict else warn)(m, "%s at (%g, %g) is not walkable" % (what, pos[0], pos[2]))
            elif c not in reach:
                err(m, "%s at (%g, %g) cannot be reached from the SpawnPoint" % (what, pos[0], pos[2]))

        # Interact ids
        seen = {}
        for n in _children(sc, "Interactables"):
            iid = _sn(n["props"].get("metadata/interact_id"))
            if iid:
                if iid in seen:
                    err(m, "interact_id '%s' repeated (%s, %s)" % (iid, seen[iid], n["name"]))
                seen[iid] = n["name"]

        # Spawns
        for n in _children(sc, "Spawns"):
            p = n["props"]
            mid = _sn(p.get("metadata/monster_id"))
            stage = int(p.get("metadata/stage", "1"))
            pos = _vec(p.get("position"))
            what = "Spawns/%s" % n["name"]
            if mid not in mons:
                err(m, "%s: monster '%s' does not exist" % (what, mid))
                continue
            if stage >= STAGE_BOSS:
                err(m, "%s asks for stage %d: bosses only in BossLairs/" % (what, stage))
            elif stage not in mons[mid]["stages"]:
                err(m, "%s: '%s' has no stage %d" % (what, mid, stage))
            else:
                lvl = mons[mid]["stages"][stage]
                if zone["max"] > 0 and not (zone["min"] - LEVEL_BELOW <= lvl <= zone["max"] + LEVEL_ABOVE):
                    err(m, "%s: '%s' stage %d is level %d, zone range %d-%d (allowed %d..%d)" % (
                        what, mid, stage, lvl, zone["min"], zone["max"], zone["min"] - LEVEL_BELOW,
                        zone["max"] + LEVEL_ABOVE))
            if zone["stage_cap"] and stage > zone["stage_cap"]:
                warn(m, "%s asks for stage %d but the zone caps at %d" % (what, stage, zone["stage_cap"]))
            walk(what, pos)
            if reach is not None and pos is not None and wg.cell_of(pos[0], pos[2]) in cells \
                    and not wg.is_interior(cells, wg.cell_of(pos[0], pos[2])):
                warn(m, "%s at (%g, %g) is on the edge of the walkable area" % (what, pos[0], pos[2]))

        # Boss lairs
        lairs = _children(sc, "BossLairs")
        for n in lairs:
            mid = _sn(n["props"].get("metadata/monster_id"))
            if mid not in mons:
                err(m, "BossLairs/%s: monster '%s' does not exist" % (n["name"], mid))
            elif STAGE_BOSS not in mons[mid]["stages"]:
                err(m, "BossLairs/%s: '%s' has no boss stage" % (n["name"], mid))
            if not zone["bosses_allowed"]:
                err(m, "BossLairs/%s but the zone has bosses_allowed = false" % n["name"])
            walk("BossLairs/%s" % n["name"], _vec(n["props"].get("position")))

        # Arrival markers: the ones some portal arrives at must be reachable; the rest only warn.
        arrivals = {p["spawn"] for o in all_maps for p in _portals(scenes[o]) if p["dest"] == m}
        arrivals.add("SpawnPoint")
        for name, pos in markers.items():
            if name.startswith("Viewpoint"):
                continue
            if name in arrivals:
                walk("arrival %s" % name, pos)
            elif reach is not None and pos is not None and wg.cell_of(pos[0], pos[2]) not in reach:
                warn(m, "marker %s at (%g, %g) is off the reachable area (not used as arrival)" % (name, pos[0], pos[2]))

        # Portals
        dests = set()
        for p in _portals(sc):
            what = "portal %s -> %s" % (p["id"], p["dest"])
            # Ids are per map for the server; older maps reuse "back"/"forward". New maps prefix the map id.
            if len(portal_ids.get(p["id"], [])) > 1:
                warn(m, "%s: interact_id also used in %s" % (what, sorted(set(portal_ids[p["id"]]) - {m}) or "this map"))
            walk(what, p["approach"])
            if p["training_exit"]:
                continue
            if p["dest"] == m:
                err(m, "%s: portal to the map itself" % what)
                continue
            if p["dest"] not in scenes or p["dest"] not in zones:
                if p["dest"] in PLANNED_PORTALS:
                    warn(m, "%s: planned destination (closed gate)" % what)
                else:
                    err(m, "%s: destination map does not exist" % what)
                continue
            dests.add(p["dest"])
            if p["dest"] not in zone["connected"] and p["dest"] != TRAINING_MAP:
                err(m, "%s: destination not in connected_maps (server refuses)" % what)
            dsc = scenes[p["dest"]]
            dmarkers = {n["name"] for n in _children(dsc, ".")}
            if p["spawn"] not in dmarkers:
                err(m, "%s: arrival '%s' does not exist in %s" % (what, p["spawn"], p["dest"]))
            if p["one_way"]:
                if not (p["boss"] and lairs):
                    err(m, "%s: one-way exit must be the boss escape (requires_boss_victory + BossLairs/)" % what)
            else:
                back = any(bp["dest"] == m for bp in _portals(dsc))
                if not back or m not in zones[p["dest"]]["connected"]:
                    err(m, "%s: no way back (%s has no portal/connected_maps to %s)" % (what, p["dest"], m))
        for c in zone["connected"]:
            if c not in scenes or c not in zones:
                err(m, "connected_maps lists '%s', which does not exist" % c)
            elif c not in dests:
                warn(m, "connected_maps lists '%s' but no portal leads there" % c)
    return errors, warnings


def main() -> int:
    maps = [a for a in sys.argv[1:] if not a.startswith("--")]
    errors, warnings = validate(maps or None)
    for w in warnings:
        print("WARN ", w)
    for e in errors:
        print("ERROR", e)
    print("validate_world: %d error(s), %d warning(s)" % (len(errors), len(warnings)))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
