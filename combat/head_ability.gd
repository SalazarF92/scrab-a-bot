class_name HeadAbility
extends RefCounted
## GDD 4.3: habilidades ativas das cabecas. Tudo aqui e interpretado a partir
## dos campos `ability*` da PartData; uma cabeca nova e uma linha nova no
## catalogo, nao uma classe nova.
##
##   mark    Camera de Seguranca: marca o inimigo mais proximo; ele recebe
##           +ability_value de dano e atrai projeteis ricocheteados no raio.
##   scream  Boneca Queimada: anel que causa ability_value de dano, empurra e
##           atordoa por ability_duration; projeteis do jogador dentro do anel
##           invertem a direcao e ganham 2 quiques.
##   alarm   Radio-Relogio: automatico a cada ability_cooldown, ability_value
##           de dano em toda a tela.
##   light   Abajur: passiva (os behaviors da cabeca entram em todo disparo).

const SCREAM_PUSH := 400.0
const SCREAM_BONUS_BOUNCES := 2
const MARK_ATTRACT_STRENGTH := 700.0
const ATTRACT_INTERVAL := 0.05

var cooldown: float = 0.0
var marked: Node2D
var marked_left: float = 0.0
var _attract_clock: float = 0.0


func reset() -> void:
	cooldown = 0.0
	marked = null
	marked_left = 0.0
	_attract_clock = 0.0


func ready() -> bool:
	return cooldown <= 0.0


func tick(robot: Node2D, part: PartData, delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	if marked_left > 0.0:
		marked_left = maxf(0.0, marked_left - delta)
		# `marked` falso indica que o pool reciclou o no como outro inimigo.
		if marked_left <= 0.0 or not is_instance_valid(marked) or not marked.get("active") or not marked.get("marked"):
			_unmark()
		else:
			_attract_clock += delta
			if _attract_clock >= ATTRACT_INTERVAL and robot.get("pool") != null:
				# Projeteis ja ricocheteados sao puxados para o alvo marcado, a 20 Hz:
				# varrer os 2048 slots a cada passo de 120 Hz pesaria na fisica.
				robot.pool.attract_to(marked.global_position, part.ability_radius, MARK_ATTRACT_STRENGTH, _attract_clock, 1)
				_attract_clock = 0.0
	if part.ability == &"alarm" and cooldown <= 0.0:
		use(robot, part)


## Devolve true se a habilidade foi usada.
func use(robot: Node2D, part: PartData) -> bool:
	if cooldown > 0.0:
		return false
	var origin: Vector2 = robot.call("body_center")
	var enemies := robot.get_tree().get_nodes_in_group(&"enemies")
	match part.ability:
		&"mark":
			var best: Node2D = null
			var best_d := INF
			for e in enemies:
				var n := e as Node2D
				if n == null or not n.get("active"):
					continue
				var d := n.global_position.distance_squared_to(origin)
				if d < best_d:
					best_d = d
					best = n
			if best == null:
				return false
			_unmark()
			marked = best
			marked_left = part.ability_duration
			best.set("damage_taken_mult", 1.0 + part.ability_value)
			best.set("marked", true)
			Sfx.play("padlock_lock", -8.0)
		&"scream":
			for e in enemies:
				var n := e as Node2D
				if n == null or not n.get("active"):
					continue
				if n.global_position.distance_to(origin) <= part.ability_radius:
					n.call("take_damage", part.ability_value, origin, 0)
					n.call("apply_stun", part.ability_duration, (n.global_position - origin).normalized() * SCREAM_PUSH)
			if robot.get("pool") != null:
				robot.pool.reverse_in_radius(origin, part.ability_radius, SCREAM_BONUS_BOUNCES)
			CombatFeel.add_trauma(0.45)
			CombatFeel.request_hitstop(60.0)
			Vfx.spawn_death(origin, part.color)
			Sfx.play("fire_heavy", -2.0)
		&"alarm":
			var hit := 0
			for e in enemies:
				var n := e as Node2D
				if n == null or not n.get("active"):
					continue
				n.call("take_damage", part.ability_value, n.global_position, 0)
				hit += 1
			# Sem inimigo na tela o alarme espera, em vez de gastar a recarga no vazio.
			if hit == 0:
				return false
			CombatFeel.add_trauma(0.3)
			Vfx.spawn_death(origin, part.color)
			Sfx.play("beeper_countdown", -6.0)
		_:
			return false
	cooldown = part.ability_cooldown
	return true


func _unmark() -> void:
	if is_instance_valid(marked):
		marked.set("damage_taken_mult", 1.0)
		marked.set("marked", false)
	marked = null
	marked_left = 0.0
