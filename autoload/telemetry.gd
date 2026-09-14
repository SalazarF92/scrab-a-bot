extends Node
## Telemetria obrigatoria desde o vertical slice. GDD 7.7.
##
## A metrica que decide o projeto esta aqui: "Distribuicao do multiplicador de
## quique no momento do dano. Se a mediana ficar abaixo de 1,25, o pilar 3
## falhou e o jogo precisa de intervencao de design."
##
## Ela existe desde o prototipo justamente porque o prototipo e o momento de
## cancelar o projeto barato, se for o caso.

const BUCKETS := 13  # indice = numero de quiques, 0 a 12

var damage_by_bounce: PackedFloat64Array
var hits_by_bounce: PackedInt64Array

var total_damage: float = 0.0
var total_hits: int = 0
var projectiles_fired: int = 0
var projectiles_expired_slow: int = 0
var enemies_killed: int = 0
var run_time: float = 0.0

## Formato de poco (GDD_ADENDOS F). A razao entre rebatidas e perdas no chao e a
## leitura direta de se o rebatedor e habilidade ou sorte.
var paddle_catches: int = 0
var projectiles_lost_floor: int = 0
## Inimigos que chegaram na base. Nao contam como abate.
var enemies_breached: int = 0
## Abates cujo ultimo acerto tinha pelo menos um quique. Desbloqueio da AMDeus.
var ricochet_kills: int = 0

var _running: bool = false


func _ready() -> void:
	reset()


func _process(delta: float) -> void:
	if _running:
		run_time += delta


func reset() -> void:
	damage_by_bounce = PackedFloat64Array()
	damage_by_bounce.resize(BUCKETS)
	hits_by_bounce = PackedInt64Array()
	hits_by_bounce.resize(BUCKETS)
	total_damage = 0.0
	total_hits = 0
	projectiles_fired = 0
	projectiles_expired_slow = 0
	enemies_killed = 0
	run_time = 0.0
	paddle_catches = 0
	projectiles_lost_floor = 0
	enemies_breached = 0
	ricochet_kills = 0
	_running = true


## Acertos no tier magenta (quique 4 ou mais). Condicao de desbloqueio da
## Placa de Video: "alcancar multiplicador 4 vinte vezes numa run".
func magenta_hits() -> int:
	var n := 0
	for b in range(4, BUCKETS):
		n += hits_by_bounce[b]
	return n


func record_hit(bounce_index: int, damage: float) -> void:
	var b: int = clampi(bounce_index, 0, BUCKETS - 1)
	damage_by_bounce[b] += damage
	hits_by_bounce[b] += 1
	total_damage += damage
	total_hits += 1


## Mediana ponderada por acerto, nao por dano. O contrato do GDD fala do
## multiplicador "no momento do dano", ou seja, por evento de acerto.
func median_bounce_multiplier() -> float:
	if total_hits == 0:
		return 0.0
	var half := total_hits / 2
	var acc := 0
	for b in BUCKETS:
		acc += hits_by_bounce[b]
		if acc >= half:
			return ProjectilePool.bounce_multiplier(b)
	return 1.0


## Fracao do dano total que veio de projeteis ja ricocheteados. E a leitura
## direta de "a arena e cumplice": se estiver baixa, o jogador esta mirando
## no inimigo e nao no chao.
func ricochet_damage_share() -> float:
	if total_damage <= 0.0:
		return 0.0
	var direct: float = damage_by_bounce[0]
	return 1.0 - direct / total_damage


func dps() -> float:
	return total_damage / maxf(run_time, 0.001)


func summary() -> String:
	return "dano %.0f | dps %.0f | acertos %d | mediana de quique x%.2f | dano por ricochete %.0f%% | rebatidas %d | perdidos no chao %d | invasoes %d" % [
		total_damage, dps(), total_hits, median_bounce_multiplier(), ricochet_damage_share() * 100.0,
		paddle_catches, projectiles_lost_floor, enemies_breached,
	]


## Estado completo, para o save de run (GDD_ADENDOS B.7).
func snapshot() -> Dictionary:
	return {
		"damage_by_bounce": Array(damage_by_bounce), "hits_by_bounce": Array(hits_by_bounce),
		"total_damage": total_damage, "total_hits": total_hits,
		"projectiles_fired": projectiles_fired, "projectiles_expired_slow": projectiles_expired_slow,
		"enemies_killed": enemies_killed, "run_time": run_time,
		"paddle_catches": paddle_catches, "projectiles_lost_floor": projectiles_lost_floor,
		"enemies_breached": enemies_breached, "ricochet_kills": ricochet_kills,
	}


func restore(data: Dictionary) -> void:
	if data.is_empty():
		return
	var damage: Array = data.get("damage_by_bounce", [])
	var hits: Array = data.get("hits_by_bounce", [])
	for b in mini(BUCKETS, damage.size()):
		damage_by_bounce[b] = float(damage[b])
	for b in mini(BUCKETS, hits.size()):
		hits_by_bounce[b] = int(hits[b])
	total_damage = float(data.get("total_damage", 0.0))
	total_hits = int(data.get("total_hits", 0))
	projectiles_fired = int(data.get("projectiles_fired", 0))
	projectiles_expired_slow = int(data.get("projectiles_expired_slow", 0))
	enemies_killed = int(data.get("enemies_killed", 0))
	run_time = float(data.get("run_time", 0.0))
	paddle_catches = int(data.get("paddle_catches", 0))
	projectiles_lost_floor = int(data.get("projectiles_lost_floor", 0))
	enemies_breached = int(data.get("enemies_breached", 0))
	ricochet_kills = int(data.get("ricochet_kills", 0))
