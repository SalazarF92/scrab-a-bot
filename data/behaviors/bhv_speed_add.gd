class_name BhvSpeedAdd
extends PartBehavior
## Aditivo percentual de velocidade de projetil no disparo. Serve ao Abajur
## "Farol da Depressao", ao enxerto de Placa de Video Queimada e ao Ryzin.

@export var amount: float = 0.15


func on_fire(ctx) -> void:
	ctx.speed_add += amount
