extends Node
## Imagens dos títulos do site (site/img/titles/<título>_m.png e _f.png, 48x92, fundo transparente, com sombra):
## LayeredCharacterPreview com fixed_scale = 1, aparência padrão do corpo + {outfit: TitleDef.outfit_id}, idle S,
## quadro 0, recortado pelo contorno e centrado em 48x92 (pés embaixo).
## Precisa de janela (xvfb): xvfb-run -a godot --path game res://tools/art/title_outfits/render_site_titles.tscn \
##     -- --out=<site>/img/titles [--titles=id1,id2]      (padrão: todos os títulos com outfit_id)
##     [--pairs=titulo:outfit,...]   (título ainda sem .tres/outfit_id: usa o par dado)

const W: int = 48
const H: int = 92


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
