class_name GarageUI
extends Control
## Interface da Garagem do Ferro-Velho (Seu Nildo). GDD 6.1 a 6.3.
## Tela de metaprogressao onde o jogador gasta Cobre permanente na arvore de 5 ramos.
##
## Tambem e a tela de fim de run: mostra a legenda automatica (GDD 1.4, item 3),
## copiavel com C, a semente da run e o desafio de hoje.
##
## So recebe teclado com foco. A versao anterior tratava as teclas em _gui_input
## sem nunca pedir foco, entao "INICIAR RUN [ESPACO]" so funcionava com o mouse.
## So existe com o jogo pausado; ver scenes/prototype.gd.

signal start_run_requested(daily: bool)

const BRANCHES: Array[String] = ["chapa", "polvora", "mola", "cobre", "sorte"]

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
var _copied_time: float = 0.0
var _reset_armed: float = 0.0
const RESET_CONFIRM_TIME := 3.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_font = ThemeDB.fallback_font
	MetaManager.save_updated.connect(queue_redraw)
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed() -> void:
	if not visible:
		return
	MetaManager.refresh_daily()
	grab_focus.call_deferred()
	queue_redraw()


func _process(delta: float) -> void:
	if _copied_time > 0.0:
		_copied_time = maxf(0.0, _copied_time - delta)
		queue_redraw()
	if _reset_armed > 0.0:
		_reset_armed = maxf(0.0, _reset_armed - delta)
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		grab_focus()
		var mpos: Vector2 = event.position
		for btn in _buttons:
			if (btn["rect"] as Rect2).has_point(mpos):
				_handle_button_click(btn)
				accept_event()
				return

	if event is InputEventKey and event.pressed and not event.echo:
		var handled := true
		match event.keycode:
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				start_run_requested.emit(false)
			KEY_H:
				start_run_requested.emit(true)
			KEY_C:
				_copy_caption()
			KEY_1:
				_buy_branch_safe("chapa")
			KEY_2:
				_buy_branch_safe("polvora")
			KEY_3:
				_buy_branch_safe("mola")
			KEY_4:
				_buy_branch_safe("cobre")
			KEY_5:
				_buy_branch_safe("sorte")
			KEY_LEFT, KEY_A, KEY_BRACKETLEFT:
				_heat_step(-1)
			KEY_RIGHT, KEY_D, KEY_BRACKETRIGHT:
				_heat_step(1)
			KEY_Z:
				_cpu_step(-1)
			KEY_X:
				_cpu_step(1)
			_:
				handled = false
		if handled:
			accept_event()


func _heat_step(direction: int) -> void:
	var cap := mini(10, MetaManager.highest_heat_beaten + 1)
	MetaManager.selected_heat = clampi(MetaManager.selected_heat + direction, 0, cap)
	queue_redraw()


func _buy_branch_safe(branch: String) -> void:
	if MetaManager.can_buy_upgrade(branch):
		MetaManager.buy_upgrade(branch)
		Sfx.play_varied("fire_heavy", -2.0)
	else:
		Sfx.play("projectile_plop", -4.0)
	queue_redraw()


## GDD 1.4, item 3: "Esse texto e copiavel e e literalmente a legenda do post."
func _copy_caption() -> void:
	var caption: String = MetaManager.last_run_summary.get("caption", "")
	if caption == "":
		return
	DisplayServer.clipboard_set(caption)
	_copied_time = 1.5
	Sfx.play("paddle", -6.0)
	queue_redraw()


func _handle_button_click(btn: Dictionary) -> void:
	match btn["action"]:
		"start_run":
			start_run_requested.emit(false)
		"start_daily":
			start_run_requested.emit(true)
		"copy_caption":
			_copy_caption()
		"select_branch":
			_selected_branch = btn["branch"]
			queue_redraw()
		"buy":
			_buy_branch_safe(btn["branch"])
		"select_cpu":
			if MetaManager.select_cpu(StringName(btn["branch"])):
				Sfx.play("paddle", -8.0)
			else:
				Sfx.play("projectile_plop", -4.0)
			queue_redraw()
		"heat_down":
			_heat_step(-1)
		"heat_up":
			_heat_step(1)
		"reset_save":
			# Dois cliques em 3 s. Um clique errado apagava o progresso inteiro.
			if _reset_armed > 0.0:
				MetaManager.reset_save()
				_reset_armed = 0.0
			else:
				_reset_armed = RESET_CONFIRM_TIME
			queue_redraw()


func _draw() -> void:
	_buttons.clear()
	var vp := get_viewport_rect().size

	# Fundo escuro texturizado estilo galpao
	draw_rect(Rect2(Vector2.ZERO, vp), Color("#14100E"))
	var backdrop := ArtDirector.texture(ArtDirector.BACKGROUND_PATH)
	if backdrop:
		draw_texture_rect(backdrop, Rect2(Vector2.ZERO, vp), false, Color(0.5, 0.5, 0.5))

	_draw_header(vp)
	_draw_branch_tabs(vp)
	_draw_branch_details(vp)
	_draw_cpu_shelf(vp)
	_draw_footer(vp)


## GDD 6.3.2: a prateleira de CPUs. Bloqueadas aparecem com a condicao
## visivel, porque condicao visivel gera objetivo. Z e X trocam a selecao.
func _draw_cpu_shelf(vp: Vector2) -> void:
	var shelf := Rect2(40, 640, vp.x - 80, 132)
	ArtDirector.panel(self, shelf, Color("#22E0FF"))
	draw_string(_font, shelf.position + Vector2(24, 30), "PRATELEIRA DE CPUs   [Z] < > [X]", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#22E0FF"))
	var cpus := PartLibrary.cpus()
	var cur := MetaManager.selected_cpu()
	var tray_w := (shelf.size.x - 48.0) / float(cpus.size())
	for i in cpus.size():
		var c: CpuData = cpus[i]
		var unlocked := MetaManager.is_cpu_unlocked(c.id)
		var is_sel := c.id == cur.id
		var tray := Rect2(shelf.position.x + 24.0 + tray_w * float(i), shelf.position.y + 42.0, tray_w - 6.0, 78.0)
		draw_rect(tray, Color("#1E2A2C") if unlocked else Color("#151313"))
		draw_rect(tray, Color("#22E0FF") if is_sel else Color(1, 1, 1, 0.15), false, 2.0 if is_sel else 1.0)
		var name_short := c.display_name.split("(")[0].strip_edges()
		draw_string(_font, tray.position + Vector2(8, 18), name_short, HORIZONTAL_ALIGNMENT_LEFT, tray.size.x - 16, 13, Color.WHITE if unlocked else Color(1, 1, 1, 0.35))
		if unlocked:
			draw_string(_font, tray.position + Vector2(8, 36), "%d W  •  calor %d  •  %d/s" % [c.tdp, int(c.heat_capacity), int(c.heat_dissipation)], HORIZONTAL_ALIGNMENT_LEFT, tray.size.x - 16, 11, Color("#FFD400"))
			_draw_wrapped(tray.position + Vector2(8, 52), c.description, tray.size.x - 16, 11, Color(1, 1, 1, 0.7), 2)
		else:
			var have := MetaManager.unlock_stat_value(c.unlock_stat)
			draw_string(_font, tray.position + Vector2(8, 36), "BLOQUEADA  %d / %d" % [have, c.unlock_value], HORIZONTAL_ALIGNMENT_LEFT, tray.size.x - 16, 11, Color("#FF6B1A"))
			_draw_wrapped(tray.position + Vector2(8, 52), c.unlock_text, tray.size.x - 16, 11, Color(1, 1, 1, 0.45), 2)
		_buttons.append({"rect": tray, "branch": String(c.id), "action": "select_cpu"})


func _draw_wrapped(at: Vector2, text: String, width: float, font_size: int, color: Color, max_lines: int) -> void:
	draw_multiline_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, max_lines, color)


func _cpu_step(direction: int) -> void:
	var cpus := PartLibrary.cpus()
	var idx := 0
	for i in cpus.size():
		if cpus[i].id == MetaManager.selected_cpu_id:
			idx = i
	# Anda ate a proxima desbloqueada, dando a volta na prateleira.
	for step in cpus.size():
		idx = (idx + direction + cpus.size()) % cpus.size()
		if MetaManager.is_cpu_unlocked(cpus[idx].id):
			MetaManager.select_cpu(cpus[idx].id)
			Sfx.play("paddle", -8.0)
			break
	queue_redraw()


func _draw_header(vp: Vector2) -> void:
	draw_string(_font, Vector2(40, 52), "A GARAGEM DO FERRO-VELHO", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("#F5F0E1"))
	draw_string(_font, Vector2(40, 78), "Balcão do Seu Nildo • \"Gaste seu cobre ou suma daqui\"", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.5))

	var copper_box := Rect2(vp.x - 340, 24, 300, 60)
	draw_rect(copper_box, Color("#241A12"))
	draw_rect(copper_box, Color("#D6C9A8"), false, 2.0)
	draw_string(_font, Vector2(vp.x - 325, 62), "COBRE: %d" % MetaManager.copper, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#FFD400"))

	if MetaManager.last_run_summary.is_empty():
		return

	var s: Dictionary = MetaManager.last_run_summary
	var outcome := "VITÓRIA" if bool(s.get("won", false)) else "derrota"
	var tag := "DESAFIO DE HOJE • " if bool(s.get("daily", false)) else ""
	var recap := "%sÚltima run: %s no setor %d • Sucata %d • +%d Cobre • semente %s" % [
		tag, outcome, int(s.get("sector_reached", 1)), int(s.get("scrap_collected", 0)),
		int(s.get("copper_earned", 0)), GameRng.seed_label(int(s.get("seed", 0))),
	]
	if int(s.get("daily_reward", 0)) > 0:
		recap += " • meta de hoje cumprida (+%d)" % int(s.get("daily_reward", 0))
	draw_string(_font, Vector2(40, 106), recap, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#8CFF1A"))

	var caption: String = s.get("caption", "")
	if caption == "":
		return
	var caption_width := vp.x - 340.0
	draw_multiline_string(_font, Vector2(40, 130), "“%s”" % caption, HORIZONTAL_ALIGNMENT_LEFT, caption_width, 16, 2, Color("#FFD400"))
	var hint_rect := Rect2(vp.x - 280.0, 112.0, 240.0, 30.0)
	draw_rect(hint_rect, Color("#241A12"))
	draw_rect(hint_rect, Color("#FFD400", 0.6), false, 1.0)
	var hint := "COPIADO!" if _copied_time > 0.0 else "[C] COPIAR LEGENDA"
	draw_string(_font, hint_rect.position + Vector2(0, 20), hint, HORIZONTAL_ALIGNMENT_CENTER, hint_rect.size.x, 13, Color("#FFD400"))
	_buttons.append({"rect": hint_rect, "branch": "", "action": "copy_caption"})


func _draw_branch_tabs(vp: Vector2) -> void:
	var tab_y := 172.0
	var tab_w := (vp.x - 80.0) / 5.0

	for i in BRANCHES.size():
		var b: String = BRANCHES[i]
		var r := Rect2(40.0 + i * tab_w, tab_y, tab_w - 8.0, 44.0)
		var is_sel: bool = b == _selected_branch
		var bcolor: Color = BRANCH_COLORS[b]

		draw_rect(r, bcolor.darkened(0.6) if is_sel else Color("#201A18"))
		draw_rect(r, bcolor if is_sel else Color(1, 1, 1, 0.2), false, 2.0 if is_sel else 1.0)

		var lvl: int = MetaManager.get_upgrade_level(b)
		var title := "[%d] %s" % [i + 1, b.to_upper()]
		draw_string(_font, r.position + Vector2(12, 22), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE if is_sel else Color(1, 1, 1, 0.6))
		draw_string(_font, r.position + Vector2(12, 38), "Nível %d/5" % lvl, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, bcolor)

		_buttons.append({"rect": r, "branch": b, "action": "select_branch"})


func _draw_branch_details(vp: Vector2) -> void:
	var panel_rect := Rect2(40, 226, vp.x - 80, 400)
	ArtDirector.panel(self, panel_rect, BRANCH_COLORS[_selected_branch])
	draw_rect(panel_rect, (BRANCH_COLORS[_selected_branch] as Color).darkened(0.4), false, 2.0)

	var b := _selected_branch
	var bname: String = BRANCH_NAMES[b]
	var cur_lvl: int = MetaManager.get_upgrade_level(b)
	var tree: Array = MetaManager.UPGRADE_TREE[b]

	draw_string(_font, Vector2(64, 262), bname, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, BRANCH_COLORS[b])

	var row_y := 280.0
	for i in tree.size():
		var node: Dictionary = tree[i]
		var is_unlocked: bool = cur_lvl > i
		var is_next: bool = cur_lvl == i
		var row_rect := Rect2(64, row_y, panel_rect.size.x - 48, 60)

		var bg_col := Color("#2A201C") if is_unlocked else (Color("#33241C") if is_next else Color("#181412"))
		draw_rect(row_rect, bg_col)
		var border_col := Color("#8CFF1A") if is_unlocked else (Color("#FFD400") if is_next else Color(1, 1, 1, 0.1))
		draw_rect(row_rect, border_col, false, 2.0 if is_next else 1.0)

		var lit := is_unlocked or is_next
		draw_string(_font, row_rect.position + Vector2(16, 24), "Nível %d: %s" % [i + 1, node["name"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE if lit else Color(1, 1, 1, 0.4))
		draw_string(_font, row_rect.position + Vector2(16, 46), node["desc"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.7) if lit else Color(1, 1, 1, 0.3))

		if is_unlocked:
			draw_string(_font, row_rect.position + Vector2(row_rect.size.x - 180, 36), "✓ ADQUIRIDO", HORIZONTAL_ALIGNMENT_CENTER, 160, 15, Color("#8CFF1A"))
		elif is_next:
			var cost: int = node["cost"]
			var can_buy := MetaManager.copper >= cost
			var btn_rect := Rect2(row_rect.position.x + row_rect.size.x - 190, row_rect.position.y + 10, 170, 40)
			draw_rect(btn_rect, Color("#8CFF1A") if can_buy else Color("#552222"))
			draw_rect(btn_rect, Color.WHITE, false, 2.0)
			draw_string(_font, btn_rect.position + Vector2(8, 26), "COMPRAR (%d Cobre)" % cost, HORIZONTAL_ALIGNMENT_CENTER, 154, 13, Color.BLACK if can_buy else Color.WHITE)
			_buttons.append({"rect": btn_rect, "branch": b, "action": "buy"})
		else:
			draw_string(_font, row_rect.position + Vector2(row_rect.size.x - 180, 36), "%d Cobre" % node["cost"], HORIZONTAL_ALIGNMENT_CENTER, 160, 14, Color(1, 1, 1, 0.3))

		row_y += 68.0


func _draw_footer(vp: Vector2) -> void:
	# Barra do Modo Ferro-Velho Infernal (Calibragem de Risco / Heat)
	var heat_y := vp.y - 126.0
	var heat_w := 540.0
	var heat_x := vp.x * 0.5 - heat_w * 0.5
	var heat_box := Rect2(heat_x, heat_y, heat_w, 36.0)
	draw_rect(heat_box, Color("#261912"))
	draw_rect(heat_box, Color("#FF6B1A"), false, 1.5)

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

	var bonus_pct := int(round(float(MetaManager.selected_heat) * 25.0))
	var heat_label := "CALIBRAGEM DE RISCO: NÍVEL %d / 10   (+%d%% Cobre Extra)" % [MetaManager.selected_heat, bonus_pct]
	draw_string(_font, Vector2(heat_x + 40, heat_y + 24), heat_label, HORIZONTAL_ALIGNMENT_CENTER, heat_w - 80, 15, Color("#FFD400"))

	var start_rect := Rect2(vp.x * 0.5 - 180, vp.y - 78, 360, 52)
	draw_rect(start_rect, Color("#8CFF1A"))
	draw_rect(start_rect, Color("#F5F0E1"), false, 3.0)
	draw_string(_font, start_rect.position + Vector2(0, 34), "INICIAR RUN [ ESPAÇO ]", HORIZONTAL_ALIGNMENT_CENTER, 360, 20, Color("#1A0F14"))
	_buttons.append({"rect": start_rect, "branch": "", "action": "start_run"})

	# Desafio de hoje: semente do dia em UTC, loadout fixo e risco zero.
	var daily_rect := Rect2(vp.x * 0.5 + 200, vp.y - 78, 330, 52)
	draw_rect(daily_rect, Color("#22E0FF").darkened(0.6))
	draw_rect(daily_rect, Color("#22E0FF"), false, 2.0)
	draw_string(_font, daily_rect.position + Vector2(0, 22), "DESAFIO DE HOJE [ H ]", HORIZONTAL_ALIGNMENT_CENTER, daily_rect.size.x, 16, Color("#F5F0E1"))
	var status := ""
	if MetaManager.daily_rewarded:
		status = "meta cumprida hoje • melhor: %d setores" % MetaManager.daily_best_sectors
	else:
		status = "limpe %d setores: +%d Cobre • melhor hoje: %d" % [
			MetaManager.DAILY_GOAL_SECTORS, MetaManager.DAILY_REWARD, MetaManager.daily_best_sectors]
	draw_string(_font, daily_rect.position + Vector2(0, 42), status, HORIZONTAL_ALIGNMENT_CENTER, daily_rect.size.x, 11, Color("#22E0FF"))
	_buttons.append({"rect": daily_rect, "branch": "", "action": "start_daily"})

	draw_string(_font, Vector2(40, vp.y - 32), "[1..5] Upgrades • [< >] Risco • [Z X] CPU • [ESPAÇO] Run • [H] Desafio de hoje • [C] Copiar legenda", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.45))

	var armed := _reset_armed > 0.0
	var reset_rect := Rect2(vp.x - 200, vp.y - 42, 160, 26)
	draw_rect(reset_rect, Color(0.5, 0, 0, 0.6) if armed else Color(0, 0, 0, 0.4))
	draw_rect(reset_rect, Color(1, 0, 0, 0.9 if armed else 0.4), false, 1.0)
	var reset_label := "CONFIRMAR? apaga tudo" if armed else "Resetar Save"
	draw_string(_font, reset_rect.position + Vector2(10, 18), reset_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#FF6B6B"))
	_buttons.append({"rect": reset_rect, "branch": "", "action": "reset_save"})
