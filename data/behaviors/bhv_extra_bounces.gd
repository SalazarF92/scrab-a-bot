class_name BhvExtraBounces
extends PartBehavior
## Soma quiques ao projetil no momento do disparo.
## Eixo 1 do efeito bola de neve (GDD 3.3.3). Serve ao enxerto de Ima de
## Alto-Falante, ao Abajur "Farol da Depressao" e a CPU "Placa de Video
## Enfiada no Soquete".

@export var amount: int = 1


func on_fire(ctx) -> void:
	ctx.bonus_bounces += amount
