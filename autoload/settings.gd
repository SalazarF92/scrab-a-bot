extends Node
## Opcoes do jogador, separadas do progresso.
##
## GDD 3.4.2: slider de tremor de 0 a 150%, com vinheta substituta em 0%.
## GDD_ADENDOS C.2 e C.3: flashes reduzidos, formas para daltonismo, slider de
## hitstop separado do de tremor e remapeamento de teclado.
## GDD 3.2: assistencia de mira de 45% no controle e 0% no mouse.
##
## Salvo em user://settings.cfg. Os testes trocam `path` antes de gravar.

signal changed

const DEFAULT_PATH := "user://settings.cfg"
const SCALE_MAX := 1.5
## Base do Sfx antes do volume do jogador.
const BASE_VOLUME_DB := -6.0

var path: String = DEFAULT_PATH

var shake: float = 1.0
var hitstop: float = 1.0
var reduced_flashes: bool = false
## Vfx ja nasce com as formas ligadas; a opcao so desliga se o jogador pedir.
var colorblind_shapes: bool = true
var aim_assist_gamepad: float = 0.45
var aim_assist_mouse: float = 0.0
var master_volume: float = 1.0
## Atalhos de desenvolvimento: F1 a F6, B, G, 1 a 3 e R. Ligados por padrao
## so em build de depuracao; um executavel de lancamento nasce sem eles.
var dev_shortcuts: bool = OS.is_debug_build()
## Teclado remapeado: nome da acao -> physical_keycode.
var bindings: Dictionary = {}


func _ready() -> void:
	load_settings()
	apply()


func reset_defaults() -> void:
	shake = 1.0
	hitstop = 1.0
	reduced_flashes = false
	colorblind_shapes = true
	aim_assist_gamepad = 0.45
	aim_assist_mouse = 0.0
	master_volume = 1.0
	dev_shortcuts = OS.is_debug_build()
	bindings = {}
	apply()


## Empurra os valores para os sistemas que os leem.
func apply() -> void:
	shake = clampf(shake, 0.0, SCALE_MAX)
	hitstop = clampf(hitstop, 0.0, SCALE_MAX)
	aim_assist_gamepad = clampf(aim_assist_gamepad, 0.0, 1.0)
	aim_assist_mouse = clampf(aim_assist_mouse, 0.0, 1.0)
	master_volume = clampf(master_volume, 0.0, 1.0)
	CombatFeel.shake_scale = shake
	CombatFeel.hitstop_scale = hitstop
	Vfx.reduced_flashes = reduced_flashes
	Vfx.colorblind_shapes = colorblind_shapes
	Sfx.master_volume_db = BASE_VOLUME_DB + (linear_to_db(master_volume) if master_volume > 0.001 else -80.0)
	GameInput.apply_bindings(bindings)
	changed.emit()


func rebind(action_name: String, physical_keycode: int) -> void:
	bindings[action_name] = physical_keycode
	apply()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("feel", "shake", shake)
	cfg.set_value("feel", "hitstop", hitstop)
	cfg.set_value("accessibility", "reduced_flashes", reduced_flashes)
	cfg.set_value("accessibility", "colorblind_shapes", colorblind_shapes)
	cfg.set_value("input", "aim_assist_gamepad", aim_assist_gamepad)
	cfg.set_value("input", "aim_assist_mouse", aim_assist_mouse)
	cfg.set_value("input", "bindings", bindings)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("dev", "shortcuts", dev_shortcuts)
	cfg.save(path)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	shake = float(cfg.get_value("feel", "shake", shake))
	hitstop = float(cfg.get_value("feel", "hitstop", hitstop))
	reduced_flashes = bool(cfg.get_value("accessibility", "reduced_flashes", reduced_flashes))
	colorblind_shapes = bool(cfg.get_value("accessibility", "colorblind_shapes", colorblind_shapes))
	aim_assist_gamepad = float(cfg.get_value("input", "aim_assist_gamepad", aim_assist_gamepad))
	aim_assist_mouse = float(cfg.get_value("input", "aim_assist_mouse", aim_assist_mouse))
	master_volume = float(cfg.get_value("audio", "master_volume", master_volume))
	dev_shortcuts = bool(cfg.get_value("dev", "shortcuts", dev_shortcuts))
	var saved = cfg.get_value("input", "bindings", {})
	bindings = saved if typeof(saved) == TYPE_DICTIONARY else {}
