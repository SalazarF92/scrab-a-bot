class_name BhvSplitOnBounce
extends PartBehavior
## No quique indicado, o projetil se divide em sub-projeteis.
## E o comportamento do Canhao de Fonte "500W Generica" (GDD 4.5), que divide
## em 3 no primeiro quique, e da CENTRIFUGA DE SERRAS (GDD 4.7.2), que libera
## 4 discos a cada quique.

@export var split_count: int = 3
@export var damage_ratio: float = 0.5
@export var spread_deg: float = 55.0
## -1 significa "em todo quique". Qualquer outro valor limita a um quique especifico.
@export var only_on_bounce_index: int = 1


func on_bounce(ctx) -> void:
	if only_on_bounce_index >= 0 and ctx.bounce_index != only_on_bounce_index:
		return
	ctx.spawn_children(split_count, damage_ratio, spread_deg)
