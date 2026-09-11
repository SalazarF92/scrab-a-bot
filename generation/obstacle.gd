class_name Obstacle
extends StaticBody2D
## Obstaculo interno da arena. GDD 3.3.4, catalogo de obstaculos.
##
## O campo `restitution` e a razao de ser deste no: o ProjectilePool o le na
## resolucao do quique. Uma Pilha de Pneus a 1,35 ACELERA o projetil, um Colchao
## a 0,45 o amortece. E assim que a geometria da arena vira uma escolha tatica
## em vez de um obstaculo burro.

@export var restitution: float = 1.0
@export var size: Vector2 = Vector2(200, 200)
@export var color: Color = Color("#4A4F52")
@export var label: String = "Parede"
@export var destructible: bool = false
@export var max_hp: float = 400.0
## Chao do poco. Projetil do jogador que chega aqui morre com um "plop": o que
## o robo nao rebate, perde. Ver ProjectilePool._resolve_bounce.
@export var is_floor: bool = false

var hp: float = 400.0
var _flash: float = 0.0


func _ready() -> void:
	add_to_group(&"obstacles")
	# So cenario destrutivel e alvo. Parede de concreto nao entra no grupo,
	# senao todo quique nela conta como acerto. Ver ProjectilePool._resolve_bounce.
	if destructible:
		add_to_group(&"damageable")
	collision_layer = ProjectilePool.LAYER_WALLS
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	add_child(shape)
	hp = max_hp
	z_index = 5


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		queue_redraw()


func take_damage(amount: float, _from: Vector2 = Vector2.ZERO, _bounce_index: int = 0) -> void:
	if not destructible:
		return
	hp -= amount
	_flash = 0.08
	queue_redraw()
	if hp <= 0.0:
		# GDD 3.3.4: a Carcaca de Fusca "cai desmontando". Aqui, so os parafusos.
		Vfx.spawn_death(global_position, color)
		Sfx.play_varied("enemy_death", -4.0)
		queue_free()


func _draw() -> void:
	ArtDirector.draw_obstacle(self, self)
	if label == "Parede":
		return

	# Leitura da restituicao sem tooltip: setas para fora quando acelera,
	# hachura quando amortece. Contrato do pilar 2, "entender em 3 segundos".
	if restitution > 1.05:
		for i in 4:
			var p := Vector2(-size.x * 0.25 + i * size.x * 0.16, 0.0)
			draw_line(p + Vector2(0, 12), p + Vector2(0, -12), Color("#FFD400"), 3.0)
			draw_line(p + Vector2(-7, -5), p + Vector2(0, -12), Color("#FFD400"), 3.0)
			draw_line(p + Vector2(7, -5), p + Vector2(0, -12), Color("#FFD400"), 3.0)
	elif restitution < 0.75:
		var step := 22.0
		var x := -size.x * 0.5 + step
		while x < size.x * 0.5:
			draw_line(Vector2(x, -size.y * 0.5), Vector2(x - 18.0, size.y * 0.5), Color(0, 0, 0, 0.25), 3.0)
			x += step

	if destructible:
		var w := size.x * 0.7
		draw_rect(Rect2(-w * 0.5, -size.y * 0.5 - 12.0, w, 5.0), Color(0, 0, 0, 0.4))
		draw_rect(Rect2(-w * 0.5, -size.y * 0.5 - 12.0, w * (hp / max_hp), 5.0), Color("#FF6B1A"))
