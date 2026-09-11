class_name Enemy
extends CharacterBody2D
## Inimigo comum e chefe. GDD 5.1 e 5.2.
##
## Quatro coisas nao obvias estao implementadas aqui:
##
## 1. "Regra de superficie" (GDD 5.1): inimigos SAO superficies de quique. O
##    campo `restitution` e lido pelo ProjectilePool na resolucao do quique.
##    Inimigos grandes e lentos existem em parte para o jogador quicar neles.
##
## 2. IA em fatias (GDD 7.2, otimizacao 2). O GDD pede "20 Hz, 12 grupos, um por
##    quadro", mas a 120 Hz de fisica 12 grupos dao 10 Hz, nao 20. Sao 6 grupos
##    aqui, que a 120 Hz dao exatamente os 20 Hz pedidos. O movimento interpola
##    entre as decisoes, entao a diferenca nao aparece na tela.
##
## 3. Pool (GDD 7.2, otimizacao 1). O inimigo nao e liberado ao morrer: volta
##    para o EnemyPool. Por isso `activate` restaura os valores de fabrica antes
##    de aplicar a especificacao. Um objeto que ja foi Rato Morto nao pode nascer
##    Parafuseta com ziguezague.
##
## 4. Anti-travamento. No poco o inimigo desce reto. Se ele pousa em cima de um
##    obstaculo e o jogador esta embaixo, a atracao horizontal vai a zero, ele
##    fica parado para sempre e a sala nunca termina. Primeiro ele contorna pelo
##    lado que tem espaco. Se nao cabe em lado nenhum, como um chefe largo num
##    corredor estreito, ele se espreme por dentro do obstaculo.

const AI_GROUPS := 6
const STUCK_BEFORE_ESCAPE := 0.35
const MAX_ESCAPE_ATTEMPTS := 2
const ESCAPE_MARGIN := 6.0
## Rede de seguranca do modo espremido. Nunca deveria ser alcancada.
const SQUEEZE_TIMEOUT := 20.0
const CONTACT_COOLDOWN := 0.6
## Chefes param acima da linha de defesa: vencer exige mata-los, e as faixas
## deixam espaco horizontal para esquiva no formato de poco (adendo F).
const BOSS_HOLD_Y := 620.0
const BOSS_ATTACK_Y := 460.0
enum BossState { APPROACH, RECOVERY, TELEGRAPH, STRIKE }

## Valores de fabrica, restaurados a cada ativacao.
const FACTORY := {
	"enemy_name": "Parafuseta", "article": "uma", "max_hp": 12.0, "move_speed": 210.0,
	"contact_damage": 6.0, "restitution": 0.85, "body_radius": 14.0,
	"color": Color("#8A4B2A"), "eyes": 2, "min_bounces_to_damage": 0,
	"zigzag_amplitude": 0.0, "flees": false, "is_boss": false, "is_bumper": false,
	"descent_factor": 0.40, "spawn_on_death": "", "spawn_on_death_count": 0,
	"scrap_value": 3,
	"boss_kind": &"", "front_damage_mult": 1.0, "back_damage_mult": 1.0,
	"mob_kind": &"", "visual_id": &"", "split_generation": 0, "minimum_hits": 0, "is_elite": false,
}

@export var enemy_name: String = "Parafuseta"
## Artigo para a legenda de fim de run: "um", "uma", "o" ou "a".
@export var article: String = "uma"
@export var max_hp: float = 12.0
@export var move_speed: float = 210.0
@export var contact_damage: float = 6.0
@export var restitution: float = 0.85
@export var body_radius: float = 14.0
@export var color: Color = Color("#8A4B2A")
@export var eyes: int = 2
## GDD 5.2, Fantasma de Disquete: "Imune a projeteis com zero quiques. So pode
## ser morto por ricochete. E o inimigo que ensina o pilar 3."
@export var min_bounces_to_damage: int = 0
## Rato Morto: ziguezague de 80 px de amplitude, que atrapalha a mira direta e
## recompensa ricochete. GDD 5.2.
@export var zigzag_amplitude: float = 0.0
## Jato Preto: "Foge do jogador." GDD 5.2. No poco, foge na horizontal.
@export var flees: bool = false
@export var is_boss: bool = false
## Superficie de quique deliberada. Desenhado com setas de aceleracao.
@export var is_bumper: bool = false
## Fracao da velocidade usada para descer o poco.
@export var descent_factor: float = 0.40
## Ao morrer por dano, libera estes inimigos no lugar.
@export var spawn_on_death: String = ""
@export var spawn_on_death_count: int = 0
@export var boss_kind: StringName = &""
## A frente olha para a base; a origem do impacto fica abaixo do centro.
@export var front_damage_mult: float = 1.0
@export var back_damage_mult: float = 1.0
@export var mob_kind: StringName = &""
@export var visual_id: StringName = &""
@export var split_generation: int = 0
@export var minimum_hits: int = 0
@export var is_elite: bool = false
var _mob := MobAbility.new()
var _hits_received := 0

var hp: float = 12.0
var scrap_value: int = 3
var active: bool = false
## EnemyPool dono deste inimigo. Nulo quando instanciado avulso.
var pool: Node

var _ai_group: int = 0
var _desired_velocity: Vector2 = Vector2.ZERO
var _flash: float = 0.0
var _deform: Vector2 = Vector2.ONE
var _phase: float = 0.0
var _player: Node2D
var _contact_cd: float = 0.0
var _dying: bool = false
var _shape: CircleShape2D
var _overlap_query: PhysicsShapeQueryParameters2D

var _stuck: float = 0.0
var _escapes: int = 0
var _escape_dir: float = 0.0
var _escape_time: float = 0.0
var _squeezing: bool = false
var _squeeze_time: float = 0.0
var _squeeze_start_y: float = 0.0

## Estado publico para o desenho autoral, a HUD e sondas de gameplay.
var boss_phase: int = 1
var boss_state: BossState = BossState.APPROACH
var boss_attack_name: String = ""
var boss_exposed: bool = false
var boss_lanes: Array[float] = []
var boss_lane_half_width: float = 70.0
var _boss_timer: float = 0.0
var _boss_telegraph_duration: float = 1.2
var _boss_cycle: int = 0
var _boss_shards: bool = false
var _boss_damage_cd: float = 0.0
var _boss_shot: ProjectileType


func _ready() -> void:
	var shape := CollisionShape2D.new()
	_shape = CircleShape2D.new()
	_shape.radius = body_radius
	shape.shape = _shape
	add_child(shape)
	z_index = 10

	_overlap_query = PhysicsShapeQueryParameters2D.new()
	_overlap_query.collide_with_bodies = true
	_overlap_query.collide_with_areas = false
	_overlap_query.collision_mask = ProjectilePool.LAYER_WALLS
	_overlap_query.shape = _shape


## Liga o inimigo com uma especificacao da EnemyLibrary. Pode ser chamado antes
## ou depois de entrar na arvore.
func activate(spec: Dictionary, ai_group: int, at: Vector2) -> void:
	_mob.reset(self)
	_hits_received = 0
	for k in FACTORY:
		set(k, FACTORY[k])
	for k in spec:
		set(k, spec[k])
	hp = max_hp
	_ai_group = ai_group % AI_GROUPS
	_phase = GameRng.randf_range_in(GameRng.Stream.AI, 0.0, TAU)

	velocity = Vector2.ZERO
	_desired_velocity = Vector2.ZERO
	_flash = 0.0
	_deform = Vector2.ONE
	_contact_cd = 0.0
	_dying = false
	_player = null
	_stuck = 0.0
	_escapes = 0
	_escape_dir = 0.0
	_escape_time = 0.0
	_squeezing = false
	_squeeze_time = 0.0
	boss_phase = 1
	boss_state = BossState.APPROACH
	boss_attack_name = ""
	boss_exposed = false
	boss_lanes.clear()
	_boss_timer = 0.0
	_boss_cycle = 0
	_boss_shards = false
	_boss_damage_cd = 0.0
	_boss_shot = null
	if boss_kind != &"":
		_boss_shot = ProjectileType.make({
			"id": &"boss_shard", "speed": 330.0, "radius": 10.0,
			"max_bounces": 2, "ttl": 4.0, "damage": contact_damage * 0.32,
			"base_color": color, "stretch": 1.1,
			"damage_source": source_text(),
		})

	if _shape != null:
		_shape.radius = body_radius
	active = true
	visible = true
	collision_layer = ProjectilePool.LAYER_ENEMIES
	collision_mask = ProjectilePool.LAYER_WALLS
	add_to_group(&"enemies")
	add_to_group(&"damageable")
	set_physics_process(true)
	if is_inside_tree():
		global_position = at
	else:
		position = at
	queue_redraw()


## Desliga o inimigo sem tira-lo da arvore. Sem camada de colisao ele deixa de
## ser superficie no mesmo instante, inclusive no meio da resolucao de um quique.
func deactivate() -> void:
	_mob.reset(self)
	active = false
	_dying = true
	remove_from_group(&"enemies")
	remove_from_group(&"damageable")
	collision_layer = 0
	collision_mask = 0
	visible = false
	set_physics_process(false)
	velocity = Vector2.ZERO
	global_position = Vector2(-10000.0, -10000.0)


func _physics_process(delta: float) -> void:
	if not active or CombatFeel.frozen:
		return

	_flash = maxf(0.0, _flash - delta)
	_contact_cd = maxf(0.0, _contact_cd - delta)
	_escape_time = maxf(0.0, _escape_time - delta)
	_deform = _deform.lerp(Vector2.ONE, minf(1.0, delta * 10.0))
	_phase += delta

	if Engine.get_physics_frames() % AI_GROUPS == _ai_group:
		_think()
	if boss_kind != &"":
		_update_boss(delta)
	if mob_kind != &"":
		_mob.tick(self, delta)
		if not active or _dying: return

	velocity = velocity.lerp(_desired_velocity, minf(1.0, delta * 12.0))
	var y_before := global_position.y
	move_and_slide()
	if _squeezing:
		_update_squeeze(delta)
	else:
		_update_stuck(delta, global_position.y - y_before)
	_check_contact()
	queue_redraw()


func _think() -> void:
	if _player == null or not is_instance_valid(_player):
		var players := get_tree().get_nodes_in_group(&"player")
		_player = players[0] if players.size() > 0 else null

	# No formato de poco, os inimigos descem em direcao a linha de defesa.
	var down_speed: float = move_speed * descent_factor * MetaManager.get_heat_descent_mult()
	var drift := 0.0

	if _escape_time > 0.0:
		drift = _escape_dir * _escape_speed()
	elif zigzag_amplitude > 0.0:
		drift = sin(_phase * 4.0) * (zigzag_amplitude * 1.5)
	elif _player != null:
		var dx: float = _player.global_position.x - global_position.x
		if flees:
			# Afasta-se na horizontal enquanto o jogador esta perto do seu eixo.
			if absf(dx) < 320.0:
				drift = -(signf(dx) if dx != 0.0 else 1.0) * move_speed * 0.6
		else:
			drift = clampf(dx * 0.6, -move_speed * 0.35, move_speed * 0.35)
	if boss_kind != &"" and _player != null:
		# A aproximacao continua respeitando obstaculos e o anti-travamento.
		down_speed = minf(maxf(down_speed, 50.0), maxf(0.0, (BOSS_HOLD_Y - global_position.y) * 2.5))
		if boss_state == BossState.TELEGRAPH or boss_state == BossState.STRIKE:
			drift = 0.0
		elif _escape_time <= 0.0 and global_position.y >= BOSS_ATTACK_Y:
			drift = sin(_phase * 0.65) * move_speed * 0.65

	_desired_velocity = Vector2(drift, down_speed)
	if mob_kind == &"bomber" and _mob.warning > 0.0:
		_desired_velocity = Vector2.ZERO
		velocity = Vector2.ZERO


func _exit_tree() -> void:
	_mob.reset(self)


func _escape_speed() -> float:
	return maxf(move_speed * 0.8, 80.0)


# --- chefes do poco: preparar, avisar, atacar, expor ---------------------------

func _update_boss(delta: float) -> void:
	var next_phase := 3 if hp <= max_hp * 0.33 else (2 if hp <= max_hp * 0.66 else 1)
	if next_phase > boss_phase:
		boss_phase = next_phase
		# Transicao cancela o golpe antigo. Nao ha dano sem novo aviso.
		boss_state = BossState.RECOVERY
		boss_exposed = true
		boss_lanes.clear()
		_boss_timer = 2.0
		boss_attack_name = "FASE %d - NUCLEO EXPOSTO" % boss_phase
		CombatFeel.add_trauma(0.25)
	if _player == null or not is_instance_valid(_player):
		return
	_boss_timer = maxf(0.0, _boss_timer - delta)
	match boss_state:
		BossState.APPROACH:
			if global_position.y >= BOSS_ATTACK_Y:
				boss_state = BossState.RECOVERY
				_boss_timer = 1.2
		BossState.RECOVERY:
			if _boss_timer <= 0.0:
				_begin_boss_attack()
		BossState.TELEGRAPH:
			if _boss_timer <= 0.0:
				boss_state = BossState.STRIKE
				_boss_timer = 0.9 if boss_kind == &"frostbyte" and not _boss_shards else 0.3
				_boss_damage_cd = 0.0
				if _boss_shards:
					_fire_boss_shards()
				else:
					_hit_boss_lanes()
				CombatFeel.add_trauma(0.25 if boss_kind == &"frostbyte" else 0.4)
				Sfx.play("fire_heavy", -5.0)
		BossState.STRIKE:
			_boss_damage_cd = maxf(0.0, _boss_damage_cd - delta)
			if not _boss_shards and _boss_damage_cd <= 0.0:
				_hit_boss_lanes()
			if _boss_timer <= 0.0:
				boss_state = BossState.RECOVERY
				boss_exposed = true
				boss_lanes.clear()
				_boss_timer = 3.8 - 0.6 * float(boss_phase - 1)
				boss_attack_name = "MAIONESE EXPOSTA" if boss_kind == &"frostbyte" and boss_phase == 3 else "NUCLEO EXPOSTO"


func _begin_boss_attack() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_boss_cycle += 1
	boss_exposed = false
	boss_lanes.clear()
	_boss_shards = boss_kind != &"mini_prensa" and _boss_cycle % 2 == 0
	boss_lane_half_width = 64.0 if boss_kind == &"mini_prensa" else 76.0
	# A mira trava no INICIO do aviso; seguir o jogador durante o aviso tornaria
	# impossivel esquivar caminhando. Mesmo a fase 3 deixa corredores livres.
	var target_x := clampf(_player.global_position.x, 90.0, ArenaGenerator.ARENA_SIZE.x - 90.0)
	if _boss_shards:
		# Sete colunas cobriam toda a base no terceiro estágio. Cinco mantêm
		# saída caminhável; a última fase aumenta a velocidade dos estilhaços.
		var spread_steps := mini(boss_phase, 2)
		_boss_shot.speed = 330.0 + 30.0 * float(boss_phase - 1)
		for i in range(-spread_steps, spread_steps + 1):
			boss_lanes.append(clampf(target_x + float(i) * 125.0, 40.0, ArenaGenerator.ARENA_SIZE.x - 40.0))
	else:
		boss_lanes.append(target_x)
		if boss_phase >= 2:
			var other_x := target_x + (-270.0 if target_x > 500.0 else 270.0)
			boss_lanes.append(other_x)
		if boss_phase == 3:
			var third_x := target_x + (-540.0 if target_x > 500.0 else 540.0)
			if third_x >= 80.0 and third_x <= ArenaGenerator.ARENA_SIZE.x - 80.0:
				boss_lanes.append(third_x)
	match boss_kind:
		&"mini_prensa":
			boss_attack_name = "CARIMBO HIDRAULICO"
		&"frostbyte":
			boss_attack_name = "COMIDA VENCIDA" if _boss_shards else "SOPRO DO FREEZER"
		&"fornalha_suprema":
			boss_attack_name = "ESTILHACOS EM BRASA" if _boss_shards else "INCINERAR COLUNAS"
	_boss_telegraph_duration = 1.35 if boss_kind == &"frostbyte" else 1.2
	_boss_timer = _boss_telegraph_duration
	boss_state = BossState.TELEGRAPH


func _hit_boss_lanes() -> void:
	_boss_damage_cd = 0.35
	if _player == null or not is_instance_valid(_player):
		return
	for x in boss_lanes:
		if absf(_player.global_position.x - x) <= boss_lane_half_width + Robot.COLLISION_RADIUS:
			# O dano escalona junto do setor, mas nao usa o multiplicador de quique
			# do jogador. Invasao e ataque de chefe sao fontes diferentes.
			_player.call("take_damage", contact_damage * 0.45, Vector2(x, global_position.y), 0,
				source_text() + " / " + boss_attack_name, false)
			break


func _fire_boss_shards() -> void:
	if _player == null or not is_instance_valid(_player) or _boss_shot == null:
		return
	var projectiles := _player.get("pool") as ProjectilePool
	if projectiles == null:
		return
	var origin := global_position + Vector2(0.0, body_radius + 14.0)
	for x in boss_lanes:
		var direction := Vector2(x, ArenaGenerator.BASELINE_Y) - origin
		projectiles.spawn(origin, direction, _boss_shot, ProjectilePool.FACTION_ENEMY)


## Dano direcional usa a posicao do impacto, fornecida pelo ProjectilePool.
## Purga/explosao com origem no proprio centro ignora placas direcionais.
func damage_multiplier_from(from: Vector2) -> float:
	var dy := from.y - global_position.y
	var multiplier := 1.0
	if dy > body_radius * 0.18:
		multiplier = front_damage_mult if not boss_exposed else 1.0
	elif dy < -body_radius * 0.18:
		multiplier = back_damage_mult
	if boss_exposed:
		multiplier *= 2.5 if boss_kind == &"frostbyte" and boss_phase == 3 else 1.5
	return multiplier


# --- anti-travamento ----------------------------------------------------------

func _update_stuck(delta: float, dy: float) -> void:
	if _escape_time > 0.0:
		return
	var wanted := _desired_velocity.y * delta
	if wanted <= 0.01 or dy >= wanted * 0.25:
		_stuck = maxf(0.0, _stuck - delta * 2.0)
		if _stuck <= 0.0:
			_escapes = 0
		return
	_stuck += delta
	if _stuck >= STUCK_BEFORE_ESCAPE:
		_stuck = 0.0
		_start_escape()


## O corpo embaixo do inimigo que esta impedindo a descida, se houver.
func _blocking_body() -> Node2D:
	for k in get_slide_collision_count():
		var c := get_slide_collision(k)
		if c.get_normal().y < -0.5:
			return c.get_collider() as Node2D
	return null


func _start_escape() -> void:
	var blocker := _blocking_body()
	if blocker == null:
		return
	_escapes += 1
	if _escapes > MAX_ESCAPE_ATTEMPTS:
		_start_squeeze()
		return

	var half_width := 130.0
	if blocker is Obstacle:
		half_width = (blocker as Obstacle).size.x * 0.5
	var left_edge := blocker.global_position.x - half_width
	var right_edge := blocker.global_position.x + half_width
	var r := body_radius + ESCAPE_MARGIN
	var fits_left := left_edge - 2.0 * r >= 0.0
	var fits_right := right_edge + 2.0 * r <= ArenaGenerator.ARENA_SIZE.x
	if not fits_left and not fits_right:
		_start_squeeze()
		return

	var travel_left := global_position.x - (left_edge - r)
	var travel_right := (right_edge + r) - global_position.x
	var go_left := fits_left and (not fits_right or travel_left <= travel_right)
	_escape_dir = -1.0 if go_left else 1.0
	var speed := _escape_speed()
	_escape_time = (travel_left if go_left else travel_right) / speed + 0.25
	_desired_velocity.x = _escape_dir * speed


func _start_squeeze() -> void:
	_squeezing = true
	_squeeze_time = 0.0
	_squeeze_start_y = global_position.y
	_escape_time = 0.0
	collision_mask = 0


func _update_squeeze(delta: float) -> void:
	_squeeze_time += delta
	# Sem mascara as paredes laterais tambem nao seguram: prende no poco na mao.
	global_position.x = clampf(global_position.x, body_radius, ArenaGenerator.ARENA_SIZE.x - body_radius)
	var timed_out := _squeeze_time >= SQUEEZE_TIMEOUT
	if not timed_out:
		# Precisa ter descido de verdade antes de testar sobreposicao: no instante
		# em que comeca, o inimigo esta apoiado EM CIMA do obstaculo, sem tocar.
		if global_position.y < _squeeze_start_y + body_radius:
			return
		_overlap_query.transform = Transform2D(0.0, global_position)
		if not get_world_2d().direct_space_state.intersect_shape(_overlap_query, 1).is_empty():
			return
	_squeezing = false
	_escapes = 0
	_stuck = 0.0
	collision_mask = ProjectilePool.LAYER_WALLS


# --- contato, dano e morte ----------------------------------------------------

func source_text() -> String:
	return RunCaption.by_whom(article, enemy_name)


func _check_contact() -> void:
	if _dying:
		return

	if _contact_cd <= 0.0 and _player != null and is_instance_valid(_player):
		var center: Vector2 = _player.call("body_center")
		if global_position.distance_to(center) < body_radius + Robot.COLLISION_RADIUS:
			_player.call("take_damage", contact_damage, global_position, 0, source_text(), false)
			_contact_cd = CONTACT_COOLDOWN
			velocity.y = -200.0
			return

	# Inimigo que atinge a baseline invade e ataca a base.
	if global_position.y >= ArenaGenerator.BASELINE_Y - 12.0:
		_breach()


## Invasao da base. Machuca e some, mas NAO paga: nada de Sucata, cura, contagem
## de abate nem som de morte. Antes a invasao passava por _die e o jogador era
## recompensado por deixar o inimigo passar.
func _breach() -> void:
	if _dying:
		return
	_dying = true
	if _player != null and is_instance_valid(_player):
		_player.call("take_damage", contact_damage, global_position, 0, source_text(), true)
	CombatFeel.add_trauma(0.25)
	Vfx.spawn_bounce(global_position, Vector2.UP, 3)
	Telemetry.enemies_breached += 1
	_release()


func take_damage(amount: float, from: Vector2 = Vector2.ZERO, bounce_index: int = 0) -> float:
	if _dying or not active:
		return 0.0
	if bounce_index < min_bounces_to_damage:
		# Nao apenas ignora: avisa. Sem o retorno visual o jogador acha que o
		# jogo bugou, e nao que aprendeu uma regra.
		Vfx.spawn_bounce(global_position, (from - global_position).normalized(), 1)
		return 0.0

	var applied := amount * damage_multiplier_from(from)
	if applied <= 0.0: return 0.0
	_hits_received += 1
	if _hits_received < minimum_hits:
		applied = minf(applied, maxf(hp - 1.0, 0.0))
	hp -= applied
	_flash = 0.06
	# GDD 2.4: inimigo levando ricochete forte espreme 0,5 no eixo do impacto.
	var squash: float = 0.5 if bounce_index >= 3 else 0.82
	_deform = Vector2(squash, 2.0 - squash)
	if hp <= 0.0:
		_die()
	return applied


func _die() -> void:
	_dying = true
	if mob_kind == &"popup" and split_generation < 3:
		get_tree().call_group(&"wave_director", &"spawn_popup_children", self)
	var player_ok := _player != null and is_instance_valid(_player)
	if is_boss:
		CombatFeel.request_hitstop(130.0)
		CombatFeel.add_trauma(0.7)
		Sfx.play("fire_heavy", 4.0)
		if player_ok:
			var boss_heal: float = _player.get("max_hp") * 0.50
			_player.call("heal", boss_heal)
			Vfx.spawn_damage_number(global_position, boss_heal, 2, false)
	else:
		CombatFeel.request_hitstop(60.0)
		# O sorteio acontece sempre, com ou sem jogador, para o consumo do fluxo
		# de drops nao depender de estado que varia entre execucoes.
		var roll := GameRng.randf_in(GameRng.Stream.DROPS)
		var chance := 0.06 + 0.01 * float(MetaManager.get_upgrade_level("sorte"))
		if roll < chance and player_ok:
			var drop_heal: float = _player.get("max_hp") * 0.04
			_player.call("heal", drop_heal)
			Vfx.spawn_damage_number(global_position, drop_heal, 1, false)

	if spawn_on_death != "" and spawn_on_death_count > 0:
		get_tree().call_group(&"wave_director", &"spawn_minions", spawn_on_death, global_position, spawn_on_death_count)

	Vfx.spawn_death(global_position, color)
	Sfx.play_varied("enemy_death", -8.0)
	Telemetry.enemies_killed += 1
	MetaManager.add_scrap(scrap_value)
	_release()


func _release() -> void:
	_mob.reset(self)
	if pool != null:
		pool.call("release", self)
	else:
		queue_free()


# --- corpo autoral e leitura de combate ---------------------------------------

func _draw() -> void:
	if not active:
		return
	_draw_boss_telegraph()
	_mob.draw_warning(self, self)
	draw_set_transform(Vector2.ZERO, 0.0, _deform)
	ArtDirector.draw_enemy(self, self)
	if is_elite:
		draw_arc(Vector2.ZERO, body_radius + 9, 0, TAU, 30, Color("#7B2FBF"), 4.0)
	if _flash > 0.0:
		draw_circle(Vector2.ZERO, body_radius, Color(1.0, 1.0, 1.0, 0.5))
	if front_damage_mult < 1.0 and not boss_exposed:
		draw_arc(Vector2.ZERO, body_radius + 4.0, 0.15, PI - 0.15, 20, Color("#FFD400"), 5.0)
		draw_arc(Vector2.ZERO, body_radius + 4.0, PI + 0.3, TAU - 0.3, 20, Color("#8CFF1A"), 3.0)
	if boss_exposed:
		draw_arc(Vector2.ZERO, body_radius + 8.0, 0.0, TAU, 28, Color("#8CFF1A"), 4.0)

	if is_bumper:
		# Setas para fora: a mesma leitura dos obstaculos que aceleram o projetil.
		for k in 6:
			var d := Vector2.from_angle(TAU * float(k) / 6.0 + _phase * 0.6)
			var p := d * (body_radius + 10.0)
			draw_line(p - d * 6.0, p + d * 6.0, Color("#FFD400"), 3.0)
			draw_line(p + d * 6.0, p + d * 6.0 - d.rotated(0.7) * 6.0, Color("#FFD400"), 3.0)
			draw_line(p + d * 6.0, p + d * 6.0 - d.rotated(-0.7) * 6.0, Color("#FFD400"), 3.0)

	if is_boss:
		draw_arc(Vector2.ZERO, body_radius + 6.0, 0.0, TAU, 28, Color("#FF2D95"), 3.0)
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(-100.0, -body_radius - 20.0), enemy_name.to_upper(),
			HORIZONTAL_ALIGNMENT_CENTER, 200.0, 16, Color("#FFD400"))
		var bw := body_radius * 2.8
		var by := -body_radius - 12.0
		draw_rect(Rect2(-bw * 0.5, by, bw, 6.0), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-bw * 0.5, by, bw * (hp / max_hp), 6.0), Color("#FF2D95"))
		if boss_kind != &"":
			draw_string(font, Vector2(-170.0, body_radius + 30.0), "FASE %d/3  %s" % [boss_phase, boss_attack_name],
				HORIZONTAL_ALIGNMENT_CENTER, 340.0, 13, Color("#8CFF1A") if boss_exposed else Color("#F5F0E1"))
	elif hp < max_hp:
		var w := body_radius * 2.0
		var y := -body_radius - 10.0
		draw_rect(Rect2(-w * 0.5, y, w, 4.0), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(-w * 0.5, y, w * (hp / max_hp), 4.0), Color("#8CFF1A"))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_boss_telegraph() -> void:
	if boss_state != BossState.TELEGRAPH and boss_state != BossState.STRIKE:
		return
	var impact := boss_state == BossState.STRIKE
	var pulse := 0.5 + sin(_phase * 18.0) * 0.2
	var ink := Color("#22E0FF") if boss_kind == &"frostbyte" else Color("#FF5500")
	var floor_y := ArenaGenerator.BASELINE_Y + 18.0 - global_position.y
	for x in boss_lanes:
		var local_x := x - global_position.x
		if _boss_shards:
			draw_line(Vector2(0, body_radius + 14.0), Vector2(local_x, floor_y), Color(ink, 0.32), 3.0)
			draw_circle(Vector2(local_x, floor_y - 22.0), 16.0, Color(ink, 0.6))
		else:
			var rect := Rect2(local_x - boss_lane_half_width, body_radius, boss_lane_half_width * 2.0, maxf(0.0, floor_y - body_radius))
			draw_rect(rect, Color(ink, 0.35 if impact else 0.09 + pulse * 0.08))
			draw_rect(rect, Color(ink, 0.9), false, 3.0)
			# Hachuras na linha do robo tornam a zona legivel mesmo sobre cenario.
			for mark in 5:
				var mx := local_x - boss_lane_half_width + 10.0 + float(mark) * (boss_lane_half_width * 2.0 - 20.0) / 4.0
				draw_line(Vector2(mx - 8.0, floor_y - 24.0), Vector2(mx + 8.0, floor_y - 8.0), ink, 3.0)
	if not impact:
		var progress := 1.0 - _boss_timer / _boss_telegraph_duration
		draw_arc(Vector2.ZERO, body_radius + 14.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 36, ink, 5.0)
