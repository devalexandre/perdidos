"""Nova tentativa da vista de COSTAS (N) com instrucao reforcada, a partir da SE escolhida (3 variacoes: d_n_2..4).
fix_back.py <id> ...  (depois olhar o board e trocar picks.json)"""
import os, sys
import monster_pipeline as M
T = ("Show the creature completely from BEHIND, turned away from the viewer and walking away toward the top of the image: "
     "we see its back, the back of its head and its tail; the face, eyes and mouth are NOT visible at all. Symmetric back view.")
jobs = []
for mid in sys.argv[1:]:
    wd = M.work(mid, 1); src = os.path.join(wd, M.picks(mid, 1)['se'])
    jobs += [[src, T + ' ' + M.KEEP, os.path.join(wd, f'd_n_{k}.png'), M.seed_of(mid, 1) + 400 + k] for k in range(2, 5)]
M.run_edits(jobs)
for mid in sys.argv[1:]:
    M.stage_board(mid, 1, 'd_n_*.png')
