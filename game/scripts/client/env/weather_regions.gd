extends RefCounted
## Perfis locais cosméticos. O Campo tem microclimas; mapas externos usam sua identidade.

static func profile(map_id: StringName, pos: Vector3) -> Dictionary:
	var id: String = String(map_id)
	if map_id == &"training_field":
		if Vector2(pos.x, pos.z).length() < 23.0:
			return _profile("camp", 0.75, 0.10, 0.15)
		if pos.z > 30.0:
			return _profile("pindorama", 1.15, 0.48, 0.42)
		if pos.z < -36.0 and pos.x > -25.0 and pos.x < 25.0:
			return _profile("nordic", 0.9, 0.65, 0.25)
		if pos.x < -35.0 and pos.z < -12.0:
			return _profile("dry", 0.12, 0.06, 0.03)
		if pos.x < -25.0 and pos.z < -25.0:
			return _profile("celtic", 1.35, 0.62, 0.35)
		if pos.x > 28.0:
			return _profile("jungle", 1.65, 0.45, 0.65)
		return _profile("meadow", 1.0, 0.30, 0.30)
	if "fog" in id or "moor" in id:
		return _profile("moor", 1.1, 0.85, 0.30)
	if "forest" in id or "mata" in id or "jungle" in id:
		return _profile("forest", 1.5, 0.60, 0.6)
	if "desert" in id or "egito" in id:
		return _profile("dry", 0.15, 0.05, 0.05)
	if "mountain" in id or "chapada" in id or "nord" in id:
		return _profile("highlands", 1.0, 0.65, 0.35)
	return _profile(id, 1.0, 0.25, 0.3)


static func _profile(id: String, rain: float, fog: float, heavy: float) -> Dictionary:
	return {"id": id, "rain_factor": rain, "fog_chance": fog, "heavy_chance": heavy}
