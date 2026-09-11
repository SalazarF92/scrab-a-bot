extends Node
## Regressao do ciclo de vida do pool: rajadas no _ready, roubo de vozes,
## sons com a arvore pausada e liberacao de todos os playbacks no fim.
## Nao modifica nem grava metaprogressao.

var _playbacks: Array[WeakRef] = []
var _ids: Dictionary = {}
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("=== SCRAP-A-BOT :: limpeza de audio ===")
	for k in 12:
		Sfx.play("overheat")
		_remember_playbacks()
	var assigned := 0
	for name_value in Sfx._voice_sound:
		if name_value == "overheat":
			assigned += 1
	_check(assigned == Sfx.MAX_VOICES_PER_SOUND,
		"rajada anterior ao primeiro quadro deveria ocupar quatro vozes, ocupou %d" % assigned)

	get_tree().paused = true
	for batch in 6:
		await get_tree().create_timer(0.04, true, false, true).timeout
		for k in 6:
			Sfx.play("overheat")
			Sfx.play_bounce(k % 5)
			_remember_playbacks()
	_check(not Sfx._voices[0].stream_paused, "audio deve continuar com menus pausados")
	Sfx.stop_all()
	await get_tree().create_timer(0.3, true, false, true).timeout
	for playback_ref in _playbacks:
		_check(playback_ref.get_ref() == null, "playback permaneceu retido apos stop_all")
	for player in Sfx._voices:
		_check(not player.playing and not player.has_stream_playback(), "voz permaneceu ativa apos stop_all")
	Sfx.play("paddle")
	_remember_playbacks()
	Sfx.shutdown()
	# Imita o benchmark que continua emitindo quiques durante a espera do quit.
	for k in 30:
		Sfx.play_bounce(k % 5)
		await get_tree().create_timer(0.01, true, false, true).timeout
	Sfx.shutdown() # O fechamento tambem precisa aceitar reentrada.
	for playback_ref in _playbacks:
		_check(playback_ref.get_ref() == null, "playback permaneceu retido apos shutdown")
	for player in Sfx._voices:
		_check(player.stream == null and not player.has_stream_playback(),
			"som tardio criou playback durante o fechamento")
	get_tree().paused = false
	if _failures.is_empty():
		print("  %d playbacks liberados; rajadas, roubo e pausa verificados" % _playbacks.size())
		print("=== TUDO OK ===")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		get_tree().quit(1)


func _remember_playbacks() -> void:
	for player in Sfx._voices:
		if player.has_stream_playback():
			var playback := player.get_stream_playback()
			var instance_id := playback.get_instance_id()
			if not _ids.has(instance_id):
				_ids[instance_id] = true
				_playbacks.append(weakref(playback))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
