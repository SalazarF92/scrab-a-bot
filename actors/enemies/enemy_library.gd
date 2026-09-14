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

## Perfis de chefe. Todo numero de balanceamento de chefe vive aqui, nao em
## Enemy. Cada perfil lista ataques em ciclo; `kind` escolhe a mecanica:
##   lanes      colunas avisadas que descem ate a base (dano por tique)
##   shards     rajada de projeteis hostis em leque
##   suction    puxa o robo para o eixo do chefe e engole projeteis que sobem
##   sweep      uma faixa que corre a base de um lado ao outro (cabecote no trilho)
##   push       esteira: empurra o robo para a parede
##   paper_ball colunas + uma bola de papel permanente (obstaculo 1,5) em cada
## Chaves opcionais: final_attack (ciclos pares da fase 3), final_spawn,
## final_restitution, final_exposed_mult, final_exposed_name, phase_hitstop_ms.
const BOSS_PROFILES := {
	&"mini_prensa": {
		"ink": Color("#FF5500"), "telegraph": 1.2, "lane_half_width": 64.0,
		"recovery": 3.8, "recovery_step": 0.6, "exposed_mult": 1.5,
		"attacks": [{"kind": &"lanes", "name": "CARIMBO HIDRAULICO", "strike": 0.3, "trauma": 0.4}],
	},
	&"sugao_3000": {
		"ink": Color("#FFB347"), "telegraph": 1.2, "lane_half_width": 70.0,
		"recovery": 3.6, "recovery_step": 0.5,
		# Ponto fraco: o filtro HEPA fica ofegante depois do Sugadao.
		"exposed_mult": 2.5, "exposed_name": "FILTRO HEPA EXPOSTO",
		"final_exposed_mult": 3.0, "final_exposed_name": "BARRIGA ESTUFADA",
		# Fase 3, "Dentro do Saco": a arena vira superficie de restituicao 1,4 e
		# tres bolotas de cabelo entram no poco.
		"final_restitution": 1.4, "final_spawn": {"key": "bolota_de_cabelo", "count": 3},
		"attacks": [
			{"kind": &"suction", "name": "SUGADAO", "strike": 2.2, "trauma": 0.15, "pull": 400.0, "projectile_pull": 1400.0},
			{"kind": &"shards", "name": "BOLA DE PELO", "strike": 0.3, "trauma": 0.25, "shard_speed": 260.0, "shard_bounces": 4},
			{"kind": &"lanes", "name": "CHICOTE DE MANGUEIRA", "strike": 0.4, "trauma": 0.35},
		],
	},
	&"frostbyte": {
		"ink": Color("#22E0FF"), "telegraph": 1.35, "lane_half_width": 76.0,
		"recovery": 3.8, "recovery_step": 0.6, "exposed_mult": 1.5,
		"final_exposed_mult": 2.5, "final_exposed_name": "MAIONESE EXPOSTA",
		"attacks": [
			{"kind": &"lanes", "name": "SOPRO DO FREEZER", "strike": 0.9, "trauma": 0.25},
			{"kind": &"shards", "name": "COMIDA VENCIDA", "strike": 0.3, "trauma": 0.25},
		],
	},
	&"formulario_27b": {
		"ink": Color("#F5F0E1"), "telegraph": 1.1, "lane_half_width": 60.0,
		"recovery": 3.4, "recovery_step": 0.5,
		# "Ela Engasga": a tampa abre e o carretel recebe dano dobrado.
		"exposed_mult": 2.0, "exposed_name": "PC LOAD LETTER",
		"final_exposed_mult": 2.0, "final_exposed_name": "PAPEL ATOLADO",
		"attacks": [
			{"kind": &"sweep", "name": "CABECOTE CORRENDO", "strike": 1.6, "trauma": 0.3, "damage_ratio": 0.6},
			{"kind": &"push", "name": "FORMULARIO CONTINUO", "strike": 2.0, "trauma": 0.1, "push": 180.0},
			{"kind": &"shards", "name": "FITA DE TINTA", "strike": 0.3, "trauma": 0.25, "shard_bounces": 3},
		],
		# "PAPER JAM RAGE": bolas de papel viram obstaculos de restituicao 1,5.
		"final_attack": {"kind": &"paper_ball", "name": "PAPER JAM", "strike": 0.3, "trauma": 0.45, "ball_restitution": 1.5},
	},
	&"fornalha_suprema": {
		"ink": Color("#FF5500"), "telegraph": 1.2, "lane_half_width": 76.0,
		"recovery": 3.8, "recovery_step": 0.6, "exposed_mult": 1.5,
		"attacks": [
			{"kind": &"lanes", "name": "INCINERAR COLUNAS", "strike": 0.3, "trauma": 0.4},
			{"kind": &"shards", "name": "ESTILHACOS EM BRASA", "strike": 0.3, "trauma": 0.4},
		],
	},
}

## GDD 5.3: elite tem 6x o HP de um comum do mesmo setor, aura roxa e
## restituicao 1,00. O modificador especifico de cada elite do GDD (ventoinhas,
## escudo, copia de peca) ainda nao existe; hoje a promocao e so de estatistica.
const ELITE_HP_MULT := 6.0
const ELITE_SCRAP_MULT := 5

static func elite_spec(key: String, sector: int = 1) -> Dictionary:
	var s := spec(key, sector)
	s["enemy_name"] = "ELITE " + str(s["enemy_name"])
	s["max_hp"] = float(s["max_hp"]) * ELITE_HP_MULT
	s["scrap_value"] = int(s["scrap_value"]) * ELITE_SCRAP_MULT
	s["restitution"] = 1.0
	s["body_radius"] = float(s["body_radius"]) * 1.2
	s["is_elite"] = true
	return s

const SPECS := {
	# Fase 3 do Sugao: tres bolotas que precisam morrer. Superficie 1,4.
	"bolota_de_cabelo": {
		"enemy_name": "Bolota de Cabelo", "article": "uma", "max_hp": 120.0, "move_speed": 40.0,
		"contact_damage": 10.0, "restitution": 1.40, "body_radius": 22.0, "descent_factor": 0.25,
		"color": Color("#8A6A3A"), "eyes": 1, "scrap_value": 10,
	},
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
	# Chefe do Setor 2: SUGAO 3000 (GDD 5.4, redesenhado para o poco). Frente
	# blindada: e a boca. O filtro HEPA nas costas e exposto apos o Sugadao.
	"sugao_3000": {
		"enemy_name": "SUGÃO 3000", "article": "o", "max_hp": 820.0, "move_speed": 50.0,
		"contact_damage": 42.0, "restitution": 1.20, "body_radius": 60.0,
		"color": Color("#FFB347"), "eyes": 2, "scrap_value": 140, "is_boss": true,
		"boss_kind": &"sugao_3000", "front_damage_mult": 0.6, "back_damage_mult": 1.5,
	},
	# Chefe do Setor 4: FORMULARIO 27-B (GDD 5.5, redesenhado para o poco).
	"formulario_27b": {
		"enemy_name": "FORMULÁRIO 27-B", "article": "o", "max_hp": 1900.0, "move_speed": 55.0,
		"contact_damage": 60.0, "restitution": 1.20, "body_radius": 72.0,
		"color": Color("#F5F0E1"), "eyes": 2, "scrap_value": 300, "is_boss": true,
		"boss_kind": &"formulario_27b",
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
