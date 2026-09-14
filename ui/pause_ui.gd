class_name PauseUI
extends Control
## Pausa durante o combate (ESC ou botao Back do controle). Desistir exige
## confirmacao e conta como derrota; sair do jogo preserva o estado de run da
## ultima transicao de sala.

signal resume_requested
signal options_requested
signal abandon_requested
signal quit_requested

const CONFIRM_TIME := 3.0
const ITEMS := [
	{"action": "resume", "label": "CONTINUAR"},
	{"action": "options", "label": "OPÇÕES"},
	{"action": "abandon", "label": "DESISTIR DA RUN"},
	{"action": "quit", "label": "SAIR DO JOGO"},
]

var sector_label := ""
var _font: Font
var _rects: Array[Rect2] = []
var _selected := 0
var _abandon_armed := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_font = ThemeDB.fallback_font
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed() -> void:
	if visible:
		_selected = 0
		_abandon_armed = 0.0
		grab_focus.call_deferred()
		queue_redraw()


func _process(delta: float) -> void:
	if _abandon_armed > 0.0:
		_abandon_armed = maxf(0.0, _abandon_armed - delta)
		queue_redraw()


func activate(action: String) -> void:
	match action:
		"resume":
			resume_requested.emit()
		"options":
			options_requested.emit()
		"abandon":
			# Um toque arma, o segundo confirma. Um clique errado nao encerra a run.
			if _abandon_armed > 0.0:
				_abandon_armed = 0.0
				abandon_requested.emit()
			else:
				_abandon_armed = CONFIRM_TIME
				queue_redraw()
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
				activate(ITEMS[i].action)
				return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		accept_event()
		resume_requested.emit()
		return
	if event.is_action_pressed("ui_down"):
		_selected = (_selected + 1) % ITEMS.size()
	elif event.is_action_pressed("ui_up"):
		_selected = (_selected - 1 + ITEMS.size()) % ITEMS.size()
	elif event.is_action_pressed("ui_accept"):
		accept_event()
		activate(ITEMS[_selected].action)
		return
	else:
		return
	accept_event()
	queue_redraw()


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.04, 0.03, 0.03, 0.72))
	var panel := Rect2(vp.x * 0.5 - 280.0, vp.y * 0.5 - 260.0, 560.0, 470.0)
	ArtDirector.panel(self, panel, Color("#22E0FF"))
	draw_string(_font, panel.position + Vector2(36, 70), "PAUSA", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color("#22E0FF"))
	if sector_label != "":
		draw_string(_font, panel.position + Vector2(40, 102), sector_label, HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 80, 16, Color("#B6A299"))
	_rects.clear()
	for i in ITEMS.size():
		var row := Rect2(panel.position + Vector2(36, 130 + 76.0 * i), Vector2(panel.size.x - 72, 64))
		_rects.append(row)
		var selected := i == _selected
		var label: String = ITEMS[i].label
		var ink := Color("#FFD400") if selected else Color("#F5F0E1")
		if ITEMS[i].action == "abandon" and _abandon_armed > 0.0:
			label = "CONFIRMAR: DESISTIR? (%.0f s)" % ceilf(_abandon_armed)
			ink = Color("#FF6B6B")
		draw_rect(row, Color("#1E2A2C") if selected else Color("#141414"))
		draw_rect(row, Color("#22E0FF") if selected else Color(1, 1, 1, 0.12), false, 3.0 if selected else 1.0)
		draw_string(_font, row.position + Vector2(22, 42), label, HORIZONTAL_ALIGNMENT_LEFT, row.size.x - 44, 26, ink)
	draw_string(_font, Vector2(panel.position.x + 36, panel.end.y - 22), "ESC volta ao combate  •  sair mantém o save da última sala",
		HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 72, 14, Color(1, 1, 1, 0.45))
