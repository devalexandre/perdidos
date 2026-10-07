#!/usr/bin/env python3
"""Shared helpers for the world generators in tools/world/ (build_*.py).

Every generator writes through this module so the same rules hold for every map:
  - writes go through write_text()/save_image(); with --check nothing is written: the new
    content is kept in memory (OVERLAY), compared with the file on disk and validated;
  - require_res() fails loudly when a res:// path (material, script, texture) does not exist;
  - floor cells (2 m x 2 m) -> floor runs, navmesh (same cells) and connectivity bridges;
  - spawn packs are snapped to the walkable area;
  - CSV translations are appended without duplicating existing keys;
  - finish() runs validate_world on the generated maps and exits non-zero on errors.

Conventions (kept by every map generator):
  - root node: script = res://scripts/shared/map.gd with `map_id = &"<id>"` (GameMap);
  - cells are (x, z) with x, z even; a cell covers [x, x+2] x [z, z+2];
  - NavigationMesh: cell_size/cell_height 0.2, one quad per cell (GameMap.nav_cell_size);
  - spawn packs (Spawns/) use stages 1-2; stage 3/4 only as boss lairs (BossLairs/);
  - arrival markers live at the map root (SpawnPoint, *Return, DescentLanding, ...).
"""

from __future__ import annotations

import csv
import io
import math
import os
import sys
from collections import deque
from pathlib import Path

GAME_DIR = Path(__file__).resolve().parents[2]
TOOLS_DIR = Path(__file__).resolve().parent

MAP_SCRIPT = "res://scripts/shared/map.gd"
CELL = 2

CHECK = "--check" in sys.argv or "--dry-run" in sys.argv
## build_all.py runs every generator in one process; their finish() calls only record the maps.
ORCHESTRATED = False
OVERLAY: dict[Path, str | bytes] = {}
CHANGED: list[Path] = []
UNCHANGED: list[Path] = []


class WorldGenError(Exception):
    pass


# ---------------------------------------------------------------------------
# Files
# ---------------------------------------------------------------------------
def _abs(path) -> Path:
    p = Path(path)
    return p if p.is_absolute() else GAME_DIR / p


def res_to_path(res_path: str) -> Path:
    assert res_path.startswith("res://"), res_path
    return GAME_DIR / res_path[len("res://"):]


def exists(path) -> bool:
    p = _abs(path)
    return p in OVERLAY or p.exists()


def read_text(path) -> str:
    p = _abs(path)
    if p in OVERLAY:
        v = OVERLAY[p]
        return v if isinstance(v, str) else v.decode("utf-8")
    return p.read_text(encoding="utf-8")


_PATH_WRITE_TEXT = Path.write_text
_PATH_READ_TEXT = Path.read_text


def write_text(path, text: str, *_args, **_kwargs) -> None:
    p = _abs(path)
    old = None
    if p in OVERLAY:
        old = OVERLAY[p]
    elif p.exists():
        old = _PATH_READ_TEXT(p, encoding="utf-8")
    (UNCHANGED if old == text else CHANGED).append(p)
    if CHECK:
        OVERLAY[p] = text
        return
    if old == text:
        return  # unchanged: keep the file (and its mtime) as is
    p.parent.mkdir(parents=True, exist_ok=True)
    _PATH_WRITE_TEXT(p, text, encoding="utf-8")


_IMAGE_SAVE = None


def save_image(img, path, *args, **kwargs) -> None:
    """PIL image save that respects --check (images are not compared, only kept in memory)."""
    save = _IMAGE_SAVE or type(img).save
    p = _abs(path)
    buf = io.BytesIO()
    save(img, buf, format="PNG")
    data = buf.getvalue()
    if CHECK:
        OVERLAY[p] = data
        return
    if p.exists() and p.read_bytes() == data:
        return  # same pixels and encoding: keep the file
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_bytes(data)


def install() -> None:
    """Route every Path.write_text / Path.read_text / PIL Image.save of a generator through this
    module (so --check never touches the disk), for generators that write with plain pathlib calls."""
    global _IMAGE_SAVE

    def _write(self, data, encoding=None, errors=None, newline=None):
        write_text(self, data)
        return len(data)

    def _read(self, encoding=None, errors=None, newline=None):
        return read_text(self) if _abs(self) in OVERLAY else _PATH_READ_TEXT(self, encoding=encoding or "utf-8")

    Path.write_text = _write
    Path.read_text = _read
    try:
        from PIL import Image
    except ImportError:
        return
    if _IMAGE_SAVE is None:
        _IMAGE_SAVE = Image.Image.save

        def _save(img, fp, *args, **kwargs):
            if isinstance(fp, (str, Path)):
                save_image(img, fp, *args, **kwargs)
            else:
                _IMAGE_SAVE(img, fp, *args, **kwargs)

        Image.Image.save = _save


def _disk(p: Path, binary: bool = False):
    if not p.exists():
        return None
    return p.read_bytes() if binary else _PATH_READ_TEXT(p, encoding="utf-8")


def require_res(res_path: str, what: str = "") -> str:
    """Fail loudly if a res:// resource does not exist (in the project or generated in this run)."""
    if not exists(res_to_path(res_path)):
        raise WorldGenError(f"{what or 'resource'} does not exist: {res_path}")
    return res_path


# ---------------------------------------------------------------------------
# Geometry: cells, floor runs, navmesh, connectivity
# ---------------------------------------------------------------------------
def dist_segment(p, a, b) -> float:
    dx, dz = b[0] - a[0], b[1] - a[1]
    denom = dx * dx + dz * dz
    if denom == 0:
        return math.hypot(p[0] - a[0], p[1] - a[1])
    t = max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / denom))
    return math.hypot(p[0] - a[0] - t * dx, p[1] - a[1] - t * dz)


def cell_of(x: float, z: float) -> tuple[int, int]:
    return (int(math.floor(x / CELL)) * CELL, int(math.floor(z / CELL)) * CELL)


def cell_center(c) -> tuple[float, float]:
    return (c[0] + CELL / 2, c[1] + CELL / 2)


def _neighbors(c):
    x, z = c
    return ((x + CELL, z), (x - CELL, z), (x, z + CELL), (x, z - CELL))


def component(cells: set, start) -> set:
    if start not in cells:
        return set()
    seen = {start}
    q = deque([start])
    while q:
        c = q.popleft()
        for n in _neighbors(c):
            if n in cells and n not in seen:
                seen.add(n)
                q.append(n)
    return seen


def nearest_cell(cells, x: float, z: float):
    return min(cells, key=lambda c: math.hypot(cell_center(c)[0] - x, cell_center(c)[1] - z))


def ensure_connected(cells: set, start_xz, targets_xz, blocked=None, bound: int = 56, label: str = "",
                     widen: bool = True) -> set:
    """Every target must be reachable from start through edge-adjacent cells.

    When a target sits on another island, the shortest bridge of new cells (avoiding the `blocked`
    predicate, e.g. pillars) is added. Returns the set of added cells (also added to `cells`).
    """
    blocked = blocked or (lambda c: False)
    added: set = set()
    start = cell_of(*start_xz)
    if start not in cells:
        raise WorldGenError(f"{label}: SpawnPoint {start_xz} is not on a floor cell")
    for tx, tz in targets_xz:
        t = cell_of(tx, tz)
        if t not in cells:
            # Off the floor (e.g. an NPC beside a pillar): connect its nearest floor cell; the
            # validator still fails on arrival markers / portals that are not walkable.
            t = nearest_cell(cells, tx, tz)
            print(f"  [{label}] target {(tx, tz)} is off the floor; using nearest cell {t}")
        comp = component(cells, start)
        if t in comp:
            continue
        # BFS from the reachable component over free grid cells to the target's island.
        island = component(cells, t)
        prev = {c: None for c in comp}
        q = deque(comp)
        hit = None
        while q and hit is None:
            c = q.popleft()
            for n in _neighbors(c):
                if n in prev or abs(n[0]) > bound or abs(n[1]) > bound:
                    continue
                if n not in cells and blocked(n):
                    continue
                prev[n] = c
                if n in island:
                    hit = n
                    break
                q.append(n)
        if hit is None:
            raise WorldGenError(f"{label}: cannot connect {(tx, tz)} to the SpawnPoint area")
        c = prev[hit]
        while c is not None and c not in comp:
            cells.add(c)
            added.add(c)
            c = prev[c]
    if added and widen:
        # Bridges are 3 cells wide where possible (a 2 m bridge is walkable but cramped).
        for c in list(added):
            for n in _neighbors(c):
                if n not in cells and not blocked(n) and abs(n[0]) <= bound and abs(n[1]) <= bound:
                    cells.add(n)
                    added.add(n)
    if added:
        print(f"  [{label}] bridged {len(added)} cell(s): {sorted(added)}")
    return added


def floor_runs(cells: set) -> list[tuple[int, int, int]]:
    """Horizontal runs (x_start, z, n_cells) of the floor, row by row."""
    runs = []
    for z in sorted({c[1] for c in cells}):
        xs = sorted(c[0] for c in cells if c[1] == z)
        start = prev = xs[0]
        for x in xs[1:]:
            if x == prev + CELL:
                prev = x
                continue
            runs.append((start, z, (prev - start) // CELL + 1))
            start = prev = x
        runs.append((start, z, (prev - start) // CELL + 1))
    return runs


def navmesh_body(cells: set, extra: str = "") -> str:
    """NavigationMesh sub_resource body: one quad per floor cell (same cells as the floor)."""
    verts: list = []
    ids: dict = {}
    polys = []
    for x, z in sorted(cells):
        poly = []
        for v in ((x, z), (x, z + CELL), (x + CELL, z + CELL), (x + CELL, z)):
            if v not in ids:
                ids[v] = len(verts)
                verts.append(v)
            poly.append(ids[v])
        polys.append("PackedInt32Array(" + ", ".join(map(str, poly)) + ")")
    body = ("cell_size = 0.2\ncell_height = 0.2\nvertices = PackedVector3Array("
            + ", ".join(f"{x}, 0, {z}" for x, z in verts)
            + ")\npolygons = Array[PackedInt32Array]([" + ", ".join(polys) + "])")
    return body + ("\n" + extra if extra else "")


def is_interior(cells, c, margin: int = 1) -> bool:
    return all((c[0] + dx * CELL, c[1] + dz * CELL) in cells
               for dx in range(-margin, margin + 1) for dz in range(-margin, margin + 1))


def snake(name: str) -> str:
    out = ""
    for i, ch in enumerate(name):
        if ch.isupper() and i and (name[i - 1].islower() or name[i - 1].isdigit()):
            out += "_"
        out += ch.lower()
    return out


def portal_id(map_id: str, node_name: str) -> str:
    """World-unique portal interact_id: <map_id>_<node_name in snake_case>."""
    return f"{map_id}_{snake(node_name)}"


def snap_to_walkable(cells: set, x: float, z: float, margin: int = 1, label: str = ""):
    """Pack position on walkable ground with its neighbours walkable too (pack radius)."""
    c = cell_of(x, z)
    if is_interior(cells, c, margin):
        return (x, z)
    pool = [k for k in cells if is_interior(cells, k, margin)] or list(cells)
    best = min(pool, key=lambda k: math.hypot(cell_center(k)[0] - x, cell_center(k)[1] - z))
    bx, bz = cell_center(best)
    print(f"  [{label}] moved ({x:g}, {z:g}) -> ({bx:g}, {bz:g}) (walkable)")
    return (bx, bz)


# ---------------------------------------------------------------------------
# Localization
# ---------------------------------------------------------------------------
def csv_add(rel_path: str, rows) -> int:
    """Append (key, pt_BR) rows to a localization CSV (keys,pt_BR) without duplicating keys.

    An existing key keeps its current text (hand edits win); a different generated text is reported.
    """
    p = _abs(rel_path)
    if not exists(p):
        raise WorldGenError(f"localization file does not exist: {rel_path}")
    text = read_text(p)
    existing = {}
    for r in csv.reader(io.StringIO(text)):
        if r:
            existing[r[0]] = r[1] if len(r) > 1 else ""
    new = []
    for key, value in rows:
        if key in existing:
            if existing[key] != value:
                print(f"  [csv] {rel_path}: {key} kept as is (generator text differs)")
            continue
        existing[key] = value
        new.append([key, value])
    if not new:
        return 0
    buf = io.StringIO()
    csv.writer(buf, lineterminator="\n").writerows(new)
    write_text(p, text.rstrip("\n") + "\n" + buf.getvalue())
    print(f"  [csv] {rel_path}: +{len(new)} key(s)")
    return len(new)


def check_written_resources() -> list[str]:
    """Every res:// referenced by a .tres/.tscn written in this run must exist (ext_resource, sprite_base)."""
    import re

    out = []
    for p in sorted(set(CHANGED + UNCHANGED)):
        if p.suffix not in (".tres", ".tscn"):
            continue
        text = read_text(p)
        rel = p.relative_to(GAME_DIR)
        for m in re.finditer(r'\[ext_resource [^\]]*path="(res://[^"]+)"', text):
            if not exists(res_to_path(m.group(1))):
                out.append(f"[{rel}] missing resource {m.group(1)}")
        for m in re.finditer(r'(?m)^sprite_base = "(res://[^"]+)"', text):
            base = res_to_path(m.group(1))
            if not any(base.parent.glob(base.name + "*")) and not any(
                    q.parent == base.parent and q.name.startswith(base.name) for q in OVERLAY):
                out.append(f"[{rel}] sprite_base has no sheets: {m.group(1)}")
    return out


def csv_set(rel_path: str, rows) -> int:
    """Like csv_add, but the generator owns these keys: an existing key gets the generated text in
    place (file order is kept) and missing keys are appended."""
    p = _abs(rel_path)
    if not exists(p):
        raise WorldGenError(f"localization file does not exist: {rel_path}")
    current = list(csv.reader(io.StringIO(read_text(p))))
    wanted = {k: v for k, v in rows}
    seen = set()
    out = []
    for r in current:
        if r and r[0] in wanted:
            out.append([r[0], wanted[r[0]]])
            seen.add(r[0])
        else:
            out.append(r)
    out += [[k, v] for k, v in rows if k not in seen]
    buf = io.StringIO()
    csv.writer(buf, lineterminator="\n").writerows(out)
    write_text(p, buf.getvalue())
    return len(rows) - len(seen)


# ---------------------------------------------------------------------------
# End of a generator run
# ---------------------------------------------------------------------------
def finish(map_ids, name: str = "") -> None:
    """Validate the generated maps (plus cross-map links) and report; exits 1 on errors."""
    if ORCHESTRATED:
        print(f"[{name}] done (validation at the end of build_all)")
        return
    import validate_world  # local module (tools/world/validate_world.py)

    errors, warnings = validate_world.validate(map_ids)
    errors += check_written_resources()
    for w in warnings:
        print("  WARN", w)
    for e in errors:
        print("  ERROR", e)
    if CHECK:
        changed = sorted(p for p in OVERLAY if OVERLAY[p] != _disk(p, binary=isinstance(OVERLAY[p], bytes)))
        print(f"[{name}] --check: {len(changed)} file(s) would change")
        for p in changed:
            print("   would change:", p.relative_to(GAME_DIR))
        dump = os.environ.get("WORLDGEN_DUMP")
        if dump:  # write what would be generated under <dump>/<path in game/> to diff it
            for p, data in OVERLAY.items():
                out = Path(dump) / p.relative_to(GAME_DIR)
                out.parent.mkdir(parents=True, exist_ok=True)
                (out.write_bytes(data) if isinstance(data, bytes) else _PATH_WRITE_TEXT(out, data, encoding="utf-8"))
            print(f"[{name}] generated files dumped to {dump}")
    print(f"[{name}] validation: {len(errors)} error(s), {len(warnings)} warning(s)")
    if errors:
        sys.exit(1)
