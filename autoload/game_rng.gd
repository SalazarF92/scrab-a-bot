extends Node
## Aleatoriedade da run, com fluxos separados por sistema.
## GDD 7.3: "Toda a aleatoriedade da run passa por um unico RandomNumberGenerator
## semeado, com fluxos separados por sistema."
##
## Fluxos separados importam porque, se o VFX e os drops compartilham um fluxo,
## mudar a quantidade de faiscas muda quais pecas caem. Isso quebra a reproducao
## de bug a partir de um relatorio e quebra os contratos diarios.
##
## SHOP e WAVES existem pelo mesmo motivo. A vitrine dividia o fluxo DROPS com a
## cura por abate, entao a loja dependia de quantos inimigos o jogador matou. O
## diretor de ondas dividia ROOMGEN com o gerador de arena, entao a sala do setor
## 2 dependia de onde o jogador estava no setor 1.

enum Stream { DROPS, ROOMGEN, VFX, COMBAT, AI, SHOP, WAVES }

var run_seed: int = 0

var _streams: Dictionary = {}


func _ready() -> void:
	reseed(fresh_seed())


## Semeia todos os fluxos a partir de uma unica semente de run.
func reseed(seed_value: int) -> void:
	run_seed = seed_value
	_streams.clear()
	for s in Stream.values():
		var rng := RandomNumberGenerator.new()
		# Deslocamento por fluxo: mesma semente de run, sequencias independentes.
		rng.seed = hash(str(seed_value) + "|" + str(s))
		_streams[s] = rng


## Semente nova para uma run comum.
func fresh_seed() -> int:
	return hash("%d|%d" % [int(Time.get_unix_time_from_system() * 1000.0), Time.get_ticks_usec()])


## Semente do desafio diario, derivavel da data em UTC sem servidor.
## Ver GDD_ADENDOS E.4.
func daily_seed() -> int:
	return hash("scrapabot-daily-" + utc_date_key())


func utc_date_key() -> String:
	var d := Time.get_datetime_dict_from_system(true)
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


## Semente em hexadecimal de 8 digitos, para mostrar na tela e num relatorio de bug.
func seed_label(seed_value: int) -> String:
	return "%08X" % (seed_value & 0xFFFFFFFF)


func stream(s: Stream) -> RandomNumberGenerator:
	return _streams[s]


func randf_range_in(s: Stream, from: float, to: float) -> float:
	return _streams[s].randf_range(from, to)


func randi_range_in(s: Stream, from: int, to: int) -> int:
	return _streams[s].randi_range(from, to)


func randf_in(s: Stream) -> float:
	return _streams[s].randf()
