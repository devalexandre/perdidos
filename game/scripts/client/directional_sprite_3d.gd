class_name DirectionalSprite3D
extends Node3D
## Visual 2.5D de personagem: Sprite3D billboard (eixo Y) com 8 direções a partir de 5 linhas
## (S, SE, E, NE, N) + espelhamento horizontal, e sombra plana no chão (GDD §17.2, §17.3).
## GDD §17.0.C ("não parecer papel"): todas as camadas usam o shader char_palette_swap_3d (luz da cena, lado
## da sombra em poucos tons, contorno aceso pelo céu, sombra projetada deitada no chão, pixel AA em escala
## fracionária); sombra macia colada aos pés (char_blob_shadow) que acompanha o sol; e "vida" procedural que
## funciona com qualquer folha: respiração parada, balanço do andar no ritmo dos passos, quique com
## achatamento na aterrissagem (monstros que pulam), flutuação (voadores), tranco + flash branco no golpe
## recebido e morte achatando e sumindo em pontilhado. Sutil em humanos, mais elástico em monstros.
## Pés do personagem ficam na origem deste nó.
## Serve para qualquer entidade: setup(body_type) (Viajante) ou setup_sheets(sprite_base) (NPC etc.).
## Folhas: <base>_idle.png, <base>_walk.png e opcional <base>_sit.png; quadro quadrado = altura / 5.

## Emitido quando um pé toca o chão na animação de andar (quadro 0 e metade do ciclo).
signal footstep

## Setores de 45° (índice 0..7), no sentido "câmera vê o personagem".
enum Dir { S, SE, E, NE, N, NW, W, SW }

const ANIM_IDLE: StringName = &"idle"
const ANIM_WALK: StringName = &"walk"
const ANIM_SIT: StringName = &"sit"
## Combate (contrato arrival, K): golpe, dano recebido e morte (morte segura o último quadro).
const ANIM_ATTACK: StringName = &"attack"
const ANIM_HIT: StringName = &"hit"
const ANIM_DEATH: StringName = &"death"
## Combate vivo (GDD §10.2.1, Agente A): golpe por tipo de arma (folha <base>_attack_<estilo>.png,
## escolhida por attack_style; sem ela, cai para _attack) e conjuração de skills mágicas.
const ANIM_ATTACK_UNARMED: StringName = &"attack_unarmed"
const ANIM_ATTACK_BLADE: StringName = &"attack_blade"
const ANIM_ATTACK_STAFF: StringName = &"attack_staff"
## Arco (item simple_bow, visual "bow"): puxa e solta a corda (tools/art/title_outfits/bow.py).
const ANIM_ATTACK_BOW: StringName = &"attack_bow"
const ANIM_CAST: StringName = &"cast"
const ATTACK_ANIMS: Array[StringName] = [ANIM_ATTACK_UNARMED, ANIM_ATTACK_BLADE, ANIM_ATTACK_STAFF, ANIM_ATTACK_BOW]
const ATTACK_STYLE_UNARMED: StringName = &"unarmed"
## Duração por quadro em ms (GDD §17.3). sit tem 1 quadro. Golpes do Viajante 70 ms, cast 90 ms.
const ANIM_FRAME_MS: Dictionary[StringName, int] = { ANIM_IDLE: 200, ANIM_WALK: 100, ANIM_SIT: 1000,
		ANIM_ATTACK: 100, ANIM_HIT: 120, ANIM_DEATH: 150, ANIM_ATTACK_UNARMED: 70, ANIM_ATTACK_BLADE: 70,
		ANIM_ATTACK_STAFF: 70, ANIM_ATTACK_BOW: 80, ANIM_CAST: 90 }
## Quadros de referência do ciclo (GDD §17.3): folhas com MAIS quadros tocam o mesmo ciclo mais fluido
## (idle 4 × 200 ms = 0,8 s; hit 2 × 120 ms = 0,24 s). Golpe e morte com mais quadros ficam mais longos (preparação).
const ANIM_REF_FRAMES: Dictionary[StringName, int] = { ANIM_IDLE: 4, ANIM_HIT: 2 }
## Folhas obrigatórias (placeholder se faltarem) e opcionais (caem para idle se faltarem).
const REQUIRED_ANIMS: Array[StringName] = [ANIM_IDLE, ANIM_WALK]
const OPTIONAL_ANIMS: Array[StringName] = [ANIM_SIT, ANIM_ATTACK, ANIM_HIT, ANIM_DEATH,
		ANIM_ATTACK_UNARMED, ANIM_ATTACK_BLADE, ANIM_ATTACK_STAFF, ANIM_ATTACK_BOW, ANIM_CAST]
## Avanço do golpe (fração da célula) e o perfil no tempo do golpe (0..1): recua um pouco na
## preparação, avança no impacto, segura e volta.
const LUNGE_CELLS: float = 0.3
const LUNGE_WINDUP: float = -0.12
## Empurrão/tremida do alvo atingido (fração da célula, duração e tremidas).
const KNOCKBACK_CELLS: float = 0.12
const KNOCKBACK_SEC: float = 0.22
const KNOCKBACK_SHAKES: float = 3.0
const LUNGE_FALLBACK_SEC: float = 0.3
## Animações que param no último quadro em vez de repetir.
const HOLD_LAST_FRAME_ANIMS: Array[StringName] = [ANIM_DEATH]
## Passos por ciclo da animação de andar (um por pé).
const STEPS_PER_WALK_CYCLE: int = 2
const TRAVELER_PREFIX: String = "chr_traveler_"
const SHADOW_FILE: String = "chr_shadow.png"
## Linhas desenhadas na folha (S, SE, E, NE, N).
const SHEET_DIRECTION_ROWS: int = 5
const DIRECTION_COUNT: int = 8
const SECTOR_ANGLE: float = TAU / DIRECTION_COUNT
const SHADOW_OPACITY: float = 0.5 # GDD §17.4 / contrato
## Eleva a sombra levemente acima do chão para evitar z-fighting.
const SHADOW_GROUND_OFFSET: float = 0.01
const MS_PER_SEC: float = 1000.0
const PLACEHOLDER_COLOR: Color = Color(1.0, 0.0, 1.0)
const SPRITE_NODE_NAME: StringName = &"Body"
const SHADOW_NODE_NAME: StringName = &"Shadow"
## Camadas sobrepostas (paper doll, GDD §17.4): em quais linhas da folha a camada aparece.
enum LayerRows { ALL, BACK_ONLY, FRONT_ONLY }
## Linhas da folha em que o personagem está de costas (NE, N e os espelhos NO): variantes _back.
const BACK_ROWS: Array[int] = [3, 4]
## Afastamento (m) entre camadas na direção da câmera, para a ordem de desenho sem z-fighting.
const LAYER_DEPTH_STEP: float = 0.004
## Grupo onde o ClientView registra a câmera que renderiza o mundo.
const CAMERA_GROUP: StringName = &"client_view_camera"
const SPRITE_SHADER_PATH: String = "res://assets/shaders/char_palette_swap_3d.gdshader"
const BLOB_SHADER_PATH: String = "res://assets/shaders/char_blob_shadow.gdshader"
## Modo "cores literais" do shader (= CharacterLayers.MODE_PLAIN).
const LAYER_MODE_PLAIN: int = 2
## Sombra macia dos pés: quad quadrado de BLOB_QUAD_M metros (o shader desenha a elipse dentro dele) e raio
## relativo à largura do quadro.
const BLOB_QUAD_M: float = 2.0
const BLOB_TEX_PX: int = 8
const BLOB_RENDER_PRIORITY: int = 6
## Perfis de "vida" procedural (GDD §17.0.C).
## BAKED (Agente B3): folhas renderizadas no Blender já trazem respiração, quique, squash & stretch e
## flutuação nos quadros (docs/arte-monstros-blender.md); o motor só acrescenta o tranco curto e o flash do golpe.
enum Life { HUMAN, MONSTER, HOPPER, FLYER, BAKED }
## Parâmetros por perfil: respiração (amplitude em Y, período s), balanço do andar (texels de tela),
## achatamento no passo, pulo (texels), flutuação (m), tranco no golpe e flash.
const LIFE_PARAMS: Dictionary = {
	Life.HUMAN: {"breath": 0.012, "breath_sec": 2.8, "bob_px": 1.0, "step_squash": 0.015, "hop_px": 0.0,
			"idle_hop_px": 0.0, "hover_m": 0.0, "flinch": 0.07, "flash": 0.25},
	Life.MONSTER: {"breath": 0.035, "breath_sec": 1.5, "bob_px": 2.0, "step_squash": 0.06, "hop_px": 0.0,
			"idle_hop_px": 0.0, "hover_m": 0.0, "flinch": 0.16, "flash": 0.85},
	Life.HOPPER: {"breath": 0.03, "breath_sec": 1.3, "bob_px": 0.0, "step_squash": 0.0, "hop_px": 9.0,
			"idle_hop_px": 3.0, "hover_m": 0.0, "flinch": 0.2, "flash": 0.85},
	Life.FLYER: {"breath": 0.02, "breath_sec": 1.1, "bob_px": 0.0, "step_squash": 0.0, "hop_px": 0.0,
			"idle_hop_px": 0.0, "hover_m": 0.16, "flinch": 0.12, "flash": 0.85},
	Life.BAKED: {"breath": 0.0, "breath_sec": 1.0, "bob_px": 0.0, "step_squash": 0.0, "hop_px": 0.0,
			"idle_hop_px": 0.0, "hover_m": 0.0, "flinch": 0.05, "flash": 0.85},
}
## Duração (s) do achatamento da aterrissagem, do tranco do golpe, do flash e da morte (achatar, sumir).
const LAND_SQUASH_SEC: float = 0.17
const FLINCH_SEC: float = 0.24
const FLASH_SEC: float = 0.13
const DEATH_SQUASH_SEC: float = 0.3
const DEATH_FADE_SEC: float = 0.7
## Intervalo (s) entre os quiques parados de quem pula.
const IDLE_HOP_EVERY_SEC: float = 1.25
const IDLE_HOP_SEC: float = 0.3

## px de tela por texel no ponto focado (ClientView.get_texel_scale()) e altura da janela: rótulos/barras no
## mundo usam isto para cair em pixels inteiros.
static var screen_texel_scale: float = 2.0
static var screen_height: float = 1080.0
static var _ui_version: int = 0
static var _sprite_shader: Shader = null
static var _blob_material: ShaderMaterial = null
static var _cam_cache: Camera3D = null
static var _cam_frame: int = -1

## Pasta dos assets de personagem; testes podem trocar antes de chamar setup().
static var asset_dir: String = "res://assets/characters/"

## Direção para onde a entidade olha (radianos, yaw no plano XZ, 0 = olhando para -Z).
var facing_yaw: float = 0.0
## Animação atual (&"idle" / &"walk" / &"sit").
var anim: StringName = ANIM_IDLE:
	set(value):
		if value != anim:
			anim = value
			_anim_time = 0.0
			_apply_anim_texture()
## Duração (ms) de um ciclo completo da animação de andar. 0 = usa ANIM_FRAME_MS. A entidade define
## a partir da velocidade (GDD §10.1: um ciclo a cada 2 células), para os pés não deslizarem.
var walk_cycle_ms: float = 0.0:
	set(value):
		# DES/velocidade podem mudar durante um passo; preservar sua fase evita um salto de pose.
		if anim == ANIM_WALK and walk_cycle_ms > 0.0 and value > 0.0:
			_anim_time *= value / walk_cycle_ms
		walk_cycle_ms = value
## Compensa o achatamento vertical do billboard eixo Y visto com a câmera inclinada, para que o
## sprite apareça ~1:1 em pixels (escala Y = 1 / cos(inclinação)). [DESVIO LOCAL — ver relatório]
@export var compensate_camera_pitch: bool = true
## Pula o processamento quando nenhum pedaço do sprite está na visão da câmera.
@export var cull_offscreen: bool = true
var _offscreen: bool = false

var body_type: StringName = &"male"
## Caminho base das folhas (sem sufixo), ex.: "res://assets/characters/chr_traveler_male".
var sprite_base: String = ""
var _sprite: Sprite3D
var _shadow: MeshInstance3D
var _textures: Dictionary[StringName, Texture2D] = {}
var _frame_counts: Dictionary[StringName, int] = {}
var _anim_time: float = 0.0
var _current_sector: int = Dir.S
var _last_col: int = -1
var _overlays: Array[Overlay] = []
## Animação de uma vez só (attack/hit) por cima da atual; &"" = nenhuma.
var _oneshot: StringName = &""
var _oneshot_left: float = 0.0
## Estilo do golpe (&"unarmed", &"blade", &"staff"...): ANIM_ATTACK vira attack_<estilo> se a folha existir.
var attack_style: StringName = &""
## Deslocamento só visual (avanço do golpe / empurrão ao ser atingido); o nó e a posição de rede não mudam.
var _lunge_dir: Vector3 = Vector3.ZERO
var _lunge_t: float = 0.0
var _lunge_len: float = 0.0
var _knock_dir: Vector3 = Vector3.ZERO
var _knock_t: float = 0.0
var _knock_delay: float = 0.0
static var _warned_paths: Dictionary[String, bool] = {}
## Personalização (ADENDO 2, Agente N): material de troca de paleta do corpo (shader
## char_palette_swap_3d, que lê a folha por uniform) e máscaras por animação.
const SHADER_SHEET_PARAM: StringName = &"sheet_tex"
const SHADER_MASK_PARAM: StringName = &"mask_tex"
const SHADER_MODULATE_PARAM: StringName = &"modulate"
var _body_material: ShaderMaterial = null
var _body_masks: Dictionary[StringName, Texture2D] = {}
## Vida procedural (GDD §17.0.C).
var life: int = Life.HUMAN
## Escala visual (estágio do monstro etc.); a compensação de inclinação e a vida multiplicam por cima.
var visual_scale: float = 1.0:
	set(value):
		visual_scale = value
		_update_vertical_scale()
var _base_scale: Vector3 = Vector3.ONE
var _life_t: float = 0.0
var _life_seed: float = 0.0
var _flinch_t: float = 0.0
var _flinch_delay: float = 0.0
var _flash_t: float = 0.0
var _death_t: float = -1.0
var _land_t: float = 10.0
var _hop_phase_prev: float = 0.0
var _lift: float = 0.0
## Últimos valores enviados aos materiais (evita set_shader_parameter todo quadro).
var _sent_lift: float = 0.0
var _sent_flash: float = 0.0
var _sent_fade: float = 1.0


## Uma camada sobreposta alinhada quadro a quadro com o corpo.
class Overlay:
	var sprite: Sprite3D
	## anim → folha (null = camada some nessa animação).
	var textures: Dictionary[StringName, Texture2D] = {}
	var frame_counts: Dictionary[StringName, int] = {}
	## Ordem relativa ao corpo (negativo = atrás).
	var order: int = 0
	var rows: int = LayerRows.ALL
	## Material de troca de paleta (personalização, ADENDO 2) ou null.
	var material: ShaderMaterial = null
	## Última folha enviada ao material.
	var shown_tex: Texture2D = null


func _init() -> void:
	_sprite = Sprite3D.new()
	_sprite.name = SPRITE_NODE_NAME
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.shaded = false
	_sprite.centered = true
	_sprite.vframes = SHEET_DIRECTION_ROWS
	# A sombra projetada é feita pelo shader (silhueta deitada no chão ao longo do sol, só na passada de sombra);
	# o billboard em pé nunca vai para o mapa de sombras (viraria um "risco" fino).
	_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
			if Balance.cfg == null or Balance.cfg.sprite_cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sprite)
	_life_seed = randf()
	_life_t = _life_seed * 10.0

	_shadow = MeshInstance3D.new()
	_shadow.name = SHADOW_NODE_NAME
	var shadow_mesh = QuadMesh.new()
	shadow_mesh.orientation = PlaneMesh.FACE_Y
	shadow_mesh.size = Vector2(BLOB_QUAD_M, BLOB_QUAD_M)
	_shadow.mesh = shadow_mesh
	_shadow.position.y = SHADOW_GROUND_OFFSET
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.material_override = blob_material()
	add_child(_shadow)
	set_body_material(null)


## Carrega as folhas do Viajante do tipo de corpo (&"male"/&"female"). Compatível com a Fase 1.
func setup(new_body_type: StringName) -> void:
	body_type = new_body_type
	setup_sheets("%s%s%s" % [asset_dir, TRAVELER_PREFIX, new_body_type])


## Carrega <base>_idle.png, <base>_walk.png e, se houver, <base>_sit.png.
func setup_sheets(base: String) -> void:
	sprite_base = base
	set_body_material(null)
	var pixel_size: float = Balance.cfg.sprite_pixel_size
	_sprite.pixel_size = pixel_size
	_textures.clear()
	_frame_counts.clear()
	for anim_name: StringName in REQUIRED_ANIMS + OPTIONAL_ANIMS:
		var path: String = "%s_%s.png" % [base, anim_name]
		var tex: Texture2D = null
		if anim_name in REQUIRED_ANIMS:
			tex = _load_texture(path)
		elif ResourceLoader.exists(path):
			tex = load(path) as Texture2D
		if tex == null:
			continue
		_textures[anim_name] = tex
		# Tamanho do quadro vem da própria folha (altura / 5 linhas): funciona com qualquer
		# tamanho de arte (ex.: provisória 64 px ou final Balance.cfg.character_frame_size).
		_frame_counts[anim_name] = maxi(1, tex.get_width() / _frame_height(tex))
	_apply_anim_texture()
	_update_vertical_scale()


## Material de troca de paleta do corpo (null = cores literais da folha, mesmo shader). masks: anim → máscara.
func set_body_material(mat: ShaderMaterial, masks: Dictionary[StringName, Texture2D] = {}) -> void:
	if mat == null:
		mat = make_sprite_material(LAYER_MODE_PLAIN)
	_body_material = mat
	_body_masks = masks
	_sprite.material_override = mat
	_configure_material(mat)
	_apply_anim_texture()
	set_tint(_sprite.modulate)


## Material do shader dos sprites (GDD §17.0.C) no modo dado (2 = cores literais da folha).
static func make_sprite_material(layer_mode: int = LAYER_MODE_PLAIN) -> ShaderMaterial:
	if _sprite_shader == null:
		_sprite_shader = load(SPRITE_SHADER_PATH) as Shader
	var m := ShaderMaterial.new()
	m.shader = _sprite_shader
	m.set_shader_parameter(&"layer_mode", layer_mode)
	return m


## Material compartilhado da sombra macia dos pés (o ClientView atualiza a direção do sol).
static func blob_material() -> ShaderMaterial:
	if _blob_material == null:
		_blob_material = ShaderMaterial.new()
		_blob_material.shader = load(BLOB_SHADER_PATH) as Shader
		# Depois das manchas de chão transparentes (terra, areia, água: prioridade até 5 nos construtores).
		_blob_material.render_priority = BLOB_RENDER_PRIORITY
	return _blob_material



## Sol da cena (direção em que a luz viaja, energia, se projeta sombra): sombra dos pés deslocada/escurecida.
static func set_scene_sun(travel_dir: Vector3, energy: float, casts_shadow: bool) -> void:
	var m := blob_material()
	m.set_shader_parameter(&"sun_dir", travel_dir.normalized())
	m.set_shader_parameter(&"sun_strength", clampf(energy / 1.2, 0.0, 1.0) if casts_shadow else
			clampf(energy / 1.2, 0.0, 1.0) * 0.5)


## Escala de texel da tela (ClientView) — rótulos, barras e balões no mundo se ajustam a ela.
static func set_screen_texel_scale(texel_scale: float, window_height: float) -> void:
	if is_equal_approx(texel_scale, screen_texel_scale) and is_equal_approx(window_height, screen_height):
		return
	screen_texel_scale = texel_scale
	screen_height = window_height
	_ui_version += 1


## Tamanho no mundo de 1 px de texto (Label3D) = 1 px de tela no ponto focado.
static func world_text_pixel_size() -> float:
	var ppu: float = float(Balance.cfg.world_pixels_per_unit) if Balance.cfg != null else 48.0
	return 1.0 / (ppu * maxf(0.25, screen_texel_scale))


## Fator da fonte dos textos no mundo (nome, números, balões): ≈1,5× o tamanho de arte em 1080p.
static func world_text_font_scale() -> float:
	return maxf(1.0, screen_texel_scale * 1.15)


## Tamanho no mundo de 1 texel de imagens de interface no mundo (barras, emotes): inteiro de px de tela.
static func world_image_pixel_size() -> float:
	var n: float = maxf(1.0, roundf(screen_texel_scale * 1.5))
	return n * world_text_pixel_size()


func _configure_material(mat: ShaderMaterial) -> void:
	if mat == null:
		return
	mat.set_shader_parameter(&"pitch_comp", _pitch_comp())
	mat.set_shader_parameter(&"lift", _sent_lift)
	mat.set_shader_parameter(&"flash", _sent_flash)
	mat.set_shader_parameter(&"fade", _sent_fade)
	mat.set_shader_parameter(&"cast_planar_shadow", Balance.cfg == null or Balance.cfg.sprite_cast_shadow)


func _pitch_comp() -> float:
	var pitch_cos: float = cos(deg_to_rad(Balance.cfg.camera_pitch_deg)) if Balance.cfg != null else 1.0
	return 1.0 / pitch_cos if compensate_camera_pitch and pitch_cos > 0.0 else 1.0


## Altura do quadro (px) da animação atual; 0 antes do setup.
func get_frame_height() -> int:
	var tex: Texture2D = _textures.get(_shown_anim())
	return _frame_height(tex) if tex != null else 0


## Altura visível do sprite no mundo (m), já com a compensação de inclinação.
func get_world_height() -> float:
	return get_frame_height() * _sprite.pixel_size * _sprite.scale.y


## Largura do quadro no mundo (m).
func get_world_width() -> float:
	return get_frame_height() * _sprite.pixel_size


## Tinge o sprite (ex.: destaque de hover).
func set_tint(color: Color) -> void:
	_sprite.modulate = color
	if _body_material != null:
		_body_material.set_shader_parameter(SHADER_MODULATE_PARAM, color)
	for o: Overlay in _overlays:
		o.sprite.modulate = color
		if o.material != null:
			o.material.set_shader_parameter(SHADER_MODULATE_PARAM, color)


func _process(delta: float) -> void:
	if _textures.is_empty():
		return
	_anim_time += delta
	_life_t += delta
	var cam: Camera3D = _find_camera()
	# Fora da tela: só o relógio da animação anda (o mapa replica centenas de entidades; GDD §17.0.C fluidez).
	if cull_offscreen and cam != null and not _on_screen(cam):
		_offscreen = true
		return
	_offscreen = false
	if cam != null:
		var to_camera: Vector3 = cam.global_position - global_position
		_current_sector = compute_sector(facing_yaw, to_camera)
		# A elipse da sombra dos pés é orientada pela câmera no próprio shader (char_blob_shadow).
	if not _oneshot.is_empty():
		_oneshot_left -= delta
		if _oneshot_left <= 0.0:
			_oneshot = &""
			_anim_time = 0.0
			_apply_anim_texture()
	var shown: StringName = _shown_anim()
	var frames: int = _frame_counts[shown]
	var frame_sec: float = get_frame_sec(shown, frames)
	var col: int = int(_anim_time / frame_sec) % frames
	if shown in HOLD_LAST_FRAME_ANIMS:
		col = mini(int(_anim_time / frame_sec), frames - 1)
	_sprite.frame = sheet_row_for_sector(_current_sector) * frames + col
	_sprite.flip_h = frame_mirrored(shown, col, _current_sector)
	_update_motion(delta)
	_update_life(delta, shown, frames, frame_sec)
	_update_overlays(shown, col)
	if col != _last_col:
		_last_col = col
		var step_every: int = maxi(1, frames / STEPS_PER_WALK_CYCLE)
		if shown == ANIM_WALK and col % step_every == 0:
			footstep.emit()


## Duração (s) de um quadro da animação: andar segue walk_cycle_ms (ciclo inteiro dividido pelos
## quadros da folha); as outras usam ANIM_FRAME_MS (GDD §17.3).
func get_frame_sec(anim_name: StringName, frames: int) -> float:
	if anim_name == ANIM_WALK and walk_cycle_ms > 0.0 and frames > 0:
		return walk_cycle_ms / frames / MS_PER_SEC
	var ms: float = ANIM_FRAME_MS.get(anim_name, ANIM_FRAME_MS[ANIM_IDLE])
	# Folhas com mais quadros que o padrão (monstros do Blender: idle 8, hit 4) mantêm a duração do ciclo.
	var ref: int = ANIM_REF_FRAMES.get(anim_name, 0)
	if ref > 0 and frames > ref:
		ms *= float(ref) / frames
	return ms / MS_PER_SEC


## Toca uma animação uma vez (attack/hit/cast) e volta à atual. false se a folha não existir.
## ANIM_ATTACK usa a folha do estilo (attack_<attack_style>) quando ela existe.
func play_oneshot(anim_name: StringName) -> bool:
	anim_name = resolve_anim(anim_name)
	if not _textures.has(anim_name):
		return false
	_oneshot = anim_name
	var frames: int = _frame_counts[anim_name]
	_oneshot_left = get_frame_sec(anim_name, frames) * frames
	_anim_time = 0.0
	_apply_anim_texture()
	return true


func has_anim(anim_name: StringName) -> bool:
	return _textures.has(anim_name)


## Quadros da folha da animação (0 se não existir).
func get_frame_count(anim_name: StringName) -> int:
	return _frame_counts.get(anim_name, 0)


## Folha usada para a animação pedida: attack -> attack_<attack_style> (se existir), senão _attack,
## senão attack_unarmed; as outras, ela mesma.
func resolve_anim(anim_name: StringName) -> StringName:
	if anim_name != ANIM_ATTACK:
		return anim_name
	if not attack_style.is_empty():
		var styled := StringName("%s_%s" % [ANIM_ATTACK, attack_style])
		if _textures.has(styled):
			return styled
	if not _textures.has(ANIM_ATTACK) and _textures.has(ANIM_ATTACK_UNARMED):
		return ANIM_ATTACK_UNARMED
	return anim_name


## Animação de uma vez tocando agora (&"" = nenhuma).
func get_oneshot() -> StringName:
	return _oneshot


## Tempo (s) que falta da animação de uma vez atual (0 = nenhuma).
func get_oneshot_left() -> float:
	return _oneshot_left if not _oneshot.is_empty() else 0.0


## Avanço do golpe na direção world_dir (XZ; ZERO = para onde olha), sincronizado com o golpe atual
## (ou LUNGE_FALLBACK_SEC sem folha de golpe). Só visual.
func play_lunge(world_dir: Vector3 = Vector3.ZERO) -> void:
	var d := Vector3(world_dir.x, 0.0, world_dir.z)
	if d.length_squared() < 0.0001:
		d = Vector3(-sin(facing_yaw), 0.0, -cos(facing_yaw))
	_lunge_dir = d.normalized()
	_lunge_len = _oneshot_left if not _oneshot.is_empty() and _oneshot_left > 0.0 else LUNGE_FALLBACK_SEC
	_lunge_t = 0.0


## Empurrão curto com tremida na direção world_dir (do atacante para o alvo), após delay_sec. Só visual.
func play_knockback(world_dir: Vector3, delay_sec: float = 0.0) -> void:
	var d := Vector3(world_dir.x, 0.0, world_dir.z)
	_knock_dir = d.normalized() if d.length_squared() > 0.0001 else Vector3.ZERO
	_knock_t = KNOCKBACK_SEC
	_knock_delay = maxf(0.0, delay_sec)


## Deslocamento visual atual (avanço + empurrão), em metros no mundo.
func get_motion_offset() -> Vector3:
	return _motion_offset()


# --- Vida procedural (GDD §17.0.C) ---

## Reação ao golpe recebido: achatamento rápido e flash branco (após delay_sec, no impacto). Só visual.
func play_flinch(delay_sec: float = 0.0) -> void:
	_flinch_t = FLINCH_SEC
	_flinch_delay = maxf(0.0, delay_sec)
	_flash_t = FLASH_SEC


## Morte: achata e some em pontilhado (monstros). Idempotente.
func play_death_fade() -> void:
	if _death_t < 0.0:
		_death_t = 0.0


## Volta ao normal (renascer / reaproveitar o visual).
func reset_life() -> void:
	if _death_t >= 0.0:
		_shadow.visible = true
	_death_t = -1.0
	_flinch_t = 0.0
	_flash_t = 0.0


func is_death_faded() -> bool:
	return _death_t >= DEATH_FADE_SEC + DEATH_SQUASH_SEC * 0.5


## Escala (x, y relativa) e altura (m) atuais da vida procedural, para testes/capturas.
func get_life_state() -> Dictionary:
	return {"scale": _sprite.scale / _base_scale, "lift": _lift, "flash": _sent_flash, "fade": _sent_fade}


## Escala Y relativa e deslocamento vertical (m) de "vida" para este quadro. Funciona com qualquer folha:
## parado respira; andando balança no ritmo dos passos (ciclo da folha de andar = 2 passos, GDD §10.1);
## quem pula quica uma vez por célula e achata ao aterrissar; voadores flutuam.
func _update_life(delta: float, shown: StringName, frames: int, frame_sec: float) -> void:
	var p: Dictionary = LIFE_PARAMS.get(life, LIFE_PARAMS[Life.HUMAN])
	var texel_m: float = (Balance.cfg.sprite_pixel_size if Balance.cfg != null else 1.0 / 48.0) * visual_scale
	# 1 px de arte na tela ≈ texel_m × pitch_comp de subida vertical (a câmera inclinada encurta a altura).
	var px_m: float = texel_m * _pitch_comp()
	var sy: float = 1.0
	var sx: float = 1.0
	var lift: float = 0.0
	var walking: bool = shown == ANIM_WALK
	var dead: bool = anim == ANIM_DEATH
	if walking:
		var cycle: float = maxf(0.05, frame_sec * frames)
		var phase: float = fposmod(_anim_time, cycle) / cycle
		var hop_px: float = float(p["hop_px"])
		if hop_px > 0.0:
			# Um pulo por célula (meio ciclo); aterrissagem = fase do pulo voltando a 0.
			var hp: float = fposmod(phase * 2.0, 1.0)
			if hp < _hop_phase_prev:
				_land_t = 0.0
			_hop_phase_prev = hp
			var air: float = sin(PI * hp)
			lift = hop_px * px_m * 4.0 * hp * (1.0 - hp)
			sy *= 1.0 + 0.08 * air
			sx *= 1.0 - 0.05 * air
		else:
			# Dois passos por ciclo: sobe no meio do passo, achata um pouco no contato.
			var step: float = absf(sin(TAU * phase))
			lift = float(p["bob_px"]) * px_m * step
			var contact: float = 1.0 - step
			sy *= 1.0 - float(p["step_squash"]) * contact * contact
			sx *= 1.0 + float(p["step_squash"]) * 0.6 * contact * contact
	elif not dead:
		var breath: float = sin(TAU * _life_t / float(p["breath_sec"]))
		sy *= 1.0 + float(p["breath"]) * breath
		sx *= 1.0 - float(p["breath"]) * 0.5 * breath
		var idle_hop: float = float(p["idle_hop_px"])
		if idle_hop > 0.0:
			var t: float = fposmod(_life_t, IDLE_HOP_EVERY_SEC)
			var hp: float = clampf(t / IDLE_HOP_SEC, 0.0, 1.0)
			if hp >= 1.0 and _hop_phase_prev < 1.0:
				_land_t = 0.0
			_hop_phase_prev = hp
			lift = idle_hop * px_m * 4.0 * hp * (1.0 - hp)
	var hover: float = float(p["hover_m"])
	if hover > 0.0 and not dead:
		lift += hover * (1.0 + 0.3 * sin(TAU * _life_t / 1.6))
	# Aterrissagem: achata e volta com um pequeno repique.
	_land_t += delta
	if _land_t < LAND_SQUASH_SEC:
		var k: float = 1.0 - _land_t / LAND_SQUASH_SEC
		var wob: float = cos(_land_t / LAND_SQUASH_SEC * PI * 1.5)
		sy *= 1.0 - 0.2 * k * wob
		sx *= 1.0 + 0.13 * k * wob
	# Golpe recebido: achata (e alarga) rápido, com flash branco.
	if _flinch_t > 0.0:
		if _flinch_delay > 0.0:
			_flinch_delay -= delta
		else:
			_flinch_t -= delta
			var k2: float = clampf(_flinch_t / FLINCH_SEC, 0.0, 1.0)
			var f: float = float(p["flinch"]) * sin(k2 * PI) * k2
			sy *= 1.0 - f
			sx *= 1.0 + f * 0.7
			_flash_t -= delta
	var flash: float = float(p["flash"]) * clampf(_flash_t / FLASH_SEC, 0.0, 1.0) if _flinch_delay <= 0.0 else 0.0
	# Morte: achata para baixo e some em pontilhado.
	var fade: float = 1.0
	if _death_t >= 0.0:
		_death_t += delta
		var ks: float = clampf(_death_t / DEATH_SQUASH_SEC, 0.0, 1.0)
		var ease_s: float = 1.0 - (1.0 - ks) * (1.0 - ks)
		sy *= lerpf(1.0, 0.55, ease_s)
		sx *= lerpf(1.0, 1.25, ease_s)
		fade = 1.0 - clampf((_death_t - DEATH_SQUASH_SEC * 0.5) / DEATH_FADE_SEC, 0.0, 1.0)
	_lift = lift
	_sprite.scale = _base_scale * Vector3(sx, sy, 1.0)
	_sprite.position.y = _motion_offset().y + lift
	# Sombra dos pés: menor e mais clara quando o sprite sobe.
	var blob_k: float = 1.0 - clampf(lift / 1.2, 0.0, 0.45)
	var frame_h: int = get_frame_height()
	var bk: float = (float(frame_h) / Balance.cfg.character_frame_size if frame_h > 0 else 1.0) * visual_scale
	_shadow.scale = Vector3(bk * blob_k * sx, 1.0, bk * blob_k * sx)
	if _death_t >= 0.0:
		_shadow.visible = fade > 0.05
	_push_life_params(lift, flash, fade)


func _push_life_params(lift: float, flash: float, fade: float) -> void:
	var changed_lift: bool = absf(lift - _sent_lift) > 0.0005
	var changed_flash: bool = absf(flash - _sent_flash) > 0.002
	var changed_fade: bool = absf(fade - _sent_fade) > 0.002
	if not (changed_lift or changed_flash or changed_fade):
		return
	_sent_lift = lift
	_sent_flash = flash
	_sent_fade = fade
	var mats: Array[ShaderMaterial] = []
	if _body_material != null:
		mats.append(_body_material)
	for o: Overlay in _overlays:
		if o.material != null:
			mats.append(o.material)
	for m: ShaderMaterial in mats:
		if changed_lift:
			m.set_shader_parameter(&"lift", lift)
		if changed_flash:
			m.set_shader_parameter(&"flash", flash)
		if changed_fade:
			m.set_shader_parameter(&"fade", fade)


## Perfil do avanço: t em 0..1 do golpe -> fração do avanço máximo.
static func lunge_curve(t: float) -> float:
	if t <= 0.0 or t >= 1.0:
		return 0.0
	if t < 0.25:
		return LUNGE_WINDUP * (t / 0.25)
	if t < 0.42:
		return lerpf(LUNGE_WINDUP, 1.0, (t - 0.25) / 0.17)
	if t < 0.62:
		return 1.0
	return lerpf(1.0, 0.0, (t - 0.62) / 0.38)


func _update_motion(delta: float) -> void:
	if _lunge_len > 0.0:
		_lunge_t += delta
		if _lunge_t >= _lunge_len:
			_lunge_len = 0.0
	if _knock_t > 0.0:
		if _knock_delay > 0.0:
			_knock_delay -= delta
		else:
			_knock_t -= delta
	var off: Vector3 = _motion_offset()
	_sprite.position = off + Vector3(0.0, _lift, 0.0)
	_shadow.position = Vector3(off.x, SHADOW_GROUND_OFFSET, off.z)


func _motion_offset() -> Vector3:
	var cell: float = Balance.cfg.cell_size if Balance.cfg != null else 1.0
	var off := Vector3.ZERO
	if _lunge_len > 0.0:
		off += _lunge_dir * LUNGE_CELLS * cell * lunge_curve(_lunge_t / _lunge_len)
	if _knock_t > 0.0 and _knock_delay <= 0.0:
		var k: float = _knock_t / KNOCKBACK_SEC # 1 -> 0
		var shake: float = sin((1.0 - k) * PI * 2.0 * KNOCKBACK_SHAKES)
		var side := Vector3(-_knock_dir.z, 0.0, _knock_dir.x)
		off += (_knock_dir * (0.6 + 0.4 * shake) + side * 0.35 * shake) * KNOCKBACK_CELLS * cell * k
	return off


## Setor exibido atualmente (Dir), útil para depuração/testes.
func get_sector() -> int:
	return _current_sector


# --- Camadas (paper doll) ---

## Adiciona uma camada. sheet_paths: anim → caminho da folha (arquivos ausentes são omitidos com aviso).
## order < 0 desenha atrás do corpo; rows limita às linhas de costas/frente.
func add_overlay(layer_name: StringName, sheet_paths: Dictionary[StringName, String], order: int,
		rows: int = LayerRows.ALL, material: ShaderMaterial = null) -> bool:
	var textures: Dictionary[StringName, Texture2D] = {}
	for anim_name: StringName in sheet_paths:
		var path: String = sheet_paths[anim_name]
		if not ResourceLoader.exists(path):
			_warn_once("DirectionalSprite3D: camada '%s' sem folha '%s', omitida." % [layer_name, path], path)
			continue
		var tex: Texture2D = load(path) as Texture2D
		if tex != null:
			textures[anim_name] = tex
	return add_overlay_textures(layer_name, textures, order, rows, material)


## Como add_overlay, com texturas prontas (anim → folha). material: troca de paleta (ou null).
func add_overlay_textures(layer_name: StringName, textures: Dictionary[StringName, Texture2D], order: int,
		rows: int = LayerRows.ALL, material: ShaderMaterial = null) -> bool:
	var o := Overlay.new()
	o.order = order
	o.rows = rows
	o.material = material
	for anim_name: StringName in textures:
		var tex: Texture2D = textures[anim_name]
		if tex == null:
			continue
		o.textures[anim_name] = tex
		o.frame_counts[anim_name] = maxi(1, tex.get_width() / _frame_height(tex))
	if o.textures.is_empty():
		return false
	o.sprite = Sprite3D.new()
	o.sprite.name = layer_name
	o.sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	o.sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	o.sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	o.sprite.shaded = false
	o.sprite.centered = true
	o.sprite.vframes = SHEET_DIRECTION_ROWS
	o.sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	o.sprite.pixel_size = _sprite.pixel_size
	o.sprite.scale = _sprite.scale
	o.sprite.visible = false
	if o.material == null:
		o.material = make_sprite_material(LAYER_MODE_PLAIN)
	o.sprite.material_override = o.material
	_configure_material(o.material)
	o.material.set_shader_parameter(SHADER_MODULATE_PARAM, _sprite.modulate)
	add_child(o.sprite)
	_overlays.append(o)
	return true


func clear_overlays() -> void:
	for o: Overlay in _overlays:
		o.sprite.queue_free()
	_overlays.clear()


## Nomes das camadas visíveis agora, da mais ao fundo para a mais à frente (inclui "Body").
func get_visible_layer_order() -> Array[StringName]:
	var entries: Array = [[0, SPRITE_NODE_NAME]]
	for o: Overlay in _overlays:
		if o.sprite.visible:
			entries.append([o.order, StringName(o.sprite.name)])
	entries.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var out: Array[StringName] = []
	for e: Array in entries:
		out.append(e[1])
	return out


func get_overlay_sprite(layer_name: StringName) -> Sprite3D:
	for o: Overlay in _overlays:
		if o.sprite.name == layer_name:
			return o.sprite
	return null


func get_body_sprite() -> Sprite3D:
	return _sprite


func _update_overlays(shown: StringName, col: int) -> void:
	if _overlays.is_empty():
		return
	var row: int = sheet_row_for_sector(_current_sector)
	var back: bool = row in BACK_ROWS
	var cam: Camera3D = _find_camera()
	var toward_cam := Vector3.ZERO
	if cam != null:
		var d: Vector3 = cam.global_position - global_position
		toward_cam = Vector3(d.x, 0.0, d.z).normalized()
	var motion: Vector3 = _sprite.position
	for o: Overlay in _overlays:
		var tex: Texture2D = o.textures.get(shown)
		var row_ok: bool = o.rows == LayerRows.ALL or (o.rows == LayerRows.BACK_ONLY) == back
		o.sprite.visible = tex != null and row_ok and _sprite.visible
		if not o.sprite.visible:
			continue
		var frames: int = o.frame_counts[shown]
		o.sprite.texture = tex
		if o.material != null and (tex != o.shown_tex or o.material.get_shader_parameter(SHADER_SHEET_PARAM) != tex):
			o.shown_tex = tex
			o.material.set_shader_parameter(SHADER_SHEET_PARAM, tex)
			o.material.set_shader_parameter(&"frame_px", float(_frame_height(tex)))
		o.sprite.hframes = frames
		o.sprite.offset = Vector2(0.0, _frame_height(tex) * 0.5)
		o.sprite.frame = row * frames + col % frames
		o.sprite.flip_h = _sprite.flip_h
		o.sprite.modulate = _sprite.modulate
		o.sprite.scale = _sprite.scale
		o.sprite.pixel_size = _sprite.pixel_size
		o.sprite.position = motion + toward_cam * LAYER_DEPTH_STEP * o.order


static func _warn_once(message: String, key: String) -> void:
	if _warned_paths.has(key):
		return
	_warned_paths[key] = true
	push_warning(message)


# --- Matemática de direção (pura, testável sem cena) ---

## Setor de 45° (Dir) em que a câmera vê a entidade.
## facing_yaw_rad: para onde a entidade olha (0 = -Z). to_camera: vetor entidade → câmera (só XZ importa).
## Ângulo relativo 0 = olhando para a câmera (S); +90° = olhando para a direita da tela (E); 180° = N.
static func compute_sector(facing_yaw_rad: float, to_camera: Vector3) -> int:
	# Vetor frente = (-sin(yaw), -cos(yaw)); ângulo de (x, z) medido como atan2(x, z).
	var facing_angle: float = facing_yaw_rad + PI
	var camera_angle: float = atan2(to_camera.x, to_camera.z)
	var relative: float = wrapf(facing_angle - camera_angle, 0.0, TAU)
	return posmod(roundi(relative / SECTOR_ANGLE), DIRECTION_COUNT)


## Linha da folha (0..4 = S, SE, E, NE, N) usada para o setor.
static func sheet_row_for_sector(sector: int) -> int:
	return sector if sector < SHEET_DIRECTION_ROWS else DIRECTION_COUNT - sector


## SW, W e NW usam SE, E e NE espelhados horizontalmente.
static func is_sector_mirrored(sector: int) -> bool:
	return sector >= SHEET_DIRECTION_ROWS


# --- Internos ---

## Animação efetivamente desenhada: a pedida, ou idle se a folha não existir (ex.: sit opcional).
func _shown_anim() -> StringName:
	if not _oneshot.is_empty() and anim != ANIM_DEATH:
		return _oneshot
	return anim if _textures.has(anim) else ANIM_IDLE


func _apply_anim_texture() -> void:
	_last_col = -1
	var shown: StringName = _shown_anim()
	if not _textures.has(shown):
		return
	_sprite.texture = _textures[shown]
	if _body_material != null:
		_body_material.set_shader_parameter(SHADER_SHEET_PARAM, _textures[shown])
		_body_material.set_shader_parameter(&"frame_px", float(_frame_height(_textures[shown])))
		if _body_masks.has(shown):
			_body_material.set_shader_parameter(SHADER_MASK_PARAM, _body_masks[shown])
	_sprite.hframes = _frame_counts[shown]
	# Pés (centro inferior do quadro) na origem: sobe meio quadro.
	_sprite.offset = Vector2(0.0, _frame_height(_textures[shown]) * 0.5)


static func _frame_height(tex: Texture2D) -> int:
	if tex == null:
		return 0
	return maxi(1, tex.get_height() / SHEET_DIRECTION_ROWS)


func _update_vertical_scale() -> void:
	_base_scale = Vector3(visual_scale, visual_scale * _pitch_comp(), visual_scale)
	_sprite.scale = _base_scale
	# Sombra dos pés proporcional à largura do quadro (quadro de 96 px = raio padrão do shader).
	var frame_h: int = get_frame_height()
	var k: float = (float(frame_h) / Balance.cfg.character_frame_size if frame_h > 0 else 1.0) * visual_scale
	_shadow.scale = Vector3(k, 1.0, k)
	if _body_material != null:
		_body_material.set_shader_parameter(&"pitch_comp", _pitch_comp())
	for o: Overlay in _overlays:
		if o.material != null:
			o.material.set_shader_parameter(&"pitch_comp", _pitch_comp())


func _find_camera() -> Camera3D:
	if not is_inside_tree():
		return null
	# Uma busca por quadro para todas as entidades (antes: 2 buscas no grupo por entidade por quadro).
	var frame: int = Engine.get_process_frames()
	if frame == _cam_frame and _cam_cache != null and is_instance_valid(_cam_cache) and _cam_cache.is_inside_tree():
		return _cam_cache
	var node: Node = get_tree().get_first_node_in_group(CAMERA_GROUP)
	_cam_cache = node as Camera3D if node is Camera3D else get_viewport().get_camera_3d()
	_cam_frame = frame
	return _cam_cache


## Algum pedaço do sprite (pés, cabeça, laterais) cai na visão da câmera?
func _on_screen(cam: Camera3D) -> bool:
	var p: Vector3 = global_position
	var h: float = maxf(1.0, get_world_height())
	var side: Vector3 = cam.global_basis.x * maxf(0.6, get_world_width() * 0.5)
	for q: Vector3 in [p, p + Vector3.UP * h, p + side + Vector3.UP * h * 0.5, p - side + Vector3.UP * h * 0.5]:
		if cam.is_position_in_frustum(q):
			return true
	return false


## Estava fora da tela no último quadro (processamento pulado)?
func is_offscreen() -> bool:
	return _offscreen


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path) as Texture2D
		if tex != null:
			return tex
	push_warning("DirectionalSprite3D: textura ausente '%s', usando placeholder." % path)
	var size: int = Balance.cfg.character_frame_size
	var img: Image = Image.create(size, size * SHEET_DIRECTION_ROWS, false, Image.FORMAT_RGBA8)
	img.fill(PLACEHOLDER_COLOR)
	return ImageTexture.create_from_image(img)


## Correção de orientação das folhas atuais do Viajante: a pose neutra SE foi exportada olhando
## para o lado oposto dos passos. Corpo e todas as camadas usam o mesmo espelhamento; NPCs e
## monstros mantêm suas próprias folhas. Retirar esta correção ao substituir as fontes afetadas.
func frame_mirrored(shown: StringName, column: int, sector: int) -> bool:
	var mirrored: bool = is_sector_mirrored(sector)
	if not sprite_base.begins_with("res://assets/characters/"):
		return mirrored
	var filename: String = sprite_base.get_file()
	var traveler: bool = filename.begins_with("chr_traveler_") or filename.begins_with("chr_male_") or filename.begins_with("chr_female_")
	return traveler_frame_mirrored(shown, column, sector) if traveler else mirrored


## Correção das folhas ATUAIS do Viajante (desenhadas por IA): a pose neutra SE foi exportada olhando para o lado
## oposto dos passos. C3 (28/09/2026): as folhas do pipeline 3D (tools/art/blender/characters) saem com a mesma
## orientação em todos os quadros; quando elas forem instaladas, LEGACY_SE_FIX deve virar false (e o teste
## _test_traveler_gait acompanha).
const LEGACY_SE_FIX: bool = false


static func traveler_frame_mirrored(shown: StringName, column: int, sector: int) -> bool:
	var mirrored: bool = is_sector_mirrored(sector)
	if LEGACY_SE_FIX and sheet_row_for_sector(sector) == 1:
		if shown == ANIM_IDLE or (shown == ANIM_WALK and column % 4 in [2, 3]):
			return not mirrored
	return mirrored
