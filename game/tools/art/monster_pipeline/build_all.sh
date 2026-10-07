#!/usr/bin/env bash
# Remonta todas as folhas de monstros do Campo de Treino a partir dos picks (MON_WORK).
# Tamanho aparente relativo ao Viajante (82 px), GDD 10.2.1: estagio 1 (normal) = pequeno 57 px em quadro 96;
# estagio 2 = medio 82 (Tatu-Rochedo: grande 123); estagio 3 (chefe) = 205 em quadro 240.
# Estagio 2 das outras nacoes: mesma folha do 1 com MonsterStage.visual_scale 1.4 (~80 px, medio).
set -e
cd "$(dirname "$0")"; P=${P:-python3}
$P build_monster.py prank_whirlwind 1 --frame 96 --height 57 --style spin
$P build_monster.py prank_whirlwind 2 --frame 96 --height 82 --style spin
$P build_monster.py prank_whirlwind 3 --frame 240 --height 205 --style spin
$P build_monster.py enchanted_firefly 1 --frame 96 --height 57 --hover 14 --style fly
$P build_monster.py enchanted_firefly 2 --frame 144 --height 82 --hover 22 --style fly
$P build_monster.py enchanted_firefly 3 --frame 240 --height 205 --hover 28 --style fly
$P build_monster.py stone_armadillo 1 --frame 96 --height 57 --style walk
$P build_monster.py stone_armadillo 2 --frame 144 --height 123 --style walk
$P build_monster.py stone_armadillo 3 --frame 240 --height 205 --style walk
for m in fountain_serpent moss_troll lindworm_hatchling griffin_chick little_chimera dune_scorpion sphinx_cub puca_trickster \
         lake_kelpie zmey_hatchling spirit_fox_cub obsidian_iguana jaguar_cub trickster_tanuki; do $P build_monster.py $m 1 --frame 96 --height 57 --style walk; done
for m in trasgo_imp kasa_obake walking_hut hopping_jiangshi; do $P build_monster.py $m 1 --frame 96 --height 57 --style hop; done
