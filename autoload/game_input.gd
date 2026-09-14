extends Node
## Registro do mapa de input em tempo de execucao.
##
## Feito em codigo e nao no project.godot de proposito: o InputMap serializado
## e verboso, dificil de revisar em diff, e o GDD_ADENDOS C.3 exige remapeamento
## completo. Com o mapa construido aqui, o remapeamento do jogador vira apenas
## uma sobreposicao salva por cima deste padrao.

const DEADZONE := 0.2

## GDD 3.2, esquema de controle padrao.
const ACTIONS := {
	"move_left":   {"keys": [KEY_A, KEY_LEFT],  "axis": [JOY_AXIS_LEFT_X, -1.0]},
	"move_right":  {"keys": [KEY_D, KEY_RIGHT], "axis": [JOY_AXIS_LEFT_X, 1.0]},
	"move_up":     {"keys": [KEY_W, KEY_UP],    "axis": [JOY_AXIS_LEFT_Y, -1.0]},
	"move_down":   {"keys": [KEY_S, KEY_DOWN],  "axis": [JOY_AXIS_LEFT_Y, 1.0]},
	"aim_left":    {"keys": [],                 "axis": [JOY_AXIS_RIGHT_X, -1.0]},
	"aim_right":   {"keys": [],                 "axis": [JOY_AXIS_RIGHT_X, 1.0]},
	"aim_up":      {"keys": [],                 "axis": [JOY_AXIS_RIGHT_Y, -1.0]},
	"aim_down":    {"keys": [],                 "axis": [JOY_AXIS_RIGHT_Y, 1.0]},
	"fire_left":   {"keys": [],  "mouse": MOUSE_BUTTON_LEFT,  "axis": [JOY_AXIS_TRIGGER_LEFT, 1.0]},
	"fire_right":  {"keys": [],  "mouse": MOUSE_BUTTON_RIGHT, "axis": [JOY_AXIS_TRIGGER_RIGHT, 1.0]},
	"dash":        {"keys": [KEY_SPACE, KEY_SHIFT], "button": JOY_BUTTON_A},
	"head_ability":{"keys": [KEY_Q], "mouse": MOUSE_BUTTON_MIDDLE, "button": JOY_BUTTON_RIGHT_SHOULDER},
	"heat_purge":  {"keys": [KEY_E], "button": JOY_BUTTON_LEFT_SHOULDER},
	"status":      {"keys": [KEY_TAB], "button": JOY_BUTTON_START},
	"pause":       {"keys": [KEY_ESCAPE], "button": JOY_BUTTON_BACK},
}


func _ready() -> void:
	for action_name in ACTIONS:
		_register(action_name, ACTIONS[action_name])


func _register(action_name: String, spec: Dictionary) -> void:
	if InputMap.has_action(action_name):
		InputMap.erase_action(action_name)
	InputMap.add_action(action_name, DEADZONE)

	for keycode in spec.get("keys", []):
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode
		InputMap.action_add_event(action_name, ev)

	if spec.has("mouse"):
		var mb := InputEventMouseButton.new()
		mb.button_index = spec["mouse"]
		InputMap.action_add_event(action_name, mb)

	if spec.has("button"):
		var jb := InputEventJoypadButton.new()
		jb.button_index = spec["button"]
		InputMap.action_add_event(action_name, jb)

	if spec.has("axis"):
		var ja := InputEventJoypadMotion.new()
		ja.axis = spec["axis"][0]
		ja.axis_value = spec["axis"][1]
		InputMap.action_add_event(action_name, ja)


## Acoes que o jogador pode remapear no teclado, na ordem da tela de opcoes.
const REBINDABLE := ["move_left", "move_right", "dash", "head_ability", "heat_purge", "pause"]
## Nomes de tecla em portugues para a HUD e as opcoes.
const KEY_NAMES := {"Space": "ESPAÇO", "Escape": "ESC", "Left": "SETA ESQ", "Right": "SETA DIR", "Up": "SETA CIMA", "Down": "SETA BAIXO", "Enter": "ENTER"}


## Reaplica o mapa padrao e troca as teclas das acoes remapeadas. Mouse e
## controle da acao continuam valendo.
func apply_bindings(bindings: Dictionary) -> void:
	for action_name in ACTIONS:
		_register(action_name, ACTIONS[action_name])
		if not bindings.has(action_name):
			continue
		for ev in InputMap.action_get_events(action_name):
			if ev is InputEventKey:
				InputMap.action_erase_event(action_name, ev)
		var key := InputEventKey.new()
		key.physical_keycode = int(bindings[action_name])
		InputMap.action_add_event(action_name, key)


## Nome legivel da primeira tecla ou botao do mouse da acao, ja remapeada.
func key_label(action_name: String) -> String:
	if not InputMap.has_action(action_name):
		return "?"
	for ev in InputMap.action_get_events(action_name):
		if ev is InputEventKey:
			var name := OS.get_keycode_string((ev as InputEventKey).physical_keycode)
			return KEY_NAMES.get(name, name.to_upper())
	for ev in InputMap.action_get_events(action_name):
		if ev is InputEventMouseButton:
			match (ev as InputEventMouseButton).button_index:
				MOUSE_BUTTON_LEFT: return "CLIQUE E"
				MOUSE_BUTTON_RIGHT: return "CLIQUE D"
				MOUSE_BUTTON_MIDDLE: return "CLIQUE MEIO"
	return "?"
