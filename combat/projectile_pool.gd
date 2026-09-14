class_name ProjectilePool
extends Node2D
## O sistema central do jogo. GDD 7.2.
##
## Projeteis NAO sao nos. Sao indices em um conjunto de vetores paralelos, com
## integracao manual e deteccao de colisao por varredura. Um RigidBody2D por
## projetil colapsa a arvore de cena bem antes dos 800 projeteis exigidos.
##
## Diferencas em relacao ao trecho de codigo do GDD, todas justificadas em
## GDD_ADENDOS D.2 e D.3:
##  - get_rest_info e consultado na transformada DO PONTO DE CONTATO, nao na de
##    origem. No trecho original o projetil ainda nao toca em nada nessa posicao,
##    entao a consulta volta vazia e o codigo cai no caminho de atravessar a parede.
##  - Existem os campos que as regras do proprio GDD exigem e que faltavam:
##    faccao, imunidade de acerto repetido, perfuracao, linhagem e dono.
##  - Ha politica explicita de estouro do pool.
##
## Regras do formato de poco (GDD_ADENDOS F):
##  - O robo e o rebatedor. Projetil do jogador que esta CAINDO colide com o
##    corpo do robo, volta para cima com angulo dependente do ponto de contato,
##    ganha um quique e nao gasta orcamento de quiques.
##  - O chao do poco nao devolve nada. Projetil do jogador que chega nele morre.

const MAX_PROJECTILES := 2048

## GDD 3.3.2, teto absoluto. Acima disso o projetil vira um enxame erratico
## e o desempenho fica em risco.
const HARD_BOUNCE_CAP := 12
## GDD 3.3.1: abaixo disso o projetil morre com um "plop" desanimado.
## E uma piada e e uma protecao de performance.
const MIN_SPEED := 90.0
## Teto de velocidade depois da restituicao. Pneu a 1,35 e rebatedor a 1,6 em
## ciclo dobrariam a velocidade a cada volta, sem limite.
const MAX_SPEED := 1800.0
## Jitter anti-loop: sem ele, um projetil entra em loop perpendicular eterno
## entre duas paredes paralelas. GDD 3.3.1.
const JITTER_RAD := 0.0262  # +/- 1,5 grau
## GDD 3.3.2: uma bala presa dentro de um chefe faria dano infinito sem isto.
const REPEAT_HIT_IMMUNITY := 0.22

## Rebatedor: desvio maximo em relacao a vertical, em radianos (62 graus), quando
## o projetil bate na borda do corpo. No centro ele sai reto para cima.
const PADDLE_MAX_ANGLE := 1.0821
## Um projetil quase parado que chega ao robo sai com pelo menos esta velocidade,
## senao o rebatedor devolveria algo que morre de lentidao logo em seguida.
const PADDLE_MIN_SPEED := 520.0

const FACTION_PLAYER := 0
const FACTION_ENEMY := 1

const LAYER_WALLS := 1
const LAYER_ENEMIES := 2
const LAYER_PLAYER := 4

## GDD 2.7.2 e 3.3.2. Indice = numero de quiques ja acumulados.
const BOUNCE_COLORS: Array[Color] = [
	Color("#F5F0E1"), Color("#FFD400"), Color("#FF6B1A"), Color("#FF2D95"),
]

signal projectile_hit(target: Node, damage: float, bounce_index: int, position: Vector2)

# --- vetores paralelos --------------------------------------------------------
var _pos: PackedVector2Array
var _prev_pos: PackedVector2Array
var _vel: PackedVector2Array
var _alive: PackedByteArray
var _bounces: PackedInt32Array
var _max_bounces: PackedInt32Array
var _infinite: PackedByteArray
var _floor_immune: PackedByteArray
var _damage: PackedFloat32Array
var _damage_source: Array[String] = []
var _radius: PackedFloat32Array
var _restitution: PackedFloat32Array
var _ttl: PackedFloat32Array
var _age: PackedFloat32Array
var _pierce: PackedInt32Array
var _faction: PackedByteArray
var _generation: PackedInt32Array
var _last_hit_id: PackedInt64Array
var _last_hit_t: PackedFloat32Array
var _color: PackedColorArray
var _stretch: PackedFloat32Array
## Referencias que nao cabem em Packed*: mantidas em Arrays simples do mesmo tamanho.
var _behaviors: Array = []

var _free: PackedInt32Array
var _alive_count: int = 0
var _clock: float = 0.0

# --- reuso por quadro, zero alocacao ------------------------------------------
var _query := PhysicsShapeQueryParameters2D.new()
var _shape := CircleShape2D.new()
var _rng := RandomNumberGenerator.new()

var _mmi: MultiMeshInstance2D
var _mm: MultiMesh

var _bounce_ctx: BounceContext
var _hit_ctx: HitContext
var _pending_spawns: Array[Dictionary] = []

## Contadores de diagnostico, lidos pelo teste de fumaca.
var debug_bounce_events: int = 0
var debug_empty_contacts: int = 0
var debug_kills: int = 0
var debug_casts: int = 0
var debug_blocked_casts: int = 0


class BounceContext extends RefCounted:
	var pool: ProjectilePool
	var index: int
	var position: Vector2
	var normal: Vector2
	var bounce_index: int
	var collider: Node
	var velocity: Vector2

	func spawn_children(count: int, damage_ratio: float, spread_deg: float = 50.0) -> void:
		pool.request_split(index, count, damage_ratio, spread_deg)


class HitContext extends RefCounted:
	var pool: ProjectilePool
	var index: int
	var target: Node
	var damage: float
	var position: Vector2
	var bounce_index: int


func _ready() -> void:
	reseed_rng()
	_bounce_ctx = BounceContext.new()
	_bounce_ctx.pool = self
	_hit_ctx = HitContext.new()
	_hit_ctx.pool = self
	_allocate()
	_setup_multimesh()

	_query.collide_with_bodies = true
	_query.collide_with_areas = false
	_query.margin = 0.5


## Chamado no inicio de cada run, depois de GameRng.reseed. Sem isto o jitter
## do desafio diario seguiria a semente da sessao anterior.
func reseed_rng() -> void:
	_rng.seed = GameRng.stream(GameRng.Stream.COMBAT).seed


func _allocate() -> void:
	_pos.resize(MAX_PROJECTILES)
	_prev_pos.resize(MAX_PROJECTILES)
	_vel.resize(MAX_PROJECTILES)
	_alive.resize(MAX_PROJECTILES)
	_bounces.resize(MAX_PROJECTILES)
	_max_bounces.resize(MAX_PROJECTILES)
	_infinite.resize(MAX_PROJECTILES)
	_floor_immune.resize(MAX_PROJECTILES)
	_damage.resize(MAX_PROJECTILES)
	_damage_source.resize(MAX_PROJECTILES)
	_radius.resize(MAX_PROJECTILES)
	_restitution.resize(MAX_PROJECTILES)
	_ttl.resize(MAX_PROJECTILES)
	_age.resize(MAX_PROJECTILES)
	_pierce.resize(MAX_PROJECTILES)
	_faction.resize(MAX_PROJECTILES)
	_generation.resize(MAX_PROJECTILES)
	_last_hit_id.resize(MAX_PROJECTILES)
	_last_hit_t.resize(MAX_PROJECTILES)
	_color.resize(MAX_PROJECTILES)
	_stretch.resize(MAX_PROJECTILES)
	_behaviors.resize(MAX_PROJECTILES)

	_free.resize(MAX_PROJECTILES)
	for i in MAX_PROJECTILES:
		_free[i] = MAX_PROJECTILES - 1 - i


func _setup_multimesh() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE

	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_2D
	_mm.use_colors = true
	_mm.mesh = quad
	_mm.instance_count = MAX_PROJECTILES
	_mm.visible_instance_count = 0

	_mmi = MultiMeshInstance2D.new()
	_mmi.multimesh = _mm
	_mmi.texture = _white_texture()
	var ink := ShaderMaterial.new()
	ink.shader = preload("res://art/projectile_ink.gdshader")
	_mmi.material = ink
	_mmi.z_index = 50
	add_child(_mmi)


func _white_texture() -> ImageTexture:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


# --- multiplicador de dano por quique -----------------------------------------

## GDD 3.3.2: progressao geometrica a 1,25 por quique, teto rigido em 4,00.
## O salto do quique 3 para o 4 e grande de proposito.
##
## Estendido por GDD_ADENDOS A.2: acima do 4o quique o multiplicador soma
## +3% do dano base por quique, chegando a 4,96 no 12o. Sem isso, os oito
## niveis de upgrade entre o quique 4 e o teto de 12 nao dao retorno nenhum
## e o jogador que investiu em ricochete nao ve diferenca.
static func bounce_multiplier(bounces: int) -> float:
	if bounces <= 0:
		return 1.0
	if bounces == 1:
		return 1.25
	if bounces == 2:
		return 1.5625
	if bounces == 3:
		return 1.953125
	return 4.0 + float(mini(bounces, HARD_BOUNCE_CAP) - 4) * 0.12


static func bounce_color(bounces: int) -> Color:
	return BOUNCE_COLORS[clampi(bounces - 1, 0, 3)]


## GDD 3.3.2: o projetil muda de escala visivelmente a cada quique.
static func bounce_scale(bounces: int) -> float:
	const SCALES := [1.0, 1.10, 1.22, 1.35, 1.50]
	return SCALES[clampi(bounces, 0, 4)]


# --- ciclo de vida ------------------------------------------------------------

func spawn(
	position: Vector2,
	direction: Vector2,
	type: ProjectileType,
	faction: int = FACTION_PLAYER,
	behaviors: Array = [],
	damage_override: float = -1.0,
	bonus_bounces: int = 0,
	speed_mult: float = 1.0,
	generation: int = 0
) -> int:
	var i := _take_index()
	if i < 0:
		return -1

	_pos[i] = position
	_prev_pos[i] = position
	_vel[i] = direction.normalized() * type.speed * speed_mult
	_alive[i] = 1
	_bounces[i] = 0
	_max_bounces[i] = mini(type.max_bounces + bonus_bounces, HARD_BOUNCE_CAP)
	_infinite[i] = 1 if type.infinite_bounces else 0
	_floor_immune[i] = 1 if type.ignore_floor else 0
	_damage[i] = type.damage if damage_override < 0.0 else damage_override
	_damage_source[i] = type.damage_source
	_radius[i] = type.radius
	_restitution[i] = type.restitution
	_ttl[i] = type.ttl
	_age[i] = 0.0
	_pierce[i] = type.pierce
	_faction[i] = faction
	_generation[i] = generation
	_last_hit_id[i] = 0
	_last_hit_t[i] = -99.0
	_color[i] = type.base_color
	_stretch[i] = type.stretch
	_behaviors[i] = behaviors

	_alive_count += 1
	if faction == FACTION_PLAYER:
		Telemetry.projectiles_fired += 1
	return i


func _take_index() -> int:
	if _free.size() > 0:
		var i := _free[_free.size() - 1]
		_free.remove_at(_free.size() - 1)
		return i
	# Politica de estouro (GDD_ADENDOS E.6): sacrifica o projetil vivo mais
	# antigo com menos quiques. O mais antigo porque ja teve sua chance; o de
	# menos quiques porque e o que menos vale para o jogador.
	var victim := -1
	var worst := -INF
	for i in MAX_PROJECTILES:
		if _alive[i] == 0:
			continue
		var score: float = _age[i] - float(_bounces[i]) * 2.0
		if score > worst:
			worst = score
			victim = i
	if victim < 0:
		return -1
	_alive[victim] = 0
	_alive_count -= 1
	return victim


## Mata o projetil. `plop` so controla o efeito; quem chama decide em qual
## contador de telemetria a morte entra.
func kill(i: int, plop: bool = false) -> void:
	if _alive[i] == 0:
		return
	_alive[i] = 0
	_alive_count -= 1
	_behaviors[i] = null
	_free.append(i)
	debug_kills += 1
	if plop:
		Vfx.spawn_plop(_pos[i])
		Sfx.play("projectile_plop", -12.0)


func clear() -> void:
	for i in MAX_PROJECTILES:
		_alive[i] = 0
		_behaviors[i] = null
	_free.resize(MAX_PROJECTILES)
	for i in MAX_PROJECTILES:
		_free[i] = MAX_PROJECTILES - 1 - i
	_alive_count = 0
	_pending_spawns.clear()
	_mm.visible_instance_count = 0


func alive_count() -> int:
	return _alive_count


# --- acessores usados pelos comportamentos e pelos testes ---------------------

func multiply_damage(i: int, factor: float) -> void:
	_damage[i] *= factor


func multiply_speed(i: int, factor: float) -> void:
	_vel[i] *= factor


func add_bounces(i: int, amount: int) -> void:
	_max_bounces[i] = mini(_max_bounces[i] + amount, HARD_BOUNCE_CAP)


func get_position_of(i: int) -> Vector2:
	return _pos[i]


func get_velocity_of(i: int) -> Vector2:
	return _vel[i]


func get_damage_of(i: int) -> float:
	return _damage[i]


func get_bounces_of(i: int) -> int:
	return _bounces[i]


func is_alive(i: int) -> bool:
	return i >= 0 and i < MAX_PROJECTILES and _alive[i] == 1


func reverse(i: int) -> void:
	_vel[i] = -_vel[i]


# --- instrumentacao para o teste de fumaca ------------------------------------

## Quantos projeteis vivos escaparam de um retangulo. Se isto for maior que
## zero, houve tunelamento e o cast de varredura falhou: e o unico bug desta
## classe que quebra o jogo inteiro em silencio.
func count_outside(rect: Rect2) -> int:
	var n := 0
	for i in MAX_PROJECTILES:
		if _alive[i] == 1 and not rect.has_point(_pos[i]):
			n += 1
	return n


func total_bounces() -> int:
	var n := 0
	for i in MAX_PROJECTILES:
		if _alive[i] == 1:
			n += _bounces[i]
	return n


# --- simulacao ----------------------------------------------------------------

## Ventoinha consulta o pool a 10 Hz. Mantém facção, energia e teto de velocidade.
## Devolve quantos projeteis foram empurrados, para o som so tocar com efeito.
func deflect_in_cone(origin: Vector2, axis: Vector2, reach: float, strength: float, delta: float) -> int:
	var pushed := 0
	for i in MAX_PROJECTILES:
		if _alive[i] == 0 or _faction[i] != FACTION_PLAYER: continue
		var offset := _pos[i] - origin
		if offset.length_squared() > reach * reach or offset.is_zero_approx(): continue
		if offset.normalized().dot(axis) < 0.6: continue
		_vel[i] = (_vel[i] + offset.normalized() * strength * delta).limit_length(MAX_SPEED)
		pushed += 1
	return pushed

func _physics_process(delta: float) -> void:
	# Hitstop congela a simulacao, nao os efeitos. GDD 3.4.1.
	if CombatFeel.frozen:
		return

	_clock += delta
	var space := get_world_2d().direct_space_state

	for i in MAX_PROJECTILES:
		if _alive[i] == 0:
			continue
		_prev_pos[i] = _pos[i]
		_age[i] += delta
		if _age[i] >= _ttl[i]:
			kill(i, true)
			continue
		_step(i, delta, space)

	_flush_splits()


func _step(i: int, delta: float, space: PhysicsDirectSpaceState2D) -> void:
	var motion := _vel[i] * delta
	if motion.is_zero_approx():
		return

	var mask := LAYER_WALLS
	if _faction[i] == FACTION_PLAYER:
		mask |= LAYER_ENEMIES
		# O robo so e superficie para o que esta caindo. Um tiro recem-disparado
		# nasce sobreposto ao corpo e subindo; sem este filtro ele quicaria no cano.
		if _vel[i].y > 0.0:
			mask |= LAYER_PLAYER
	else:
		mask |= LAYER_PLAYER

	_shape.radius = _radius[i]
	_query.shape = _shape
	_query.transform = Transform2D(0.0, _pos[i])
	_query.motion = motion
	_query.collision_mask = mask

	# Cast de varredura em vez de mover e depois testar. E o que impede
	# tunelamento a 900 px/s. GDD 7.2.
	var result := space.cast_motion(_query)
	var safe: float = result[0]
	debug_casts += 1

	if safe >= 1.0:
		_pos[i] += motion
		return

	debug_blocked_casts += 1
	_pos[i] += motion * safe

	# Consulta na transformada DO CONTATO, com uma sobreposicao minima para que
	# get_rest_info tenha o que reportar. Ver GDD_ADENDOS D.3.
	var dir := motion.normalized()
	_query.transform = Transform2D(0.0, _pos[i] + dir * (_query.margin + 0.75))
	_query.motion = Vector2.ZERO
	var contact := space.get_rest_info(_query)

	if contact.is_empty():
		# Nada resolvido: segue o movimento para nao travar o projetil no lugar.
		debug_empty_contacts += 1
		_pos[i] += motion * (1.0 - safe)
		return

	_resolve_bounce(i, contact["normal"], contact.get("collider_id", 0))


func _resolve_bounce(i: int, normal: Vector2, collider_id: int) -> void:
	var collider: Object = instance_from_id(collider_id) if collider_id != 0 else null
	var node := collider as Node
	# Reflexão de blindagem muda a facção no mesmo slot do pool, sem duplicar
	# projétil e sem causar dano ao robô que acabou de defendê-lo.
	if node is Robot and _faction[i] == FACTION_ENEMY:
		var reflection := (node as Robot).reflection_multiplier(_pos[i], _vel[i])
		if reflection > 0.0:
			_faction[i] = FACTION_PLAYER
			_damage[i] *= reflection
			_vel[i] = _vel[i].bounce((node as Robot).aim_direction).limit_length(MAX_SPEED)
			_pos[i] = (node as Robot).body_center() + (node as Robot).aim_direction * (Robot.COLLISION_RADIUS + _radius[i] + 2.0)
			_prev_pos[i] = _pos[i]
			_last_hit_id[i] = 0
			(node as Robot).on_paddle_hit(_pos[i], _bounces[i])
			return

	if node != null and _faction[i] == FACTION_PLAYER:
		if node.is_in_group(&"player"):
			_paddle(i, node)
			return
		if _floor_immune[i] == 0 and "is_floor" in node and node.get("is_floor"):
			Telemetry.projectiles_lost_floor += 1
			kill(i, true)
			return

	debug_bounce_events += 1
	var bounce_index := _bounces[i]
	var surface_restitution := 1.0

	if node != null:
		if "restitution" in node:
			surface_restitution = node.get("restitution")

		# Uma parede NAO e um alvo. O teste ser apenas has_method("take_damage")
		# faz todo quique em parede disparar hitstop, e como o hitstop congela a
		# simulacao inteira, o jogo trava sozinho em camera lenta permanente.
		# A pertinencia ao grupo "damageable" e o que separa alvo de cenario;
		# um obstaculo destrutivel entra no grupo, uma parede de concreto nao.
		# Projetil inimigo so fere o jogador: o cenario destrutivel e alvo do
		# jogador, nao da horda. Sem este filtro, teclas do QWERTYpede
		# derrubavam a Carcaca de Fusca e mostravam numero de dano.
		var can_damage: bool = _faction[i] == FACTION_PLAYER or node.is_in_group(&"player")
		if can_damage and node.is_in_group(&"damageable") and node.has_method("take_damage"):
			# Imunidade de acerto repetido. GDD 3.3.2.
			var same_target: bool = _last_hit_id[i] == collider_id
			var recent: bool = (_clock - _last_hit_t[i]) < REPEAT_HIT_IMMUNITY
			if not (same_target and recent):
				var dealt: float = _damage[i] * bounce_multiplier(bounce_index)
				# Polvora Grossa, ramo Polvora nivel 4. Antes o no era vendido na
				# Garagem por 2.200 de Cobre e nada lia o bonus.
				if _faction[i] == FACTION_PLAYER and bounce_index >= 2:
					dealt *= 1.0 + MetaManager.get_bounce_damage_bonus()
				var applied: Variant
				if node is Robot and _faction[i] == FACTION_ENEMY:
					applied = node.call("take_damage", dealt, _pos[i], bounce_index, _damage_source[i], false)
				else:
					applied = node.call("take_damage", dealt, _pos[i], bounce_index)
				if applied is float or applied is int:
					dealt = float(applied)
				_last_hit_id[i] = collider_id
				_last_hit_t[i] = _clock

				# Cenario destrutivel recebe dano e mostra numero, mas nao entra
				# na telemetria de combate nem gera hitstop: hitstop e o peso do
				# soco, e socar um armario nao e o mesmo que acertar um inimigo.
				var is_actor: bool = node.is_in_group(&"enemies") or node.is_in_group(&"player")
				Vfx.spawn_damage_number(_pos[i], dealt, bounce_index)
				projectile_hit.emit(node, dealt, bounce_index, _pos[i])

				_hit_ctx.index = i
				_hit_ctx.target = node
				_hit_ctx.damage = dealt
				_hit_ctx.position = _pos[i]
				_hit_ctx.bounce_index = bounce_index
				_run_behaviors(i, "on_hit", _hit_ctx)

				if is_actor and dealt > 0.0:
					Telemetry.record_hit(bounce_index, dealt)
					# GDD 3.4.1, tabela de hitstop.
					if _faction[i] == FACTION_PLAYER:
						CombatFeel.request_hitstop(110.0 if bounce_index >= 4 else 40.0)
						if bounce_index >= 3:
							CombatFeel.add_trauma(0.18)

				# Perfuracao: atravessa sem gastar quique.
				if _pierce[i] > 0:
					_pierce[i] -= 1
					_pos[i] += _vel[i].normalized() * (_radius[i] * 2.0 + 2.0)
					return

	# GDD 3.3.2: "O contador de quiques e do projetil, nao do inimigo.
	# Acertar um inimigo consome um quique e mantem o multiplicador."
	_bounces[i] += 1

	if _infinite[i] == 0 and _bounces[i] > _max_bounces[i]:
		Vfx.spawn_bounce(_pos[i], normal, _bounces[i])
		Sfx.play_bounce(_bounces[i] - 1)
		kill(i)
		return

	# Reflexao, restituicao da superficie vezes a do projetil, e o jitter.
	_vel[i] = _vel[i].bounce(normal) * surface_restitution * _restitution[i]
	_vel[i] = _vel[i].rotated(_rng.randf_range(-JITTER_RAD, JITTER_RAD)).limit_length(MAX_SPEED)

	# Empurra para fora da superficie, senao o proximo passo comeca sobreposto
	# e o projetil entra num loop de quiques no mesmo ponto.
	_pos[i] += normal * (_radius[i] + 1.0)

	_bounce_ctx.index = i
	_bounce_ctx.position = _pos[i]
	_bounce_ctx.normal = normal
	_bounce_ctx.bounce_index = _bounces[i]
	_bounce_ctx.collider = node
	_bounce_ctx.velocity = _vel[i]
	_run_behaviors(i, "on_bounce", _bounce_ctx)

	if _vel[i].length() < MIN_SPEED:
		Telemetry.projectiles_expired_slow += 1
		kill(i, true)
		return

	Vfx.spawn_bounce(_pos[i], normal, _bounces[i])
	Sfx.play_bounce(_bounces[i] - 1)


## O robo como rebatedor. Tres decisoes:
##  - O angulo de saida vem do ponto de contato, nao da normal. Bater na borda
##    manda o tiro em diagonal. E isso que transforma o movimento horizontal na
##    baseline em mira, e o formato de poco em habilidade.
##  - Ganha um quique (sobe o multiplicador) e ganha tambem um de orcamento, entao
##    rebater nunca encurta a vida do projetil. O teto de 12 continua valendo.
##  - Zera a idade: o TTL existe para limitar o custo de projetil esquecido, e um
##    projetil rebatido nao esta esquecido.
func _paddle(i: int, robot: Node) -> void:
	debug_bounce_events += 1
	var center: Vector2 = robot.call("body_center")
	var reach: float = Robot.COLLISION_RADIUS + _radius[i]
	var offset := clampf((_pos[i].x - center.x) / reach, -1.0, 1.0)
	var angle := -PI * 0.5 + offset * PADDLE_MAX_ANGLE
	var rest: float = robot.get("paddle_restitution")
	var speed := clampf(_vel[i].length() * rest, PADDLE_MIN_SPEED, MAX_SPEED)

	_vel[i] = Vector2.from_angle(angle) * speed
	_pos[i] = Vector2(_pos[i].x, minf(_pos[i].y, center.y - reach - 1.0))
	_bounces[i] = mini(_bounces[i] + 1, HARD_BOUNCE_CAP)
	_max_bounces[i] = mini(maxi(_max_bounces[i], _bounces[i]) + 1, HARD_BOUNCE_CAP)
	_age[i] = 0.0
	_last_hit_id[i] = 0

	Telemetry.paddle_catches += 1
	robot.call("on_paddle_hit", _pos[i], _bounces[i])

	_bounce_ctx.index = i
	_bounce_ctx.position = _pos[i]
	_bounce_ctx.normal = Vector2.UP
	_bounce_ctx.bounce_index = _bounces[i]
	_bounce_ctx.collider = robot
	_bounce_ctx.velocity = _vel[i]
	_run_behaviors(i, "on_bounce", _bounce_ctx)

	Vfx.spawn_bounce(_pos[i], Vector2.UP, _bounces[i])
	Sfx.play_bounce(_bounces[i] - 1)


func _run_behaviors(i: int, method: StringName, ctx: RefCounted) -> void:
	var list = _behaviors[i]
	if list == null:
		return
	for b in list:
		b.call(method, ctx)


# --- divisao de projetil ------------------------------------------------------

## Adiar a criacao dos filhos evita mutar o pool no meio da varredura, o que
## invalidaria a iteracao e poderia fazer um filho ser simulado no mesmo quadro
## em que nasceu.
func request_split(parent: int, count: int, damage_ratio: float, spread_deg: float) -> void:
	if _generation[parent] >= 2:
		return  # linhagem limitada, senao uma build de divisao estoura o pool
	_pending_spawns.append({
		"pos": _pos[parent], "vel": _vel[parent],
		"count": count, "ratio": damage_ratio, "spread": spread_deg,
		"damage": _damage[parent], "radius": _radius[parent],
		"faction": _faction[parent], "color": _color[parent],
		"max_bounces": _max_bounces[parent], "gen": _generation[parent] + 1,
		"restitution": _restitution[parent], "stretch": _stretch[parent],
		"floor_immune": _floor_immune[parent],
		"source": _damage_source[parent],
	})


func _flush_splits() -> void:
	if _pending_spawns.is_empty():
		return
	for s in _pending_spawns:
		var base_angle: float = (s["vel"] as Vector2).angle()
		var spread := deg_to_rad(s["spread"])
		var n: int = s["count"]
		for c in n:
			var t := 0.0 if n == 1 else (float(c) / float(n - 1) - 0.5) * 2.0
			var i := _take_index()
			if i < 0:
				break
			var dir := Vector2.from_angle(base_angle + t * spread * 0.5)
			_pos[i] = s["pos"]
			_prev_pos[i] = s["pos"]
			_vel[i] = dir * (s["vel"] as Vector2).length()
			_alive[i] = 1
			_bounces[i] = 0
			_max_bounces[i] = 2
			_infinite[i] = 0
			_floor_immune[i] = s["floor_immune"]
			_damage[i] = s["damage"] * s["ratio"]
			_radius[i] = s["radius"] * 0.75
			_restitution[i] = s["restitution"]
			_ttl[i] = 3.0
			_age[i] = 0.0
			_pierce[i] = 0
			_faction[i] = s["faction"]
			_generation[i] = s["gen"]
			_last_hit_id[i] = 0
			_last_hit_t[i] = -99.0
			_color[i] = s["color"]
			_stretch[i] = s["stretch"]
			_behaviors[i] = null
			# Sem isto o filho herdava a fonte de dano do ocupante anterior do
			# slot, e a legenda de morte culpava a peca errada.
			_damage_source[i] = s["source"]
			_alive_count += 1
	_pending_spawns.clear()


# --- renderizacao -------------------------------------------------------------

func _process(_delta: float) -> void:
	# Interpolacao no lado do render: a simulacao roda a 120 Hz e a tela pode
	# rodar a qualquer taxa. Sem isto, projetil rapido serrilha na horizontal.
	var alpha := 0.0 if CombatFeel.frozen else Engine.get_physics_interpolation_fraction()
	var count := 0
	for i in MAX_PROJECTILES:
		if _alive[i] == 0:
			continue
		var p: Vector2 = _prev_pos[i].lerp(_pos[i], alpha)
		var s := bounce_scale(_bounces[i]) * _radius[i] * 2.0
		# Transform2D(rotacao, escala, inclinacao, origem): escala local, sem
		# arrastar a origem junto, que e o que .scaled() faria.
		var xf := Transform2D(_vel[i].angle(), Vector2(s * _stretch[i], s), 0.0, p)
		_mm.set_instance_transform_2d(count, xf)
		var col: Color = _color[i] if _bounces[i] == 0 else bounce_color(_bounces[i])
		_mm.set_instance_color(count, col)
		count += 1
	_mm.visible_instance_count = count
