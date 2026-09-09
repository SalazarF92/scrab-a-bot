class_name BhvSpread
extends PartBehavior
## Dispara varios projeteis num leque. GDD 7.3, exemplo de comportamento
## reutilizavel. Serve a Torradeira (3 torradas), a Impressora (6 folhas)
## e a Cusparada de Fita de Tinta do FORMULARIO 27-B (8 tiras).

@export var count: int = 3
@export var angle_deg: float = 40.0


func on_fire(ctx) -> void:
	ctx.extra_shots += count - 1
	ctx.spread_radians = maxf(ctx.spread_radians, deg_to_rad(angle_deg))
