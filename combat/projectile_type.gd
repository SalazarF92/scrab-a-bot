class_name ProjectileType
extends Resource
## Definicao de um tipo de projetil. GDD 7.3: Resource customizado e nao JSON,
## porque e tipado, editavel no inspetor e serializa sem codigo de conversao.

@export var id: StringName = &"generic"

@export_group("Balistica")
@export var speed: float = 900.0
@export var radius: float = 7.0
## GDD_ADENDOS A.3: a base sobe de 3 para 4 quiques, senao o tier magenta de
## multiplicador 4,00 e literalmente inalcancavel sem upgrade de metaprogressao.
@export var max_bounces: int = 4
## GDD_ADENDOS A.4: "quiques infinitos" significa que o contador nao mata o
## projetil. O TTL vira o limitador, para o custo de simulacao continuar previsivel.
@export var infinite_bounces: bool = false
@export var restitution: float = 1.0
@export var ttl: float = 6.0
@export var pierce: int = 0

@export_group("Combate")
@export var damage: float = 10.0
@export var heat_per_shot: float = 1.0

@export_group("Visual")
@export var base_color: Color = Color("#8CFF1A")
@export var stretch: float = 1.6


static func make(p: Dictionary) -> ProjectileType:
	var t := ProjectileType.new()
	for k in p:
		t.set(k, p[k])
	return t
