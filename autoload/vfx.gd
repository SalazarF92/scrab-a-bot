extends Node2D
## Efeitos visuais em espaco de mundo, todos desenhados por _draw em pools fixos.
## Zero instanciacao durante o combate. GDD 7.2, otimizacao obrigatoria 1.
##
## Este autoload e um Node2D filho da raiz, entao herda a transformada de canvas
## da Camera2D ativa e desenha em coordenadas de mundo sem trabalho extra.

const MAX_RINGS := 96
const MAX_SPARKS := 512
const MAX_NUMBERS := 64
const MAX_MARKS := 128

## GDD 2.7.2: o anel muda de cor conforme o numero do quique. E assim que o
## jogador le a multiplicacao de dano sem olhar numero nenhum.
const BOUNCE_COLORS: Array[Color] = [
	Color("#F5F0E1"),  # 1 - branco osso
	Color("#FFD400"),  # 2 - amarelo
	Color("#FF6B1A"),  # 3 - laranja
	Color("#FF2D95"),  # 4+ - magenta
]

## GDD_ADENDOS C.1: a cor sozinha exclui ~8% dos jogadores. A forma do anel e a
## contagem de pips sao o canal redundante obrigatorio.
## 0 = circulo, 1 = quadrado, 2 = triangulo, 3 = estrela.
const BOUNCE_SHAPES := [0, 1, 2, 3]

## Acessibilidade. GDD_ADENDOS C.2.
var reduced_flashes: bool = false
var colorblind_shapes: bool = true

var _rings: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
var _numbers: Array[Dictionary] = []
var _marks: Array[Dictionary] = []
var _font: Font


func _ready() -> void:
	z_index = 100
	_font = ThemeDB.fallback_font


func _process(delta: float) -> void:
	# Efeitos avancam com delta REAL, nao com o relogio de combate.
	# Durante o hitstop o jogo congela e os efeitos continuam: e exatamente
	# essa dissociacao que da a sensacao de impacto. GDD 3.4.1.
	_age(_rings, delta)
	_age(_sparks, delta)
	_age(_marks, delta)
	_step_numbers(delta)
	queue_redraw()


func _age(pool: Array[Dictionary], delta: float) -> void:
	var i := pool.size() - 1
	while i >= 0:
		pool[i]["t"] += delta
		if pool[i]["t"] >= pool[i]["life"]:
			pool.remove_at(i)
		i -= 1


func _step_numbers(delta: float) -> void:
	var i := _numbers.size() - 1
	while i >= 0:
		var n := _numbers[i]
		n["t"] += delta
		# GDD 2.7.4: arco balistico com gravidade, nao linha reta.
		n["vel"].y += 900.0 * delta
		n["pos"] += n["vel"] * delta
		if n["pos"].y > n["floor_y"] and n["vel"].y > 0.0 and not n["bounced"]:
			n["vel"].y = -n["vel"].y * 0.45
			n["bounced"] = true
		if n["t"] >= n["life"]:
			_numbers.remove_at(i)
		i -= 1


# --- API ----------------------------------------------------------------------

## GDD 2.7.2, disparado em todo quique. "E o feedback mais importante do jogo."
func spawn_bounce(pos: Vector2, normal: Vector2, bounce_index: int) -> void:
	var tier: int = clampi(bounce_index - 1, 0, 3)
	var color: Color = BOUNCE_COLORS[tier]

	if _rings.size() < MAX_RINGS:
		_rings.append({
			"pos": pos, "t": 0.0, "life": 0.12,
			"color": color, "tier": tier, "normal": normal,
		})

	# 4 a 7 particulas num leque de 120 graus centrado na normal.
	var count := GameRng.randi_range_in(GameRng.Stream.VFX, 4, 7)
	for i in count:
		if _sparks.size() >= MAX_SPARKS:
			break
		var ang := normal.angle() + GameRng.randf_range_in(GameRng.Stream.VFX, -PI / 3.0, PI / 3.0)
		var speed := GameRng.randf_range_in(GameRng.Stream.VFX, 140.0, 380.0)
		_sparks.append({
			"pos": pos, "vel": Vector2.from_angle(ang) * speed,
			"t": 0.0, "life": GameRng.randf_range_in(GameRng.Stream.VFX, 0.12, 0.30),
			"color": color,
		})

	# Marca de impacto persistente no cenario, 3 s com desaparecimento gradual.
	if _marks.size() < MAX_MARKS:
		_marks.append({"pos": pos, "t": 0.0, "life": 3.0, "color": color, "normal": normal})


func spawn_death(pos: Vector2, color: Color = Color("#8A4B2A")) -> void:
	# Chuva de parafusos. GDD 2.7.5.
	var count := GameRng.randi_range_in(GameRng.Stream.VFX, 12, 22)
	for i in count:
		if _sparks.size() >= MAX_SPARKS:
			break
		var ang := GameRng.randf_range_in(GameRng.Stream.VFX, 0.0, TAU)
		_sparks.append({
			"pos": pos, "vel": Vector2.from_angle(ang) * GameRng.randf_range_in(GameRng.Stream.VFX, 90.0, 420.0),
			"t": 0.0, "life": GameRng.randf_range_in(GameRng.Stream.VFX, 0.25, 0.6),
			"color": color,
		})


func spawn_plop(pos: Vector2) -> void:
	# O projetil que ficou lento demais morre com uma fumacinha desanimada.
	# GDD 3.3.1, velocidade minima.
	if _rings.size() < MAX_RINGS:
		_rings.append({
			"pos": pos, "t": 0.0, "life": 0.25,
			"color": Color("#4A4F52"), "tier": 0, "normal": Vector2.UP,
		})


## GDD 2.7.4, agregacao obrigatoria: acima de 12 numeros na tela, um novo dano
## se soma ao numero existente mais proximo. Sem isso, builds tardias viram
## sopa ilegivel.
func spawn_damage_number(pos: Vector2, amount: float, bounce_index: int, crit: bool = false) -> void:
	if _numbers.size() > 12:
		var best := -1
		var best_d := 90.0
		for i in _numbers.size():
			var d: float = _numbers[i]["pos"].distance_to(pos)
			if d < best_d:
				best_d = d
				best = i
		if best >= 0:
			_numbers[best]["value"] += amount
			_numbers[best]["t"] = minf(_numbers[best]["t"], _numbers[best]["life"] * 0.35)
			_numbers[best]["scale"] = minf(_numbers[best]["scale"] * 1.06, 2.6)
			return

	if _numbers.size() >= MAX_NUMBERS:
		return

	var tier: int = clampi(bounce_index - 1, -1, 3)
	var color: Color = Color("#FFD400") if tier < 0 else BOUNCE_COLORS[tier]
	var scale := 1.0 + maxf(0.0, float(tier)) * 0.3
	if crit:
		color = Color("#FF2D95")
		scale = 2.2

	_numbers.append({
		"pos": pos, "value": amount, "t": 0.0, "life": 0.7,
		"vel": Vector2(GameRng.randf_range_in(GameRng.Stream.VFX, -80.0, 80.0), -350.0),
		"color": color, "scale": scale, "crit": crit,
		"rot": GameRng.randf_range_in(GameRng.Stream.VFX, -0.26, 0.26) if crit else 0.0,
		"floor_y": pos.y + 46.0, "bounced": false,
	})


func clear_all() -> void:
	_rings.clear()
	_sparks.clear()
	_numbers.clear()
	_marks.clear()


# --- desenho ------------------------------------------------------------------

func _draw() -> void:
	for m in _marks:
		var a: float = 1.0 - m["t"] / m["life"]
		draw_circle(m["pos"], 5.0, Color(m["color"], a * 0.35))

	for s in _sparks:
		var k: float = s["t"] / s["life"]
		var p: Vector2 = s["pos"] + s["vel"] * s["t"] * (1.0 - k * 0.6)
		draw_line(p, p - s["vel"].normalized() * 9.0, Color(s["color"], 1.0 - k), 2.5)

	for r in _rings:
		var k: float = r["t"] / r["life"]
		var radius: float = lerpf(6.0, 34.0, k)
		var col := Color(r["color"], 1.0 - k)
		var width := lerpf(4.0, 1.0, k)
		if colorblind_shapes:
			_draw_tier_shape(r["pos"], radius, r["tier"], col, width)
		else:
			draw_arc(r["pos"], radius, 0.0, TAU, 20, col, width)

	for n in _numbers:
		var k: float = n["t"] / n["life"]
		var alpha: float = 1.0 if k < 0.7 else 1.0 - (k - 0.7) / 0.3
		var size := int(20.0 * n["scale"])
		var text := str(int(round(n["value"])))
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var at: Vector2 = n["pos"] - Vector2(w * 0.5, 0.0)
		# Sombra dura deslocada 4 px, imitando o contorno desenhado a mao.
		draw_string(_font, at + Vector2(3, 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, alpha * 0.8))
		draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(n["color"], alpha))


## O canal redundante de leitura do multiplicador: circulo, quadrado, triangulo,
## estrela. Somado a escala e ao arpejo de audio, a cor vira o quarto canal.
func _draw_tier_shape(center: Vector2, radius: float, tier: int, color: Color, width: float) -> void:
	var shape: int = BOUNCE_SHAPES[clampi(tier, 0, 3)]
	match shape:
		0:
			draw_arc(center, radius, 0.0, TAU, 20, color, width)
		1:
			var pts := PackedVector2Array()
			for i in 5:
				pts.append(center + Vector2.from_angle(PI * 0.25 + TAU * i / 4.0) * radius)
			draw_polyline(pts, color, width)
		2:
			var pts3 := PackedVector2Array()
			for i in 4:
				pts3.append(center + Vector2.from_angle(-PI * 0.5 + TAU * i / 3.0) * radius)
			draw_polyline(pts3, color, width)
		_:
			var pts5 := PackedVector2Array()
			for i in 11:
				var r: float = radius if i % 2 == 0 else radius * 0.45
				pts5.append(center + Vector2.from_angle(-PI * 0.5 + TAU * i / 10.0) * r)
			draw_polyline(pts5, color, width)
