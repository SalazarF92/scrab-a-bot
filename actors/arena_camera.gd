class_name ArenaCamera
extends Camera2D
## Camera da arena. GDD 3.4.4 e GDD_ADENDOS E.1.
##
## Tres comportamentos, todos exigidos pelo pilar 1:
##  - zoom dinamico de 1,0 a 1,25 conforme o numero de inimigos vivos e a
##    dispersao deles (GDD 3.3.4 e 3.4.4);
##  - antecipacao na direcao da mira, que e o que faz o jogador enxergar para
##    onde esta atirando em vez de para onde esta o proprio corpo;
##  - tremor por trauma, lido do CombatFeel.

const SMOOTH := 8.0

var target: Robot
var _base_position: Vector2


func _ready() -> void:
	position_smoothing_enabled = false
	ignore_rotation = false


func _process(delta: float) -> void:
	var center := Vector2(ArenaGenerator.ARENA_SIZE.x * 0.5, ArenaGenerator.ARENA_SIZE.y * 0.5)
	var nudge := Vector2.ZERO
	if target != null and is_instance_valid(target):
		nudge = target.aim_direction * 24.0

	var want := center + nudge
	_base_position = _base_position.lerp(want, minf(1.0, delta * SMOOTH))
	zoom = Vector2.ONE

	global_position = _base_position + CombatFeel.shake_offset()
	rotation = CombatFeel.shake_rotation()


func snap_to(pos: Vector2) -> void:
	_base_position = pos
	global_position = pos
