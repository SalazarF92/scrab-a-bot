class_name MetaManagerScript
extends Node
## Gerenciador de metaprogressao, economia e persistencia.
## Implementa GDD 6.1 a 6.3 e o sistema de salvamento em user://save.json do GDD 7.3.
##
## Tambem guarda o desafio diario (GDD 6.3.5 e GDD_ADENDOS E.4): semente derivada
## da data em UTC, sem servidor, loadout fixo e nivel de risco zero, para que a
## mesma run seja comparavel entre jogadores.

signal save_updated
signal scrap_changed(current_scrap: int)

const DEFAULT_SAVE_PATH := "user://save.json"
## Versao 2 acrescenta os campos do desafio diario. Um save da versao 1 carrega
## com esses campos no valor padrao, entao a migracao e a propria leitura.
const SAVE_VERSION := 2

## GDD 6.2: "Desafio diario completo: 150."
const DAILY_REWARD := 150
## O GDD nao diz o que e "completo". Aqui: limpar 3 setores numa tentativa do dia.
## Numero de balanceamento, ajustavel sem mexer em mais nada.
const DAILY_GOAL_SECTORS := 3

## Arvore de upgrades da Garagem. GDD 6.3.1.
## 5 ramos, cada um com 5 nos com custo e descricao.
const UPGRADE_TREE := {
	"chapa": [
		{"id": "solda_reforcada", "name": "Solda Reforçada", "desc": "+15 HP base permanente", "cost": 150},
		{"id": "chapas_dobradas", "name": "Chapas Dobradas", "desc": "+15% de HP máximo", "cost": 400},
		{"id": "blindagem_estrada", "name": "Blindagem de Estrada", "desc": "-10% de dano recebido", "cost": 850},
		{"id": "para_choque", "name": "Para-Choque de Caminhão", "desc": "+25% HP, mas -5% velocidade", "cost": 1600},
		{"id": "airbag_vencido", "name": "Airbag Vencido", "desc": "Sobrevive a 1 golpe fatal por run com 1 HP", "cost": 3200},
	],
	"polvora": [
		{"id": "polvora_caseira", "name": "Pólvora Caseira", "desc": "+8% de dano geral", "cost": 200},
		{"id": "pinos_polidos", "name": "Pinos Polidos", "desc": "+12% velocidade de projétil", "cost": 500},
		{"id": "mira_seu_nildo", "name": "Mira do Seu Nildo", "desc": "+12% de chance de acerto crítico (2x)", "cost": 1100},
		{"id": "polvora_grossa", "name": "Pólvora Grossa", "desc": "+15% de dano adicional em quiques 2+", "cost": 2200},
		{"id": "terceiro_quique_gratis", "name": "Terceiro Quique Grátis", "desc": "Projéteis já nascem com 1 quique contado (1,25x)", "cost": 4000},
	],
	"mola": [
		{"id": "graxa_boa", "name": "Graxa Boa", "desc": "-15% tempo de recarga do dash", "cost": 180},
		{"id": "rodizio_lubrificado", "name": "Rodízio Lubrificado", "desc": "+10% velocidade de movimento", "cost": 420},
		{"id": "amortecedor_rapido", "name": "Amortecedor Rápido", "desc": "+20% velocidade durante o dash", "cost": 950},
		{"id": "freio_borracha", "name": "Freio de Borracha", "desc": "-60% de recuo ao disparar", "cost": 1700},
		{"id": "perna_extra", "name": "Perna Extra", "desc": "+1 carga máxima de dash permanente", "cost": 2800},
	],
	"cobre": [
		{"id": "ventoinha_verdade", "name": "Ventoinha de Verdade", "desc": "+25% dissipação passiva de calor", "cost": 220},
		{"id": "fiacao_grossa", "name": "Fiação Grossa", "desc": "+15 Watts de TDP em qualquer CPU", "cost": 550},
		{"id": "dissipador_aluminio", "name": "Dissipador de Alumínio", "desc": "-15% geração de calor por tiro", "cost": 1200},
		{"id": "valvula_alivio", "name": "Válvula de Alívio", "desc": "-25% recarga da Purga de Calor", "cost": 2200},
		{"id": "purga_dupla", "name": "Purga Turbinada", "desc": "+50% de dano e raio na Purga de Calor", "cost": 3400},
	],
	"sorte": [
		{"id": "ima_sucata", "name": "Ímã de Sucata", "desc": "+20% de Sucata obtida de inimigos", "cost": 250},
		{"id": "olho_clinico", "name": "Olho Clínico", "desc": "+15% chance de peças raras na Bancada", "cost": 650},
		{"id": "barganha_ferro", "name": "Barganha do Ferro", "desc": "-25% custo de reroll na Bancada", "cost": 1400},
		{"id": "sucata_fina", "name": "Reciclagem Eficiente", "desc": "+25% Cobre convertido da Sucata pós-run", "cost": 2500},
		{"id": "quarta_opcao", "name": "Quarta Opção", "desc": "Bancada passa a oferecer 4 opções", "cost": 4200},
	],
}

## Caminho do save. Os testes trocam isto antes de qualquer escrita; a versao
## anterior do teste de fumaca chamava reset_save no save real do jogador.
var save_path: String = DEFAULT_SAVE_PATH

# --- Estado Persistente ---
var copper: int = 0
var upgrades: Dictionary = {}  # branch_name -> int (nivel desbloqueado, 0 a 5)
var total_runs: int = 0
var total_kills: int = 0
var best_sector: int = 1
var lifetime_copper: int = 0
var highest_heat_beaten: int = 0
var daily_date: String = ""
var daily_best_sectors: int = 0
var daily_rewarded: bool = false

# --- Estado da Run Atual ---
var current_scrap: int = 0
var run_sectors_cleared: int = 0
var airbag_available: bool = false
var selected_heat: int = 0
var run_is_daily: bool = false
var run_seed: int = 0
var last_run_summary: Dictionary = {}


func _ready() -> void:
	_init_default_upgrades()
	load_save()


func _init_default_upgrades() -> void:
	for branch in UPGRADE_TREE:
		upgrades[branch] = 0


func start_new_run(heat: int = -1, daily: bool = false, seed_value: int = 0) -> void:
	if heat >= 0:
		selected_heat = clampi(heat, 0, 10)
	run_is_daily = daily
	run_seed = seed_value
	current_scrap = 0
	run_sectors_cleared = 0
	airbag_available = get_upgrade_level("chapa") >= 5
	if daily:
		refresh_daily()
	scrap_changed.emit(current_scrap)


## Nivel de risco em vigor na run. O desafio diario ignora a Calibragem de Risco
## para que todo mundo jogue a mesma coisa.
func active_heat() -> int:
	return 0 if run_is_daily else selected_heat


func add_scrap(amount: int) -> void:
	var mult := get_scrap_gain_mult()
	var final_amount := int(round(float(amount) * mult))
	current_scrap += final_amount
	scrap_changed.emit(current_scrap)


## Gasto de Sucata na Bancada. Falha sem alterar nada se nao houver saldo.
func spend_scrap(amount: int) -> bool:
	if amount < 0 or current_scrap < amount:
		return false
	current_scrap -= amount
	scrap_changed.emit(current_scrap)
	return true


## Devolucao de Sucata. Nao passa pelo Ima de Sucata: reembolso nao e coleta.
func refund_scrap(amount: int) -> void:
	current_scrap += maxi(0, amount)
	scrap_changed.emit(current_scrap)


## Zera o progresso do dia quando a data em UTC muda.
func refresh_daily() -> void:
	var today := GameRng.utc_date_key()
	if daily_date != today:
		daily_date = today
		daily_best_sectors = 0
		daily_rewarded = false


func end_run(sector_reached: int, won: bool = false, extra: Dictionary = {}) -> Dictionary:
	total_runs += 1
	total_kills += Telemetry.enemies_killed
	if sector_reached > best_sector:
		best_sector = sector_reached

	if won and not run_is_daily and selected_heat >= highest_heat_beaten:
		highest_heat_beaten = mini(10, selected_heat + 1)

	# GDD 6.2: 1 Cobre para cada 8 Sucata + 40 por setor completado
	var conversion_rate := 8.0
	if get_upgrade_level("sorte") >= 4:
		conversion_rate = 6.4 # +25% conversao

	var scrap_copper := int(floor(float(current_scrap) / conversion_rate))
	var sector_bonus := maxi(0, sector_reached - 1) * 40
	var victory_bonus := 200 if won else 0
	var raw_copper := scrap_copper + sector_bonus + victory_bonus
	var heat_mult := get_heat_copper_bonus_mult()
	var copper_earned := int(round(float(raw_copper) * heat_mult))

	var sectors_cleared := 5 if won else maxi(0, sector_reached - 1)
	var daily_reward := 0
	if run_is_daily:
		refresh_daily()
		daily_best_sectors = maxi(daily_best_sectors, sectors_cleared)
		if not daily_rewarded and sectors_cleared >= DAILY_GOAL_SECTORS:
			daily_rewarded = true
			daily_reward = DAILY_REWARD
	copper_earned += daily_reward

	copper += copper_earned
	lifetime_copper += copper_earned

	last_run_summary = {
		"sector_reached": sector_reached,
		"sectors_cleared": sectors_cleared,
		"won": won,
		"heat": active_heat(),
		"scrap_collected": current_scrap,
		"scrap_copper": scrap_copper,
		"sector_bonus": sector_bonus,
		"victory_bonus": victory_bonus,
		"heat_mult": heat_mult,
		"daily": run_is_daily,
		"daily_reward": daily_reward,
		"seed": run_seed,
		"kills": Telemetry.enemies_killed,
		"copper_earned": copper_earned,
		"total_copper": copper,
	}
	last_run_summary.merge(extra, true)

	save_game()
	save_updated.emit()
	return last_run_summary


# --- Upgrades API ---

func get_upgrade_level(branch: String) -> int:
	return upgrades.get(branch, 0)


func get_next_upgrade_cost(branch: String) -> int:
	var level: int = get_upgrade_level(branch)
	var list: Array = UPGRADE_TREE.get(branch, [])
	if level >= list.size():
		return -1 # Maximo atingido
	return list[level]["cost"]


func can_buy_upgrade(branch: String) -> bool:
	var cost := get_next_upgrade_cost(branch)
	return cost > 0 and copper >= cost


func buy_upgrade(branch: String) -> bool:
	if not can_buy_upgrade(branch):
		return false
	var cost := get_next_upgrade_cost(branch)
	copper -= cost
	upgrades[branch] = get_upgrade_level(branch) + 1
	save_game()
	save_updated.emit()
	return true


# --- Modificadores Concretos Derivados dos Upgrades ---

func get_bonus_hp_flat() -> float:
	return 15.0 if get_upgrade_level("chapa") >= 1 else 0.0


func get_bonus_hp_mult() -> float:
	var mult := 1.0
	var lvl := get_upgrade_level("chapa")
	if lvl >= 2: mult += 0.15
	if lvl >= 4: mult += 0.25
	return mult


func get_damage_reduction_mult() -> float:
	return 0.90 if get_upgrade_level("chapa") >= 3 else 1.0


func get_bonus_speed_mult() -> float:
	var mult := 1.0
	if get_upgrade_level("chapa") >= 4:
		mult -= 0.05 # Penalidade do para-choque
	if get_upgrade_level("mola") >= 2:
		mult += 0.10 # Rodizio lubrificado
	return mult


func get_bonus_damage_mult() -> float:
	var mult := 1.0
	if get_upgrade_level("polvora") >= 1:
		mult += 0.08
	return mult


func get_proj_speed_mult() -> float:
	return 1.12 if get_upgrade_level("polvora") >= 2 else 1.0


func get_crit_chance() -> float:
	return 0.12 if get_upgrade_level("polvora") >= 3 else 0.0


## Lido pelo ProjectilePool em todo acerto com dois quiques ou mais.
func get_bounce_damage_bonus() -> float:
	return 0.15 if get_upgrade_level("polvora") >= 4 else 0.0


func get_free_bounces() -> int:
	# Terceiro Quique Gratis: comeca com 1 quique contado
	return 1 if get_upgrade_level("polvora") >= 5 else 0


func get_dash_cooldown_mult() -> float:
	return 0.85 if get_upgrade_level("mola") >= 1 else 1.0


func get_dash_speed_mult() -> float:
	return 1.20 if get_upgrade_level("mola") >= 3 else 1.0


func get_recoil_mult() -> float:
	return 0.40 if get_upgrade_level("mola") >= 4 else 1.0


func get_bonus_dash_charges() -> int:
	return 1 if get_upgrade_level("mola") >= 5 else 0


func get_bonus_dissipation_mult() -> float:
	return 1.25 if get_upgrade_level("cobre") >= 1 else 1.0


func get_bonus_tdp() -> int:
	return 15 if get_upgrade_level("cobre") >= 2 else 0


func get_heat_gen_mult() -> float:
	return 0.85 if get_upgrade_level("cobre") >= 3 else 1.0


func get_purge_cooldown_mult() -> float:
	return 0.75 if get_upgrade_level("cobre") >= 4 else 1.0


func get_purge_power_mult() -> float:
	return 1.50 if get_upgrade_level("cobre") >= 5 else 1.0


func get_scrap_gain_mult() -> float:
	return 1.20 if get_upgrade_level("sorte") >= 1 else 1.0


func get_workbench_options_count() -> int:
	return 4 if get_upgrade_level("sorte") >= 5 else 3


# --- Modificadores do Modo Ferro-Velho Infernal (Heat) ---

func get_heat_enemy_hp_mult() -> float:
	return 1.0 + float(active_heat()) * 0.12


func get_heat_enemy_speed_mult() -> float:
	return minf(1.0 + float(active_heat()) * 0.05, 1.40)


## Dano de contato e de projetil inimigo. Sem isto o nivel de risco so
## engrossava e acelerava os inimigos, e o jogador nunca sentia o golpe.
func get_heat_enemy_damage_mult() -> float:
	return 1.0 + float(active_heat()) * 0.06


func get_heat_descent_mult() -> float:
	return 1.0 + float(active_heat()) * 0.08


func get_heat_budget_mult() -> float:
	return 1.0 + float(active_heat()) * 0.15


func get_heat_copper_bonus_mult() -> float:
	return 1.0 + float(active_heat()) * 0.25


# --- Persistencia JSON ---

func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"copper": copper,
		"lifetime_copper": lifetime_copper,
		"total_runs": total_runs,
		"total_kills": total_kills,
		"best_sector": best_sector,
		"highest_heat_beaten": highest_heat_beaten,
		"upgrades": upgrades,
		"daily_date": daily_date,
		"daily_best_sectors": daily_best_sectors,
		"daily_rewarded": daily_rewarded,
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


func load_save() -> void:
	if not FileAccess.file_exists(save_path):
		save_game()
		return

	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return

	var json_text := file.get_as_text()
	file.close()

	var parser := JSON.new()
	if parser.parse(json_text) != OK:
		push_warning("Falha ao ler %s, mantendo o estado atual." % save_path)
		return

	var data = parser.data
	if typeof(data) != TYPE_DICTIONARY:
		return

	copper = int(data.get("copper", 0))
	lifetime_copper = int(data.get("lifetime_copper", copper))
	total_runs = int(data.get("total_runs", 0))
	total_kills = int(data.get("total_kills", 0))
	best_sector = int(data.get("best_sector", 1))
	highest_heat_beaten = int(data.get("highest_heat_beaten", 0))
	daily_date = str(data.get("daily_date", ""))
	daily_best_sectors = int(data.get("daily_best_sectors", 0))
	daily_rewarded = bool(data.get("daily_rewarded", false))

	var upg = data.get("upgrades", {})
	if typeof(upg) == TYPE_DICTIONARY:
		for k in UPGRADE_TREE:
			upgrades[k] = int(upg.get(k, 0))
	else:
		_init_default_upgrades()


func reset_save() -> void:
	copper = 0
	lifetime_copper = 0
	total_runs = 0
	total_kills = 0
	best_sector = 1
	highest_heat_beaten = 0
	selected_heat = 0
	daily_date = ""
	daily_best_sectors = 0
	daily_rewarded = false
	run_is_daily = false
	run_seed = 0
	last_run_summary = {}
	_init_default_upgrades()
	save_game()
	save_updated.emit()
