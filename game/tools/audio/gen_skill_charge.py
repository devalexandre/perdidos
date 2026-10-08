#!/usr/bin/env python3
"""Substituído em 08/10/2026 por gen_skill_energy.py (cargas por escola, liberação e impacto).

Mantido só como atalho: gera as cargas em laço (100% síntese, sem amostras externas).
"""
import runpy
import sys
from pathlib import Path

if __name__ == "__main__":
    sys.argv = [sys.argv[0]]
    runpy.run_path(str(Path(__file__).with_name("gen_skill_energy.py")), run_name="__main__")
