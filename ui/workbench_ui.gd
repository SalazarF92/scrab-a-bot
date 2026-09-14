class_name WorkbenchUI
extends Control
## A Bancada de Trabalho entre setores. GDD 4.7 e GDD_ADENDOS B.1 / B.3.
## Vitrine de pecas, evolucao de tier, fusao de duplicata, reroll e solda de reparo.
##
## Fusao de duplicata, GDD 4.7.1: "Pegar a mesma peca duas vezes a promove um
## nivel." Comprar a peca que ja esta equipada sobe o tier. Antes a compra trocava
## a peca e o tier acumulado era perdido.
## Troca, GDD_ADENDOS B.3: substituir por uma peca diferente devolve 50% do preco
## da peca que sai.
##
## So recebe teclado com foco, e so existe com o jogo pausado. Ver
## scenes/prototype.gd.

signal proceed_requested

const REPAIR_COST := 120
const REPAIR_PERCENT := 0.35
const BASE_REROLL_COST := 60
const REROLL_INCREMENT := 40
const BATTERY_MODULE := &"car_battery"

const SLOT_LABELS := {
	PartData.Slot.ARM_LEFT: "Braço E",
	PartData.Slot.ARM_RIGHT: "Braço D",
	PartData.Slot.HEAD: "Cabeça",
	PartData.Slot.CHASSIS: "Chassi",
}

var robot: Robot
var sector: int = 1

var _offers: Array[PartData] = []
var _rerolls_used: int = 0
var _repair_used: bool = false
var _font: Font
var _buttons: Array[Dictionary] = [] # {"rect": Rect2, "action": String, "payload": Variant}
var inventory := FusionInventory.new()
var _recipes: Array[FusionRecipe] = PartLibrary.fusion_recipes()
## Catalogo de modulos (GDD 4.7.2 e 4.7.3): a navegacao da Bancada percorre
## modulos; a receita, quando existe, aparece junto do modulo que a exige.
var _modules: Array[StringName] = PartLibrary.graft_modules()
var _selected_module_idx: int = 0
var _graft_target: int = PartData.Slot.ARM_LEFT
var _status: String = ""
var _fusion_time: float = 0.0
var _fusion_name: String = ""
var _pulse_time: float = 0.0


func _ready() -> void:
	# A celebracao de fusao e a UI avancam mesmo com o combate pausado.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_font = ThemeDB.fallback_font
	visibility_changed.connect(_on_visibility_changed)


func _process(delta: float) -> void:
	if not visible:
		return
	_pulse_time += delta
	_fusion_time = maxf(0.0, _fusion_time - delta)
	queue_redraw()


func reset_for_run() -> void:
	inventory.clear()
	_offers.clear()
	_rerolls_used = 0
	_repair_used = false
	_status = ""
	_fusion_time = 0.0
	_selected_module_idx = 0
	_graft_target = PartData.Slot.ARM_LEFT


func _on_visibility_changed() -> void:
	if visible:
		grab_focus.call_deferred()


func open_workbench(p_sector: int) -> void:
	sector = p_sector
	_rerolls_used = 0
	_repair_used = false
	_selected_module_idx = 0
	for r_idx in _recipes.size():
		if recipe_available(r_idx):
			_selected_module_idx = maxi(0, _modules.find(_recipes[r_idx].module_id))
			break
	_status = "Pecas repetidas sobem o tier. Trocas devolvem metade do valor, incluindo o tier."
	_roll_offers()
	visible = true
	queue_redraw()


func _roll_offers() -> void:
	var count := MetaManager.get_workbench_options_count()
	var rare_bonus: float = 0.15 if MetaManager.get_upgrade_level("sorte") >= 2 else 0.0
	# Bitcorn Rig: "+25% de chance de peca rara".
	if robot != null and robot.cpu != null:
		rare_bonus += robot.cpu.rare_chance_bonus
	_offers = PartLibrary.roll_shop_offer(count, sector, rare_bonus)


func _reroll_cost() -> int:
	var cost := BASE_REROLL_COST + _rerolls_used * REROLL_INCREMENT
	if MetaManager.get_upgrade_level("sorte") >= 3:
		cost = int(round(float(cost) * 0.75)) # 25% desconto
	return cost


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		grab_focus()
		var mpos: Vector2 = event.position
		for btn in _buttons:
			if (btn["rect"] as Rect2).has_point(mpos):
				_handle_button_action(btn["action"], btn.get("payload"))
				accept_event()
				return

	if event is InputEventKey and event.pressed and not event.echo:
		var handled := true
		match event.keycode:
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				_proceed()
			KEY_R:
				_try_reroll()
			KEY_H:
				_try_repair()
			KEY_LEFT, KEY_Z:
				_cycle_module(-1)
			KEY_RIGHT, KEY_X:
				_cycle_module(1)
			KEY_M:
				_try_buy_module(_selected_module())
			KEY_F:
				_try_fuse_recipe(_selected_recipe_index())
			KEY_DELETE:
				_try_sell_module(_selected_module())
			KEY_G:
				_try_graft(_selected_module(), _graft_target)
			KEY_T:
				_cycle_graft_target()
			KEY_1:
				_try_buy_offer(0)
			KEY_2:
				_try_buy_offer(1)
			KEY_3:
				_try_buy_offer(2)
			KEY_4:
				_try_buy_offer(3)
			_:
				handled = false
		if handled:
			accept_event()


func _handle_button_action(action: String, payload: Variant) -> void:
	match action:
		"proceed":
			_proceed()
		"repair":
			_try_repair()
		"reroll":
			_try_reroll()
		"prev_recipe":
			_cycle_module(-1)
		"next_recipe":
			_cycle_module(1)
		"graft_module":
			_try_graft(StringName(payload), _graft_target)
		"buy_offer":
			_try_buy_offer(int(payload))
		"upgrade_slot":
			_try_upgrade_slot(int(payload))
		"buy_module":
			_try_buy_module(StringName(payload))
		"sell_module":
			_try_sell_module(StringName(payload))
		"fuse_recipe":
			_try_fuse_recipe(int(payload))


func _proceed() -> void:
	visible = false
	proceed_requested.emit()


func _try_repair() -> void:
	if _repair_used or robot == null:
		return
	if robot.hp >= robot.max_hp:
		return
	if not MetaManager.spend_scrap(REPAIR_COST):
		Sfx.play("projectile_plop", -4.0)
		return

	_repair_used = true
	robot.heal(robot.max_hp * REPAIR_PERCENT)
	Sfx.play_varied("fire_heavy", -4.0)
	queue_redraw()


func _try_reroll() -> void:
	if not MetaManager.spend_scrap(_reroll_cost()):
		Sfx.play("projectile_plop", -4.0)
		return
	_rerolls_used += 1
	_roll_offers()
	Sfx.play_varied("dash", -6.0)
	queue_redraw()


## O que comprar esta oferta faria: equipar num slot vazio, fundir com a peca
## igual equipada, trocar por uma diferente, ou nada se a igual ja esta no tier IV.
func offer_mode(part: PartData) -> StringName:
	if robot == null:
		return &"equip"
	var current: PartData = robot.equipped.get(part.slot)
	if current == null:
		return &"equip"
	if current.id == part.id:
		return &"maxed" if current.fusion_level >= 3 else &"fuse"
	return &"swap"


func _try_buy_offer(idx: int) -> void:
	if idx < 0 or idx >= _offers.size() or robot == null:
		return
	var part: PartData = _offers[idx]
	var mode := offer_mode(part)
	if mode == &"maxed" or not MetaManager.spend_scrap(part.base_price()):
		Sfx.play("projectile_plop", -4.0)
		return

	var current: PartData = robot.equipped.get(part.slot)
	match mode:
		&"fuse":
			var upgraded := current.clone()
			upgraded.fusion_level += 1
			if part.rarity > upgraded.rarity:
				upgraded.rarity = part.rarity
			robot.equip(upgraded)
			_celebrate_fusion("%s - TIER %s" % [upgraded.display_name, upgraded.fusion_roman()])
			Sfx.play_varied("fire_heavy", 4.0)
		&"swap":
			MetaManager.refund_scrap(current.sell_value())
			robot.equip(part.clone())
			Sfx.play_varied("fire_heavy", 0.0)
		_:
			robot.equip(part.clone())
			Sfx.play_varied("fire_heavy", 0.0)

	_offers.remove_at(idx)
	queue_redraw()


func _try_upgrade_slot(slot: int) -> void:
	if robot == null:
		return
	var part: PartData = robot.equipped.get(slot)
	if part == null or part.fusion_level >= 3:
		return
	var cost: int = part.upgrade_cost()
	if cost < 0 or not MetaManager.spend_scrap(cost):
		Sfx.play("projectile_plop", -4.0)
		return

	var upgraded := part.clone()
	upgraded.fusion_level += 1
	robot.equip(upgraded) # reaplica e recalcula stats sem alterar a peca-modelo
	_celebrate_fusion("%s - TIER %s" % [upgraded.display_name, upgraded.fusion_roman()])
	Sfx.play_varied("fire_heavy", 2.0)
	queue_redraw()


func _try_buy_module(module_id: StringName) -> void:
	var cost := PartLibrary.fusion_module_price(module_id)
	if cost < 0 or robot == null:
		return
	if inventory.is_full():
		_status = "Mochila cheia: funda uma receita ou venda um modulo para liberar espaco."
		return
	if not MetaManager.spend_scrap(cost):
		_status = "Falta Sucata para comprar o modulo."
		Sfx.play("projectile_plop", -4.0)
		return
	inventory.add(module_id)
	_status = "%s na mochila. Equipe %s e pressione F para fundir." % [PartLibrary.fusion_module_name(module_id), _recipe_source_name(_recipe_for_module(module_id))]
	Sfx.play_varied("dash", -6.0)
	queue_redraw()


func _try_sell_module(module_id: StringName) -> void:
	var price := PartLibrary.fusion_module_price(module_id)
	if price < 0 or not inventory.consume(module_id):
		return
	var refund := int(floor(float(price) * 0.5))
	MetaManager.refund_scrap(refund)
	_status = "Modulo vendido: +%d Sucata. Um espaco livre na mochila." % refund
	queue_redraw()


## Nome da peca-fonte de uma receita, para as mensagens nao ficarem presas
## na Torradeira quando a receita selecionada e outra.
func _recipe_source_name(recipe: FusionRecipe) -> String:
	if recipe == null:
		return "a peca certa"
	var source := PartLibrary.part_by_id(recipe.source_part_id)
	return source.display_name if source != null else str(recipe.source_part_id)


func _recipe_for_module(module_id: StringName) -> FusionRecipe:
	for r in _recipes:
		if r.module_id == module_id:
			return r
	return null


func recipe_available(index: int) -> bool:
	if robot == null or index < 0 or index >= _recipes.size():
		return false
	var recipe := _recipes[index]
	if recipe.result_part == null:
		return false
	var source: PartData = robot.equipped.get(recipe.result_part.slot)
	return recipe.accepts(source) and inventory.count(recipe.module_id) > 0


func _try_fuse_recipe(index: int) -> void:
	if not recipe_available(index):
		var missing: FusionRecipe = _recipes[index] if index >= 0 and index < _recipes.size() else null
		if missing != null:
			_status = "Receita: %s equipada + 1 %s na mochila." % [_recipe_source_name(missing), PartLibrary.fusion_module_name(missing.module_id)]
		Sfx.play("projectile_plop", -4.0)
		return
	var recipe := _recipes[index]
	var source: PartData = robot.equipped.get(recipe.result_part.slot)
	var result := recipe.craft(source)
	if result == null or not inventory.consume(recipe.module_id):
		return
	robot.equip(result)
	_status = "%s equipada! Bateria consumida; tier preservado; sem taxa de fusao." % result.display_name
	_celebrate_fusion(result.display_name)
	Sfx.play_varied("fire_heavy", 4.0)
	queue_redraw()


func _celebrate_fusion(part_name: String) -> void:
	_fusion_name = part_name
	_fusion_time = 2.5


# --- Desenho da Interface ---

func _draw() -> void:
	_buttons.clear()
	var vp := get_viewport_rect().size

	draw_rect(Rect2(Vector2.ZERO, vp), Color("#120E0D"))
	var backdrop := ArtDirector.texture(ArtDirector.BACKGROUND_PATH)
	if backdrop:
		draw_texture_rect(backdrop, Rect2(Vector2.ZERO, vp), false, Color(0.4, 0.4, 0.4))

	_draw_header(vp)
	_draw_equipped_section(vp)
	_draw_shop_section(vp)
	_draw_recipe_section(vp)
	_draw_repair_and_footer(vp)


func _draw_header(vp: Vector2) -> void:
	draw_string(_font, Vector2(40, 48), "BANCADA DE TRABALHO DO FERRO-VELHO", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#F5F0E1"))
	var sub := "Setor %d Limpo • \"Monte antes que a próxima onda desmonte você\"" % sector
	draw_string(_font, Vector2(40, 74), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.5))

	var info_box := Rect2(vp.x - 420, 20, 380, 64)
	draw_rect(info_box, Color("#201712"))
	draw_rect(info_box, Color("#FFD400"), false, 2.0)

	draw_string(_font, Vector2(info_box.position.x + 16, info_box.position.y + 28), "SUCATA: %d" % MetaManager.current_scrap, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#FFD400"))

	if robot != null:
		var hp_text := "HP: %d / %d   ENERGIA: %d / %d W" % [
			int(round(robot.hp)), int(round(robot.max_hp)), robot.watts_used, robot.total_tdp()
		]
		draw_string(_font, Vector2(info_box.position.x + 16, info_box.position.y + 52), hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#8CFF1A") if not robot.is_undervolt() else Color("#FF2D95"))


func _draw_equipped_section(vp: Vector2) -> void:
	var section_w := (vp.x - 100.0) * 0.44
	var panel := Rect2(40, 100, section_w, vp.y - 430)
	_draw_panel(panel, Color("#1A1412"), Color("#8A4B2A"))

	draw_string(_font, Vector2(56, 130), "ROBÔ EQUIPADO & EVOLUÇÃO (+TIER)", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#FFD400"))

	var slots := [
		[PartData.Slot.ARM_LEFT, "Braço E (Serial)"],
		[PartData.Slot.ARM_RIGHT, "Braço D (Paralelo)"],
		[PartData.Slot.HEAD, "Cabeça"],
		[PartData.Slot.CHASSIS, "Chassi & Pernas"],
	]

	var slot_y := 150.0
	var card_h := (panel.size.y - 70.0) / 4.0 - 8.0

	for s in slots:
		var slot_id: int = s[0]
		var slot_name: String = s[1]
		var part: PartData = robot.equipped.get(slot_id) if robot else null
		var card_rect := Rect2(56, slot_y, panel.size.x - 32, card_h)

		draw_rect(card_rect, Color("#241B17"))
		draw_rect(card_rect, Color(1, 1, 1, 0.15), false, 1.0)

		if part != null:
			draw_rect(Rect2(card_rect.position.x + 8, card_rect.position.y + 8, 12, card_rect.size.y - 16), part.color)

			ArtDirector.part_icon(self, part, Rect2(card_rect.position + Vector2(20, 6), Vector2(84, card_rect.size.y - 12)))

			var title := "%s: %s" % [slot_name, part.display_name]
			_draw_ellipsis(card_rect.position + Vector2(112, 25), title, card_rect.size.x - 266, 18, Color.WHITE)

			var tier_str := "Tier %s (+%.0f%% poder)  •  %s  •  %dW" % [
				part.fusion_roman(), (part.fusion_mult() - 1.0) * 100.0, part.rarity_name(), part.watts
			]
			if slot_id == PartData.Slot.CHASSIS:
				tier_str += "  •  rebatedor x%.2f" % part.restitution
			_draw_ellipsis(card_rect.position + Vector2(112, 49), tier_str, card_rect.size.x - 266, 16, part.rarity_color())
			var trade_line := "Troca devolve %d Sucata" % part.sell_value()
			if not part.grafts.is_empty():
				var names := PackedStringArray()
				for g in part.grafts:
					names.append(PartLibrary.fusion_module_name(g))
				trade_line += "  •  Enxertos: " + ", ".join(names)
			_draw_ellipsis(card_rect.position + Vector2(112, 72), trade_line, card_rect.size.x - 266, 15, Color("#BCA68D"))

			var up_cost: int = part.upgrade_cost()
			var up_btn := Rect2(card_rect.position.x + card_rect.size.x - 140, card_rect.position.y + 10, 130, card_rect.size.y - 20)

			if up_cost > 0:
				var can_up := MetaManager.current_scrap >= up_cost
				draw_rect(up_btn, Color("#8CFF1A") if can_up else Color("#442222"))
				draw_rect(up_btn, Color.WHITE, false, 1.0)
				draw_string(_font, up_btn.position + Vector2(0, up_btn.size.y * 0.5 + 4), "Evoluir (%d)" % up_cost, HORIZONTAL_ALIGNMENT_CENTER, up_btn.size.x, 12, Color.BLACK if can_up else Color.WHITE)
				_buttons.append({"rect": up_btn, "action": "upgrade_slot", "payload": slot_id})
			else:
				draw_string(_font, up_btn.position + Vector2(0, up_btn.size.y * 0.5 + 4), "TIER MÁXIMO", HORIZONTAL_ALIGNMENT_CENTER, up_btn.size.x, 12, Color("#8CFF1A"))
		else:
			draw_string(_font, card_rect.position + Vector2(20, card_rect.size.y * 0.5 + 4), "%s: (Vazio)" % slot_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.4))

		slot_y += card_h + 8.0


func _draw_shop_section(vp: Vector2) -> void:
	var left_w := (vp.x - 100.0) * 0.44
	var section_x := 40.0 + left_w + 20.0
	var section_w := vp.x - section_x - 40.0
	var panel := Rect2(section_x, 100, section_w, vp.y - 430)
	_draw_panel(panel, Color("#1A1412"), Color("#22E0FF").darkened(0.5))

	draw_string(_font, Vector2(section_x + 16, 130), "VITRINE DE PEÇAS DISPONÍVEIS", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#22E0FF"))

	var offer_y := 150.0
	var n_offers := _offers.size()
	var card_h := (panel.size.y - 120.0) / maxf(float(n_offers), 1.0) - 8.0

	for i in n_offers:
		var part: PartData = _offers[i]
		var card := Rect2(section_x + 16, offer_y, panel.size.x - 32, card_h)

		draw_rect(card, Color("#221A16"))
		draw_rect(card, part.rarity_color().darkened(0.5), false, 1.0)

		ArtDirector.part_icon(self, part, Rect2(card.position + Vector2(9, 9), Vector2(86, card.size.y - 18)))
		var header_text := "[%d] [%s] %s • %s" % [i + 1, SLOT_LABELS.get(part.slot, "?"), part.display_name, part.rarity_name()]
		_draw_ellipsis(card.position + Vector2(105, 25), header_text, card.size.x - 304, 18, part.rarity_color())

		var stats_text := "Consumo: %dW  •  Calor: %.1f  •  Cadência: %.1f/s" % [part.watts, part.heat_per_shot, part.fire_rate]
		if part.projectile != null:
			stats_text += "  •  Dano: %.0f  •  Quiques: %d" % [part.projectile.damage, part.projectile.max_bounces]
		elif part.slot == PartData.Slot.CHASSIS:
			stats_text = "Consumo: %dW  •  HP: %.0f  •  Velocidade: %.0f  •  Rebatedor x%.2f" % [part.watts, part.hp, part.move_speed, part.restitution]
		_draw_ellipsis(card.position + Vector2(105, 50), stats_text, card.size.x - 304, 16, Color(1, 1, 1, 0.7))

		var price: int = part.base_price()
		var mode := offer_mode(part)
		var can_buy := MetaManager.current_scrap >= price and mode != &"maxed"
		var buy_btn := Rect2(card.position.x + card.size.x - 190, card.position.y + 10, 175, card.size.y - 20)
		var label := "Equipar (%d)" % price
		var fill := Color("#22E0FF")
		match mode:
			&"fuse":
				label = "FUNDIR +TIER (%d)" % price
				fill = Color("#FF2D95")
			&"maxed":
				label = "JÁ NO TIER IV"
			&"swap":
				var current: PartData = robot.equipped.get(part.slot)
				label = "Trocar (%d, volta %d)" % [price, current.sell_value()]

		draw_rect(buy_btn, fill if can_buy else Color("#442222"))
		draw_rect(buy_btn, Color.WHITE, false, 1.0)
		draw_string(_font, buy_btn.position + Vector2(0, buy_btn.size.y * 0.5 + 4), label, HORIZONTAL_ALIGNMENT_CENTER, buy_btn.size.x, 12, Color.BLACK if can_buy else Color.WHITE)
		_buttons.append({"rect": buy_btn, "action": "buy_offer", "payload": i})

		offer_y += card_h + 8.0

	var reroll_cost := _reroll_cost()
	var can_reroll := MetaManager.current_scrap >= reroll_cost
	var reroll_btn := Rect2(section_x + 16, panel.position.y + panel.size.y - 48, panel.size.x - 32, 38)
	draw_rect(reroll_btn, Color("#33241A") if can_reroll else Color("#221512"))
	draw_rect(reroll_btn, Color("#FFD400") if can_reroll else Color(1, 1, 1, 0.2), false, 1.0)
	draw_string(_font, reroll_btn.position + Vector2(0, 24), "REROLL DA VITRINE [R] (%d Sucata)" % reroll_cost, HORIZONTAL_ALIGNMENT_CENTER, reroll_btn.size.x, 14, Color("#FFD400") if can_reroll else Color(1, 1, 1, 0.3))
	_buttons.append({"rect": reroll_btn, "action": "reroll", "payload": null})


func _selected_module() -> StringName:
	if _modules.is_empty():
		return &""
	return _modules[clampi(_selected_module_idx, 0, _modules.size() - 1)]


## Indice em _recipes da receita que usa o modulo selecionado, ou -1.
func _selected_recipe_index() -> int:
	var module := _selected_module()
	for i in _recipes.size():
		if _recipes[i].module_id == module:
			return i
	return -1


func _cycle_module(direction: int) -> void:
	if _modules.is_empty():
		return
	_selected_module_idx = (_selected_module_idx + direction + _modules.size()) % _modules.size()
	queue_redraw()


func _cycle_graft_target() -> void:
	var order := [PartData.Slot.ARM_LEFT, PartData.Slot.ARM_RIGHT, PartData.Slot.HEAD, PartData.Slot.CHASSIS]
	_graft_target = order[(order.find(_graft_target) + 1) % order.size()]
	queue_redraw()


## GDD 4.7.3: enxerta o modulo na peca do slot alvo. Consome o modulo. Nao ha
## como remover um enxerto; trocar a peca na vitrine descarta os dela.
func _try_graft(module_id: StringName, slot: int) -> bool:
	if robot == null or not PartLibrary.GRAFTS.has(module_id):
		return false
	var part: PartData = robot.equipped.get(slot)
	if part == null:
		_status = "Nao ha peca no slot %s para enxertar." % SLOT_LABELS.get(slot, "?")
		return false
	if part.grafts.size() >= robot.graft_slots():
		_status = "%s ja tem %d enxertos, o maximo desta CPU." % [part.display_name, part.grafts.size()]
		Sfx.play("projectile_plop", -4.0)
		return false
	if inventory.count(module_id) <= 0:
		_status = "Compre %s antes de enxertar." % PartLibrary.fusion_module_name(module_id)
		return false
	if not inventory.consume(module_id):
		return false
	part.grafts.append(module_id)
	robot.call("_recompute_stats")
	_status = "%s enxertada em %s. %s" % [PartLibrary.fusion_module_name(module_id), part.display_name, PartLibrary.fusion_module_desc(module_id)]
	_fusion_time = 1.2
	_fusion_name = "ENXERTO: " + PartLibrary.fusion_module_name(module_id)
	Sfx.play_varied("fire_heavy", 0.0)
	queue_redraw()
	return true


func _draw_recipe_section(vp: Vector2) -> void:
	var panel := Rect2(40, vp.y - 314, vp.x - 80, 194)
	var module := _selected_module()
	var recipe_idx := _selected_recipe_index()
	var recipe: FusionRecipe = _recipes[recipe_idx] if recipe_idx >= 0 else null
	var ready := recipe_idx >= 0 and recipe_available(recipe_idx)
	var accent := Color("#FFD400") if ready else Color("#8A4B2A")
	_draw_panel(panel, Color("#271D25"), accent)
	var left := panel.position + Vector2(20, 0)
	var module_count := inventory.count(module)
	var module_name := PartLibrary.fusion_module_name(module)
	var module_cost := PartLibrary.fusion_module_price(module)

	var title := "MODULOS DE SUCATA (%d/%d)  /  %s" % [_selected_module_idx + 1, _modules.size(), module_name]
	if ready:
		title = "RECEITA PRONTA!  %s" % recipe.result_part.display_name
	var btn_prev := Rect2(left + Vector2(0, 10), Vector2(28, 24))
	_draw_action_button(btn_prev, "<", "prev_recipe", null, true, Color("#D6C9A8"))
	draw_string(_font, left + Vector2(36, 30), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, accent if ready else Color("#F5F0E1"))
	var title_w := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var btn_next := Rect2(left + Vector2(48 + title_w, 10), Vector2(28, 24))
	_draw_action_button(btn_next, ">", "next_recipe", null, true, Color("#D6C9A8"))

	# Linha 1: a receita, se o modulo for ingrediente de alguma.
	if recipe != null:
		var source: PartData = robot.equipped.get(recipe.result_part.slot) if robot != null else null
		var source_ready := recipe.accepts(source)
		var source_name := _recipe_source_name(recipe)
		var ingredients := "RECEITA  %s %s  +  %s %s (%d)  =  %s" % [
			"[OK]" if source_ready else "[--]", source_name, "[OK]" if module_count > 0 else "[--]", module_name, module_count, recipe.result_part.display_name]
		_draw_ellipsis(left + Vector2(0, 58), ingredients, panel.size.x * 0.55 - 30, 15, Color("#D6C9A8"))
		_draw_ellipsis(left + Vector2(0, 80), recipe.description, panel.size.x * 0.55 - 30, 14, Color("#22E0FF"))
	else:
		draw_string(_font, left + Vector2(0, 58), "Sem receita: este modulo serve so de enxerto.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#BCA68D"))
	# Linha 2: o enxerto, sempre.
	var target: PartData = robot.equipped.get(_graft_target) if robot != null else null
	var target_name := target.display_name if target != null else "(vazio)"
	var target_grafts := target.grafts.size() if target != null else 0
	var slots_max := robot.graft_slots() if robot != null else PartData.MAX_GRAFTS
	_draw_ellipsis(left + Vector2(0, 104), "ENXERTO  %s   ->   [T] alvo: %s / %s (%d/%d)" % [
		PartLibrary.fusion_module_desc(module), SLOT_LABELS.get(_graft_target, "?"), target_name, target_grafts, slots_max],
		panel.size.x * 0.55 - 30, 14, Color("#8CFF1A"))
	var half_w := (panel.size.x * 0.55 - 40.0) * 0.5
	var craft_button := Rect2(left + Vector2(0, 122), Vector2(half_w - 6.0, 47))
	_draw_action_button(craft_button, "FUNDIR RECEITA [F]", "fuse_recipe", recipe_idx, ready, Color("#FFD400"))
	if ready:
		var pulse := 0.5 + 0.5 * sin(_pulse_time * 3.0)
		draw_rect(craft_button.grow(3), Color(1.0, 0.83, 0.0, 0.3 + pulse * 0.3), false, 2.0)
	var graft_button := Rect2(left + Vector2(half_w + 6.0, 122), Vector2(half_w - 6.0, 47))
	var can_graft := module_count > 0 and target != null and target_grafts < slots_max
	_draw_action_button(graft_button, "ENXERTAR [G]", "graft_module", module, can_graft, Color("#8CFF1A"))

	var stock_x := panel.position.x + panel.size.x * 0.55
	draw_line(Vector2(stock_x - 18, panel.position.y + 20), Vector2(stock_x - 18, panel.end.y - 20), Color("#665044"), 2.0)
	draw_string(_font, Vector2(stock_x, panel.position.y + 30), "MOCHILA DE MODULOS  %d / %d" % [inventory.size(), inventory.capacity], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#F5F0E1"))
	_draw_battery(Vector2(stock_x + 22, panel.position.y + 67))
	draw_string(_font, Vector2(stock_x + 58, panel.position.y + 61), "%s  /  %d Sucata" % [module_name, module_cost], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#FFD400"))
	var bag := ""
	for m in _modules:
		var n := inventory.count(m)
		if n > 0:
			bag += "%s x%d  " % [PartLibrary.fusion_module_name(m), n]
	_draw_ellipsis(Vector2(stock_x + 58, panel.position.y + 84), "Na mochila: " + (bag if bag != "" else "nada"), panel.end.x - stock_x - 80, 14, Color("#BCA68D"))
	var stock_w := panel.end.x - stock_x - 20
	var module_button := Rect2(stock_x, panel.position.y + 122, stock_w * 0.62, 47)
	var can_buy := robot != null and not inventory.is_full() and MetaManager.current_scrap >= module_cost
	_draw_action_button(module_button, "COMPRAR [M] (%d)" % module_cost, "buy_module", module, can_buy, Color("#22E0FF"))
	var sell_button := Rect2(module_button.end.x + 12, module_button.position.y, stock_w - module_button.size.x - 12, 47)
	_draw_action_button(sell_button, "VENDER [DEL] (+%d)" % (module_cost / 2), "sell_module", module, module_count > 0, Color("#D6C9A8"))

	# Celebracao local: sem flash de tela inteira e sem retomar o combate.
	if _fusion_time > 0.0:
		var progress := 1.0 - _fusion_time / 2.5
		draw_rect(panel.grow(4), Color(1.0, 0.83, 0.0, 1.0 - progress), false, 4.0)
		var banner := Rect2(56, 82, vp.x - 112, 26)
		draw_rect(banner, Color("#FFD400"))
		_draw_ellipsis(banner.position + Vector2(10, 19), "SOLDA CONCLUIDA!  " + _fusion_name, banner.size.x - 20, 17, Color("#1A0F14"))
		if not Vfx.reduced_flashes:
			for i in 12:
				var direction := Vector2.from_angle(float(i) * TAU / 12.0)
				var center := craft_button.get_center()
				var offset := direction * (24.0 + progress * 75.0)
				draw_line(center + offset, center + offset + direction * 9.0, Color(1.0, 0.83, 0.0, 1.0 - progress), 2.0)


func _draw_panel(rect: Rect2, fill: Color, border: Color) -> void:
	draw_rect(Rect2(rect.position + Vector2(5, 7), rect.size), Color("#09080C"))
	draw_rect(rect, fill)
	draw_rect(rect, Color("#08070B"), false, 5.0)
	draw_rect(rect.grow(-3), border, false, 2.0)
	for corner in [rect.position + Vector2(8, 8), rect.position + Vector2(rect.size.x - 8, 8), rect.end - Vector2(8, 8), rect.position + Vector2(8, rect.size.y - 8)]:
		draw_circle(corner, 3.0, Color("#D6C9A8"))
		draw_line(corner - Vector2(2, 1), corner + Vector2(2, 1), Color("#1A0F14"), 1.0)


func _draw_action_button(rect: Rect2, label: String, action: String, payload: Variant, enabled: bool, color: Color) -> void:
	draw_rect(Rect2(rect.position + Vector2(3, 4), rect.size), Color("#09080C"))
	draw_rect(rect, color if enabled else Color("#3B3031"))
	draw_rect(rect, Color("#09080C"), false, 3.0)
	draw_string(_font, rect.position + Vector2(0, rect.size.y * 0.5 + 6), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 17, Color("#1A0F14") if enabled else Color("#A2938C"))
	_buttons.append({"rect": rect, "action": action, "payload": payload})


func _draw_ellipsis(at: Vector2, text: String, width: float, font_size: int, color: Color) -> void:
	var fitted := text
	if _font.get_string_size(fitted, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		while not fitted.is_empty() and _font.get_string_size(fitted + "...", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
			fitted = fitted.left(fitted.length() - 1)
		fitted += "..."
	draw_string(_font, at, fitted, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)


func _draw_battery(at: Vector2) -> void:
	ArtDirector.cell(self, ArtDirector.PARTS_PATH, 13, 4, Rect2(at - Vector2(27, 29), Vector2(54, 58)))


func _draw_repair_and_footer(vp: Vector2) -> void:
	_draw_ellipsis(Vector2(40, vp.y - 98), _status, vp.x - 80, 16, Color("#D6C9A8"))
	var can_repair: bool = not _repair_used and robot != null and robot.hp < robot.max_hp and MetaManager.current_scrap >= REPAIR_COST
	var repair_btn := Rect2(40, vp.y - 82, 280, 52)

	draw_rect(repair_btn, Color("#225522") if can_repair else Color("#221512"))
	draw_rect(repair_btn, Color("#8CFF1A") if can_repair else Color(1, 1, 1, 0.2), false, 1.0)

	var repair_label := "SOLDA DE REPARO [H] (%d)" % REPAIR_COST
	if _repair_used:
		repair_label = "SOLDA: JÁ UTILIZADA"
	elif robot != null and robot.hp >= robot.max_hp:
		repair_label = "SOLDA: HP CHEIO"

	draw_string(_font, repair_btn.position + Vector2(0, 24), repair_label, HORIZONTAL_ALIGNMENT_CENTER, repair_btn.size.x, 13, Color("#8CFF1A") if can_repair else Color(1, 1, 1, 0.4))
	draw_string(_font, repair_btn.position + Vector2(0, 42), "Recupera 35% do HP máximo", HORIZONTAL_ALIGNMENT_CENTER, repair_btn.size.x, 11, Color(1, 1, 1, 0.6))
	_buttons.append({"rect": repair_btn, "action": "repair", "payload": null})

	var next_btn := Rect2(vp.x - 440, vp.y - 82, 400, 52)
	draw_rect(next_btn, Color("#8CFF1A"))
	draw_rect(next_btn, Color("#F5F0E1"), false, 2.0)
	draw_string(_font, next_btn.position + Vector2(0, 32), "PROSSEGUIR PRO SETOR %d [ ESPAÇO ]" % (sector + 1), HORIZONTAL_ALIGNMENT_CENTER, next_btn.size.x, 18, Color("#1A0F14"))
	_buttons.append({"rect": next_btn, "action": "proceed", "payload": null})
