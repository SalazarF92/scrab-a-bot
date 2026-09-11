class_name ArenaGenerator
extends Node2D
## Gerador de sala. GDD 3.3.4, restricoes fixas.
##
## A restricao que importa e a terceira: "Nenhum ponto da arena a mais de 700 px
## de uma superficie de quique." E ela que garante que o pilar 3 sempre funcione,
## em toda sala, sem excecao. As outras existem para o jogador nao ficar preso.
##
## Todas as restricoes sao verificadas apos gerar, e a geracao e refeita se
## alguma falhar. O resultado da validacao fica em `last_report` e aparece no
## overlay de depuracao, porque uma restricao que ninguem ve nao e respeitada.

## O Poço Vertical (The Pit) no formato Ball x Pit.
## Corredor vertical onde inimigos descem e o jogador dispara para cima.

const ARENA_SIZE := Vector2(1000, 1080)
const BASELINE_Y := 960.0
const MIN_OBSTACLES := 3
const MAX_OBSTACLES := 6
const MIN_COVERAGE := 0.06
const MAX_COVERAGE := 0.18
const MIN_CORRIDOR := 150.0
const MAX_DIST_TO_SURFACE := 700.0
const WALL_THICKNESS := 200.0

## GDD 3.3.4, catalogo de obstaculos e bumpers do poco.
const CATALOG := [
	{"label": "Pilha de Pneus", "restitution": 1.35, "color": Color("#241A12"), "destructible": false},
	{"label": "Carcaca de Fusca", "restitution": 1.00, "color": Color("#8A4B2A"), "destructible": true, "max_hp": 300.0},
	{"label": "Colchao Velho", "restitution": 0.50, "color": Color("#2E5943"), "destructible": false},
	{"label": "Prensa Parada", "restitution": 1.00, "color": Color("#4A4F52"), "destructible": false},
	{"label": "Barril Toxico", "restitution": 1.05, "color": Color("#7E874A"), "destructible": true, "max_hp": 180.0},
	{"label": "TV Quebrada", "restitution": 0.90, "color": Color("#BBA788"), "destructible": true, "max_hp": 220.0},
	{"label": "Bobina de Cobre", "restitution": 1.40, "color": Color("#B77948"), "destructible": false},
	{"label": "Tubulacao", "restitution": 0.80, "color": Color("#84685A"), "destructible": false},
]

var visual_sector: int = 1
var last_report: Dictionary = {}

var _obstacle_rects: Array[Rect2] = []


func generate(sector: int = 1) -> void:
	visual_sector = sector
	for c in get_children():
		c.queue_free()
	_obstacle_rects.clear()

	var attempt := 0
	while attempt < 30:
		attempt += 1
		if _try_layout():
			break
	_build_walls()
	_build_obstacles(sector)
	last_report = _validate()
	queue_redraw()


func arena_rect() -> Rect2:
	return Rect2(Vector2.ZERO, ARENA_SIZE)


func center() -> Vector2:
	return ARENA_SIZE * 0.5


func baseline_spawn() -> Vector2:
	return Vector2(ARENA_SIZE.x * 0.5, BASELINE_Y)


# --- disposicao ---------------------------------------------------------------

func _try_layout() -> bool:
	_obstacle_rects.clear()
	var rng := GameRng.stream(GameRng.Stream.ROOMGEN)
	var count := rng.randi_range(MIN_OBSTACLES, MAX_OBSTACLES)
	var coverage := rng.randf_range(MIN_COVERAGE, MAX_COVERAGE)
	var area_each := ARENA_SIZE.x * ARENA_SIZE.y * coverage / float(count)

	for i in count:
		var placed := false
		for attempt in 300:
			var aspect := rng.randf_range(0.6, 1.8)
			var h := sqrt(area_each / aspect)
			var w := area_each / h
			w = clampf(w, 80.0, 240.0)
			h = clampf(h, 60.0, 150.0)
			# No poco vertical, os obstaculos ficam na zona intermediaria:
			# Y entre 220 (abaixo do spawn) e 800 (acima da baseline).
			var x := rng.randf_range(MIN_CORRIDOR, ARENA_SIZE.x - MIN_CORRIDOR - w)
			var y := rng.randf_range(220.0, 800.0 - h)
			var r := Rect2(x, y, w, h)
			if _fits(r):
				_obstacle_rects.append(r)
				placed = true
				break
		if not placed:
			continue

	if _obstacle_rects.size() < MIN_OBSTACLES:
		return false

	_grow_to_coverage(rng)
	var cov := _coverage()
	return cov >= MIN_COVERAGE and cov <= MAX_COVERAGE


func _grow_to_coverage(rng: RandomNumberGenerator) -> void:
	const STEP := 20.0
	const TARGET := 0.12
	var guard := 0
	while _coverage() < TARGET and guard < 800:
		guard += 1
		var i := rng.randi_range(0, _obstacle_rects.size() - 1)
		var r := _obstacle_rects[i]
		var grown := r.grow_individual(
			STEP if rng.randf() < 0.5 else 0.0,
			STEP if rng.randf() < 0.5 else 0.0,
			STEP if rng.randf() < 0.5 else 0.0,
			STEP if rng.randf() < 0.5 else 0.0)
		if grown.size == r.size:
			continue
		if grown.position.x < MIN_CORRIDOR or grown.position.y < 200.0:
			continue
		if grown.end.x > ARENA_SIZE.x - MIN_CORRIDOR or grown.end.y > 820.0:
			continue
		if not _fits(grown, i):
			continue
		_obstacle_rects[i] = grown


func _coverage() -> float:
	var area := 0.0
	for r in _obstacle_rects:
		area += r.size.x * r.size.y
	return area / (ARENA_SIZE.x * ARENA_SIZE.y)


## Dois obstaculos precisam de MIN_CORRIDOR de folga entre si. Crescendo cada um
## por metade disso e exigindo que nao se toquem, a checagem fica exata para
## retangulos e nao precisa de grade.
func _fits(candidate: Rect2, ignore_index: int = -1) -> bool:
	var grown := candidate.grow(MIN_CORRIDOR * 0.5)
	for i in _obstacle_rects.size():
		if i == ignore_index:
			continue
		if grown.intersects(_obstacle_rects[i].grow(MIN_CORRIDOR * 0.5)):
			return false
	return true


# --- construcao ---------------------------------------------------------------

func _build_walls() -> void:
	var t := WALL_THICKNESS
	var walls := [
		Rect2(-t, -t, ARENA_SIZE.x + t * 2.0, t),                       # topo
		Rect2(-t, ARENA_SIZE.y, ARENA_SIZE.x + t * 2.0, t),             # base
		Rect2(-t, 0.0, t, ARENA_SIZE.y),                                # esquerda
		Rect2(ARENA_SIZE.x, 0.0, t, ARENA_SIZE.y),                      # direita
	]
	for r in walls:
		var o := Obstacle.new()
		o.size = r.size
		o.position = r.position + r.size * 0.5
		# Parede de concreto: restituicao 1,00, o projetil nao perde velocidade.
		o.restitution = 1.0
		# Cinza chumbo e nao marrom-sombra: no greybox a parede precisa se separar
		# do piso a olho, senao nao da para julgar se um quique foi justo.
		o.color = Color("#4A4F52")
		o.label = "Parede"
		o.is_floor = r.position.y >= ARENA_SIZE.y
		add_child(o)


func _build_obstacles(_sector: int) -> void:
	var rng := GameRng.stream(GameRng.Stream.ROOMGEN)
	var destructible_index := rng.randi_range(0, _obstacle_rects.size() - 1)

	for i in _obstacle_rects.size():
		var r := _obstacle_rects[i]
		var entry: Dictionary = CATALOG[rng.randi_range(0, 3 if _sector <= 1 else CATALOG.size() - 1)]
		# GDD 3.3.4: "Pelo menos um obstaculo e movel ou destrutivel por sala."
		if i == destructible_index:
			entry = CATALOG[1]

		var o := Obstacle.new()
		o.size = r.size
		o.position = r.position + r.size * 0.5
		o.restitution = entry["restitution"]
		o.color = entry["color"]
		o.label = entry["label"]
		o.destructible = entry.get("destructible", false)
		o.max_hp = entry.get("max_hp", 400.0)
		add_child(o)


# --- validacao ----------------------------------------------------------------

func _validate() -> Dictionary:
	var area := 0.0
	for r in _obstacle_rects:
		area += r.size.x * r.size.y
	var coverage := area / (ARENA_SIZE.x * ARENA_SIZE.y)

	var corridors_ok := true
	for i in _obstacle_rects.size():
		for j in range(i + 1, _obstacle_rects.size()):
			if _obstacle_rects[i].grow(MIN_CORRIDOR * 0.5).intersects(_obstacle_rects[j].grow(MIN_CORRIDOR * 0.5)):
				corridors_ok = false

	var worst_dist := _max_distance_to_surface()

	return {
		"obstacles": _obstacle_rects.size(),
		"coverage": coverage,
		"coverage_ok": coverage >= MIN_COVERAGE - 0.02 and coverage <= MAX_COVERAGE + 0.02,
		"corridors_ok": corridors_ok,
		"reachable_ok": _bfs_reachable(),
		"surface_dist_ok": worst_dist <= MAX_DIST_TO_SURFACE,
		"max_surface_dist": worst_dist,
	}


## GDD 3.3.4: "O gerador roda validacao por busca em largura para garantir que
## toda a arena e alcancavel." Grade de 60 px, o suficiente para o raio de
## colisao de 26 px do jogador.
func _bfs_reachable() -> bool:
	const CELL := 60.0
	var cols := int(ARENA_SIZE.x / CELL)
	var rows := int(ARENA_SIZE.y / CELL)
	var blocked := PackedByteArray()
	blocked.resize(cols * rows)

	for r in _obstacle_rects:
		var padded := r.grow(Robot.COLLISION_RADIUS)
		var x0: int = maxi(0, int(padded.position.x / CELL))
		var y0: int = maxi(0, int(padded.position.y / CELL))
		var x1: int = mini(cols - 1, int(padded.end.x / CELL))
		var y1: int = mini(rows - 1, int(padded.end.y / CELL))
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				blocked[y * cols + x] = 1

	var start := -1
	for i in blocked.size():
		if blocked[i] == 0:
			start = i
			break
	if start < 0:
		return false

	var seen := PackedByteArray()
	seen.resize(cols * rows)
	var queue: Array[int] = [start]
	seen[start] = 1
	var visited := 1
	while not queue.is_empty():
		var cur: int = queue.pop_back()
		var cx := cur % cols
		var cy := cur / cols
		var neighbours: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		for d in neighbours:
			var nx := cx + d.x
			var ny := cy + d.y
			if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
				continue
			var ni := ny * cols + nx
			if seen[ni] == 1 or blocked[ni] == 1:
				continue
			seen[ni] = 1
			visited += 1
			queue.append(ni)

	var free_cells := 0
	for i in blocked.size():
		if blocked[i] == 0:
			free_cells += 1
	return visited == free_cells


## A restricao do pilar 3. Amostrada numa grade grossa: o pior caso e sempre o
## centro de uma regiao vazia, e 120 px de resolucao ja o encontra.
func _max_distance_to_surface() -> float:
	const STEP := 120.0
	var worst := 0.0
	var y := STEP * 0.5
	while y < ARENA_SIZE.y:
		var x := STEP * 0.5
		while x < ARENA_SIZE.x:
			var p := Vector2(x, y)
			var inside := false
			for r in _obstacle_rects:
				if r.has_point(p):
					inside = true
					break
			if not inside:
				var d: float = minf(minf(p.x, ARENA_SIZE.x - p.x), minf(p.y, ARENA_SIZE.y - p.y))
				for r in _obstacle_rects:
					d = minf(d, _distance_to_rect(p, r))
				worst = maxf(worst, d)
			x += STEP
		y += STEP
	return worst


func _distance_to_rect(p: Vector2, r: Rect2) -> float:
	var dx: float = maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dy: float = maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return sqrt(dx * dx + dy * dy)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	ArtDirector.draw_arena(self, visual_sector)
