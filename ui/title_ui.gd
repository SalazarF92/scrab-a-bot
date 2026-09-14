class_name TitleUI
extends Control
## Tela de titulo. Aparece quando o jogo abre normalmente, sem semente de teste.
## "Continuar run" retoma o estado salvo na ultima transicao de sala
## (GDD_ADENDOS B.7). Teclado, mouse e controle (acoes ui_*).

signal continue_requested
signal play_requested
signal daily_requested
signal options_requested
signal quit_requested

var _font: Font
var _items: Array[Dictionary] = []
var _rects: Array[Rect2] = []
var _selected := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_font = ThemeDB.fallback_font
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed() -> void:
	if visible:
		refresh()
		grab_focus.call_deferred()


## Remonta o menu. "Continuar run" so existe com um estado de run valido.
func refresh() -> void:
	_items.clear()
	var state := MetaManager.load_run_state()
	if not state.is_empty():
		var where := "bancada depois do setor %d" if str(state.get("resume", "")) == "workbench" else "inicio do setor %d"
		_items.append({"action": "continue", "label": "CONTINUAR RUN",
			"hint": (where % int(state.get("sector", 1))) + "  •  semente " + GameRng.seed_label(int(state.get("seed", 0)))})
	_items.append({"action": "play", "label": "JOGAR", "hint": "Garagem do Seu Nildo: upgrades, CPU e nova run"})
	_items.append({"action": "daily", "label": "DESAFIO DE HOJE", "hint": "semente do dia, loadout fixo, risco zero"})
	_items.append({"action": "options", "label": "OPÇÕES", "hint": "tremor, hitstop, acessibilidade, volume e teclas"})
	_items.append({"action": "quit", "label": "SAIR", "hint": ""})
	_selected = 0
	queue_redraw()


func actions() -> Array[String]:
	var out: Array[String] = []
	for item in _items:
		out.append(item.action)
	return out


func activate(action: String) -> void:
	match action:
		"continue":
			continue_requested.emit()
		"play":
			play_requested.emit()
		"daily":
			daily_requested.emit()
		"options":
			options_requested.emit()
		"quit":
			quit_requested.emit()
	Sfx.play("paddle", -8.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		for i in _rects.size():
			if _rects[i].has_point(event.position) and _selected != i:
				_selected = i
				queue_redraw()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		grab_focus()
		for i in _rects.size():
			if _rects[i].has_point(event.position):
				accept_event()
				activate(_items[i].action)
				return
	if _items.is_empty():
		return
	if event.is_action_pressed("ui_down"):
		_selected = (_selected + 1) % _items.size()
	elif event.is_action_pressed("ui_up"):
		_selected = (_selected - 1 + _items.size()) % _items.size()
	elif event.is_action_pressed("ui_accept"):
		accept_event()
		activate(_items[_selected].action)
		return
	else:
		return
	accept_event()
	queue_redraw()


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color("#0F0B0A"))
	var backdrop := ArtDirector.texture(ArtDirector.BACKGROUND_PATH)
	if backdrop:
		draw_texture_rect(backdrop, Rect2(Vector2.ZERO, vp), false, Color(0.45, 0.42, 0.40))
	var left := vp.x * 0.5 - 330.0
	draw_string(_font, Vector2(left, 250), "SCRAP-A-BOT", HORIZONTAL_ALIGNMENT_LEFT, -1, 96, Color("#FFD400"))
	draw_string(_font, Vector2(left + 6, 300), "SUCATA SEM LICENÇA", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#D6C9A8"))
	draw_string(_font, Vector2(left + 6, 338), "MONTE. RICOCHETEIE. EXPLODA.", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#B6A299"))

	_rects.clear()
	var panel := Rect2(left, 390, 660, 92.0 * _items.size() + 36.0)
	ArtDirector.panel(self, panel, Color("#FFD400"))
	for i in _items.size():
		var item: Dictionary = _items[i]
		var row := Rect2(panel.position + Vector2(18, 18 + 92.0 * i), Vector2(panel.size.x - 36, 80))
		_rects.append(row)
		var selected := i == _selected
		draw_rect(row, Color("#3A2A1C") if selected else Color("#1B1512"))
		draw_rect(row, Color("#FFD400") if selected else Color(1, 1, 1, 0.12), false, 3.0 if selected else 1.0)
		draw_string(_font, row.position + Vector2(24, 42), item.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 30,
			Color("#FFD400") if selected else Color("#F5F0E1"))
		if item.hint != "":
			draw_string(_font, row.position + Vector2(24, 68), item.hint, HORIZONTAL_ALIGNMENT_LEFT, row.size.x - 48, 15, Color("#B6A299"))
	draw_string(_font, Vector2(left, panel.end.y + 40), "SETAS escolhem  •  ENTER confirma  •  controle: direcional e A",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.45))
