#!/usr/bin/env python3
"""Checa nomes sensíveis (GDD §4.0 regra 3 e §0 regra 5) em traduções e documentos de conteúdo.

Uso: python3 game/tools/check_names.py [--strict-docs]
- Traduções (game/localization/*.csv) e dados (game/data/**/*.tres): termo "!" = ERRO (código de saída 1).
- Documentos de conteúdo (TITULOS-E-SKILLS.md, docs/lore, docs/tutorial-design.md): "!" = aviso,
  ou erro com --strict-docs.
- "?" e "~" são sempre avisos para revisão humana.
"""
import re, sys, unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TERMS = ROOT / "game/data/cultural/sensitive_terms.txt"
SHIPPED = sorted((ROOT / "game/localization").glob("*.csv")) + sorted((ROOT / "game/data").rglob("*.tres"))
DOCS = [ROOT / "TITULOS-E-SKILLS.md", ROOT / "docs/tutorial-design.md"] + sorted((ROOT / "docs/lore").glob("*.md")) + sorted((ROOT / "docs/mundo").glob("*.md"))
LABEL = {"!": "PROIBIDO", "?": "sensível", "~": "Ragnarok"}

def norm(s: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFD", s.lower()) if unicodedata.category(c) != "Mn")

def load_terms():
    out = []
    for line in TERMS.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("re"):
            level, term = line[2], line[3:].strip()
            out.append((level, term, re.compile(term), True))
            continue
        level, term = line[0], line[1:].strip()
        pat = re.compile(r"(?<![\w-])" + re.escape(norm(term)).replace(r"\ ", r"[\s-]+") + r"(?![\w-])")
        out.append((level, term, pat, False))
    return out

def scan(path: Path, terms, shipped: bool, strict_docs: bool) -> int:
    errors = 0
    for n, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        if shipped and path.suffix == ".csv" and n == 1:
            continue
        nl = norm(line)
        for level, term, pat, raw in terms:
            if pat.search(line if raw else nl):
                is_err = level == "!" and (shipped or strict_docs)
                errors += is_err
                print(f"{'ERRO ' if is_err else 'aviso'} [{LABEL[level]}] {path.relative_to(ROOT)}:{n}: '{term}' → {line.strip()[:110]}")
    return errors

def main():
    strict = "--strict-docs" in sys.argv
    terms = load_terms()
    errors = sum(scan(p, terms, True, strict) for p in SHIPPED if p.exists())
    errors += sum(scan(p, terms, False, strict) for p in DOCS if p.exists())
    print(f"\n{len(terms)} termos checados; {errors} erro(s).")
    sys.exit(1 if errors else 0)

if __name__ == "__main__":
    main()
