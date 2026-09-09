class_name WorkbenchUI
extends Control
## A Bancada de Trabalho entre salas/setores. GDD 4.7 e GDD_ADENDOS B.1 / B.3.
## Permite comprar pecas novas, evoluir pecas equipadas (+Tier de fusao), reroll e solda de reparo.

signal proceed_requested

const REPAIR_COST := 120
const REPAIR_PERCENT := 0.35
const BASE_REROLL_COST := 60
const REROLL_INCREMENT := 30

var robot: Robot
var sector: int = 1

var _offers: Array[PartData] = []
var _rerolls_used: int = 0
var _repair_used: bool = false
var _font: Font
var _buttons: Array[Dictionary] = [] # {"rect": Rect2, "action": String, "payload": Variant}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = ThemeDB.fallback_font


func open_workbench(p_sector: int) -> void:
	sector = p_sector
	_rerolls_used = 0
	_repair_used = false
	_roll_offers()
	visible = true
	queue_redraw()


func _roll_offers() -> void:
	var count := MetaManager.get_workbench_options_count()
	var rare_bonus: float = 0.15 if MetaManager.get_upgrade_level("sorte") >= 2 else 0.0
	_offers = PartLibrary.roll_shop_offer(count, rare_bonus)


func _reroll_cost() -> int:
	var cost := BASE_REROLL_COST + _rerolls_used * REROLL_INCREMENT
	if MetaManager.get_upgrade_level("sorte") >= 3:
		cost = int(round(float(cost) * 0.75)) # 25% desconto
	return cost


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mpos: Vector2 = event.position
		for btn in _buttons:
			if (btn["rect"] as Rect2).has_point(mpos):
				_handle_button_action(btn["action"], btn.get("payload"))
				accept_event()
				return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE, KEY_ENTER:
				_proceed()
				accept_event()
			KEY_R:
				_try_reroll()
				accept_event()
			KEY_H:
				_try_repair()
				accept_event()
			KEY_1:
				_try_buy_offer(0)
				accept_event()
			KEY_2:
				_try_buy_offer(1)
				accept_event()
			KEY_3:
				_try_buy_offer(2)
				accept_event()
			KEY_4:
				if _offers.size() >= 4:
					_try_buy_offer(3)
					accept_event()


func _handle_button_action(action: String, payload: Variant) -> void:
	match action:
		"proceed":
			_proceed()
		"repair":
			_try_repair()
		"reroll":
			_try_reroll()
		"buy_offer":
			_try_buy_offer(int(payload))
		"upgrade_slot":
			_try_upgrade_slot(int(payload))


func _proceed() -> void:
	visible = false
	proceed_requested.emit()


func _try_repair() -> void:
	if _repair_used or robot == null:
		return
	if robot.hp >= robot.max_hp:
		return
	if MetaManager.current_scrap < REPAIR_COST:
		Sfx.play("projectile_plop", -4.0)
		return

	MetaManager.current_scrap -= REPAIR_COST
	_repair_used = true
	var heal_amt := robot.max_hp * REPAIR_PERCENT
	robot.heal(heal_amt)
	Sfx.play_varied("fire_heavy", -4.0)
	CombatFeel.add_trauma(0.15)
	queue_redraw()


func _try_reroll() -> void:
	var cost := _reroll_cost()
	if MetaManager.current_scrap < cost:
		Sfx.play("projectile_plop", -4.0)
		return

	MetaManager.current_scrap -= cost
	_rerolls_used += 1
	_roll_offers()
	Sfx.play_varied("dash", -6.0)
	queue_redraw()


func _try_buy_offer(idx: int) -> void:
	if idx < 0 or idx >= _offers.size() or robot == null:
		return
	var part: PartData = _offers[idx]
	var cost: int = part.base_price()
	if MetaManager.current_scrap < cost:
		Sfx.play("projectile_plop", -4.0)
		return

	MetaManager.current_scrap -= cost
	robot.equip(part.clone())
	_offers.remove_at(idx)
	Sfx.play_varied("fire_heavy", 0.0)
	CombatFeel.add_trauma(0.2)
	queue_redraw()


func _try_upgrade_slot(slot: int) -> void:
	if robot == null:
		return
	var part: PartData = robot.equipped.get(slot)
	if part == null or part.fusion_level >= 3:
		return
	var cost: int = part.upgrade_cost()
	if cost < 0 or MetaManager.current_scrap < cost:
		Sfx.play("projectile_plop", -4.0)
		return

	MetaManager.current_scrap -= cost
	part.fusion_level += 1
	robot.equip(part) # reaplica e recalcula stats
	Sfx.play_varied("fire_heavy", 2.0)
	CombatFeel.add_trauma(0.25)
	queue_redraw()


# --- Desenho da Interface ---

func _draw() -> void:
	_buttons.clear()
	var vp := get_viewport_rect().size

	# Fundo da bancada com textura de chapa escura
	draw_rect(Rect2(Vector2.ZERO, vp), Color("#120E0D"))

	_draw_header(vp)
	_draw_equipped_section(vp)
	_draw_shop_section(vp)
	_draw_repair_and_footer(vp)


func _draw_header(vp: Vector2) -> void:
	draw_string(_font, Vector2(40, 48), "BANCADA DE TRABALHO DO FERRO-VELHO", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#F5F0E1"))
	var sub := "Setor %d Limpo • \"Monte antes que a proxima onda desmonte voce\"" % sector
	draw_string(_font, Vector2(40, 74), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.5))

	# Sucata e HP
	var info_box := Rect2(vp.x - 420, 20, 380, 64)
	draw_rect(info_box, Color("#201712"))
	draw_rect(info_box, Color("#FFD400"), false, 2.0)

	var scrap_text := "SUCATA: %d 🔩" % MetaManager.current_scrap
	draw_string(_font, Vector2(info_box.position.x + 16, info_box.position.y + 28), scrap_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#FFD400"))

	if robot != null:
		var hp_text := "HP: %d / %d ❤️   ENERGIA: %d / %d W" % [
			int(round(robot.hp)), int(round(robot.max_hp)), robot.watts_used, robot.cpu.tdp if robot.cpu else 0
		]
		draw_string(_font, Vector2(info_box.position.x + 16, info_box.position.y + 52), hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#8CFF1A") if not robot.is_undervolt() else Color("#FF2D95"))


func _draw_equipped_section(vp: Vector2) -> void:
	var section_w := (vp.x - 100.0) * 0.44
	var panel := Rect2(40, 100, section_w, vp.y - 200)
	draw_rect(panel, Color("#1A1412"))
	draw_rect(panel, Color("#8A4B2A"), false, 2.0)

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
			# Indicador colorido da peca
			draw_rect(Rect2(card_rect.position.x + 8, card_rect.position.y + 8, 12, card_rect.size.y - 16), part.color)

			var title := "%s: %s" % [slot_name, part.display_name]
			draw_string(_font, card_rect.position + Vector2(28, 22), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

			var tier_str := "Tier %s (+%.0f%% Dano)  •  %s  •  %dW" % [
				part.fusion_roman(), (part.fusion_mult() - 1.0) * 100.0, part.rarity_name(), part.watts
			]
			draw_string(_font, card_rect.position + Vector2(28, 42), tier_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, part.rarity_color())

			# Botao de evolucao de Tier
			var up_cost: int = part.upgrade_cost()
			var up_btn := Rect2(card_rect.position.x + card_rect.size.x - 140, card_rect.position.y + 10, 130, card_rect.size.y - 20)

			if up_cost > 0:
				var can_up := MetaManager.current_scrap >= up_cost
				draw_rect(up_btn, Color("#8CFF1A") if can_up else Color("#442222"))
				draw_rect(up_btn, Color.WHITE, false, 1.0)
				var btn_label := "Evoluir (%d 🔩)" % up_cost
				draw_string(_font, up_btn.position + Vector2(0, up_btn.size.y * 0.5 + 4), btn_label, HORIZONTAL_ALIGNMENT_CENTER, up_btn.size.x, 12, Color.BLACK if can_up else Color.WHITE)
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
	var panel := Rect2(section_x, 100, section_w, vp.y - 200)

	draw_rect(panel, Color("#1A1412"))
	draw_rect(panel, Color("#22E0FF").darkened(0.5), false, 2.0)

	draw_string(_font, Vector2(section_x + 16, 130), "VITRINE DE PEÇAS DISPONÍVEIS", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#22E0FF"))

	# Desenho das ofertas
	var offer_y := 150.0
	var n_offers := _offers.size()
	var card_h := (panel.size.y - 120.0) / maxf(float(n_offers), 1.0) - 8.0

	for i in n_offers:
		var part: PartData = _offers[i]
		var card := Rect2(section_x + 16, offer_y, panel.size.x - 32, card_h)

		draw_rect(card, Color("#221A16"))
		draw_rect(card, part.rarity_color().darkened(0.5), false, 1.0)

		# Slot e nome
		var slot_label := ""
		match part.slot:
			PartData.Slot.ARM_LEFT: slot_label = "[Braço E]"
			PartData.Slot.ARM_RIGHT: slot_label = "[Braço D]"
			PartData.Slot.HEAD: slot_label = "[Cabeça]"
			PartData.Slot.CHASSIS: slot_label = "[Chassi]"

		var header_text := "[%d] %s %s • %s" % [i + 1, slot_label, part.display_name, part.rarity_name()]
		draw_string(_font, card.position + Vector2(16, 22), header_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, part.rarity_color())

		var stats_text := "Consumo: %dW  •  Calor: %.1f  •  Cadência: %.1f/s" % [part.watts, part.heat_per_shot, part.fire_rate]
		if part.projectile != null:
			stats_text += "  •  Dano: %.0f  •  Quiques: %d" % [part.projectile.damage, part.projectile.max_bounces]
		elif part.slot == PartData.Slot.CHASSIS:
			stats_text += "  •  HP: %.0f  •  Velocidade: %.0f" % [part.hp, part.move_speed]
		draw_string(_font, card.position + Vector2(16, 42), stats_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.7))

		# Botao de compra
		var price: int = part.base_price()
		var can_buy := MetaManager.current_scrap >= price
		var buy_btn := Rect2(card.position.x + card.size.x - 170, card.position.y + 10, 155, card.size.y - 20)

		draw_rect(buy_btn, Color("#22E0FF") if can_buy else Color("#442222"))
		draw_rect(buy_btn, Color.WHITE, false, 1.0)
		var btn_label := "Equipar (%d 🔩)" % price
		draw_string(_font, buy_btn.position + Vector2(0, buy_btn.size.y * 0.5 + 4), btn_label, HORIZONTAL_ALIGNMENT_CENTER, buy_btn.size.x, 12, Color.BLACK if can_buy else Color.WHITE)
		_buttons.append({"rect": buy_btn, "action": "buy_offer", "payload": i})

		offer_y += card_h + 8.0

	# Botao de Reroll na parte inferior da vitrine
	var reroll_cost := _reroll_cost()
	var can_reroll := MetaManager.current_scrap >= reroll_cost
	var reroll_btn := Rect2(section_x + 16, panel.position.y + panel.size.y - 48, panel.size.x - 32, 38)
	draw_rect(reroll_btn, Color("#33241A") if can_reroll else Color("#221512"))
	draw_rect(reroll_btn, Color("#FFD400") if can_reroll else Color(1, 1, 1, 0.2), false, 1.0)
	var reroll_str := "REROLL DA VITRINE [R] (%d Sucata)" % reroll_cost
	draw_string(_font, reroll_btn.position + Vector2(0, 24), reroll_str, HORIZONTAL_ALIGNMENT_CENTER, reroll_btn.size.x, 14, Color("#FFD400") if can_reroll else Color(1, 1, 1, 0.3))
	_buttons.append({"rect": reroll_btn, "action": "reroll", "payload": null})


func _draw_repair_and_footer(vp: Vector2) -> void:
	# Botao de Solda de Reparo
	var can_repair: bool = not _repair_used and robot != null and robot.hp < robot.max_hp and MetaManager.current_scrap >= REPAIR_COST
	var repair_btn := Rect2(40, vp.y - 82, 280, 52)

	draw_rect(repair_btn, Color("#225522") if can_repair else Color("#221512"))
	draw_rect(repair_btn, Color("#8CFF1A") if can_repair else Color(1, 1, 1, 0.2), false, 1.0)

	var repair_label := "SOLDA DE REPARO [H] (%d 🔩)" % REPAIR_COST
	if _repair_used:
		repair_label = "SOLDA: JÁ UTILIZADA"
	elif robot != null and robot.hp >= robot.max_hp:
		repair_label = "SOLDA: HP CHEIO"

	draw_string(_font, repair_btn.position + Vector2(0, 24), repair_label, HORIZONTAL_ALIGNMENT_CENTER, repair_btn.size.x, 13, Color("#8CFF1A") if can_repair else Color(1, 1, 1, 0.4))
	draw_string(_font, repair_btn.position + Vector2(0, 42), "Recupera 35% do HP máximo", HORIZONTAL_ALIGNMENT_CENTER, repair_btn.size.x, 11, Color(1, 1, 1, 0.6))
	_buttons.append({"rect": repair_btn, "action": "repair", "payload": null})

	# Botao grande de Prosseguir para a proxima sala
	var next_btn := Rect2(vp.x - 440, vp.y - 82, 400, 52)
	draw_rect(next_btn, Color("#8CFF1A"))
	draw_rect(next_btn, Color("#F5F0E1"), false, 2.0)
	draw_string(_font, next_btn.position + Vector2(0, 32), "PROSSEGUIR PRO SETOR %d [ ESPAÇO ]" % (sector + 1), HORIZONTAL_ALIGNMENT_CENTER, next_btn.size.x, 18, Color("#1A0F14"))
	_buttons.append({"rect": next_btn, "action": "proceed", "payload": null})
