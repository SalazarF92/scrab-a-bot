class_name WaveDirector
extends Node2D
## Diretor de ondas. GDD 3.1, regras de ritmo.
##
## O GDD define "3 ondas" e "nunca mais de 8 segundos sem um inimigo em tela",
## mas nao define as regras de posicionamento do spawn. Elas estao em
## GDD_ADENDOS B.5 e sao implementadas aqui:
##  - nenhum inimigo nasce a menos de 400 px do jogador;
##  - todo spawn tem telegrafia, uma sombra crescendo no chao;
##  - o tamanho da onda e um orcamento de ameaca em pontos, nao uma contagem
##    bruta, para o gerador escalar sem quebrar o ritmo.
##
## Sobre os 8 segundos: a proxima onda nasce 0,6 s depois da tela limpar, entao o
## contrato e cumprido com folga e nao existe temporizador de 8 s para manter.
##
## Onda de bumpers (GDD_ADENDOS F). Nos setores sem chefe, a segunda onda troca o
## enxame por Vovos Geladeiras Lotadas, superficies de quique de restituicao 1,35
## que descem devagar, escoltadas por Fantasmas de Disquete, que so morrem por
## ricochete. Matar a geladeira cedo libera um enxame de Parafusetas e tira a
## superficie que alimentava o multiplicador. E o inverso do reflexo do genero:
## o alvo mais gordo da tela e a coisa que voce quer manter viva por um tempo.

signal room_cleared
signal wave_started(index: int, kind: StringName)

const WAVES_PER_ROOM := 3
const MIN_SPAWN_DISTANCE := 400.0
const TELEGRAPH_TIME := 0.5
const BOSS_TELEGRAPH_TIME := 1.2
## Filhotes nascem de uma morte que o jogador acabou de ver, entao a telegrafia
## pode ser mais curta sem ferir o contrato de justica do spawn.
const MINION_TELEGRAPH_TIME := 0.25
const NEXT_WAVE_SILENCE := 0.6
## A porta abre 1,2 s depois do ultimo inimigo morrer. GDD 3.1.
const ROOM_CLEAR_DELAY := 1.2
const BANNER_TIME := 2.5

const BOSS_BY_SECTOR := {1: "mini_prensa", 3: "frostbyte", 5: "fornalha_suprema"}
## Setor -> indice da onda de bumpers.
const BUMPER_WAVE_BY_SECTOR := {2: 2, 4: 2}

## Custo em pontos de ameaca por inimigo. Um tanque vale por varios enxames.
const THREAT_COST := {
	"qwertypede": 4.0, "popup_vivo": 6.0, "cadeado_chorao": 7.0, "olhudo": 4.0,
	"bipador": 3.5, "ze_ventoinha": 5.0, "cabo_cobra": 4.0, "fabricadora": 12.0,
	"parafuseta": 1.0,
	"rato_morto": 1.8,
	"fantasma_disquete": 3.0,
	"jato_preto": 3.2,
	"vovo_geladeira": 6.0,
	"geladeira_bumper": 8.0,
	"mini_prensa": 12.0,
	"frostbyte": 25.0,
	"fornalha_suprema": 50.0,
}

const COMMON_KEYS := ["parafuseta", "rato_morto", "fantasma_disquete", "jato_preto", "vovo_geladeira"]
const BUMPER_ESCORT_KEYS := ["fantasma_disquete"]
const FEATURED_MOBS := {2: {1: "qwertypede", 3: "popup_vivo"}, 3: {1: "olhudo", 2: "bipador"},
	4: {1: "cadeado_chorao", 3: "ze_ventoinha"}, 5: {1: "cabo_cobra", 2: "fabricadora"}}
const LIMITED_MOBS := ["popup_vivo", "cadeado_chorao", "ze_ventoinha", "fabricadora"]


static func available_mobs(p_sector: int) -> Array:
	var available: Array = COMMON_KEYS.duplicate()
	for key in EnemyLibrary.EXPANSION_KEYS:
		if p_sector >= EnemyLibrary.INTRO_SECTOR[key]: available.append(key)
	return available

var arena: ArenaGenerator
var player: Node2D
var enemy_pool: EnemyPool
var sector: int = 1
var active: bool = false

var wave_index: int = 0
var wave_kind: StringName = &"normal"
## Tempo restante do letreiro de onda especial, lido pela HUD.
var wave_banner_time: float = 0.0

var _silence: float = 0.0
var _telegraphs: Array[Dictionary] = []
var _post_clear: float = 0.0


func _ready() -> void:
	add_to_group(&"wave_director")


func start_room(p_sector: int) -> void:
	sector = p_sector
	wave_index = 0
	wave_kind = &"normal"
	wave_banner_time = 0.0
	_silence = 0.0
	_post_clear = 0.0
	_telegraphs.clear()
	active = true
	_spawn_wave()


func stop() -> void:
	active = false
	_telegraphs.clear()
	wave_banner_time = 0.0
	queue_redraw()


func alive_enemies() -> int:
	if enemy_pool != null:
		return enemy_pool.active_count()
	return get_tree().get_nodes_in_group(&"enemies").size()


func pending_spawns() -> int:
	return _telegraphs.size()


func _process(delta: float) -> void:
	if not active or CombatFeel.frozen:
		return

	wave_banner_time = maxf(0.0, wave_banner_time - delta)

	var i := _telegraphs.size() - 1
	while i >= 0:
		_telegraphs[i]["t"] += delta
		if _telegraphs[i]["t"] >= _telegraphs[i]["time"]:
			_materialize(_telegraphs[i])
			_telegraphs.remove_at(i)
		i -= 1
	queue_redraw()

	if alive_enemies() > 0 or not _telegraphs.is_empty():
		_silence = 0.0
		_post_clear = 0.0
		return

	_silence += delta

	if wave_index < WAVES_PER_ROOM:
		# Se o jogador limpou rapido, a proxima onda e antecipada. GDD 3.1.
		if _silence >= NEXT_WAVE_SILENCE:
			_spawn_wave()
	else:
		_post_clear += delta
		if _post_clear >= ROOM_CLEAR_DELAY:
			active = false
			room_cleared.emit()


## Orcamento de ameaca por onda. Cresce com o setor e com o indice da onda.
func _wave_budget() -> float:
	var base := 14.0 * pow(1.35, float(sector - 1))
	return base * (0.8 + 0.35 * float(wave_index)) * MetaManager.get_heat_budget_mult()


func _spawn_wave() -> void:
	wave_index += 1
	_silence = 0.0
	_post_clear = 0.0
	wave_kind = &"normal"

	var budget := _wave_budget()
	# Fluxo proprio. Se o diretor dividisse o fluxo com o gerador de arena, a
	# arena do setor 2 dependeria de quantas tentativas de spawn o setor 1 fez,
	# e o desafio diario deixaria de ter a mesma sala para todo mundo.
	var rng := GameRng.stream(GameRng.Stream.WAVES)
	var keys: Array = available_mobs(sector)
	var counts: Dictionary = {}

	if wave_index == WAVES_PER_ROOM and BOSS_BY_SECTOR.has(sector):
		var boss_key: String = BOSS_BY_SECTOR[sector]
		wave_kind = &"boss"
		budget = maxf(0.0, budget - THREAT_COST[boss_key])
		_telegraph(boss_key, Vector2(ArenaGenerator.ARENA_SIZE.x * 0.5, 140.0), BOSS_TELEGRAPH_TIME)
	elif BUMPER_WAVE_BY_SECTOR.get(sector, -1) == wave_index:
		wave_kind = &"bumpers"
		keys = BUMPER_ESCORT_KEYS
		budget = _spawn_bumpers(budget, rng)
	if wave_kind == &"normal":
		var featured: String = FEATURED_MOBS.get(sector, {}).get(wave_index, "")
		if featured != "" and THREAT_COST[featured] <= budget:
			_telegraph(featured, _pick_spawn_point(rng), TELEGRAPH_TIME)
			budget -= THREAT_COST[featured]
			counts[featured] = 1

	var guard := 0
	while budget > 0.0 and guard < 200:
		guard += 1
		var key: String = keys[rng.randi_range(0, keys.size() - 1)]
		if key in LIMITED_MOBS and counts.get(key, 0) >= 1:
			key = "parafuseta"
		var cost: float = THREAT_COST[key]
		if cost > budget:
			key = "parafuseta"
			cost = THREAT_COST[key]
		budget -= cost
		counts[key] = counts.get(key, 0) + 1
		_telegraph(key, _pick_spawn_point(rng), TELEGRAPH_TIME)

	wave_banner_time = BANNER_TIME if wave_kind != &"normal" else 0.0
	wave_started.emit(wave_index, wave_kind)


func _spawn_bumpers(budget: float, rng: RandomNumberGenerator) -> float:
	var count := 2 if sector < 4 else 3
	var w := ArenaGenerator.ARENA_SIZE.x
	for b in count:
		var x := w * float(b + 1) / float(count + 1) + rng.randf_range(-40.0, 40.0)
		_telegraph("geladeira_bumper", Vector2(x, rng.randf_range(100.0, 140.0)), TELEGRAPH_TIME)
		budget -= THREAT_COST["geladeira_bumper"]
	return maxf(0.0, budget)


## Chamado por call_group quando um inimigo com `spawn_on_death` morre.
func spawn_minions(key: String, at: Vector2, count: int) -> void:
	if not active:
		return
	var rng := GameRng.stream(GameRng.Stream.WAVES)
	for c in count:
		var p := at + Vector2(rng.randf_range(-60.0, 60.0), rng.randf_range(-30.0, 10.0))
		p.x = clampf(p.x, 30.0, ArenaGenerator.ARENA_SIZE.x - 30.0)
		p.y = minf(p.y, ArenaGenerator.BASELINE_Y - 80.0)
		_telegraph(key, p, MINION_TELEGRAPH_TIME)


func spawn_popup_children(parent: Node2D) -> void:
	if not active or parent.split_generation >= 3: return
	for side in [-1.0, 1.0]:
		var child := EnemyLibrary.spec("popup_vivo", sector)
		child["max_hp"] = parent.max_hp * 0.5
		child["split_generation"] = parent.split_generation + 1
		child["body_radius"] = maxf(10.0, parent.body_radius * 0.78)
		child["scrap_value"] = 1
		var at: Vector2 = parent.global_position + Vector2(side * 28, -15)
		at.x = clampf(at.x, 35, ArenaGenerator.ARENA_SIZE.x - 35)
		at.y = minf(at.y, ArenaGenerator.BASELINE_Y - 85)
		_telegraphs.append({"key": "popup_vivo", "pos": at, "t": 0.0,
			"time": MINION_TELEGRAPH_TIME, "spec": child})


func _pick_spawn_point(rng: RandomNumberGenerator) -> Vector2:
	var size := ArenaGenerator.ARENA_SIZE
	for attempt in 60:
		var p := Vector2(rng.randf_range(100.0, size.x - 100.0), rng.randf_range(60.0, 240.0))
		if player != null and p.distance_to(player.global_position) < MIN_SPAWN_DISTANCE:
			continue
		var blocked := false
		for o in get_tree().get_nodes_in_group(&"obstacles"):
			var ob := o as Obstacle
			if ob == null:
				continue
			if Rect2(ob.global_position - ob.size * 0.5, ob.size).grow(40.0).has_point(p):
				blocked = true
				break
		if not blocked:
			return p
	return Vector2(size.x * 0.5, 120.0)


func _telegraph(key: String, at: Vector2, time: float) -> void:
	_telegraphs.append({"key": key, "pos": at, "t": 0.0, "time": time})


func _materialize(tg: Dictionary) -> void:
	var spec: Dictionary = tg["spec"] if tg.has("spec") else EnemyLibrary.spec(tg["key"], sector)
	var at: Vector2 = tg["pos"]
	if enemy_pool != null:
		enemy_pool.acquire(spec, at)
		return
	var e := Enemy.new()
	e.activate(spec, alive_enemies(), at)
	get_parent().add_child(e)


func _draw() -> void:
	# A sombra que cresce e o contrato de justica do spawn: o jogador sempre tem
	# tempo para sair de onde a coisa vai nascer.
	for tg in _telegraphs:
		var k: float = tg["t"] / tg["time"]
		var spec: Dictionary = tg["spec"] if tg.has("spec") else EnemyLibrary.SPECS[tg["key"]]
		var r: float = lerpf(4.0, float(spec.get("body_radius", 26.0)), k)
		var at: Vector2 = tg["pos"]
		draw_circle(at, r, Color(0, 0, 0, 0.35))
		draw_arc(at, r + 6.0, 0.0, TAU * k, 24, Color("#FF2D95"), 3.0)
