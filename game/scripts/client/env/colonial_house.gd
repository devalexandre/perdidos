class_name ColonialHouse
extends RefCounted
## Casa colonial montada com as peças modulares do Medieval Village MegaKit (Quaternius, CC0) convertidas por
## build_pack_kit.gd (malhas pkv_*), retexturizadas: reboco caiado quente (cor por casa), telha canal, cunhais de
## pedra, barrado de azulejo, janelas/portas com venezianas coloridas (cor por casa) — GDD §4.2 / §17.0.A.
## Só gera a lista de itens [nome da malha, Transform3D, Color]; quem chama agrupa em MultiMesh (KitCatalog.group).
## Referencial da casa: centro no chão, fachada para +Z local, largura w em X, profundidade d em Z.

const WALL_W := 2.0
const FLOOR_H := 3.12

## Tons de parede (cal quente) e de molduras/venezianas.
const WALL_TINTS := {
	"wall_white": Color(1.0, 0.97, 0.9), "wall_yellow": Color(1.0, 0.84, 0.56), "wall_pink": Color(1.0, 0.8, 0.74),
	"wall_blue": Color(0.82, 0.9, 0.96), "wall_green": Color(0.86, 0.94, 0.76),
}
const FRAME_TINTS := {
	"frame_teal": Color(0.32, 0.72, 0.7), "frame_magenta": Color(0.8, 0.36, 0.55), "frame_yellow": Color(0.98, 0.78, 0.3),
	"frame_green": Color(0.38, 0.62, 0.36), "frame_red": Color(0.78, 0.3, 0.26), "frame_blue": Color(0.36, 0.52, 0.85),
}


static func build(items: Array, tr: Transform3D, w: float, d: float, floors: int, wall: String, frame: String,
		azulejo_base: bool, rng: RandomNumberGenerator) -> void:
	var wc: Color = WALL_TINTS.get(wall, Color(1, 0.97, 0.9))
	var fc: Color = FRAME_TINTS.get(frame, Color(0.36, 0.52, 0.85))
	var add := func(mesh: String, local: Transform3D, col: Color = Color.WHITE) -> void:
		items.append([mesh, tr * local, col])
	# 4 lados: [centro local, direção para fora, comprimento]
	var sides := [
		[Vector3(0, 0, d * 0.5), 0.0, w, true], # frente
		[Vector3(0, 0, -d * 0.5), PI, w, false], # fundos
		[Vector3(w * 0.5, 0, 0), PI * 0.5, d, false],
		[Vector3(-w * 0.5, 0, 0), -PI * 0.5, d, false],
	]
	for sd: Array in sides:
		var center: Vector3 = sd[0]
		var yaw: float = sd[1]
		var length: float = sd[2]
		var front: bool = sd[3]
		var n := maxi(1, roundi(length / WALL_W))
		var sx := length / (n * WALL_W)
		var b := Basis(Vector3.UP, yaw)
		var along := b * Vector3.RIGHT
		for fl in floors:
			for i in n:
				var off := (float(i) - (n - 1) * 0.5) * WALL_W * sx
				var p := center + along * off + Vector3.UP * fl * FLOOR_H
				var piece := "pkv_wall_plaster_straight"
				var mid := i == n / 2
				if fl == 0:
					if front and mid:
						piece = "pkv_wall_plaster_door_round"
					elif (i + fl) % 2 == 1 or n <= 2:
						piece = "pkv_wall_plaster_window_wide_round"
					elif azulejo_base:
						piece = "pkv_wall_plaster_straight_base"
				else:
					piece = "pkv_wall_plaster_window_thin_round" if (i % 2 == 0 or front) else "pkv_wall_plaster_straight"
				var xf := Transform3D(b * Basis.from_scale(Vector3(sx, 1, 1)), p)
				add.call(piece, xf, wc)
				# portas, janelas, venezianas coloridas
				var face := Transform3D(b, p)
				if piece == "pkv_wall_plaster_door_round":
					add.call("pkv_door_1_round", face, fc)
				elif piece == "pkv_wall_plaster_window_wide_round":
					add.call("pkv_window_wide_round1", face)
					add.call("pkv_windowshutters_wide_round_open", face, fc)
				elif piece == "pkv_wall_plaster_window_thin_round":
					add.call("pkv_window_thin_round1", face)
					add.call("pkv_windowshutters_thin_round_open" if rng.randf() < 0.6 else "pkv_windowshutters_thin_round_closed",
							face, fc)
					if front and fl > 0 and rng.randf() < 0.35:
						add.call("pkv_balcony_simple_straight", Transform3D(b, p + Vector3.DOWN * 0.05))
	# cunhais de pedra nos cantos
	for cx: float in [-1.0, 1.0]:
		for cz: float in [-1.0, 1.0]:
			for fl in floors:
				var yaw := atan2(cx, cz)
				add.call("pkv_corner_exterior_brick", Transform3D(Basis(Vector3.UP, yaw - PI * 0.25),
						Vector3(cx * w * 0.5, fl * FLOOR_H, cz * d * 0.5)))
	# telhado de telha canal (cumeeira ao longo de X) — peça 6x8 esticada para a planta da casa
	var top := floors * FLOOR_H
	var roof_w := 8.25
	var roof_d := 9.68
	var rs := Vector3((d + 1.3) / roof_w, clampf(d / 8.0, 0.75, 1.1), (w + 1.3) / roof_d)
	add.call("pkv_roof_roundtiles_6x8", Transform3D(Basis(Vector3.UP, PI * 0.5) * Basis.from_scale(rs), Vector3(0, top, 0)))
	# empenas (triângulos de reboco sob o telhado) nas duas pontas
	for sx2: float in [-1.0, 1.0]:
		var gs := Vector3(d / 6.4, rs.y, 1.0)
		add.call("pkv_roof_front_brick6", Transform3D(Basis(Vector3.UP, sx2 * PI * 0.5) * Basis.from_scale(gs),
				Vector3(sx2 * w * 0.5, top, 0)), wc)
	# chaminé
	if rng.randf() < 0.7:
		add.call("pkv_prop_chimney2", Transform3D(Basis.IDENTITY, Vector3(w * 0.25 * (1.0 if rng.randf() < 0.5 else -1.0),
				top + 1.2, -d * 0.2)))
