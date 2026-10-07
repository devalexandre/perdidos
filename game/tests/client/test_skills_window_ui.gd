extends Node

const TITLE_ID: StringName = &"sabia_blade_machete"
const SKILLS_WINDOW_SCRIPT: GDScript = preload("res://scripts/client/ui/skills_window.gd")

var _failures: int = 0
var _out_dir: String = "/tmp"


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var window := SKILLS_WINDOW_SCRIPT.new() as SkillsWindow
	add_child(window)
	await _frames(2)
	var skill_bundle: Array[StringName] = TitleService.skills_for_title(TITLE_ID)
	_check(not skill_bundle.is_empty(), "título de teste tem uma árvore de skills")
	if skill_bundle.is_empty():
		get_tree().quit(1)
		return
	var skill_id: StringName = skill_bundle[0]
	var progress := {
		"skill_points": 2,
		"titles": [TITLE_ID],
		"displayed_title": TITLE_ID,
		"skills": {String(skill_id): 1},
	}
	window.set_progress(progress)
	window.open()
	await _frames(3)
	var tabs := window.find_child("TreeScroll", true, false) as ScrollContainer
	var tab_row := window.find_child("TreeTabs", true, false) as VBoxContainer
	var trees: Array[StringName] = SkillsWindow.trees_for(progress)
	_check(tabs != null and tab_row != null and tab_row.get_child_count() == trees.size(),
			"há uma aba acessível para cada árvore disponível")
	# 05/10/2026: títulos em lista vertical à esquerda (uma aba abaixo da outra), árvore à direita.
	if tab_row != null and tab_row.get_child_count() > 1:
		var a: Control = tab_row.get_child(0) as Control
		var b: Control = tab_row.get_child(1) as Control
		_check(b.global_position.y > a.global_position.y and is_equal_approx(b.global_position.x, a.global_position.x),
				"abas de título empilhadas na vertical")
		var page0: Control = window.find_child("Page_" + String(trees[0]), true, false) as Control
		_check(page0 != null and page0.global_position.x > a.global_position.x + a.size.x - 1.0,
				"árvore fica à direita da lista de títulos")
	if tabs != null and tab_row != null:
		for index: int in trees.size():
			var title: TitleDef = Content.title(trees[index])
			var expected_name: String = tr(title.name_key) if title != null else tr("UI_SKILL_TREE_OTHER")
			_check((tab_row.get_child(index) as Button).text == expected_name, "aba %d tem o título correto" % index)
			var page: Control = window.find_child("Page_" + String(trees[index]), true, false) as Control
			var list := page.find_child("SkillList", true, false) as GridContainer
			_check(list != null and list.get_child_count() == SkillsWindow.tree_entries(
					trees[index], progress.skills).size(), "aba %d mostra a árvore correspondente" % index)
		var show_title: Button = window.get("_show_title")	
		_check(show_title.visible and show_title.text == tr("UI_TITLE_SHOWN"), "título ativo mantém o controle Exibindo")
		if tab_row.get_child_count() > 1:
			var next_tab: int = tab_row.get_child_count() - 1
			(tab_row.get_child(next_tab) as Button).pressed.emit()
			await _frames(2)
			_check(StringName(str(window.get("_tree"))) == trees[next_tab], "trocar aba seleciona a árvore correta")
	# 06/10/2026: ofício do título (bonus_skills) fica na árvore dele; não abre "Outras" e clicar não muda de aba.
	var craft_progress := {"skill_points": 0, "titles": [&"sabia_blade_jaguar"], "displayed_title": &"sabia_blade_jaguar",
			"skills": {"blade_pilfer": 1, "blade_field_dressing": 1}}
	window.set_progress(craft_progress)
	await _frames(2)
	var craft_trees: Array[StringName] = SkillsWindow.trees_for(craft_progress)
	_check(SkillsWindow.OTHER_TREE not in craft_trees and &"blade_pilfer" in SkillsWindow.tree_entries(
			&"sabia_blade_jaguar", craft_progress.skills) and &"blade_field_dressing" in SkillsWindow.tree_entries(
			TITLE_ID, craft_progress.skills), "ofícios aparecem nas árvores dos títulos, sem aba Outras")
	window._select_tree(&"sabia_blade_jaguar")
	await _frames(2)
	window._select(&"blade_pilfer")
	await _frames(2)
	_check(StringName(str(window.get("_tree"))) == &"sabia_blade_jaguar" and window.get("_selected") == &"blade_pilfer",
			"selecionar o ofício mantém a árvore do título")
	window._select(&"blade_field_dressing")
	await _frames(2)
	_check(StringName(str(window.get("_tree"))) == TITLE_ID, "ofício herdado abre a árvore do título base")
	var every_title: Array[StringName] = []
	for id: Variant in Content.all(&"titles").keys():
		every_title.append(StringName(str(id)))
	var many_progress := {"titles": every_title, "skills": {}}
	window.set_progress(many_progress)
	await _frames(3)
	var many_row := window.find_child("TreeTabs", true, false) as VBoxContainer
	var many_scroll := window.find_child("TreeScroll", true, false) as ScrollContainer
	var many_trees: Array[StringName] = SkillsWindow.trees_for(many_progress)
	_check(many_row != null and many_row.get_child_count() == many_trees.size(),
			"conta avançada mantém todas as abas no conteúdo rolável")
	if many_row != null and many_scroll != null and many_row.get_child_count() > 0:
		var last: Button = many_row.get_child(many_row.get_child_count() - 1) as Button
		last.pressed.emit()
		await _frames(2)
		_check(StringName(str(window.get("_tree"))) == many_trees[-1], "última árvore continua selecionável com muitas abas")
	var bounds: Rect2 = Rect2(window.global_position, window.size)
	_check(get_viewport().get_visible_rect().encloses(bounds), "janela de Skills cabe na viewport")
	var image: Image = get_viewport().get_texture().get_image()
	var size: Vector2 = get_viewport().get_visible_rect().size
	image.save_png(_out_dir.path_join("skills_%dx%d.png" % [int(size.x), int(size.y)]))
	print("RESULT: " + ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


func _frames(count: int) -> void:
	for index: int in count:
		await get_tree().process_frame


func _check(condition: bool, description: String) -> void:
	print(("ok   " if condition else "FAIL ") + description)
	if not condition:
		_failures += 1