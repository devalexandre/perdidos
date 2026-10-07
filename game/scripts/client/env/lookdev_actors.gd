class_name LookdevActors
extends Node3D
## Cenas de lookdev (scenes/lookdev/): troca cada Marker3D filho por um sprite do jogo
## (DirectionalSprite3D, arte aprovada — não mexe nos sprites). Metadados do marcador:
##   body = &"male"/&"female" (Viajante)  ou  sheet = "res://assets/monsters/<id>/mon_<id>_s1"
##   anim = &"idle"/&"walk"   (opcional)   hero = true (alvo da câmera nas capturas)
## A rotação Y do marcador vira facing_yaw.

var hero: Node3D = null


func _ready() -> void:
	for m: Node in get_children():
		if not m is Marker3D:
			continue
		var marker := m as Marker3D
		var s := DirectionalSprite3D.new()
		s.name = marker.name + "_Sprite"
		add_child(s)
		s.global_transform = Transform3D(Basis.IDENTITY, marker.global_position)
		if marker.has_meta(&"sheet"):
			s.setup_sheets(String(marker.get_meta(&"sheet")))
		else:
			s.setup(StringName(marker.get_meta(&"body", &"male")))
		s.facing_yaw = marker.rotation.y
		s.anim = StringName(marker.get_meta(&"anim", &"idle"))
		# Sprites billboard projetam sombra como "risco" fino no chão: no lookdev só a sombra redonda
		# própria do sprite (recomendado também no jogo — ver docs/arte-cenario.md).
		for g: Node in s.find_children("*", "GeometryInstance3D", true, false):
			(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if bool(marker.get_meta(&"hero", false)):
			hero = s
