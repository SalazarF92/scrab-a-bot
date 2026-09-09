extends Node
## Hitstop e tremor de camera. GDD 3.4.1 e 3.4.2.
##
## Decisao de arquitetura (ver GDD_ADENDOS D.4): hitstop NAO usa Engine.time_scale,
## porque isso congelaria tambem os efeitos visuais e a interface, que o GDD exige
## que continuem rodando. Em vez disso existe um relogio de combate proprio:
## os sistemas de jogo consultam `frozen` no _physics_process e pulam o passo.
## Como autoloads sao processados antes do resto da arvore, o decremento aqui
## acontece antes de qualquer sistema consultar o valor no mesmo tique.

signal hitstop_started(duration_ms: float)

## GDD 3.4.1: "Nenhum quadro pode ter mais de 130 ms de congelamento,
## exceto os eventos roteirizados de chefe e fusao."
const HITSTOP_CAP_MS := 130.0
const TRAUMA_DECAY := 1.8
const SHAKE_MAX_OFFSET := 14.0
const SHAKE_MAX_ROTATION_DEG := 2.5

## Sliders de acessibilidade. GDD 3.4.2 e GDD_ADENDOS C.3.
var shake_scale: float = 1.0   # 0.0 a 1.5
var hitstop_scale: float = 1.0 # 0.0 a 1.5

var frozen: bool = false
var trauma: float = 0.0

var _freeze_remaining: float = 0.0
var _noise_t: float = 0.0


func _physics_process(delta: float) -> void:
	if _freeze_remaining > 0.0:
		_freeze_remaining -= delta
		frozen = _freeze_remaining > 0.0
	else:
		frozen = false


func _process(delta: float) -> void:
	trauma = maxf(0.0, trauma - TRAUMA_DECAY * delta)
	_noise_t += delta


## GDD 3.4.1, regra de acumulo: "Hitstop nao soma. Vale sempre o maior valor
## pendente." Sem isso uma build de alto DPS trava o jogo em camera lenta
## permanente, que e o bug classico do genero.
func request_hitstop(duration_ms: float, scripted: bool = false) -> void:
	var ms := duration_ms * hitstop_scale
	if not scripted:
		ms = minf(ms, HITSTOP_CAP_MS)
	if ms <= 0.0:
		return
	var seconds := ms * 0.001
	if seconds > _freeze_remaining:
		_freeze_remaining = seconds
		frozen = true
		hitstop_started.emit(ms)


## Sistema de trauma: a amplitude e o trauma ao quadrado, o que deixa tremores
## pequenos sutis e grandes violentos. GDD 3.4.2.
func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func shake_offset() -> Vector2:
	if trauma <= 0.0 or shake_scale <= 0.0:
		return Vector2.ZERO
	var amp := trauma * trauma * shake_scale
	var t := _noise_t * 27.0
	return Vector2(sin(t * 1.13) + sin(t * 2.71) * 0.5, cos(t * 1.61) + cos(t * 3.17) * 0.5) \
		* SHAKE_MAX_OFFSET * amp * 0.66


func shake_rotation() -> float:
	if trauma <= 0.0 or shake_scale <= 0.0:
		return 0.0
	var amp := trauma * trauma * shake_scale
	return deg_to_rad(SHAKE_MAX_ROTATION_DEG) * amp * sin(_noise_t * 21.0)


## Em 0% de tremor o GDD exige substituir por um pulso de vinheta na borda,
## para nao perder a informacao. A HUD le este valor.
func vignette_pulse() -> float:
	return trauma if shake_scale <= 0.001 else 0.0


func reset() -> void:
	frozen = false
	_freeze_remaining = 0.0
	trauma = 0.0
