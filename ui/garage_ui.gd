class_name GarageUI
extends Control
## Interface da Garagem do Ferro-Velho (Seu Nildo). GDD 6.1 a 6.3.
## Tela de metaprogressao onde o jogador gasta Cobre permanente na arvore de 5 ramos.

signal start_run_requested

const BRANCH_NAMES := {
	"chapa": "CHAPA (Vida & Defesa)",
	"polvora": "PÓLVORA (Dano & Quique)",
	"mola": "MOLA (Mobilidade)",
	"cobre": "COBRE (Energia & Calor)",
	"sorte": "SORTE (Bancada & Drops)",
}

const BRANCH_COLORS := {
	"chapa": Color("#8A4B2A"),
	"polvora": Color("#FF6B1A"),
	"mola": Color("#FFD400"),
	"cobre": Color("#22E0FF"),
	"sorte": Color("#8CFF1A"),
}

var _font: Font
var _buttons: Array[Dictionary] = [] # {"rect": Rect2, "branch": String, "action": String}
var _selected_branch: String = "chapa"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = ThemeDB.fallback_font
	MetaManager.save_updated.connect(queue_redraw)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mpos: Vector2 = event.position
		for btn in _buttons:
			if (btn["rect"] as Rect2).has_point(mpos):
				_handle_button_click(btn)
				accept_event()
				return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE, KEY_ENTER:
				start_run_requested.emit()
				accept_event()
			KEY_1:
				_buy_branch_safe("chapa")
				accept_event()
			KEY_2:
				_buy_branch_safe("polvora")
				accept_event()
			KEY_3:
				_buy_branch_safe("mola")
				accept_event()
			KEY_4:
				_buy_branch_safe("cobre")
				accept_event()
			KEY_5:
				_buy_branch_safe("sorte")
				accept_event()
			KEY_LEFT, KEY_A, KEY_BRACKETLEFT:
				if MetaManager.selected_heat > 0:
					MetaManager.selected_heat -= 1
					queue_redraw()
				accept_event()
			KEY_RIGHT, KEY_D, KEY_BRACKETRIGHT:
				if MetaManager.selected_heat < mini(10, MetaManager.highest_heat_beaten + 1):
					MetaManager.selected_heat += 1
					queue_redraw()
				accept_event()


func _buy_branch_safe(branch: String) -> void:
	if MetaManager.can_buy_upgrade(branch):
		MetaManager.buy_upgrade(branch)
		Sfx.play_varied("fire_heavy", -2.0)
		CombatFeel.add_trauma(0.12)
	else:
		Sfx.play("projectile_plop", -4.0)
	queue_redraw()


func _handle_button_click(btn: Dictionary) -> void:
	match btn["action"]:
		"start_run":
			start_run_requested.emit()
		"select_branch":
			_selected_branch = btn["branch"]
			queue_redraw()
		"buy":
			_buy_branch_safe(btn["branch"])
		"heat_down":
			if MetaManager.selected_heat > 0:
				MetaManager.selected_heat -= 1
				queue_redraw()
		"heat_up":
			if MetaManager.selected_heat < mini(10, MetaManager.highest_heat_beaten + 1):
				MetaManager.selected_heat += 1
				queue_redraw()
		"reset_save":
			MetaManager.reset_save()
			queue_redraw()


func _draw() -> void:
	_buttons.clear()
	var vp := get_viewport_rect().size

	# Fundo escuro texturizado estilo galpao
	draw_rect(Rect2(Vector2.ZERO, vp), Color("#14100E"))

	_draw_header(vp)
	_draw_branch_tabs(vp)
	_draw_branch_details(vp)
	_draw_footer(vp)


func _draw_header(vp: Vector2) -> void:
	# Titulo
	draw_string(_font, Vector2(40, 52), "A GARAGEM DO FERRO-VELHO", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("#F5F0E1"))
	draw_string(_font, Vector2(40, 78), "Balcao do Seu Nildo • \"Gaste seu cobre ou suma daqui\"", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.5))

	# Saldo de Cobre
	var copper_box := Rect2(vp.x - 340, 24, 300, 60)
	draw_rect(copper_box, Color("#241A12"))
	draw_rect(copper_box, Color("#D6C9A8"), false, 2.0)
	var copper_text := "COBRE: %d 🔶" % MetaManager.copper
	draw_string(_font, Vector2(vp.x - 325, 62), copper_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#FFD400"))

	# Resumo da ultima run
	if not MetaManager.last_run_summary.is_empty():
		var s = MetaManager.last_run_summary
		var recap := "Ultima run: Setor %d alcançado • Sucata: %d • Ganho: +%d Cobre" % [
			s.get("sector_reached", 1), s.get("scrap_collected", 0), s.get("copper_earned", 0)
		]
		draw_string(_font, Vector2(40, 112), recap, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#8CFF1A"))


func _draw_branch_tabs(vp: Vector2) -> void:
	var tab_y := 136.0
	var tab_w := (vp.x - 80.0) / 5.0
	var branches := ["chapa", "polvora", "mola", "cobre", "sorte"]

	for i in branches.size():
		var b := branches[i]
		var r := Rect2(40.0 + i * tab_w, tab_y, tab_w - 8.0, 48.0)
		var is_sel := b == _selected_branch
		var bcolor: Color = BRANCH_COLORS[b]

		draw_rect(r, bcolor.darkened(0.6) if is_sel else Color("#201A18"))
		draw_rect(r, bcolor if is_sel else Color(1, 1, 1, 0.2), false, 2.0 if is_sel else 1.0)

		var lvl: int = MetaManager.get_upgrade_level(b)
		var title := "[%d] %s" % [i + 1, b.to_upper()]
		draw_string(_font, r.position + Vector2(12, 24), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE if is_sel else Color(1, 1, 1, 0.6))
		draw_string(_font, r.position + Vector2(12, 40), "Nivel %d/5" % lvl, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, bcolor)

		_buttons.append({"rect": r, "branch": b, "action": "select_branch"})


func _draw_branch_details(vp: Vector2) -> void:
	var panel_rect := Rect2(40, 196, vp.x - 80, vp.y - 310)
	draw_rect(panel_rect, Color("#1C1715"))
	draw_rect(panel_rect, BRANCH_COLORS[_selected_branch].darkened(0.4), false, 2.0)

	var b := _selected_branch
	var bname: String = BRANCH_NAMES[b]
	var cur_lvl: int = MetaManager.get_upgrade_level(b)
	var tree: Array = MetaManager.UPGRADE_TREE[b]

	# Cabecalho do ramo selecionado
	draw_string(_font, Vector2(64, 236), bname, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, BRANCH_COLORS[b])

	var row_y := 260.0
	for i in tree.size():
		var node: Dictionary = tree[i]
		var is_unlocked: bool = cur_lvl > i
		var is_next: bool = cur_lvl == i
		var row_rect := Rect2(64, row_y, panel_rect.size.x - 48, 64)

		var bg_col := Color("#2A201C") if is_unlocked else (Color("#33241C") if is_next else Color("#181412"))
		draw_rect(row_rect, bg_col)
		var border_col := Color("#8CFF1A") if is_unlocked else (Color("#FFD400") if is_next else Color(1, 1, 1, 0.1))
		draw_rect(row_rect, border_col, false, 2.0 if is_next else 1.0)

		# Icone/Status
		var status_str := "✓ ADQUIRIDO" if is_unlocked else ("PRÓXIMO" if is_next else "BLOQUEADO")
		var status_col := Color("#8CFF1A") if is_unlocked else (Color("#FFD400") if is_next else Color(1, 1, 1, 0.3))
		draw_string(_font, row_rect.position + Vector2(16, 26), "Nível %d: %s" % [i + 1, node["name"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE if (is_unlocked or is_next) else Color(1, 1, 1, 0.4))
		draw_string(_font, row_rect.position + Vector2(16, 50), node["desc"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.7) if (is_unlocked or is_next) else Color(1, 1, 1, 0.3))

		# Preco ou status
		if is_unlocked:
			draw_string(_font, row_rect.position + Vector2(row_rect.size.x - 180, 38), status_str, HORIZONTAL_ALIGNMENT_CENTER, 160, 15, status_col)
		elif is_next:
			var cost: int = node["cost"]
			var can_buy := MetaManager.copper >= cost
			var btn_rect := Rect2(row_rect.position.x + row_rect.size.x - 190, row_rect.position.y + 12, 170, 40)
			draw_rect(btn_rect, Color("#8CFF1A") if can_buy else Color("#552222"))
			draw_rect(btn_rect, Color.WHITE, false, 2.0)
			var btn_text := "COMPRAR (%d Cobre)" % cost
			draw_string(_font, btn_rect.position + Vector2(8, 26), btn_text, HORIZONTAL_ALIGNMENT_CENTER, 154, 13, Color.BLACK if can_buy else Color.WHITE)
			_buttons.append({"rect": btn_rect, "branch": b, "action": "buy"})
		else:
			draw_string(_font, row_rect.position + Vector2(row_rect.size.x - 180, 38), "%d Cobre" % node["cost"], HORIZONTAL_ALIGNMENT_CENTER, 160, 14, Color(1, 1, 1, 0.3))

		row_y += 74.0


func _draw_footer(vp: Vector2) -> void:
	# Barra do Modo Ferro-Velho Infernal (Calibragem de Risco / Heat)
	var heat_y := vp.y - 122.0
	var heat_w := 540.0
	var heat_x := vp.x * 0.5 - heat_w * 0.5
	var heat_box := Rect2(heat_x, heat_y, heat_w, 36.0)
	draw_rect(heat_box, Color("#261912"))
	draw_rect(heat_box, Color("#FF6B1A"), false, 1.5)

	# Botoes < e >
	var btn_l := Rect2(heat_x + 4, heat_y + 4, 32, 28)
	draw_rect(btn_l, Color("#18100C"))
	draw_rect(btn_l, Color(1, 1, 1, 0.3), false, 1.0)
	draw_string(_font, btn_l.position + Vector2(10, 20), "<", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	_buttons.append({"rect": btn_l, "branch": "", "action": "heat_down"})

	var btn_r := Rect2(heat_x + heat_w - 36, heat_y + 4, 32, 28)
	draw_rect(btn_r, Color("#18100C"))
	draw_rect(btn_r, Color(1, 1, 1, 0.3), false, 1.0)
	draw_string(_font, btn_r.position + Vector2(10, 20), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	_buttons.append({"rect": btn_r, "branch": "", "action": "heat_up"})

	var bonus_pct := int(round((MetaManager.get_heat_copper_bonus_mult() - 1.0) * 100.0))
	var heat_label := "CALIBRAGEM DE RISCO: NÍVEL %d / 10   (+%d%% Cobre Extra)" % [MetaManager.selected_heat, bonus_pct]
	draw_string(_font, Vector2(heat_x + 40, heat_y + 24), heat_label, HORIZONTAL_ALIGNMENT_CENTER, heat_w - 80, 15, Color("#FFD400"))

	# Botao grande de Iniciar Run
	var start_rect := Rect2(vp.x * 0.5 - 180, vp.y - 74, 360, 52)
	draw_rect(start_rect, Color("#8CFF1A"))
	draw_rect(start_rect, Color("#F5F0E1"), false, 3.0)
	draw_string(_font, start_rect.position + Vector2(0, 34), "INICIAR RUN [ ESPAÇO ]", HORIZONTAL_ALIGNMENT_CENTER, 360, 20, Color("#1A0F14"))
	_buttons.append({"rect": start_rect, "branch": "", "action": "start_run"})

	# Atalhos e Dica
	draw_string(_font, Vector2(40, vp.y - 32), "Dica: [1..5] Upgrades • [< >] Nível de Risco • [ESPAÇO] Iniciar Run", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.45))

	# Botao de resetar save
	var reset_rect := Rect2(vp.x - 160, vp.y - 42, 120, 26)
	draw_rect(reset_rect, Color(0, 0, 0, 0.4))
	draw_rect(reset_rect, Color(1, 0, 0, 0.4), false, 1.0)
	draw_string(_font, reset_rect.position + Vector2(10, 18), "Resetar Save", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#FF6B6B"))
	_buttons.append({"rect": reset_rect, "branch": "", "action": "reset_save"})
