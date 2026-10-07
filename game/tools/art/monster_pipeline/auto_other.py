"""Etapas em lote para os monstros de 1 estagio (outras nacoes): dirs -> picks padrao (_0) -> attack -> rmbg.
auto_other.py <id>:<frente.png> ...   (a revisao olhando vem depois: preview.py e troca no picks.json)"""
import sys, os
import monster_pipeline as M
for arg in sys.argv[1:]:
    mid, front = arg.split(':')
    P = M.picks(mid, 1); P['se'] = front; M.save_picks(mid, 1, P)
    M.stage_dirs(mid, 1)
    P = M.picks(mid, 1)
    P.setdefault('dirs', {}); P['dirs'].update({d: P['dirs'].get(d) or f'd_{d}_0.png' for d in ('s', 'e', 'ne', 'n')}); P['dirs']['se'] = front
    M.save_picks(mid, 1, P)
    M.stage_attack(mid, 1, variants=1)
    P = M.picks(mid, 1); P['atk'] = {d: f'a_{d}_0.png' for d in ('s', 'se', 'e')}; M.save_picks(mid, 1, P)
    M.stage_rmbg(mid, 1)
    print('DONE', mid, flush=True)
