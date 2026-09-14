class_name OptionsUI
extends Control
## Opcoes do jogador (autoload Settings). GDD 3.4.2 e GDD_ADENDOS C.2 e C.3.
## Cada mudanca e aplicada e salva na hora. ESC ou B do controle volta.
## Nas linhas de tecla, ENTER espera a proxima tecla; ESC cancela a espera.

signal closed

const VALUE_ROWS := [
	{"key": "shake", "label": "Tremor de tela", "kind": "percent", "max": 1.5, "step": 0.1,
		"hint": "Em 0% o tremor vira um pulso na borda da tela, para a informação não se perder."},
	{"key": "hitstop", "label": "Congelamento no impacto", "kind": "percent", "max": 1.5, "step": 0.1,
		"hint": "Separado do tremor. Reduz o hitstop sem mexer no resto."},
	{"key": "reduced_flashes", "label": "Flashes reduzidos", "kind": "toggle",
		"hint": "Troca clarões por efeitos locais. Recomendado para fotossensibilidade."},
	{"key": "colorblind_shapes", "label": "Formas no quique", "kind": "toggle",
		"hint": "Círculo, quadrado, triângulo e estrela repetem a cor de cada quique."},
	{"key": "aim_assist_gamepad", "label": "Assistência de mira no controle", "kind": "percent", "max": 1.0, "step": 0.05,
		"hint": "Nunca atua em projétil que já quicou."},
	{"key": "aim_assist_mouse", "label": "Assistência de mira no mouse", "kind": "percent", "max": 1.0, "step": 0.05,
		"hint": "Padrão 0%."},
	{"key": "master_volume", "label": "Volume", "kind": "percent", "max": 1.0, "step": 0.05, "hint": ""},
	{"key": "dev_shortcuts", "label": "Atalhos de desenvolvimento", "kind": "toggle",
		"hint": "F1 a F6, B, G, 1 a 3 e R. Desligados, o jogo não aceita teclas de depuração."},
]
const ACTION_LABELS := {
	"move_left": "Tecla: mover para a esquerda",
	"move_right": "Tecla: mover para a direita",
	"dash": "Tecla: dash",
	"head_ability": "Tecla: cabeça",
	"heat_purge": "Tecla: purga de calor",
	"pause": "Tecla: pausa",
}

var _font: Font
var _rows: Array[Dictionary] = []
var _rects: Array[Rect2] = []
var _selected := 0
var _waiting_action := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_font = ThemeDB.fallback_font
	for row in VALUE_ROWS:
		_rows.append(row)
	for action_name in GameInput.REBINDABLE:
		_rows.append({"key": action_name, "label": ACTION_LABELS.get(action_name, action_name), "kind": "key",
			"hint": "ENTER e depois a tecla nova. ESC cancela. Mouse e controle continuam valendo."})
	_rows.append({"key": "reset", "label": "Restaurar padrão", "kind": "button", "hint": "Volta todas as opções e teclas ao padrão."})
	_rows.append({"key": "back", "label": "Voltar", "kind": "button", "hint": ""})
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed() -> void:
	if visible:
		_selected = 0
		_waiting_action = ""
		grab_focus.call_deferred()
		queue_redraw()


func waiting_for_key() -> bool:
	return _waiting_action != ""


## Ajusta a linha: percentuais andam um passo, interruptores invertem.
func adjust(index: int, direction: int) -> void:
	var row: Dictionary = _rows[index]
	match row.kind:
		"percent":
			var value := float(Settings.get(row.key)) + float(row.step) * float(direction)
			Settings.set(row.key, clampf(snappedf(value, float(row.step)), 0.0, float(row.max)))
			_commit()
		"toggle":
			Settings.set(row.key, not bool(Settings.get(row.key)))
			_commit()


func activate(index: int) -> void:
	var row: Dictionary = _rows[index]
	match row.kind:
		"toggle":
			adjust(index, 1)
		"percent":
			adjust(index, 1)
		"key":
			_waiting_action = row.key
			queue_redraw()
		"button":
			if row.key == "reset":
				Settings.reset_defaults()
				Settings.save_settings()
				Sfx.play("paddle", -8.0)
				queue_redraw()
			else:
				closed.emit()


func _commit() -> void:
	Settings.apply()
	Settings.save_settings()
	Sfx.play("paddle", -10.0)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if _waiting_action != "":
		if event is InputEventKey and event.pressed and not event.echo:
			accept_event()
			if (event as InputEventKey).keycode != KEY_ESCAPE:
				var physical := (event as InputEventKey).physical_keycode
				if physical == KEY_NONE:
					physical = (event as InputEventKey).keycode
				Settings.rebind(_waiting_action, physical)
				Settings.save_settings()
				Sfx.play("paddle", -6.0)
			_waiting_action = ""
			queue_redraw()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		grab_focus()
		for i in _rects.size():
			if _rects[i].has_point(event.position):
				accept_event()
				_selected = i
				# Clique na metade esquerda de um percentual diminui; na direita, aumenta.
				if _rows[i].kind == "percent":
					adjust(i, -1 if event.position.x < _rects[i].get_center().x else 1)
				else:
					activate(i)
				return
	if event.is_action_pressed("ui_cancel"):
		accept_event()
		closed.emit()
		return
	if event.is_action_pressed("ui_down"):
		_selected = (_selected + 1) % _rows.size()
	elif event.is_action_pressed("ui_up"):
		_selected = (_selected - 1 + _rows.size()) % _rows.size()
	elif event.is_action_pressed("ui_right"):
		adjust(_selected, 1)
	elif event.is_action_pressed("ui_left"):
		adjust(_selected, -1)
	elif event.is_action_pressed("ui_accept"):
		accept_event()
		activate(_selected)
		return
	else:
		return
	accept_event()
	queue_redraw()


func _value_text(row: Dictionary) -> String:
	match row.kind:
		"percent":
			return "%d%%" % int(round(float(Settings.get(row.key)) * 100.0))
		"toggle":
			return "LIGADO" if bool(Settings.get(row.key)) else "DESLIGADO"
		"key":
			return "aperte uma tecla..." if _waiting_action == row.key else GameInput.key_label(row.key)
	return ""


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.05, 0.04, 0.04, 0.94))
	var panel := Rect2(vp.x * 0.5 - 520.0, 60.0, 1040.0, vp.y - 120.0)
	ArtDirector.panel(self, panel, Color("#8CFF1A"))
	draw_string(_font, panel.position + Vector2(36, 62), "OPÇÕES", HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color("#8CFF1A"))
	_rects.clear()
	var row_h := 44.0
	for i in _rows.size():
		var row: Dictionary = _rows[i]
		var rect := Rect2(panel.position + Vector2(36, 96 + row_h * i), Vector2(panel.size.x - 72, row_h - 6))
		_rects.append(rect)
		var selected := i == _selected
		draw_rect(rect, Color("#1F2A1A") if selected else Color("#141212"))
		draw_rect(rect, Color("#8CFF1A") if selected else Color(1, 1, 1, 0.10), false, 2.0 if selected else 1.0)
		draw_string(_font, rect.position + Vector2(18, 26), row.label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x * 0.62, 19,
			Color("#FFD400") if selected else Color("#F5F0E1"))
		var value := _value_text(row)
		if value != "":
			var shown := ("◀  " + value + "  ▶") if row.kind == "percent" else value
			draw_string(_font, rect.position + Vector2(rect.size.x * 0.62, 26), shown, HORIZONTAL_ALIGNMENT_RIGHT,
				rect.size.x * 0.38 - 18, 19, Color("#8CFF1A") if selected else Color("#D6C9A8"))
	var hint: String = _rows[_selected].get("hint", "")
	draw_string(_font, Vector2(panel.position.x + 36, panel.end.y - 52), hint, HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 72, 16, Color("#B6A299"))
	draw_string(_font, Vector2(panel.position.x + 36, panel.end.y - 24), "SETAS escolhem e ajustam  •  ENTER altera  •  ESC volta",
		HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 72, 14, Color(1, 1, 1, 0.45))
