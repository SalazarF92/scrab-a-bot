class_name BhvDamageRampOnBounce
extends PartBehavior
## Ganha dano proprio a cada quique, acumulando COM o multiplicador global.
## E a Bazuca de Cano de Pia "Encanamento Livre" (GDD 4.5): "+40% de dano por
## quique, acumulando com o multiplicador global", 70 de dano ate 260 no quinto.

@export var damage_add_per_bounce: float = 0.40
@export var speed_add_per_bounce: float = 0.0


func on_bounce(ctx) -> void:
	var pool: ProjectilePool = ctx.pool
	pool.multiply_damage(ctx.index, 1.0 + damage_add_per_bounce)
	if speed_add_per_bounce != 0.0:
		pool.multiply_speed(ctx.index, 1.0 + speed_add_per_bounce)
