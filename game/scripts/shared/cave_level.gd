class_name CaveLevel
extends GameMap
## Quatro pisos autorados em tools/world/build_cave.py. A mesma silhueta gera chão,
## colisão e navegação; portais e covis existem na cena antes de entrar na árvore.
@export_range(1, 4) var floor_number: int = 1
