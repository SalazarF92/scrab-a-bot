class_name Enemy
extends CharacterBody2D
## Inimigo comum. GDD 5.1 e 5.2.
##
## Duas coisas nao obvias estao implementadas aqui:
##
## 1. "Regra de superficie" (GDD 5.1): inimigos SAO superficies de quique. O
##    campo `restitution` e lido pelo ProjectilePool na resolucao do quique.
##    Inimigos grandes e lentos existem em parte para o jogador quicar neles.
##
## 2. IA em fatias (GDD 7.2, otimizacao 2). O GDD pede "20 Hz, 12 grupos, um por
##    quadro", mas a 120 Hz de fisica 12 grupos dao 10 Hz, nao 20. Sao 6 grupos
##    aqui, que a 120 Hz dao exatamente os 20 Hz pedidos. O movimento interpola
##    entre as decisoes, entao a diferenca nao aparece na tela.

const AI_GROUPS := 6

@export var enemy_name: String = "Parafuseta"
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
@export var flees: bool = false
@export var is_boss: bool = false
@export var enemy_name: String = ""

var hp: float = 12.0
var scrap_value: int = 3

var _ai_group: int = 0
var _desired_velocity: Vector2 = Vector2.ZERO
var _flash: float = 0.0
var _deform: Vector2 = Vector2.ONE
var _phase: float = 0.0
var _player: Node2D
var _contact_cd: float = 0.0
var _dying: bool = false


func setup(spec: Dictionary, ai_group: int) -> void:
	for k in spec:
		set(k, spec[k])
	hp = max_hp
	_ai_group = ai_group % AI_GROUPS
	_phase = GameRng.randf_range_in(GameRng.Stream.AI, 0.0, TAU)


func _ready() -> void:
	add_to_group(&"enemies")
	add_to_group(&"damageable")
	collision_layer = ProjectilePool.LAYER_ENEMIES
	collision_mask = ProjectilePool.LAYER_WALLS
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = body_radius
	shape.shape = circle
	add_child(shape)
	z_index = 10
	hp = max_hp


func _physics_process(delta: float) -> void:
	if CombatFeel.frozen:
		return

	_flash = maxf(0.0, _flash - delta)
	_contact_cd = maxf(0.0, _contact_cd - delta)
	_deform = _deform.lerp(Vector2.ONE, minf(1.0, delta * 10.0))
	_phase += delta

	if Engine.get_physics_frames() % AI_GROUPS == _ai_group:
		_think()

	velocity = velocity.lerp(_desired_velocity, minf(1.0, delta * 12.0))
	move_and_slide()
	_check_contact()
	queue_redraw()


func _think() -> void:
	if _player == null or not is_instance_valid(_player):
		var players := get_tree().get_nodes_in_group(&"player")
		_player = players[0] if players.size() > 0 else null

	# No formato Ball x Pit, os inimigos descem pelo poco vertical em direcao a linha de defesa
	var descent_factor: float = 0.40
	if Engine.has_singleton(&"MetaManager") or is_instance_valid(MetaManager):
		descent_factor *= MetaManager.get_heat_descent_mult()
	var down_speed: float = move_speed * descent_factor
	var horizontal_drift: float = 0.0

	if zigzag_amplitude > 0.0:
		horizontal_drift = sin(_phase * 4.0) * (zigzag_amplitude * 1.5)
	elif _player != null and is_instance_valid(_player):
		# Leve atracao horizontal em direcao ao jogador
		var dx: float = _player.global_position.x - global_position.x
		horizontal_drift = clampf(dx * 0.6, -move_speed * 0.35, move_speed * 0.35)

	_desired_velocity = Vector2(horizontal_drift, down_speed)


func _check_contact() -> void:
	if _dying:
		return

	# Colisao direta de contato com o robo
	if _contact_cd <= 0.0 and _player != null and is_instance_valid(_player):
		if global_position.distance_to(_player.global_position) < body_radius + Robot.COLLISION_RADIUS:
			_player.call("take_damage", contact_damage, global_position, 0)
			_contact_cd = 0.6
			velocity.y = -200.0
			return

	# No formato Ball x Pit: inimigo que atinge a baseline invade e ataca a base
	if global_position.y >= ArenaGenerator.BASELINE_Y - 12.0:
		if _player != null and is_instance_valid(_player):
			_player.call("take_damage", contact_damage, global_position, 0)
		CombatFeel.add_trauma(0.25)
		Vfx.spawn_bounce(global_position, Vector2.UP, 3)
		_die()


func take_damage(amount: float, from: Vector2 = Vector2.ZERO, bounce_index: int = 0) -> void:
	if _dying:
		return
	if bounce_index < min_bounces_to_damage:
		# Nao apenas ignora: avisa. Sem o retorno visual o jogador acha que o
		# jogo bugou, e nao que aprendeu uma regra.
		Vfx.spawn_bounce(global_position, (from - global_position).normalized(), 1)
		return

	hp -= amount
	_flash = 0.06
	# GDD 2.4: inimigo levando ricochete forte espreme 0,5 no eixo do impacto.
	var squash: float = 0.5 if bounce_index >= 3 else 0.82
	_deform = Vector2(squash, 2.0 - squash)
	if hp <= 0.0:
		_die()


func _die() -> void:
	_dying = true
	if is_boss:
		CombatFeel.request_hitstop(130.0)
		CombatFeel.add_trauma(0.7)
		Sfx.play("fire_heavy", 4.0)
		if _player != null and is_instance_valid(_player):
			var heal_amount: float = _player.max_hp * 0.50
			_player.call("heal", heal_amount)
			Vfx.spawn_damage_number(global_position, heal_amount, 2, false)
	else:
		CombatFeel.request_hitstop(60.0)
		var luck_bonus: float = 0.01 * float(MetaManager.get_upgrade_level("sorte")) if Engine.has_singleton(&"MetaManager") or is_instance_valid(MetaManager) else 0.0
		if randf() < (0.06 + luck_bonus) and _player != null and is_instance_valid(_player):
			var heal_amount: float = _player.max_hp * 0.04
			_player.call("heal", heal_amount)
			Vfx.spawn_damage_number(global_position, heal_amount, 1, false)

	Vfx.spawn_death(global_position, color)
	Sfx.play_varied("enemy_death", -8.0)
	Telemetry.enemies_killed += 1
	MetaManager.add_scrap(scrap_value)
	queue_free()


# --- desenho greybox ----------------------------------------------------------

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, _deform)
	var c: Color = Color.WHITE if _flash > 0.0 else color
	if min_bounces_to_damage > 0:
		# O Fantasma de Disquete e translucido, o que ja avisa que ele e diferente.
		c.a = 0.55

	draw_circle(Vector2.ZERO, body_radius, c)
	draw_arc(Vector2.ZERO, body_radius, 0.0, TAU, 20, Color("#1A0F14"), 3.0)

	# GDD 2.6, regra dos olhos: inimigo comum tem dois olhos, elite tem quatro
	# ou mais. Os olhos sao o vetor primario de leitura de estado.
	var eye_r: float = maxf(2.5, body_radius * 0.28)
	var look := velocity.normalized() * eye_r * 0.4
	for i in eyes:
		var a := -PI * 0.5 + (float(i) - (eyes - 1) * 0.5) * 0.75
		var at := Vector2.from_angle(a) * body_radius * 0.45
		draw_circle(at, eye_r, Color("#F5F0E1"))
		draw_circle(at + look, eye_r * 0.45, Color("#1A0F14"))

	if is_boss:
		# Coroa / borda de perigo do chefe
		draw_arc(Vector2.ZERO, body_radius + 6.0, 0.0, TAU, 28, Color("#FF2D95"), 3.0)
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(-100.0, -body_radius - 20.0), enemy_name.to_upper(),
			HORIZONTAL_ALIGNMENT_CENTER, 200.0, 16, Color("#FFD400"))
		var bw := body_radius * 2.8
		var by := -body_radius - 12.0
		draw_rect(Rect2(-bw * 0.5, by, bw, 6.0), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-bw * 0.5, by, bw * (hp / max_hp), 6.0), Color("#FF2D95"))
	elif hp < max_hp:
		var w := body_radius * 2.0
		var y := -body_radius - 10.0
		draw_rect(Rect2(-w * 0.5, y, w, 4.0), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(-w * 0.5, y, w * (hp / max_hp), 4.0), Color("#8CFF1A"))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
