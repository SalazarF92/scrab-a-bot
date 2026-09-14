class_name EnemyLibrary
extends RefCounted
## Catalogo de inimigos do prototipo. GDD 5.2.
##
## Cada inimigo declara sua funcao, conforme a filosofia da 5.1: preencher
## espaco, forcar movimento, ou testar a build. Inimigo sem funcao declarada
## nao entra no jogo.
##
## O artigo de cada inimigo alimenta a legenda de fim de run ("Morto por uma
## Parafuseta", "pela Mini-Prensa 500"). Ver RunCaption.

## GDD 5.2: "O HP multiplica por 2,05 a cada setor. O dano multiplica por 1,55.
## A velocidade multiplica por 1,08, com teto em 420 px/s."
## Estas tres alavancas sao o balanceamento primario e ficam num unico lugar.
const HP_PER_SECTOR := 2.05
const DAMAGE_PER_SECTOR := 1.55
const SPEED_PER_SECTOR := 1.08
const SPEED_CAP := 420.0
const EXPANSION_KEYS := ["qwertypede", "popup_vivo", "cadeado_chorao", "olhudo", "bipador", "ze_ventoinha", "cabo_cobra", "fabricadora"]
const INTRO_SECTOR := {"qwertypede": 2, "popup_vivo": 2, "olhudo": 3, "bipador": 3,
	"cadeado_chorao": 4, "ze_ventoinha": 4, "cabo_cobra": 5, "fabricadora": 5}

const SPECS := {
	"qwertypede": {
		"enemy_name": "QWERTYpede", "article": "uma", "max_hp": 90.0, "move_speed": 140.0,
		"contact_damage": 12.0, "restitution": 0.90, "body_radius": 26.0,
		"color": Color("#D6C9A8"), "scrap_value": 16, "mob_kind": &"keyboard",
		"minimum_hits": 8, "spawn_on_death": "parafuseta", "spawn_on_death_count": 3,
	},
	"popup_vivo": {
		"enemy_name": "Pop-Up Vivo", "article": "um", "max_hp": 40.0, "move_speed": 180.0,
		"contact_damage": 10.0, "restitution": 1.0, "body_radius": 22.0,
		"color": Color("#FF2D95"), "scrap_value": 5, "mob_kind": &"popup",
	},
	"cadeado_chorao": {
		"enemy_name": "Cadeado Chorão", "article": "um", "max_hp": 150.0, "move_speed": 120.0,
		"contact_damage": 0.0, "restitution": 0.85, "body_radius": 25.0,
		"color": Color("#8CFF1A"), "scrap_value": 24, "mob_kind": &"lock",
	},
	"olhudo": {
		"enemy_name": "Olhudo", "article": "um", "max_hp": 55.0, "move_speed": 0.0,
		"contact_damage": 22.0, "restitution": 1.20, "body_radius": 22.0,
		"color": Color("#22E0FF"), "scrap_value": 15, "mob_kind": &"laser",
	},
	"bipador": {
		"enemy_name": "Bipador", "article": "um", "max_hp": 45.0, "move_speed": 340.0,
		"contact_damage": 60.0, "restitution": 0.70, "body_radius": 24.0,
		"color": Color("#FF6B1A"), "scrap_value": 12, "mob_kind": &"bomber",
	},
	"ze_ventoinha": {
		"enemy_name": "Zé Ventoinha", "article": "um", "max_hp": 80.0, "move_speed": 160.0,
		"contact_damage": 5.0, "restitution": 0.95, "body_radius": 26.0,
		"color": Color("#FFD400"), "scrap_value": 20, "mob_kind": &"fan",
	},
	"cabo_cobra": {
		"enemy_name": "Cabo Cobra", "article": "um", "max_hp": 70.0, "move_speed": 200.0,
		"contact_damage": 14.0, "restitution": 0.85, "body_radius": 26.0,
		"color": Color("#7B2FBF"), "scrap_value": 18, "mob_kind": &"cable", "zigzag_amplitude": 35.0,
	},
	"fabricadora": {
		"enemy_name": "Fabricadora 3D", "article": "uma", "max_hp": 180.0, "move_speed": 75.0,
		"contact_damage": 16.0, "restitution": 1.0, "body_radius": 38.0,
		"color": Color("#FF6B1A"), "scrap_value": 35, "mob_kind": &"printer", "is_elite": true,
	},
	# Preenchimento. Morre em uma bala e alimenta o snowball.
	"parafuseta": {
		"enemy_name": "Parafuseta", "article": "uma", "max_hp": 12.0, "move_speed": 210.0,
		"contact_damage": 6.0, "restitution": 0.85, "body_radius": 12.0,
		"color": Color("#8A4B2A"), "eyes": 2, "scrap_value": 3,
	},
	# Forcar movimento. O ziguezague atrapalha a mira direta de proposito.
	"rato_morto": {
		"enemy_name": "Rato Morto", "article": "um", "max_hp": 25.0, "move_speed": 290.0,
		"contact_damage": 9.0, "restitution": 0.85, "body_radius": 15.0,
		"color": Color("#4A4F52"), "eyes": 2, "zigzag_amplitude": 80.0, "scrap_value": 6,
	},
	# Preenchimento tanque. Existe para ser uma superficie de quique gorda.
	"vovo_geladeira": {
		"enemy_name": "Vovó Geladeira", "article": "uma", "max_hp": 260.0, "move_speed": 90.0,
		"contact_damage": 20.0, "restitution": 1.15, "body_radius": 38.0,
		"color": Color("#D6C9A8"), "eyes": 2, "scrap_value": 20,
	},
	# Teste de build, e o professor do pilar 3.
	"fantasma_disquete": {
		"enemy_name": "Fantasma de Disquete", "article": "um", "max_hp": 35.0, "move_speed": 150.0,
		"contact_damage": 11.0, "restitution": 1.0, "body_radius": 16.0,
		"color": Color("#22E0FF"), "eyes": 2, "min_bounces_to_damage": 1, "scrap_value": 12,
	},
	# Forcar movimento. Foge e deixa o jogador sem alvo parado.
	"jato_preto": {
		"enemy_name": "Jato Preto", "article": "um", "max_hp": 60.0, "move_speed": 100.0,
		"contact_damage": 8.0, "restitution": 0.80, "body_radius": 18.0,
		"color": Color("#241A12"), "eyes": 2, "flees": true, "scrap_value": 10,
	},
	# Onda de bumpers (GDD_ADENDOS F). Superficie de quique deliberada: desce
	# devagar, acelera o projetil, e ao morrer derrama o que tinha dentro.
	"geladeira_bumper": {
		"enemy_name": "Vovó Geladeira Lotada", "article": "uma", "max_hp": 420.0,
		"move_speed": 60.0, "descent_factor": 0.35, "contact_damage": 20.0,
		"restitution": 1.35, "body_radius": 42.0, "color": Color("#D6C9A8"),
		"eyes": 2, "scrap_value": 30, "is_bumper": true,
		"spawn_on_death": "parafuseta", "spawn_on_death_count": 6,
	},
	# Chefe do Setor 1: Mini-Prensa 500 (GDD 3.1 e GDD_ADENDOS A.1)
	"mini_prensa": {
		"enemy_name": "Mini-Prensa 500", "article": "a", "max_hp": 480.0, "move_speed": 45.0,
		"contact_damage": 35.0, "restitution": 1.30, "body_radius": 52.0,
		"color": Color("#FF5500"), "eyes": 4, "scrap_value": 80, "is_boss": true,
		"boss_kind": &"mini_prensa", "front_damage_mult": 0.30, "back_damage_mult": 2.0,
	},
	# Chefe do Setor 3: Frostbyte 500
	"frostbyte": {
		"enemy_name": "FROSTBYTE 500", "article": "o", "max_hp": 1250.0, "move_speed": 55.0,
		"contact_damage": 50.0, "restitution": 1.20, "body_radius": 68.0,
		"color": Color("#00E5FF"), "eyes": 6, "scrap_value": 200, "is_boss": true,
		"boss_kind": &"frostbyte",
	},
	# Chefe Final do Setor 5: A Fornalha Suprema
	"fornalha_suprema": {
		"enemy_name": "Fornalha Suprema", "article": "a", "max_hp": 3000.0, "move_speed": 65.0,
		"contact_damage": 75.0, "restitution": 1.40, "body_radius": 84.0,
		"color": Color("#FF0055"), "eyes": 8, "scrap_value": 500, "is_boss": true,
		"boss_kind": &"fornalha_suprema",
	},
}


static func spec(key: String, sector: int = 1) -> Dictionary:
	var base: Dictionary = SPECS[key].duplicate()
	base["visual_id"] = StringName(key)
	var s := float(sector - 1)
	base["max_hp"] = base["max_hp"] * pow(HP_PER_SECTOR, s) * MetaManager.get_heat_enemy_hp_mult()
	base["contact_damage"] = base["contact_damage"] * pow(DAMAGE_PER_SECTOR, s) * MetaManager.get_heat_enemy_damage_mult()
	base["move_speed"] = minf(base["move_speed"] * pow(SPEED_PER_SECTOR, s) * MetaManager.get_heat_enemy_speed_mult(), SPEED_CAP)
	return base


static func keys() -> Array:
	return SPECS.keys()
