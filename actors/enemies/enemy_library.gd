class_name EnemyLibrary
extends RefCounted
## Catalogo de inimigos do prototipo. GDD 5.2.
##
## Cada inimigo declara sua funcao, conforme a filosofia da 5.1: preencher
## espaco, forcar movimento, ou testar a build. Inimigo sem funcao declarada
## nao entra no jogo.

## GDD 5.2: "O HP multiplica por 2,05 a cada setor. O dano multiplica por 1,55.
## A velocidade multiplica por 1,08, com teto em 420 px/s."
## Estas tres alavancas sao o balanceamento primario e ficam num unico lugar.
const HP_PER_SECTOR := 2.05
const DAMAGE_PER_SECTOR := 1.55
const SPEED_PER_SECTOR := 1.08
const SPEED_CAP := 420.0

const SPECS := {
	# Preenchimento. Morre em uma bala e alimenta o snowball.
	"parafuseta": {
		"enemy_name": "Parafuseta", "max_hp": 12.0, "move_speed": 210.0,
		"contact_damage": 6.0, "restitution": 0.85, "body_radius": 12.0,
		"color": Color("#8A4B2A"), "eyes": 2, "scrap_value": 3,
	},
	# Forcar movimento. O ziguezague atrapalha a mira direta de proposito.
	"rato_morto": {
		"enemy_name": "Rato Morto", "max_hp": 25.0, "move_speed": 290.0,
		"contact_damage": 9.0, "restitution": 0.85, "body_radius": 15.0,
		"color": Color("#4A4F52"), "eyes": 2, "zigzag_amplitude": 80.0, "scrap_value": 6,
	},
	# Preenchimento tanque. Existe para ser uma superficie de quique gorda.
	"vovo_geladeira": {
		"enemy_name": "Vovo Geladeira", "max_hp": 260.0, "move_speed": 90.0,
		"contact_damage": 20.0, "restitution": 1.15, "body_radius": 38.0,
		"color": Color("#D6C9A8"), "eyes": 2, "scrap_value": 20,
	},
	# Teste de build, e o professor do pilar 3.
	"fantasma_disquete": {
		"enemy_name": "Fantasma de Disquete", "max_hp": 35.0, "move_speed": 150.0,
		"contact_damage": 11.0, "restitution": 1.0, "body_radius": 16.0,
		"color": Color("#22E0FF"), "eyes": 2, "min_bounces_to_damage": 1, "scrap_value": 12,
	},
	# Forcar movimento. Foge e deixa o jogador sem alvo parado.
	"jato_preto": {
		"enemy_name": "Jato Preto", "max_hp": 60.0, "move_speed": 100.0,
		"contact_damage": 8.0, "restitution": 0.80, "body_radius": 18.0,
		"color": Color("#241A12"), "eyes": 2, "flees": true, "scrap_value": 10,
	},
	# Chefe do Setor 1: Mini-Prensa 500 (GDD 3.1 e GDD_ADENDOS A.1)
	"mini_prensa": {
		"enemy_name": "Mini-Prensa 500", "max_hp": 480.0, "move_speed": 45.0,
		"contact_damage": 35.0, "restitution": 1.30, "body_radius": 52.0,
		"color": Color("#FF5500"), "eyes": 4, "scrap_value": 80, "is_boss": true,
	},
	# Chefe do Setor 3: Frostbyte 500
	"frostbyte": {
		"enemy_name": "FROSTBYTE 500", "max_hp": 1250.0, "move_speed": 55.0,
		"contact_damage": 50.0, "restitution": 1.20, "body_radius": 68.0,
		"color": Color("#00E5FF"), "eyes": 6, "scrap_value": 200, "is_boss": true,
	},
	# Chefe Final do Setor 5: A Fornalha Suprema
	"fornalha_suprema": {
		"enemy_name": "A Fornalha Suprema", "max_hp": 3000.0, "move_speed": 65.0,
		"contact_damage": 75.0, "restitution": 1.40, "body_radius": 84.0,
		"color": Color("#FF0055"), "eyes": 8, "scrap_value": 500, "is_boss": true,
	},
}


static func spec(key: String, sector: int = 1) -> Dictionary:
	var base: Dictionary = SPECS[key].duplicate()
	var s := float(sector - 1)
	var heat_hp_mult: float = 1.0
	var heat_spd_mult: float = 1.0
	if Engine.has_singleton(&"MetaManager") or is_instance_valid(MetaManager):
		heat_hp_mult = MetaManager.get_heat_enemy_hp_mult()
		heat_spd_mult = MetaManager.get_heat_enemy_speed_mult()
	base["max_hp"] = base["max_hp"] * pow(HP_PER_SECTOR, s) * heat_hp_mult
	base["contact_damage"] = base["contact_damage"] * pow(DAMAGE_PER_SECTOR, s)
	base["move_speed"] = minf(base["move_speed"] * pow(SPEED_PER_SECTOR, s) * heat_spd_mult, SPEED_CAP)
	return base


static func keys() -> Array:
	return SPECS.keys()
