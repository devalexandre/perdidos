#!/usr/bin/env python3
"""Confere a sincronia do movimento por células (GDD §10.1).

Lê os caminhos autoritativos do servidor ("autotest_path") e as amostras que cada cliente registrou
("autotest_trace": posição de cada jogador no relógio estimado do servidor) e compara, no MESMO
instante do relógio do servidor, a posição mostrada pelo cliente com a do caminho do servidor.

Uso: check_move_sync.py <server.log> <client.log>... [--max-error=0.2]
Saída 0 = todas as amostras dentro do limite (m).
"""
import json
import math
import sys

PREFIX_SERVER = "[server] autotest_path "
PREFIX_CLIENT = "[client] autotest_trace "


def load_paths(path):
    by_entity = {}
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            if line.startswith(PREFIX_SERVER):
                d = json.loads(line[len(PREFIX_SERVER):])
                by_entity.setdefault(d["entity"], []).append(d)
    for lst in by_entity.values():
        lst.sort(key=lambda d: d["issued"])
    return by_entity


def sample(p, t):
    """Mesma conta de MovePath.sample (interpolação linear por trecho com horário)."""
    pts, times = p["points"], p["times"]
    rel = t - p["start"]
    if len(pts) == 1 or rel <= 0:
        return pts[0][0], pts[0][2]
    if rel >= times[-1]:
        return pts[-1][0], pts[-1][2]
    k = 0
    while k + 1 < len(times) and rel >= times[k + 1]:
        k += 1
    span = times[k + 1] - times[k]
    f = (rel - times[k]) / span if span > 0 else 1.0
    a, b = pts[k], pts[k + 1]
    return a[0] + (b[0] - a[0]) * f, a[2] + (b[2] - a[2]) * f


def truth(paths, t):
    cur = None
    for p in paths:
        if p["issued"] <= t:
            cur = p
        else:
            break
    return sample(cur, t) if cur else None


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    max_err = 0.2
    for a in sys.argv[1:]:
        if a.startswith("--max-error="):
            max_err = float(a.split("=", 1)[1])
    paths = load_paths(args[0])
    errs = {}  # (viewer, entity) -> [erros]
    moving = {}
    for log in args[1:]:
        with open(log, encoding="utf-8", errors="replace") as f:
            for line in f:
                if not line.startswith(PREFIX_CLIENT):
                    continue
                d = json.loads(line[len(PREFIX_CLIENT):])
                ent = d["entity"]
                if ent not in paths:
                    continue
                tr = truth(paths[ent], d["t"])
                if tr is None:
                    continue
                e = math.hypot(d["x"] - tr[0], d["z"] - tr[1])
                key = ("self" if d["viewer"] == ent else "remote", d["viewer"], ent)
                errs.setdefault(key, []).append(e)
                # Conta as amostras em que o jogador estava de fato andando.
                p_last = [p for p in paths[ent] if p["issued"] <= d["t"]]
                if p_last and len(p_last[-1]["points"]) > 1 and \
                        d["t"] < p_last[-1]["start"] + p_last[-1]["times"][-1]:
                    moving[key] = moving.get(key, 0) + 1
    ok = bool(errs)
    for key in sorted(errs):
        v = sorted(errs[key])
        mx = v[-1]
        p95 = v[int(0.95 * (len(v) - 1))]
        good = mx < max_err and moving.get(key, 0) > 0
        ok = ok and good
        print("  [%-4s] %-6s viewer=%s entity=%s samples=%d walking=%d max=%.3f m p95=%.3f m" % (
            "pass" if good else "FAIL", key[0], key[1], key[2], len(v), moving.get(key, 0), mx, p95))
    if not errs:
        print("  [FAIL] nenhuma amostra de movimento encontrada")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
