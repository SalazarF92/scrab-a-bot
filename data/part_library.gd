class_name PartLibrary
extends RefCounted
## Catalogo do prototipo, montado em codigo.
##
## Na producao estes viram arquivos .tres autorados no inspetor, exatamente como
## manda o GDD 7.3, e os numeros passam a vir da planilha de balanceamento via
## BalanceImporter. Em codigo aqui porque o prototipo precisa rodar antes de
## existir pipeline de dados, e porque assim o diff de balanceamento e legivel.
##
## Todos os valores sao os do GDD, secoes 4.3 a 4.6.

static func _proj(p: Dictionary) -> ProjectileType:
	return ProjectileType.make(p)


# --- BRACO ESQUERDO: barramento serial, cadencia ------------------------------

static func arm_left_parts() -> Array[PartData]:
	var out: Array[PartData] = []

	var mouse := PartData.new()
	mouse.id = &"arm_l_mousetrap"
	mouse.display_name = "Ratoeira de Mouse \"Clica Clica\""
	mouse.slot = PartData.Slot.ARM_LEFT
	mouse.watts = 25
	mouse.heat_per_shot = 1.0
	mouse.fire_rate = 10.0
	mouse.color = Color("#D6C9A8")
	# GDD 4.4: quica 6 vezes com restituicao 1,15, ganhando velocidade.
	mouse.projectile = _proj({
		"id": &"cursor_click", "speed": 1050.0, "radius": 6.0, "max_bounces": 6,
		"restitution": 1.15, "ttl": 5.0, "damage": 6.0,
		"base_color": Color("#22E0FF"), "stretch": 1.8,
	})
	out.append(mouse)

	var drill := PartData.new()
	drill.id = &"arm_l_drill"
	drill.display_name = "Furadeira de Impacto \"Broca Gaga\""
	drill.slot = PartData.Slot.ARM_LEFT
	drill.watts = 34
	drill.heat_per_shot = 1.2
	drill.fire_rate = 11.0
	drill.color = Color("#FF6B1A")
	# GDD 4.4: quica 2 vezes, perfura 1 inimigo antes de quicar.
	drill.projectile = _proj({
		"id": &"drill_bit", "speed": 1250.0, "radius": 5.0, "max_bounces": 2,
		"restitution": 1.0, "ttl": 3.0, "damage": 9.0, "pierce": 1,
		"base_color": Color("#FF6B1A"), "stretch": 2.4,
	})
	out.append(drill)

	var stapler := PartData.new()
	stapler.id = &"arm_l_stapler"
	stapler.display_name = "Metralhadora de Grampeador \"Tec-Tec-Tec\""
	stapler.slot = PartData.Slot.ARM_LEFT
	stapler.watts = 36
	stapler.heat_per_shot = 0.9
	stapler.fire_rate = 14.0
	stapler.color = Color("#4A4F52")
	stapler.projectile = _proj({
		"id": &"staple", "speed": 1400.0, "radius": 4.0, "max_bounces": 2,
		"restitution": 0.95, "ttl": 2.5, "damage": 7.0,
		"base_color": Color("#F5F0E1"), "stretch": 2.8,
	})
	out.append(stapler)

	return out


# --- BRACO DIREITO: barramento paralelo, impacto -------------------------------

static func arm_right_parts() -> Array[PartData]:
	var out: Array[PartData] = []

	var psu := PartData.new()
	psu.id = &"arm_r_psu"
	psu.display_name = "Canhao de Fonte \"500W Generica\""
	psu.slot = PartData.Slot.ARM_RIGHT
	psu.watts = 52
	psu.heat_per_shot = 22.0
	psu.fire_rate = 0.7
	psu.automatic = false
	psu.color = Color("#4A4F52")
	# GDD 4.5: ao primeiro quique se divide em 3 sub-bolas com 50% do dano.
	psu.projectile = _proj({
		"id": &"plasma_ball", "speed": 520.0, "radius": 16.0, "max_bounces": 4,
		"restitution": 1.0, "ttl": 6.0, "damage": 90.0,
		"base_color": Color("#8CFF1A"), "stretch": 1.0,
	})
	var split := BhvSplitOnBounce.new()
	split.split_count = 3
	split.damage_ratio = 0.5
	split.only_on_bounce_index = 1
	psu.behaviors.append(split)
	out.append(psu)

	var bazooka := PartData.new()
	bazooka.id = &"arm_r_pipe_bazooka"
	bazooka.display_name = "Bazuca de Cano de Pia \"Encanamento Livre\""
	bazooka.slot = PartData.Slot.ARM_RIGHT
	bazooka.watts = 50
	bazooka.heat_per_shot = 20.0
	bazooka.fire_rate = 0.8
	bazooka.automatic = false
	bazooka.color = Color("#8A4B2A")
	# GDD 4.5: quica 5 vezes e ganha +40% de dano por quique, acumulando com o
	# multiplicador global. 70 de dano, ate 260 no quinto quique.
	bazooka.projectile = _proj({
		"id": &"pipe_rocket", "speed": 320.0, "radius": 14.0, "max_bounces": 5,
		"restitution": 1.0, "ttl": 8.0, "damage": 70.0,
		"base_color": Color("#FFD400"), "stretch": 1.9,
	})
	var ramp := BhvDamageRampOnBounce.new()
	ramp.damage_add_per_bounce = 0.40
	bazooka.behaviors.append(ramp)
	out.append(bazooka)

	var hdd := PartData.new()
	hdd.id = &"arm_r_hdd"
	hdd.display_name = "Lancador de HD \"Disco Rigido Voador\""
	hdd.slot = PartData.Slot.ARM_RIGHT
	hdd.watts = 46
	hdd.heat_per_shot = 16.0
	hdd.fire_rate = 1.4
	hdd.automatic = false
	hdd.color = Color("#4A4F52")
	# GDD 4.5 diz "quica infinitamente por 6 segundos". Conforme GDD_ADENDOS A.4,
	# isso vira: o contador nao mata o projetil, o TTL limita. Assim o custo de
	# simulacao continua previsivel e o benchmark noturno continua valendo.
	hdd.projectile = _proj({
		"id": &"hdd_saw", "speed": 700.0, "radius": 13.0, "max_bounces": 12,
		"infinite_bounces": true, "restitution": 1.0, "ttl": 6.0, "damage": 42.0,
		"base_color": Color("#7B2FBF"), "stretch": 1.0,
	})
	out.append(hdd)

	return out


# --- CABECA -------------------------------------------------------------------

static func head_parts() -> Array[PartData]:
	var out: Array[PartData] = []

	var toaster := PartData.new()
	toaster.id = &"head_toaster"
	toaster.display_name = "Torradeira \"Cuspe-Torrada\""
	toaster.slot = PartData.Slot.HEAD
	toaster.watts = 18
	toaster.heat_per_shot = 5.0
	toaster.fire_rate = 1.0 / 3.5   # recarga de 3,5 s
	toaster.automatic = false
	toaster.color = Color("#D6C9A8")
	# GDD 4.3: lanca 3 torradas em leque de 40 graus, quica 3 vezes.
	toaster.projectile = _proj({
		"id": &"toast", "speed": 620.0, "radius": 11.0, "max_bounces": 4,
		"restitution": 1.0, "ttl": 5.0, "damage": 22.0,
		"base_color": Color("#8A4B2A"), "stretch": 1.3,
	})
	var spread := BhvSpread.new()
	spread.count = 3
	spread.angle_deg = 40.0
	toaster.behaviors.append(spread)
	out.append(toaster)

	# A prova da arquitetura, citada no GDD 7.3: a TORRADA TESLA e literalmente
	# a Torradeira com BhvChainLightning acrescentado ao array e o spread mudado
	# de 3 para 5. Zero codigo novo. Um designer faz isso em dez minutos.
	var tesla := PartData.new()
	tesla.id = &"head_toaster_tesla"
	tesla.display_name = "TORRADA TESLA"
	tesla.slot = PartData.Slot.HEAD
	tesla.rarity = PartData.Rarity.RARE
	tesla.watts = 26
	tesla.heat_per_shot = 7.0
	tesla.fire_rate = 1.0 / 3.5
	tesla.automatic = false
	tesla.color = Color("#FFD400")
	tesla.projectile = toaster.projectile
	var spread5 := BhvSpread.new()
	spread5.count = 5
	spread5.angle_deg = 46.0
	var chain := BhvChainLightning.new()
	chain.jumps = 3
	chain.range_px = 250.0
	chain.damage_ratio = 0.55
	chain.trigger_on_bounce = true
	tesla.behaviors.append(spread5)
	tesla.behaviors.append(chain)
	out.append(tesla)

	return out


# --- CHASSI E PERNAS ----------------------------------------------------------

static func chassis_parts() -> Array[PartData]:
	var out: Array[PartData] = []

	var springs := PartData.new()
	springs.id = &"chassis_springs"
	springs.display_name = "Molas de Sofa \"Boing Boing\""
	springs.slot = PartData.Slot.CHASSIS
	springs.watts = 22
	springs.hp = 85.0
	springs.move_speed = 312.0
	springs.dash_charges = 1
	springs.color = Color("#8A4B2A")
	out.append(springs)

	var treads := PartData.new()
	treads.id = &"chassis_treads"
	treads.display_name = "Esteiras de Trator de Brinquedo \"Lagarta Lenta\""
	treads.slot = PartData.Slot.CHASSIS
	treads.watts = 30
	treads.hp = 240.0
	treads.move_speed = 195.0
	treads.dash_charges = 1
	treads.color = Color("#FF6B1A")
	out.append(treads)

	var casters := PartData.new()
	casters.id = &"chassis_casters"
	casters.display_name = "Rodinhas de Carrinho de Mercado \"Roda Bamba\""
	casters.slot = PartData.Slot.CHASSIS
	casters.watts = 26
	casters.hp = 70.0
	casters.move_speed = 377.0
	casters.dash_charges = 1
	casters.color = Color("#4A4F52")
	out.append(casters)

	var mannequin := PartData.new()
	mannequin.id = &"chassis_mannequin"
	mannequin.display_name = "Pernas de Manequim \"Passo de Modelo\""
	mannequin.slot = PartData.Slot.CHASSIS
	mannequin.watts = 28
	mannequin.hp = 95.0
	mannequin.move_speed = 268.0
	# GDD 4.6: tres cargas de dash, com recarga de 0,9 s cada.
	mannequin.dash_charges = 3
	mannequin.color = Color("#F5F0E1")
	out.append(mannequin)

	return out


# --- CPUs ---------------------------------------------------------------------

static func cpus() -> Array[CpuData]:
	var out: Array[CpuData] = []

	# GDD_ADENDOS A.5: os 100 W da tabela do GDD 4.1.3 nao comportam NENHUMA
	# combinacao de quatro pecas das tabelas 4.3 a 4.6; a mais barata possivel
	# custa 101 W. Com 100 W o jogador comeca a primeira run permanentemente em
	# Subvoltagem, que e uma penalidade, nao uma escolha. Os TDPs abaixo seguem
	# a regra proposta: no minimo 1,15 vez a build mais barata legal.
	var pentiun := CpuData.new()
	pentiun.id = &"cpu_pentiun"
	pentiun.display_name = "Pentiun Ferrugem 100 MHz"
	pentiun.tdp = 120
	pentiun.heat_capacity = 100.0
	pentiun.heat_dissipation = 12.0
	pentiun.damage_mult = 1.10  # "mais 10% de dano geral por ser honesta"
	pentiun.description = "Nenhuma passiva. Mais 10% de dano por ser honesta."
	out.append(pentiun)

	var ryzin := CpuData.new()
	ryzin.id = &"cpu_ryzin"
	ryzin.display_name = "Ryzin 9 Frito (Overclock)"
	ryzin.tdp = 116
	ryzin.heat_capacity = 80.0
	ryzin.heat_dissipation = 7.0
	ryzin.fire_rate_mult = 1.35
	ryzin.projectile_speed_mult = 1.20
	ryzin.description = "Mais 35% de cadencia e 20% de velocidade. Dissipacao pessima."
	out.append(ryzin)

	var gpu := CpuData.new()
	gpu.id = &"cpu_gpu_in_socket"
	gpu.display_name = "Placa de Video Enfiada no Soquete"
	gpu.tdp = 116
	gpu.heat_capacity = 70.0
	gpu.heat_dissipation = 6.0
	gpu.bonus_bounces = 2
	gpu.projectile_speed_mult = 1.40
	gpu.heat_gen_mult = 2.0
	gpu.description = "Nao deveria funcionar. Mais 2 quiques e 40% de velocidade. Calor dobrado."
	out.append(gpu)

	return out


static func all_parts() -> Array[PartData]:
	var out: Array[PartData] = []
	out.append_array(arm_left_parts())
	out.append_array(arm_right_parts())
	out.append_array(head_parts())
	out.append_array(chassis_parts())
	return out


## Sorteia uma vitrine de pecas para a Bancada.
## Considera bonus de raridade (ex: da arvore de Sorte).
static func roll_shop_offer(count: int, rare_bonus: float = 0.0) -> Array[PartData]:
	var pool := all_parts()
	var rng := GameRng.stream(GameRng.Stream.DROPS)
	var chosen: Array[PartData] = []
	var available := pool.duplicate()

	for i in count:
		if available.is_empty():
			available = pool.duplicate()
		var idx := rng.randi_range(0, available.size() - 1)
		var base_part: PartData = available[idx]
		available.remove_at(idx)

		var item: PartData = base_part.clone()

		# Chance de raridade aumentada conforme GDD e Sorte
		var roll := rng.randf() + rare_bonus
		if roll > 0.95:
			item.rarity = PartData.Rarity.LEGENDARY
		elif roll > 0.78:
			item.rarity = PartData.Rarity.RARE
		elif roll > 0.45:
			item.rarity = PartData.Rarity.UNCOMMON
		else:
			item.rarity = PartData.Rarity.COMMON

		chosen.append(item)
	return chosen

