class_name FireContext
extends RefCounted
## Contexto mutavel passado aos comportamentos no momento do disparo.
## Uma unica instancia e reutilizada por soquete, para nao alocar por tiro.
##
## Ordem de aplicacao dos modificadores, fixada em GDD_ADENDOS B.6, porque o GDD
## nunca disse se dois "+22% de dano" somam ou multiplicam, e sem essa regra o
## balanceamento de 90 pecas e indecidivel:
##   aditivos somam entre si, multiplicadores nomeados multiplicam, nada mais.

var robot: Node
var origin: Vector2
var direction: Vector2

## Aditivos percentuais. Somam entre si e entram como (1 + soma).
var damage_add: float = 0.0
var fire_rate_add: float = 0.0
var speed_add: float = 0.0

## Multiplicadores nomeados. Multiplicam.
var rarity_mult: float = 1.0
var fusion_mult: float = 1.0

var extra_shots: int = 0
var spread_radians: float = 0.0
var bonus_bounces: int = 0
## Enxertos (GDD 4.7.3): tamanho, vida e perfuracao do projetil.
var radius_add: float = 0.0
var ttl_add: float = 0.0
var pierce_add: int = 0
var cancelled: bool = false


func reset(p_robot: Node, p_origin: Vector2, p_direction: Vector2) -> void:
	robot = p_robot
	origin = p_origin
	direction = p_direction
	damage_add = 0.0
	fire_rate_add = 0.0
	speed_add = 0.0
	rarity_mult = 1.0
	fusion_mult = 1.0
	extra_shots = 0
	spread_radians = 0.0
	bonus_bounces = 0
	radius_add = 0.0
	ttl_add = 0.0
	pierce_add = 0
	cancelled = false


func final_damage(base: float) -> float:
	return base * (1.0 + damage_add) * rarity_mult * fusion_mult
