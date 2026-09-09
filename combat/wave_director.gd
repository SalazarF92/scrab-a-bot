class_name WaveDirector
extends Node2D
## Diretor de ondas. GDD 3.1, regras de ritmo.
##
## O GDD define "3 ondas" e "nunca mais de 8 segundos sem um inimigo em tela",
## mas nao define as regras de posicionamento do spawn. Elas estao em
## GDD_ADENDOS B.5 e sao implementadas aqui:
##  - nenhum inimigo nasce a menos de 400 px do jogador;
##  - todo spawn tem 0,5 s de telegrafia, uma sombra crescendo no chao;
##  - o tamanho da onda e um orcamento de ameaca em pontos, nao uma contagem
##    bruta, para o gerador escalar sem quebrar o ritmo.

signal room_cleared

const WAVES_PER_ROOM := 3
const MAX_SILENCE := 8.0
const MIN_SPAWN_DISTANCE := 400.0
const TELEGRAPH_TIME := 0.5

## Custo em pontos de ameaca por inimigo. Um tanque vale por varios enxames.
const THREAT_COST := {
	"parafuseta": 1.0,
	"rato_morto": 1.8,
	"fantasma_disquete": 3.0,
	"jato_preto": 3.2,
	"vovo_geladeira": 6.0,
	"mini_prensa": 12.0,
	"frostbyte": 25.0,
	"fornalha_suprema": 50.0,
}

var arena: ArenaGenerator
var player: Node2D
var sector: int = 1
var active: bool = true

var wave_index: int = 0
var _silence: float = 0.0
var _telegraphs: Array[Dictionary] = []
var _wave_pending: bool = false
var _post_clear: float = 0.0


func start_room(p_sector: int) -> void:
	sector = p_sector
	wave_index = 0
	_silence = 0.0
	_telegraphs.clear()
	active = true
	_spawn_wave()


func _process(delta: float) -> void:
	if not active:
		return

	var i := _telegraphs.size() - 1
	while i >= 0:
		_telegraphs[i]["t"] += delta
		if _telegraphs[i]["t"] >= TELEGRAPH_TIME:
			_materialize(_telegraphs[i])
			_telegraphs.remove_at(i)
		i -= 1
	queue_redraw()

	var alive := get_tree().get_nodes_in_group(&"enemies").size()
	if alive > 0 or not _telegraphs.is_empty():
		_silence = 0.0
		return

	_silence += delta

	if wave_index < WAVES_PER_ROOM:
		# Se o jogador limpou rapido, a proxima onda e antecipada. GDD 3.1.
		if _silence >= 0.6:
			_spawn_wave()
	else:
		# A porta abre 1,2 s depois do ultimo inimigo morrer, tempo para os
		# parafusos cairem e a fumaca dissipar. GDD 3.1.
		_post_clear += delta
		if _post_clear >= 1.2:
			active = false
			room_cleared.emit()


## Orcamento de ameaca por onda. Cresce com o setor e com o indice da onda.
func _wave_budget() -> float:
	var base := 14.0 * pow(1.35, float(sector - 1))
	var heat_mult: float = 1.0
	if Engine.has_singleton(&"MetaManager") or is_instance_valid(MetaManager):
		heat_mult = MetaManager.get_heat_budget_mult()
	return base * (0.8 + 0.35 * float(wave_index)) * heat_mult


func _spawn_wave() -> void:
	wave_index += 1
	_silence = 0.0
	_post_clear = 0.0

	var budget := _wave_budget()
	var rng := GameRng.stream(GameRng.Stream.ROOMGEN)

	# Se for a 3a onda de setor de chefe (1, 3 ou 5), gera o chefe centralizado no topo do poco
	if wave_index == WAVES_PER_ROOM:
		var boss_key := ""
		if sector == 1:
			boss_key = "mini_prensa"
		elif sector == 3:
			boss_key = "frostbyte"
		elif sector == 5:
			boss_key = "fornalha_suprema"

		if boss_key != "":
			var boss_cost: float = THREAT_COST[boss_key]
			budget = maxf(0.0, budget - boss_cost)
			_telegraph(boss_key, Vector2(ArenaGenerator.ARENA_SIZE.x * 0.5, 140.0))

	const COMMON_KEYS := ["parafuseta", "rato_morto", "fantasma_disquete", "jato_preto", "vovo_geladeira"]

	var guard := 0
	while budget > 0.0 and guard < 200:
		guard += 1
		var key: String = COMMON_KEYS[rng.randi_range(0, COMMON_KEYS.size() - 1)]
		var cost: float = THREAT_COST[key]
		if cost > budget:
			key = "parafuseta"
			cost = THREAT_COST[key]
		budget -= cost
		_telegraph(key, _pick_spawn_point(rng))


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


func _telegraph(key: String, at: Vector2) -> void:
	_telegraphs.append({"key": key, "pos": at, "t": 0.0})


func _materialize(tg: Dictionary) -> void:
	var e := Enemy.new()
	e.setup(EnemyLibrary.spec(tg["key"], sector), get_tree().get_nodes_in_group(&"enemies").size())
	e.position = tg["pos"]
	get_parent().add_child(e)
	e.global_position = tg["pos"]


func _draw() -> void:
	# A sombra que cresce e o contrato de justica do spawn: o jogador sempre tem
	# meio segundo para sair de onde a coisa vai nascer.
	for tg in _telegraphs:
		var k: float = tg["t"] / TELEGRAPH_TIME
		var r: float = lerpf(4.0, 26.0, k)
		draw_circle(tg["pos"], r, Color(0, 0, 0, 0.35))
		draw_arc(tg["pos"], r + 6.0, 0.0, TAU * k, 24, Color("#FF2D95"), 3.0)
