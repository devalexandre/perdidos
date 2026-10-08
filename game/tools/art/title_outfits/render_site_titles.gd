extends Node
## Imagens dos títulos do site (site/img/titles/<título>_m.png e _f.png, 48x92, fundo transparente, com sombra):
## LayeredCharacterPreview com fixed_scale = 1, aparência padrão do corpo + {outfit: TitleDef.outfit_id}, idle S,
## quadro 0, recortado pelo contorno e centrado em 48x92 (pés embaixo).
## Precisa de janela (xvfb): xvfb-run -a godot --path game res://tools/art/title_outfits/render_site_titles.tscn \
##     -- --out=<site>/img/titles [--titles=id1,id2]      (padrão: todos os títulos com outfit_id)
##     [--pairs=titulo:outfit,...]   (título ainda sem .tres/outfit_id: usa o par dado)
##     [--anim]   versão animada (08/10/2026): em vez do PNG, salva os quadros de idle -> golpe/conjuração do título ->
##                idle (~3 s, tempos do jogo) em <out>/_frames/<título>_<m|f>_NN.png + <título>_<m|f>.txt (ms por
##                quadro), mesmo recorte 48x92 do PNG; site/tools/titles_anim.py monta os .webp animados.
##     [--idle-only] salva apenas um ciclo de repouso; site/tools/build_motion.py monta os GIFs.

const W: int = 48
const H: int = 92
## Ação do título no site animado: arquétipo -> [animação, arma (visual) ou ""].
const ACTION: Dictionary = {"arcane": ["cast", ""], "support": ["cast", ""], "blade": ["attack_blade", "blade"],
	"hybrid": ["attack_blade", "blade"], "bow": ["attack_bow", "bow"], "tank": ["attack_unarmed", ""],
	"traveler": ["attack_unarmed", ""]}
const ANIM_TOTAL_MS: float = 3000.0
var _anim_mode: bool = false
var _idle_only: bool = false
var _arch: Dictionary = {}


func _ready() -> void:
	var out_dir: String = ""
	var only: PackedStringArray = []
	var pairs: Dictionary = {}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--pairs="):
			for pr: String in a.trim_prefix("--pairs=").split(",", false):
				var kv: PackedStringArray = pr.split(":")
				if kv.size() == 2:
					pairs[kv[0]] = StringName(kv[1])
		if a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
		elif a == "--anim":
			_anim_mode = true
		elif a == "--idle-only":
			_anim_mode = true
			_idle_only = true
		elif a.begins_with("--titles="):
			only = a.trim_prefix("--titles=").split(",", false)
	if out_dir.is_empty():
		push_error("--out=<dir> obrigatório")
		get_tree().quit(1)
		return
	_run.call_deferred(out_dir, only, pairs)


func _run(out_dir: String, only: PackedStringArray, pairs: Dictionary) -> void:
	var opts: CustomizationOptions = CustomizationOptions.get_default()
	var vp := SubViewport.new()
	vp.size = Vector2i(160, 160)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var n: int = 0
	var todo: Dictionary = {}   # título -> outfit_id
	for f: String in DirAccess.get_files_at("res://data/titles"):
		if not f.ends_with(".tres"):
			continue
		var t: TitleDef = load("res://data/titles/" + f) as TitleDef
		if t == null or String(t.outfit_id).is_empty():
			continue
		todo[String(t.id)] = t.outfit_id
		_arch[String(t.id)] = String(t.archetype)
	for k: String in pairs:
		if not todo.has(k):
			todo[k] = pairs[k]
	for tid: String in todo:
		if not only.is_empty() and not only.has(tid):
			continue
		var outfit_id: StringName = todo[tid]
		for body: StringName in [&"male", &"female"]:
			var p := LayeredCharacterPreview.new()
			p.show_rotate_buttons = false
			p.fixed_scale = 1
			p.size = Vector2(160, 160)
			vp.add_child(p)
			p.set_appearance(opts.default_appearance(body).merged({&"outfit": outfit_id}, true))
			p.set_anim(&"idle")
			p.set_sector(0)
			p.set_process(false)
			if _anim_mode:
				await _render_anim(vp, p, tid, body, out_dir)
				n += 1
				p.queue_free()
				await get_tree().process_frame
				continue
			await get_tree().process_frame
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img: Image = vp.get_texture().get_image()
			var used: Rect2i = img.get_used_rect()
			var out := Image.create(W, H, false, Image.FORMAT_RGBA8)
			# centro horizontal do contorno, pés na última linha
			var src := Rect2i(used.position.x + used.size.x / 2 - W / 2, used.end.y - H, W, H)
			out.blit_rect(img, src, Vector2i.ZERO)
			var path: String = "%s/%s_%s.png" % [out_dir, tid, "m" if body == &"male" else "f"]
			out.save_png(path)
			print("site_title ", path, " used=", used)
			n += 1
			p.queue_free()
			await get_tree().process_frame
	print("site_titles_done ", n)
	get_tree().quit(0)


## Quadros da versão animada (mesmo recorte do PNG estático: contorno do idle quadro 0, pés embaixo).
func _render_anim(vp: SubViewport, p: LayeredCharacterPreview, tid: String, body: StringName, out_dir: String) -> void:
	var arch: String = "traveler" if tid == "traveler" else str(_arch.get(tid, "traveler"))
	var act: Array = ACTION.get(arch, ACTION["traveler"])
	var action: StringName = StringName(act[0])
	var weapon: String = act[1]
	if _idle_only:
		weapon = ""
	DirAccess.make_dir_recursive_absolute(out_dir + "/_frames")
	var stage: Control = p.get(&"_stage") as Control
	var wsprite: Sprite2D = null
	if weapon != "" and stage != null:
		wsprite = Sprite2D.new()
		wsprite.centered = false
		wsprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		wsprite.vframes = 5
		wsprite.scale = Vector2(p.frame_scale, p.frame_scale)
		stage.add_child(wsprite)
	var seq: Array = []   # [anim, col, ms]
	var n_idle: int = _frames_of(p, &"idle")
	var fs_idle: float = LayeredCharacterPreview.frame_sec(&"idle", n_idle) * 1000.0
	var n_act: int = _frames_of(p, action)
	var fs_act: float = LayeredCharacterPreview.frame_sec(action, n_act) * 1000.0
	for i: int in n_idle:
		seq.append([&"idle", i, fs_idle])
	if not _idle_only:
		for i: int in n_act:
			seq.append([action, i, fs_act])
		var rest: int = maxi(0, roundi((ANIM_TOTAL_MS - fs_idle * n_idle - fs_act * n_act) / fs_idle))
		for i: int in rest:
			seq.append([&"idle", i % n_idle, fs_idle])
	var src := Rect2i()
	var tag: String = "%s_%s" % [tid, "m" if body == &"male" else "f"]
	var durs: PackedStringArray = []
	for k: int in seq.size():
		var an: StringName = seq[k][0]
		var col: int = seq[k][1]
		var ms: float = seq[k][2]
		p.set_anim(an)
		p.set(&"_time", (col + 0.5) * ms / 1000.0)
		p.call(&"_update_frame")
		if wsprite != null:
			# a arma só entra no golpe: no idle as roupas de título já trazem a arma desenhada na mão
			wsprite.visible = an == action
		if wsprite != null and an == action:
			var wp: String = "res://assets/equipment/weapon/%s/%s_%s.png" % [weapon, body, an]
			var wt: Texture2D = load(wp) as Texture2D if ResourceLoader.exists(wp) else null
			wsprite.visible = wt != null
			if wt != null:
				wsprite.texture = wt
				var wf: int = maxi(1, wt.get_width() / (wt.get_height() / 5))
				wsprite.hframes = wf
				wsprite.frame = DirectionalSprite3D.overlay_column(col, _frames_of(p, an), wf)
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img: Image = vp.get_texture().get_image()
		if k == 0:
			var used: Rect2i = img.get_used_rect()
			src = Rect2i(used.position.x + used.size.x / 2 - W / 2, used.end.y - H, W, H)
		var out := Image.create(W, H, false, Image.FORMAT_RGBA8)
		out.blit_rect(img, src, Vector2i.ZERO)
		out.save_png("%s/_frames/%s_%02d.png" % [out_dir, tag, k])
		durs.append(str(roundi(ms)))
	var f := FileAccess.open("%s/_frames/%s.txt" % [out_dir, tag], FileAccess.WRITE)
	f.store_string(",".join(durs))
	f.close()
	if wsprite != null:
		wsprite.queue_free()
	print("site_title_anim ", tag, " quadros=", seq.size(), " acao=", &"idle" if _idle_only else action)


func _frames_of(p: LayeredCharacterPreview, an: StringName) -> int:
	var layers: Array = p.get(&"_layers")
	for l: Dictionary in layers:
		if l[&"name"] == CharacterLayers.LAYER_BASE:
			var t: Texture2D = (l[&"textures"] as Dictionary).get(an)
			if t != null:
				return maxi(1, t.get_width() / (t.get_height() / 5))
	return 1
