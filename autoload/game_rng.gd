extends Node
## Aleatoriedade da run, com fluxos separados por sistema.
## GDD 7.3: "Toda a aleatoriedade da run passa por um unico RandomNumberGenerator
## semeado, com fluxos separados por sistema."
##
## Fluxos separados importam porque, se o VFX e os drops compartilham um fluxo,
## mudar a quantidade de faiscas muda quais pecas caem. Isso quebra a reproducao
## de bug a partir de um relatorio e quebra os contratos diarios.

enum Stream { DROPS, ROOMGEN, VFX, COMBAT, AI }

var run_seed: int = 0

var _streams: Dictionary = {}


func _ready() -> void:
	reseed(Time.get_unix_time_from_system() as int)


## Semeia todos os fluxos a partir de uma unica semente de run.
func reseed(seed_value: int) -> void:
	run_seed = seed_value
	_streams.clear()
	for s in Stream.values():
		var rng := RandomNumberGenerator.new()
		# Deslocamento por fluxo: mesma semente de run, sequencias independentes.
		rng.seed = hash(str(seed_value) + "|" + str(s))
		_streams[s] = rng


## Semente do contrato diario, derivavel da data em UTC sem servidor.
## Ver GDD_ADENDOS E.4.
func daily_seed() -> int:
	var d := Time.get_datetime_dict_from_system(true)
	return hash("scrapabot-daily-%04d-%02d-%02d" % [d.year, d.month, d.day])


func stream(s: Stream) -> RandomNumberGenerator:
	return _streams[s]


func randf_range_in(s: Stream, from: float, to: float) -> float:
	return _streams[s].randf_range(from, to)


func randi_range_in(s: Stream, from: int, to: int) -> int:
	return _streams[s].randi_range(from, to)


func randf_in(s: Stream) -> float:
	return _streams[s].randf()
