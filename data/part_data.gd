class_name PartData
extends Resource
## GDD 7.3. Uma peca e dado, nunca codigo. O que a diferencia de outra e a
## combinacao de numeros mais o array de comportamentos.

enum Slot { CPU, HEAD, ARM_LEFT, ARM_RIGHT, CHASSIS }
enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY }

## GDD 4.2, multiplicador de stats por raridade.
const RARITY_MULT := [1.0, 1.35, 1.80, 2.50]
## GDD 4.7.1, fusao de duplicata.
const FUSION_MULT := [1.0, 1.40, 1.90, 2.60]
const UPGRADE_COSTS := [80, 140, 220]

@export var id: StringName = &""
@export var display_name: String = ""
@export var slot: Slot = Slot.ARM_LEFT
@export var rarity: Rarity = Rarity.COMMON
@export var fusion_level: int = 0  # 0 a 3, corresponde a I..IV

@export_group("Custo")
## GDD 4.1.1: cada peca consome entre 12 e 65 Watts.
@export var watts: int = 25
## GDD 4.1.2: cada disparo gera de 0,8 a 9 unidades de calor.
@export var heat_per_shot: float = 2.0

@export_group("Disparo")
@export var fire_rate: float = 3.0          # tiros por segundo
@export var automatic: bool = true          # barramento serial e automatico
@export var projectile: ProjectileType

@export_group("Chassi")
@export var hp: float = 100.0
@export var move_speed: float = 260.0
@export var dash_charges: int = 1
## Restituicao do robo como rebatedor (GDD_ADENDOS F). So e lida no chassi.
@export var restitution: float = 1.0

@export_group("Loja")
## Resultado de receita de fusao. GDD 4.7.2: "gera uma peca unica que nao existe
## na tabela de drops". Fica fora da vitrine.
@export var recipe_only: bool = false

@export_group("Comportamento")
@export var behaviors: Array[PartBehavior] = []

@export_group("Visual")
@export var color: Color = Color("#8A4B2A")
@export var silhouette: String = "box"
## Como a peca aparece na legenda de fim de run: artigo e apelido em minusculas,
## por exemplo "uma torradeira". GDD 1.4, item 3.
@export var caption: String = ""


func rarity_mult() -> float:
	return RARITY_MULT[rarity]


func fusion_mult() -> float:
	return FUSION_MULT[clampi(fusion_level, 0, 3)]


## Raridade vezes tier de fusao, os dois multiplicadores nomeados de GDD_ADENDOS B.6.
func power_mult() -> float:
	return rarity_mult() * fusion_mult()


func effective_damage() -> float:
	if projectile == null:
		return 0.0
	return projectile.damage * power_mult()


## GDD 4.2: barramento serial no braco esquerdo (cadencia), paralelo no direito
## (impacto). Portas incompativeis, o que forca assimetria visual e impede
## equipar duas copias da arma dominante.
func bus_name() -> String:
	match slot:
		Slot.ARM_LEFT: return "Barramento Serial"
		Slot.ARM_RIGHT: return "Barramento Paralelo"
		_: return ""


func rarity_name() -> String:
	match rarity:
		Rarity.COMMON: return "Comum"
		Rarity.UNCOMMON: return "Incomum"
		Rarity.RARE: return "Rara"
		Rarity.LEGENDARY: return "Lendária"
	return ""


func rarity_color() -> Color:
	match rarity:
		Rarity.COMMON: return Color("#D6C9A8")
		Rarity.UNCOMMON: return Color("#8CFF1A")
		Rarity.RARE: return Color("#22E0FF")
		Rarity.LEGENDARY: return Color("#FF2D95")
	return Color.WHITE


func fusion_roman() -> String:
	const ROMANS := ["I", "II", "III", "IV"]
	return ROMANS[clampi(fusion_level, 0, 3)]


## Preco de compra em Sucata por raridade. GDD_ADENDOS B.3.
func base_price() -> int:
	match rarity:
		Rarity.COMMON: return 90
		Rarity.UNCOMMON: return 160
		Rarity.RARE: return 280
		Rarity.LEGENDARY: return 480
	return 90


## Valor de reposicao: preco da raridade mais os degraus de evolucao aplicados.
## O tier adquirido por duplicata usa a mesma tabela de valor do tier comprado.
func replacement_value() -> int:
	var value := base_price()
	for level in clampi(fusion_level, 0, 3):
		value += UPGRADE_COSTS[level]
	return value


## GDD_ADENDOS B.3: substituir devolve 50%, incluindo o investimento em tier.
func sell_value() -> int:
	return int(floor(float(replacement_value()) * 0.5))


## Custo em Sucata para subir de nivel de fusao (+Tier).
func upgrade_cost() -> int:
	if fusion_level >= 3:
		return -1
	return UPGRADE_COSTS[clampi(fusion_level, 0, 2)]


func clone() -> PartData:
	var c := PartData.new()
	c.id = id
	c.display_name = display_name
	c.slot = slot
	c.rarity = rarity
	c.fusion_level = fusion_level
	c.watts = watts
	c.heat_per_shot = heat_per_shot
	c.fire_rate = fire_rate
	c.automatic = automatic
	c.projectile = projectile
	c.hp = hp
	c.move_speed = move_speed
	c.dash_charges = dash_charges
	c.restitution = restitution
	c.recipe_only = recipe_only
	c.behaviors = behaviors.duplicate()
	c.color = color
	c.silhouette = silhouette
	c.caption = caption
	return c
