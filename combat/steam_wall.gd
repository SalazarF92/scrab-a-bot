class_name SteamWall
extends StaticBody2D
## Parede de vapor deixada pela Purga de Calor.
##
## A Purga deixa de ser so uma explosao de area: ela desenha uma superficie de
## quique no ponto mirado, por alguns segundos, perpendicular a mira. Um tiro
## reto na parede volta reto para o rebatedor. "A arena e cumplice" passa a ser
## algo que o jogador constroi, e nao so algo que o gerador entrega.
##
## Ela tambem segura inimigos por alguns segundos, porque inimigos colidem com a
## camada de paredes. O GDD 4.1.2 ja chama a Purga de "defesa e ataque ao mesmo
## tempo"; agora isso vale nos dois sentidos.
##
## Nao e instanciada em combate. O robo recebe um conjunto pre-alocado e liga e
## desliga a camada de colisao. GDD 7.2, otimizacao obrigatoria 1.

const DURATION := 3.0
const SIZE := Vector2(240.0, 26.0)
const FADE_TIME := 0.5
## Mesma restituicao da Pilha de Pneus: a parede acelera, e premio e nao so bloqueio.
const RESTITUTION := 1.35

## Lido pelo ProjectilePool na resolucao do quique.
var restitution: float = RESTITUTION
var life: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	add_child(shape)
	z_index = 6
	visible = false


func is_active() -> bool:
	return life > 0.0


func deploy(at: Vector2, angle: float, duration: float = DURATION) -> void:
	global_position = at
	rotation = angle
	life = duration
	collision_layer = ProjectilePool.LAYER_WALLS
	visible = true
	queue_redraw()


func retract() -> void:
	life = 0.0
	collision_layer = 0
	visible = false


func _physics_process(delta: float) -> void:
	if life <= 0.0 or CombatFeel.frozen:
		return
	life -= delta
	if life <= 0.0:
		retract()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var fade := clampf(life / FADE_TIME, 0.0, 1.0)
	var puff := Color("#F5F0E1", 0.85 * fade)
	# Nuvem de desenho animado: bolotas ao longo do comprimento, sem gradiente.
	# GDD 2.7.1: fumaca some por escala e forma, nunca por gradiente suave.
	var n := 7
	var t := Time.get_ticks_msec() * 0.006
	for i in n:
		var x := lerpf(-SIZE.x * 0.5 + 14.0, SIZE.x * 0.5 - 14.0, float(i) / float(n - 1))
		var wobble := sin(t + i * 1.7) * 2.0
		draw_circle(Vector2(x, wobble), 17.0 * lerpf(0.6, 1.0, fade), puff)
	draw_rect(Rect2(-SIZE * 0.5, SIZE), Color("#22E0FF", 0.45 * fade), false, 3.0)
	# Setas de aceleracao: a mesma leitura dos obstaculos com restituicao acima de 1.
	var arrow := Color("#FFD400", fade)
	for i in 3:
		var p := Vector2(-SIZE.x * 0.3 + i * SIZE.x * 0.3, 0.0)
		draw_line(p + Vector2(0, 8), p + Vector2(0, -8), arrow, 3.0)
		draw_line(p + Vector2(-6, -3), p + Vector2(0, -8), arrow, 3.0)
		draw_line(p + Vector2(6, -3), p + Vector2(0, -8), arrow, 3.0)
