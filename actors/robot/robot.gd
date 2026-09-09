class_name Robot
extends CharacterBody2D
## O robo do jogador. GDD 3.2 (movimentacao), 4.1 (energia e calor), 4.2 (slots).
##
## Greybox: nao ha sprite nenhum, tudo e desenhado por _draw. O marco Prototipo
## do GDD 7.5 e explicito: "um retangulo cinza atirando bolas que quicam. A meta
## e unica: o ricochete precisa ser divertido sem arte nenhuma."
## A deformacao de squash and stretch da 2.4 ja esta aqui porque ela e feita em
## tempo de execucao, nao quadro a quadro, e portanto nao depende de arte.

signal died
signal stats_changed

# --- GDD 3.2, valores de movimentacao ----------------------------------------
const ACCELERATION := 2600.0
const DECELERATION := 3400.0
const DASH_SPEED := 900.0
const DASH_DURATION := 0.180
const DASH_IFRAME_START := 0.045
const DASH_IFRAME_END := 0.135
const DASH_COOLDOWN := 1.2
const COLLISION_RADIUS := 26.0
## GDD 1.2, contrato do pilar 1: buffer de input de 133 ms (8 quadros).
const INPUT_BUFFER := 0.133

# --- GDD 4.1.2, sistema de calor ---------------------------------------------
const HEAT_COOLDOWN_DELAY := 0.6
const OVERHEAT_LOCK := 1.8
const PURGE_HEAT_FRACTION := 0.60
const PURGE_DAMAGE := 40.0
const PURGE_RADIUS := 200.0
const PURGE_COOLDOWN := 8.0

# --- GDD 4.1.1, subvoltagem ---------------------------------------------------
const UNDERVOLT_FIRE_RATE_PENALTY := 0.30
const UNDERVOLT_SPASM_PERIOD := 4.0
const UNDERVOLT_SPASM_DURATION := 0.3

## GDD_ADENDOS B.2: sem i-frame pos-dano um enxame mata o jogador em 4 quadros
## e ele nao entende o que aconteceu.
const HIT_IFRAMES := 0.6

# --- GDD 3.2, assistencia de mira ---------------------------------------------
const AIM_ASSIST_CONE_DEG := 8.0
const AIM_ASSIST_RATE_DEG := 6.0
const AIM_ASSIST_RANGE := 500.0

var pool: ProjectilePool

var cpu: CpuData
var equipped: Dictionary = {}   # PartData.Slot -> PartData

var max_hp: float = 100.0
var hp: float = 100.0
var heat: float = 0.0
var heat_capacity: float = 100.0
var watts_used: int = 0
var overheated: bool = false

var aim_direction: Vector2 = Vector2.RIGHT
var deform: Vector2 = Vector2.ONE   # consumido pelo _draw, GDD 2.4

var _max_speed: float = 260.0
var _dash_charges_max: int = 1
var _dash_charges: float = 1.0
var _dash_time: float = 0.0
var _dash_dir: Vector2 = Vector2.RIGHT
var _dash_buffer: float = 0.0
var _iframes: float = 0.0
var _heat_idle: float = 0.0
var _overheat_timer: float = 0.0
var _purge_cd: float = 0.0
var _spasm_timer: float = 0.0
var _spasm_lock: float = 0.0
var _cooldowns: Dictionary = {}
var _fire_ctx := FireContext.new()
var _recoil: Vector2 = Vector2.ZERO
var _hit_flash: float = 0.0
var _using_gamepad: bool = false


func _ready() -> void:
	add_to_group(&"player")
	add_to_group(&"damageable")
	collision_layer = ProjectilePool.LAYER_PLAYER
	collision_mask = ProjectilePool.LAYER_WALLS
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	# GDD 3.2: "Raio de colisao do jogador 26 px. Sempre menor que o sprite.
	# Isso e intencional e melhora a sensacao de esquiva."
	circle.radius = COLLISION_RADIUS
	shape.shape = circle
	add_child(shape)
	z_index = 20


func equip(part: PartData) -> void:
	var old: PartData = equipped.get(part.slot)
	if old != null:
		for b in old.behaviors:
			b.on_unequip(self)
	equipped[part.slot] = part
	for b in part.behaviors:
		b.on_equip(self)
	_recompute_stats()


func set_cpu(c: CpuData) -> void:
	cpu = c
	heat_capacity = c.heat_capacity
	heat = 0.0
	overheated = false
	_recompute_stats()


func _recompute_stats() -> void:
	var chassis: PartData = equipped.get(PartData.Slot.CHASSIS)
	var new_max_hp := 100.0
	if chassis != null:
		new_max_hp = (chassis.hp * chassis.rarity_mult() + MetaManager.get_bonus_hp_flat()) * MetaManager.get_bonus_hp_mult()
		_max_speed = chassis.move_speed * MetaManager.get_bonus_speed_mult()
		_dash_charges_max = chassis.dash_charges + MetaManager.get_bonus_dash_charges()
	var ratio: float = 1.0 if max_hp <= 0.0 else hp / max_hp
	max_hp = new_max_hp
	hp = max_hp * ratio
	_dash_charges = minf(_dash_charges, float(_dash_charges_max))

	watts_used = 0
	for slot in equipped:
		watts_used += (equipped[slot] as PartData).watts
	stats_changed.emit()


## GDD 4.1.1: passar do TDP nao e proibido, e uma decisao de build valida quando
## as pecas sao muito boas. Mas custa caro.
func is_undervolt() -> bool:
	var total_tdp: int = (cpu.tdp if cpu != null else 0) + MetaManager.get_bonus_tdp()
	return cpu != null and watts_used > total_tdp


func heat_ratio() -> float:
	return heat / maxf(heat_capacity, 1.0)


func dash_charges() -> int:
	return int(floor(_dash_charges))


func purge_ready() -> bool:
	return _purge_cd <= 0.0


func purge_cooldown_ratio() -> float:
	return 1.0 - _purge_cd / PURGE_COOLDOWN


func purge_seconds_left() -> float:
	return _purge_cd


func dash_charges_max() -> int:
	return _dash_charges_max


## Fracao de recarga restante de um slot, de 0 (pronto) a 1 (acabou de disparar).
func cooldown_ratio(slot: int) -> float:
	var part: PartData = equipped.get(slot)
	if part == null:
		return 0.0
	var full := 1.0 / maxf(part.fire_rate, 0.01)
	return clampf(_cooldowns.get(slot, 0.0) / full, 0.0, 1.0)


# --- ciclo de fisica ----------------------------------------------------------

func _physics_process(delta: float) -> void:
	# Hitstop congela o jogador junto com o resto da simulacao. GDD 3.4.1.
	if CombatFeel.frozen:
		return

	_tick_timers(delta)
	_update_aim(delta)
	_handle_dash(delta)
	_handle_movement(delta)
	_handle_firing(delta)
	_handle_heat(delta)
	_decay_deform(delta)
	move_and_slide()
	queue_redraw()


func _tick_timers(delta: float) -> void:
	_dash_buffer = maxf(0.0, _dash_buffer - delta)
	_iframes = maxf(0.0, _iframes - delta)
	_purge_cd = maxf(0.0, _purge_cd - delta)
	_hit_flash = maxf(0.0, _hit_flash - delta)
	_recoil = _recoil.lerp(Vector2.ZERO, minf(1.0, delta * 8.0))

	var recharge_time := (0.9 if _dash_charges_max >= 3 else DASH_COOLDOWN) * MetaManager.get_dash_cooldown_mult()
	if _dash_charges < float(_dash_charges_max):
		_dash_charges = minf(float(_dash_charges_max), _dash_charges + delta / recharge_time)

	for k in _cooldowns:
		_cooldowns[k] = maxf(0.0, _cooldowns[k] - delta)

	if is_undervolt():
		_spasm_timer += delta
		if _spasm_timer >= UNDERVOLT_SPASM_PERIOD:
			_spasm_timer = 0.0
			_spasm_lock = UNDERVOLT_SPASM_DURATION
	_spasm_lock = maxf(0.0, _spasm_lock - delta)

	if overheated:
		_overheat_timer -= delta
		if _overheat_timer <= 0.0:
			overheated = false
			heat = 0.0


func _update_aim(delta: float) -> void:
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	var raw := aim_direction
	if stick.length() > 0.25:
		_using_gamepad = true
		raw = stick.normalized()
	else:
		var mouse := get_global_mouse_position() - global_position
		if mouse.length() > 8.0:
			if not _using_gamepad or mouse.length() > 20.0:
				_using_gamepad = false
			raw = mouse.normalized()

	# Formato Ball x Pit: o tiro e apontado para cima dentro do poco.
	# Clampa o angulo entre -172 graus e -8 graus (sempre apontando para cima).
	var ang := raw.angle()
	if ang > 0.0:
		ang = -PI * 0.95 if raw.x < 0.0 else -PI * 0.05
	else:
		ang = clampf(ang, -PI * 0.95, -PI * 0.05)
	raw = Vector2.from_angle(ang)

	var assist := 0.45 if _using_gamepad else 0.0
	aim_direction = _apply_aim_assist(raw, assist, delta)


func _apply_aim_assist(dir: Vector2, strength: float, delta: float) -> Vector2:
	if strength <= 0.0:
		return dir
	var target := _nearest_enemy_in_cone(dir, deg_to_rad(AIM_ASSIST_CONE_DEG), AIM_ASSIST_RANGE)
	if target == null:
		return dir
	var want := (target.global_position - global_position).normalized()
	var max_turn := deg_to_rad(AIM_ASSIST_RATE_DEG) * strength * delta
	var diff := wrapf(want.angle() - dir.angle(), -PI, PI)
	return dir.rotated(clampf(diff, -max_turn, max_turn))


func _nearest_enemy_in_cone(dir: Vector2, half_angle: float, range_px: float) -> Node2D:
	var best: Node2D = null
	var best_d := range_px
	for e in get_tree().get_nodes_in_group(&"enemies"):
		var n := e as Node2D
		if n == null:
			continue
		var to := n.global_position - global_position
		var d := to.length()
		if d > best_d:
			continue
		if absf(wrapf(to.angle() - dir.angle(), -PI, PI)) > half_angle:
			continue
		best_d = d
		best = n
	return best


func _handle_dash(delta: float) -> void:
	if Input.is_action_just_pressed("dash"):
		_dash_buffer = INPUT_BUFFER

	if _dash_time > 0.0:
		_dash_time -= delta
		velocity = _dash_dir * (DASH_SPEED * MetaManager.get_dash_speed_mult())
		velocity.y = 0.0
		var elapsed := DASH_DURATION - _dash_time
		if elapsed >= DASH_IFRAME_START and elapsed <= DASH_IFRAME_END:
			_iframes = maxf(_iframes, 0.016)
		if _dash_time <= 0.0:
			deform = Vector2(0.65, 1.35)
		return

	if _dash_buffer > 0.0 and _dash_charges >= 1.0 and _spasm_lock <= 0.0:
		var input_x := Input.get_axis("move_left", "move_right")
		var dir_x := input_x if absf(input_x) > 0.1 else (1.0 if aim_direction.x >= 0.0 else -1.0)
		_dash_dir = Vector2(signf(dir_x), 0.0)
		_dash_time = DASH_DURATION
		_dash_charges -= 1.0
		_dash_buffer = 0.0
		deform = Vector2(1.45, 0.70)
		CombatFeel.add_trauma(0.06)
		Sfx.play_varied("dash", -6.0)


func _handle_movement(delta: float) -> void:
	if _dash_time > 0.0:
		return
	if _spasm_lock > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, DECELERATION * delta * 2.0)
		velocity.y = 0.0
		return

	# Controle no estilo Ball x Pit: movimento horizontal na baseline do poco
	var input_x := Input.get_axis("move_left", "move_right")
	var target_x := input_x * _max_speed
	if absf(input_x) > 0.01:
		velocity.x = move_toward(velocity.x, target_x, ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, DECELERATION * delta)
	velocity.x += _recoil.x
	velocity.y = 0.0

	# Trava o robo na baseline do poco e limita o movimento dentro das paredes
	global_position.y = ArenaGenerator.BASELINE_Y
	global_position.x = clampf(global_position.x, 50.0, ArenaGenerator.ARENA_SIZE.x - 50.0)


func _handle_firing(delta: float) -> void:
	if overheated or _spasm_lock > 0.0:
		return
	_try_fire(PartData.Slot.ARM_LEFT, "fire_left")
	_try_fire(PartData.Slot.ARM_RIGHT, "fire_right")
	_try_fire(PartData.Slot.HEAD, "head_ability")

	if Input.is_action_just_pressed("heat_purge"):
		_heat_purge()


func _try_fire(slot: int, action: String) -> void:
	var part: PartData = equipped.get(slot)
	if part == null or part.projectile == null or pool == null:
		return

	var pressed := Input.is_action_pressed(action) if part.automatic else Input.is_action_just_pressed(action)
	if not pressed:
		return
	if _cooldowns.get(slot, 0.0) > 0.0:
		return

	var rate := part.fire_rate * (cpu.fire_rate_mult if cpu else 1.0)
	if is_undervolt():
		rate *= (1.0 - UNDERVOLT_FIRE_RATE_PENALTY)

	var muzzle := global_position + aim_direction * 34.0
	_fire_ctx.reset(self, muzzle, aim_direction)
	_fire_ctx.rarity_mult = part.rarity_mult()
	_fire_ctx.fusion_mult = part.fusion_mult()
	for b in part.behaviors:
		b.on_fire(_fire_ctx)
	if _fire_ctx.cancelled:
		return

	rate *= (1.0 + _fire_ctx.fire_rate_add)
	_cooldowns[slot] = 1.0 / maxf(rate, 0.01)

	var shots: int = 1 + _fire_ctx.extra_shots
	var spread: float = _fire_ctx.spread_radians
	var damage: float = _fire_ctx.final_damage(part.projectile.damage) * (cpu.damage_mult if cpu else 1.0) * MetaManager.get_bonus_damage_mult()
	var is_crit := randf() < MetaManager.get_crit_chance()
	if is_crit:
		damage *= 2.0
	var speed_mult: float = (cpu.projectile_speed_mult if cpu else 1.0) * (1.0 + _fire_ctx.speed_add) * MetaManager.get_proj_speed_mult()
	var bonus_bounces: int = _fire_ctx.bonus_bounces + (cpu.bonus_bounces if cpu else 0) + MetaManager.get_free_bounces()

	for s in shots:
		var t := 0.0 if shots == 1 else (float(s) / float(shots - 1) - 0.5) * 2.0
		var dir := aim_direction.rotated(t * spread * 0.5)
		pool.spawn(muzzle, dir, part.projectile, ProjectilePool.FACTION_PLAYER,
			part.behaviors, damage, bonus_bounces, speed_mult)

	# Calor, coice e tremor escalam com o peso da arma. GDD 3.4.2 e 3.4.4.
	var heavy := part.heat_per_shot >= 10.0
	heat += part.heat_per_shot * (cpu.heat_gen_mult if cpu else 1.0) * MetaManager.get_heat_gen_mult()
	_heat_idle = 0.0
	CombatFeel.add_trauma(0.22 if heavy else 0.08)
	if heavy:
		_recoil = -aim_direction * 240.0 * MetaManager.get_recoil_mult()
		deform = Vector2(0.85, 1.15)
		Sfx.play_varied("fire_heavy", -4.0)
	else:
		Sfx.play_varied("fire_light", -14.0)


func _handle_heat(delta: float) -> void:
	if heat >= heat_capacity and not overheated:
		overheated = true
		_overheat_timer = OVERHEAT_LOCK
		deform = Vector2(1.2, 1.2)
		CombatFeel.add_trauma(0.3)
		Sfx.play("overheat", -4.0)
		return

	_heat_idle += delta
	if _heat_idle >= HEAT_COOLDOWN_DELAY and not overheated:
		var dissipation := (cpu.heat_dissipation if cpu else 12.0) * MetaManager.get_bonus_dissipation_mult()
		heat = maxf(0.0, heat - dissipation * delta)


## GDD 4.1.2: "e defesa e ataque ao mesmo tempo, e e o que separa jogador bom de
## jogador mediano."
func _heat_purge() -> void:
	if _purge_cd > 0.0:
		return
	_purge_cd = PURGE_COOLDOWN * MetaManager.get_purge_cooldown_mult()
	heat = maxf(0.0, heat - heat_capacity * PURGE_HEAT_FRACTION)
	CombatFeel.add_trauma(0.35)
	CombatFeel.request_hitstop(60.0)
	Vfx.spawn_death(global_position, Color("#F5F0E1"))
	Sfx.play("fire_heavy", -2.0)
	var purge_power := MetaManager.get_purge_power_mult()
	var purge_dmg := PURGE_DAMAGE * purge_power
	var purge_r := PURGE_RADIUS * purge_power
	for e in get_tree().get_nodes_in_group(&"enemies"):
		var n := e as Node2D
		if n != null and n.global_position.distance_to(global_position) <= purge_r:
			n.call("take_damage", purge_dmg, n.global_position, 0)


func _decay_deform(delta: float) -> void:
	deform = deform.lerp(Vector2.ONE, minf(1.0, delta * 11.0))


# --- dano ---------------------------------------------------------------------

func take_damage(amount: float, _from: Vector2 = Vector2.ZERO, _bounce_index: int = 0) -> void:
	if _iframes > 0.0 or hp <= 0.0:
		return
	var final_amount := amount * MetaManager.get_damage_reduction_mult()
	hp -= final_amount
	_iframes = HIT_IFRAMES
	_hit_flash = 0.12
	# GDD 2.4: tomar dano espreme 0,80 uniforme mais flash branco.
	deform = Vector2(0.80, 0.80)
	CombatFeel.add_trauma(0.45)
	CombatFeel.request_hitstop(130.0)
	Sfx.play("player_hit")
	stats_changed.emit()
	if hp <= 0.0:
		if MetaManager.airbag_available:
			MetaManager.airbag_available = false
			hp = 1.0
			_iframes = 1.5
			CombatFeel.add_trauma(0.6)
			CombatFeel.request_hitstop(130.0)
			Sfx.play("fire_heavy", 2.0)
			Vfx.spawn_damage_number(global_position, 0.0, 4, true)
			stats_changed.emit()
			return
		hp = 0.0
		died.emit()


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	stats_changed.emit()


# --- desenho greybox ----------------------------------------------------------

func _draw() -> void:
	# GDD 2.4, nota de implementacao: o pivo da deformacao e a BASE do sprite,
	# ou seja, os pes, e nao o centro. Se for o centro, o robo afunda no chao ao
	# espremer. Por isso o desenho e transladado para a base antes de escalar.
	# A origem do no ja E a base do robo: o corpo e desenhado para cima, em y
	# negativo, e a deformacao escala em torno de (0,0).
	var base_y := 0.0
	draw_set_transform(Vector2(0.0, base_y), 0.0, deform)

	var chassis: PartData = equipped.get(PartData.Slot.CHASSIS)
	var body_color: Color = chassis.color if chassis else Color("#4A4F52")
	if _hit_flash > 0.0:
		body_color = Color.WHITE
	if _iframes > 0.0 and fmod(_iframes * 12.0, 1.0) < 0.5:
		body_color = body_color.lightened(0.4)

	# Chassi e pernas.
	draw_rect(Rect2(-24, -60, 48, 52), body_color)
	draw_rect(Rect2(-24, -60, 48, 52), Color("#1A0F14"), false, 4.0)
	draw_rect(Rect2(-18, -10, 12, 10), body_color.darkened(0.3))
	draw_rect(Rect2(6, -10, 12, 10), body_color.darkened(0.3))

	# Cabeca, gira 35 graus seguindo a mira. GDD 2.5.
	var head: PartData = equipped.get(PartData.Slot.HEAD)
	var head_tilt: float = clampf(aim_direction.angle(), -0.61, 0.61) * 0.3
	draw_set_transform(Vector2(0.0, base_y), 0.0, deform)
	var head_color: Color = head.color if head else Color("#D6C9A8")
	var head_rect := Rect2(-17, -88, 34, 28)
	draw_rect(head_rect, head_color)
	draw_rect(head_rect, Color("#1A0F14"), false, 4.0)
	# Olhos: grandes, brancos, pupila pequena e desalinhada. GDD 2.1, mandamento 3.
	var look := aim_direction * 3.0
	draw_circle(Vector2(-8, -76) + Vector2(0, head_tilt * 6.0), 6.0, Color("#F5F0E1"))
	draw_circle(Vector2(7, -74) + Vector2(0, head_tilt * 6.0), 5.0, Color("#F5F0E1"))
	draw_circle(Vector2(-8, -76) + look, 2.5, Color("#1A0F14"))
	draw_circle(Vector2(7, -74) + look + Vector2(0.5, 0.5), 2.0, Color("#1A0F14"))

	# Bracos, ancorados nos ombros, giram 360 graus.
	_draw_arm(Vector2(-26, -46), equipped.get(PartData.Slot.ARM_LEFT), base_y)
	_draw_arm(Vector2(26, -46), equipped.get(PartData.Slot.ARM_RIGHT), base_y)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_heat_ring()

	# Linha guia de mira para o poco vertical (Ball x Pit)
	for dot in 8:
		var dot_pos := aim_direction * (45.0 + dot * 35.0)
		var dot_r := 3.0 - dot * 0.25
		draw_circle(dot_pos, dot_r, Color("#FFD400", 0.45 - dot * 0.04))


func _draw_arm(shoulder: Vector2, part: PartData, base_y: float) -> void:
	var color: Color = part.color if part else Color("#4A4F52")
	draw_set_transform(shoulder + Vector2(0.0, base_y), aim_direction.angle(), deform)
	var length: float = 34.0 if part == null else 26.0 + minf(part.watts, 60) * 0.4
	draw_rect(Rect2(0, -7, length, 14), color)
	draw_rect(Rect2(0, -7, length, 14), Color("#1A0F14"), false, 3.0)
	draw_set_transform(Vector2(0.0, base_y), 0.0, deform)


## GDD_ADENDOS B.4: a barra de calor e um anel em volta do robo, e nao um
## elemento de borda. Isso mantem os olhos no centro da tela.
func _draw_heat_ring() -> void:
	var ratio := heat_ratio()
	if ratio <= 0.01:
		return
	var color := Color("#FFD400").lerp(Color("#FF6B1A"), ratio)
	if ratio > 0.85:
		# Acima de 85% o robo emite vapor e o reticulo treme. GDD 4.1.2.
		color = Color("#FF2D95") if fmod(Time.get_ticks_msec() / 90.0, 2.0) < 1.0 else Color("#FF6B1A")
	draw_arc(Vector2(0, -20), 46.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 28, color, 5.0)
	if overheated:
		draw_arc(Vector2(0, -20), 52.0, 0.0, TAU, 32, Color("#FF2D95"), 3.0)
