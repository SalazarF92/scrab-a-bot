extends Node2D
## Visualizador interativo de animação da Mini-Prensa 500 (Boss do Setor 1).
## Permite testar os ciclos de Andar, Ataque e Poder em tempo real.

enum Mode { WALK, ATTACK, POWER, GRID }
var mode: Mode = Mode.WALK

var _timer: float = 0.0
var _anim_frame: int = 0
var _shake: float = 0.0

const FRAMES_WALK := [
	Rect2(21, 27, 306, 314),
	Rect2(370, 26, 312, 291),
	Rect2(682, 36, 307, 286),
]
const FRAMES_ATTACK := [
	Rect2(41, 341, 292, 331),
	Rect2(356, 353, 307, 314),
	Rect2(683, 393, 334, 282),
]
const FRAMES_POWER := [
	Rect2(39, 705, 302, 315),
	Rect2(341, 682, 341, 338),
	Rect2(682, 696, 318, 324),
]

var _tex: Texture2D


func _ready() -> void:
	_tex = load("res://assets/art/mini_prensa_animated.png")


var auto_loop: bool = true
var _state_timer: float = 0.0
const STATE_DURATION := 3.2
var _last_step := -1


func _process(delta: float) -> void:
	_timer += delta
	_shake = maxf(0.0, _shake - delta * 4.0)

	if auto_loop and mode != Mode.GRID:
		_state_timer += delta
		if _state_timer >= STATE_DURATION:
			_state_timer = 0.0
			_timer = 0.0
			match mode:
				Mode.WALK:
					mode = Mode.ATTACK
				Mode.ATTACK:
					mode = Mode.POWER
				Mode.POWER:
					mode = Mode.WALK

	match mode:
		Mode.WALK:
			var prev_frame := _anim_frame
			_anim_frame = int(floorf(_timer * 5.0)) % 3
			if _anim_frame != prev_frame and (_anim_frame == 0 or _anim_frame == 2):
				Sfx.play("dash", -16.0)
		Mode.ATTACK:
			var cycle := fmod(_timer, 1.6)
			if cycle < 0.5:
				_anim_frame = 0
			elif cycle < 0.9:
				_anim_frame = 1
			else:
				if _anim_frame != 2:
					_shake = 14.0
					Sfx.play("fire_heavy", 2.0)
				_anim_frame = 2
		Mode.POWER:
			var prev_frame := _anim_frame
			_anim_frame = 1 if (int(floorf(_timer * 6.0)) % 2 == 0) else 2
			if _anim_frame == 1 and prev_frame == 2:
				Sfx.play("overheat", -10.0)
		Mode.GRID:
			_anim_frame = 0

	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	match event.keycode:
		KEY_1:
			mode = Mode.WALK
			auto_loop = false
			_timer = 0.0
			_state_timer = 0.0
		KEY_2:
			mode = Mode.ATTACK
			auto_loop = false
			_timer = 0.0
			_state_timer = 0.0
		KEY_3:
			mode = Mode.POWER
			auto_loop = false
			_timer = 0.0
			_state_timer = 0.0
		KEY_4:
			mode = Mode.GRID
			auto_loop = false
		KEY_SPACE:
			auto_loop = not auto_loop
			_state_timer = 0.0
		KEY_ESCAPE:
			get_tree().quit(0)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var vp := get_viewport_rect().size

	# Fundo do depósito industrial:
	draw_rect(Rect2(Vector2.ZERO, vp), Color("#131015"))
	for y in range(40, int(vp.y), 60):
		draw_line(Vector2(0, y), Vector2(vp.x, y), Color("#241D26", 0.35), 1.0)
	for x in range(40, int(vp.x), 80):
		draw_line(Vector2(x, 0), Vector2(x, vp.y), Color("#241D26", 0.35), 1.0)

	# Cabeçalho e Instruções:
	draw_string(font, Vector2(0, 50), "SCRAP-A-BOT :: SHOWCASE DE ANIMAÇÃO DA MINI-PRENSA 500",
		HORIZONTAL_ALIGNMENT_CENTER, vp.x, 24, Color("#FFD400"))
	var help := "[1] ANDAR    [2] ATAQUE    [3] PODER    [4] GRADE COMPLETA    [ESPAÇO] CICLAR    [ESC] SAIR"
	draw_string(font, Vector2(0, 85), help, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 15, Color("#8CFF1A"))

	if _tex == null:
		draw_string(font, Vector2(0, 300), "ERRO: Textura não carregada", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 20, Color.RED)
		return

	if mode == Mode.GRID:
		_draw_grid(font, vp)
		return

	# Modo Focado no Centro:
	var shake_offset := Vector2(sin(_timer * 40.0) * _shake, cos(_timer * 47.0) * _shake)
	var center := vp * 0.5 + Vector2(0, 30) + shake_offset

	# Pedestal de sucata / sombra:
	draw_circle(center + Vector2(0, 180), 160, Color(0, 0, 0, 0.45))
	draw_line(center + Vector2(-220, 180), center + Vector2(220, 180), Color("#FFD400", 0.35), 3.0)

	var current_rect: Rect2
	var mode_label := ""
	var mode_desc := ""
	var badge_color := Color("#FFD400")

	match mode:
		Mode.WALK:
			current_rect = FRAMES_WALK[_anim_frame]
			mode_label = "ESTADO 1: ANDAR (Caminhada Pesada com Passadas Hidráulicas)"
			mode_desc = "Pistões laterais alternam apoio enquanto os pés de esteira avançam pelo poço (Frame %d/3)" % [_anim_frame + 1]
			badge_color = Color("#8CFF1A")
		Mode.ATTACK:
			current_rect = FRAMES_ATTACK[_anim_frame]
			mode_label = "ESTADO 2: ATAQUE (Carimbo Hidráulico)"
			var steps := ["1. Mandíbula abre até o limite com pistões esticados", "2. Salto para frente carregando a prensa", "3. IMPACTO DESTRUTIVO no piso com onda de choque"]
			mode_desc = steps[_anim_frame]
			badge_color = Color("#FF2D95")
		Mode.POWER:
			current_rect = FRAMES_POWER[_anim_frame]
			mode_label = "ESTADO 3: PODER ESPECIAL (Núcleo Exposto & Válvulas de Vapor)"
			mode_desc = "Fornalha central entra em ponto de fusão, jorrando vapor e chamas sob pressão pelas quatro saídas"
			badge_color = Color("#FF6B1A")

	# Desenha sprite em tamanho grande (360x360):
	var target_rect := Rect2(center - Vector2(180, 180), Vector2(360, 360))
	draw_texture_rect_region(_tex, target_rect, current_rect)

	# Faixas e legendas do estado ativo:
	draw_string(font, Vector2(0, vp.y - 130), mode_label, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 20, badge_color)
	draw_string(font, Vector2(0, vp.y - 100), mode_desc, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 15, Color("#F5F0E1"))

	# Barra de progresso do loop automático:
	if auto_loop:
		var bar_w := 400.0
		var bar_h := 8.0
		var bar_x := (vp.x - bar_w) * 0.5
		var bar_y := vp.y - 55.0
		var next_label := "Próximo: ATAQUE" if mode == Mode.WALK else ("Próximo: PODER" if mode == Mode.ATTACK else "Próximo: ANDAR")
		var progress := clampf(_state_timer / STATE_DURATION, 0.0, 1.0)
		draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color("#1C1622"))
		draw_rect(Rect2(bar_x, bar_y, bar_w * progress, bar_h), badge_color)
		draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(1, 1, 1, 0.3), false, 1.0)
		draw_string(font, Vector2(0, bar_y - 8), "LOOP ATIVO — " + next_label, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 12, Color(1, 1, 1, 0.6))
	else:
		draw_string(font, Vector2(0, vp.y - 50), "[LOOP PAUSADO - MODO TRAVADO - PRESSIONE ESPAÇO PARA REATIVAR]", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 13, Color("#FFD400"))


func _draw_grid(font: Font, vp: Vector2) -> void:
	var rows := [
		{"name": "ANDAR", "frames": FRAMES_WALK, "color": Color("#8CFF1A")},
		{"name": "ATAQUE", "frames": FRAMES_ATTACK, "color": Color("#FF2D95")},
		{"name": "PODER", "frames": FRAMES_POWER, "color": Color("#FF6B1A")},
	]
	var cell_size := Vector2(240, 240)
	var start_y := 120.0
	for r in 3:
		var row_info: Dictionary = rows[r]
		var y: float = start_y + float(r) * 280.0
		draw_string(font, Vector2(80, y + 120), row_info["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, row_info["color"])
		for c in 3:
			var x := 260.0 + float(c) * 380.0
			var rect := Rect2(Vector2(x, y), cell_size)
			draw_rect(rect.grow(4), Color("#2A2230"), false, 2.0)
			draw_texture_rect_region(_tex, rect, row_info["frames"][c])
			draw_string(font, Vector2(x, y + 255), "Frame %d" % [c + 1], HORIZONTAL_ALIGNMENT_CENTER, cell_size.x, 13, Color(1, 1, 1, 0.6))
