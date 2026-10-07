#!/usr/bin/env python3
"""Revisão humana da moderação do chat (GDD §13, docs/moderacao.md).

Os dois últimos degraus da sanção (30 dias e perda do personagem) NÃO valem sozinhos: o servidor
abre um caso PENDING_REVIEW e deixa o chat do jogador bloqueado até alguém decidir aqui.

Uso:
  python3 game/tools/moderation_review.py list                         casos pendentes
  python3 game/tools/moderation_review.py show <conta> [--log 20]      estado + últimas ações da conta
  python3 game/tools/moderation_review.py approve <case_id> --reviewer <nome> [--note "..."]
  python3 game/tools/moderation_review.py reject  <case_id> --reviewer <nome> [--note "..."]
  python3 game/tools/moderation_review.py pardon  <conta> --reviewer <nome> [--note "..."]
        (apelação aceita: desce 1 degrau, tira o bloqueio e desfaz perda do personagem)
  python3 game/tools/moderation_review.py purge [--days 365]            apaga do log o que passou
        do prazo de guarda (LGPD: minimização)
Opções: --dir <pasta>  (padrão: pasta user:// do projeto + /moderation; no autoteste use
        .../moderation_autotest). Pode rodar com o servidor ligado: ele relê o registro alterado.

Formato dos arquivos: ver game/scripts/server/moderation/moderation_record.gd e moderation_store.gd.
"""
import argparse, json, os, sys, time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHARACTER_LOSS = -1


def project_name() -> str:
    try:
        for line in (ROOT / "project.godot").read_text(encoding="utf-8").splitlines():
            if line.startswith("config/name="):
                return line.split("=", 1)[1].strip().strip('"')
    except OSError:
        pass
    return "Projeto Isekai"


def default_dir() -> Path:
    name = project_name()
    if sys.platform.startswith("win"):
        base = Path(os.environ.get("APPDATA", "")) / "Godot" / "app_userdata"
    elif sys.platform == "darwin":
        base = Path.home() / "Library/Application Support/Godot/app_userdata"
    else:
        base = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "godot/app_userdata"
    return base / name / "moderation"


def now() -> int:
    return int(time.time())


def iso(ts: int) -> str:
    return datetime.fromtimestamp(ts, timezone.utc).strftime("%Y-%m-%d %H:%M:%SZ")


def fmt_dur(sec: int) -> str:
    if sec == CHARACTER_LOSS:
        return "PERDA DO PERSONAGEM"
    d, r = divmod(max(sec, 0), 86400)
    return (f"{d}d " if d else "") + f"{r // 3600:02d}:{(r % 3600) // 60:02d}:{r % 60:02d}"


class Store:
    def __init__(self, d: Path):
        self.dir = d
        self.records = d / "records"
        self.log = d / "log.jsonl"
        if not self.records.is_dir():
            sys.exit(f"Pasta de moderação não encontrada: {self.records}")

    def all(self):
        for p in sorted(self.records.glob("*.json")):
            try:
                yield p, json.loads(p.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError) as e:
                print(f"aviso: registro ilegível {p.name}: {e}", file=sys.stderr)

    def get(self, account: str):
        for p, r in self.all():
            if r.get("account", p.stem) == account.lower():
                return p, r
        return None, None

    def by_case(self, case_id: str):
        for p, r in self.all():
            if (r.get("pending") or {}).get("case_id") == case_id:
                return p, r
        return None, None

    def save(self, p: Path, rec: dict):
        tmp = p.with_suffix(".json.tmp")
        tmp.write_text(json.dumps(rec, ensure_ascii=False, indent="\t"), encoding="utf-8")
        os.replace(tmp, p)

    def append_log(self, entry: dict):
        t = now()
        e = {"ts": t, "time": iso(t)}
        e.update(entry)
        with self.log.open("a", encoding="utf-8") as f:
            f.write(json.dumps(e, ensure_ascii=False, separators=(",", ":")) + "\n")

    def read_log(self):
        if not self.log.exists():
            return []
        out = []
        for line in self.log.read_text(encoding="utf-8").splitlines():
            try:
                out.append(json.loads(line))
            except json.JSONDecodeError:
                pass
        return out


def cmd_list(st: Store, _a):
    n = 0
    for _p, r in st.all():
        pend = r.get("pending") or {}
        if not pend:
            continue
        n += 1
        print(f"{pend['case_id']}  conta={r['account']}  personagem={r.get('character', '')}  "
              f"degrau={pend.get('level')}  proposto={fmt_dur(int(pend.get('proposed_sec', 0)))}  "
              f"aberto={iso(int(pend.get('created', 0)))}  motivo={pend.get('reason', '')}")
    print(f"{n} caso(s) pendente(s).")


def cmd_show(st: Store, a):
    p, r = st.get(a.account)
    if r is None:
        sys.exit(f"Conta sem registro: {a.account}")
    print(json.dumps(r, ensure_ascii=False, indent=2))
    left = int(r.get("mute_until", 0)) - now()
    print(f"bloqueio restante: {fmt_dur(left) if left > 0 else 'nenhum'}")
    entries = [e for e in st.read_log() if e.get("account") == r["account"]][-a.log:]
    print(f"--- últimas {len(entries)} ações do log (texto filtrado; o original só existe como hash)")
    for e in entries:
        print(f"{e.get('time')}  {e.get('action'):16} degrau={e.get('level')}  por={e.get('actor')}  "
              f"termos={e.get('terms', '')}  texto={e.get('filtered_text', '')!r}  {e.get('note', '')}")


def decide(st: Store, a, approve: bool):
    p, r = st.by_case(a.case_id)
    if r is None:
        sys.exit(f"Caso não encontrado ou já decidido: {a.case_id}")
    pend = r["pending"]
    proposed = int(pend.get("proposed_sec", 0))
    t = now()
    if approve:
        if proposed == CHARACTER_LOSS:
            r["character_lost"] = True
        else:
            r["mute_until"] = max(int(r.get("mute_until", 0)), t + proposed)
    else:
        r["level"] = max(int(r.get("level", 0)) - 1, 0)
        r["mute_until"] = 0
    r["pending"] = {}
    r["last_decay"] = t
    st.save(p, r)
    st.append_log({"action": "review_approved" if approve else "review_rejected", "actor": a.reviewer,
                   "account": r["account"], "character": r.get("character", ""), "case_id": a.case_id,
                   "level": r["level"], "mute_until": r["mute_until"], "proposed_sec": proposed,
                   "note": a.note})
    what = fmt_dur(proposed) if approve else "rejeitado (volta 1 degrau, chat liberado)"
    print(f"{a.case_id}: {'APROVADO — ' if approve else ''}{what}")


def cmd_pardon(st: Store, a):
    p, r = st.get(a.account)
    if r is None:
        sys.exit(f"Conta sem registro: {a.account}")
    r["level"] = max(int(r.get("level", 0)) - 1, 0)
    r["mute_until"] = 0
    r["pending"] = {}
    r["character_lost"] = False
    r["window"] = []
    r["last_decay"] = now()
    st.save(p, r)
    st.append_log({"action": "appeal_pardoned", "actor": a.reviewer, "account": r["account"],
                   "character": r.get("character", ""), "level": r["level"], "mute_until": 0,
                   "note": a.note})
    print(f"{r['account']}: perdoado (degrau {r['level']}, chat liberado).")


def cmd_purge(st: Store, a):
    limit = now() - a.days * 86400
    entries = st.read_log()
    keep = [e for e in entries if int(e.get("ts", 0)) >= limit]
    tmp = st.log.with_suffix(".jsonl.tmp")
    tmp.write_text("".join(json.dumps(e, ensure_ascii=False, separators=(",", ":")) + "\n" for e in keep),
                   encoding="utf-8")
    os.replace(tmp, st.log)
    print(f"{len(entries) - len(keep)} entrada(s) removida(s); {len(keep)} mantida(s).")


def main():
    ap = argparse.ArgumentParser(description="Revisão humana da moderação do chat.")
    ap.add_argument("--dir", type=Path, default=None, help="pasta da moderação (user://moderation)")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("list")
    s = sub.add_parser("show"); s.add_argument("account"); s.add_argument("--log", type=int, default=20)
    for name in ("approve", "reject"):
        s = sub.add_parser(name); s.add_argument("case_id")
        s.add_argument("--reviewer", required=True); s.add_argument("--note", default="")
    s = sub.add_parser("pardon"); s.add_argument("account")
    s.add_argument("--reviewer", required=True); s.add_argument("--note", default="")
    s = sub.add_parser("purge"); s.add_argument("--days", type=int, default=365)
    a = ap.parse_args()
    st = Store(a.dir or default_dir())
    {"list": cmd_list, "show": cmd_show, "approve": lambda s, x: decide(s, x, True),
     "reject": lambda s, x: decide(s, x, False), "pardon": cmd_pardon, "purge": cmd_purge}[a.cmd](st, a)


if __name__ == "__main__":
    main()
