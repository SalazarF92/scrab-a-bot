extends Node
## Audio do prototipo, sintetizado em tempo de carga.
##
## O GDD 3.4.3 exige captacao de campo com sucata real na producao. Nada disso
## existe ainda, mas a REGRA que importa para o prototipo e testavel sem asset
## nenhum: "A escala de quique e musical e ascendente. Quatro quiques seguidos
## formam um arpejo." Se o arpejo nao for prazeroso aqui, nenhum sample resolve.
##
## Tambem implementa o limitador de vozes de 4 por som, sem o qual uma build
## tardia vira ruido branco.

const MIX_RATE := 22050
const VOICE_COUNT := 32
const MAX_VOICES_PER_SOUND := 4

## Semitons acima da fundamental por indice de quique. GDD 3.4.3:
## quique 1 base, 2 = +2, 3 = +4, 4 = +7. Um arpejo maior aberto.
const BOUNCE_SEMITONES := [0.0, 2.0, 4.0, 7.0, 12.0]
const BOUNCE_ROOT_HZ := 392.0  # Sol4. Trilha em La menor, ver GDD_ADENDOS E.2.

var master_volume_db: float = -6.0

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _voice_next: int = 0
var _active_per_sound: Dictionary = {}


func _ready() -> void:
	for i in VOICE_COUNT:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_voices.append(p)

	for i in BOUNCE_SEMITONES.size():
		var hz: float = BOUNCE_ROOT_HZ * pow(2.0, BOUNCE_SEMITONES[i] / 12.0)
		# O brilho sobe junto com a nota: quique alto soa mais agudo E mais nitido.
		_streams["bounce_%d" % i] = _make_clank(hz, 0.13 - i * 0.012, 0.55 + i * 0.10)

	_streams["fire_light"] = _make_noise_burst(0.05, 2400.0, 0.35)
	_streams["fire_heavy"] = _make_clank(90.0, 0.28, 0.9)
	_streams["enemy_death"] = _make_pop(0.16)
	_streams["player_hit"] = _make_clank(140.0, 0.22, 1.0)
	_streams["dash"] = _make_noise_burst(0.09, 1200.0, 0.25)
	_streams["overheat"] = _make_kettle(0.6)
	_streams["projectile_plop"] = _make_pop(0.10)


## Toca um som com limitacao de vozes: no maximo 4 instancias simultaneas do
## mesmo som, roubando a mais antiga. GDD 3.4.3.
func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(sound):
		return
	var active: int = _active_per_sound.get(sound, 0)
	if active >= MAX_VOICES_PER_SOUND:
		return

	var player := _voices[_voice_next]
	_voice_next = (_voice_next + 1) % VOICE_COUNT
	player.stream = _streams[sound]
	player.volume_db = master_volume_db + volume_db
	player.pitch_scale = pitch
	player.play()

	_active_per_sound[sound] = active + 1
	var duration: float = (_streams[sound] as AudioStreamWAV).get_length() / maxf(pitch, 0.01)
	get_tree().create_timer(duration, false, false, true).timeout.connect(
		func() -> void: _active_per_sound[sound] = maxi(0, _active_per_sound.get(sound, 1) - 1)
	)


## O som do quique e afinado de proposito e por isso NAO recebe a variacao
## aleatoria de mais ou menos 4% que todo som avulso recebe. GDD 3.4.3.
func play_bounce(bounce_index: int) -> void:
	var i: int = clampi(bounce_index, 0, BOUNCE_SEMITONES.size() - 1)
	play("bounce_%d" % i, -3.0 + i * 1.2, 1.0)


func play_varied(sound: String, volume_db: float = 0.0) -> void:
	play(sound, volume_db, GameRng.randf_range_in(GameRng.Stream.VFX, 0.96, 1.04))


# --- sintese ------------------------------------------------------------------

func _make_clank(freq_hz: float, duration: float, brightness: float) -> AudioStreamWAV:
	# Chapa de metal: uma fundamental com parciais inarmonicos, envelope percussivo.
	var partials := [1.0, 2.76, 5.40, 8.93]
	var samples := int(duration * MIX_RATE)
	var data := PackedFloat32Array()
	data.resize(samples)
	for n in samples:
		var t := float(n) / MIX_RATE
		var env := exp(-t / (duration * 0.28))
		var v := 0.0
		for pi in partials.size():
			var amp: float = brightness if pi > 0 else 1.0
			v += sin(TAU * freq_hz * partials[pi] * t) * amp / (pi + 1.0)
		# Estalo inicial: 4 ms de ruido, e o que da o "tac" antes do tom.
		if t < 0.004:
			v += (randf() * 2.0 - 1.0) * 2.0
		data[n] = v * env * 0.22
	return _to_wav(data)


func _make_noise_burst(duration: float, cutoff_hz: float, decay: float) -> AudioStreamWAV:
	var samples := int(duration * MIX_RATE)
	var data := PackedFloat32Array()
	data.resize(samples)
	var lp := 0.0
	var alpha: float = clampf(cutoff_hz / float(MIX_RATE), 0.0, 1.0)
	for n in samples:
		var t := float(n) / MIX_RATE
		var env := exp(-t / (duration * decay))
		lp += alpha * ((randf() * 2.0 - 1.0) - lp)
		data[n] = lp * env * 0.5
	return _to_wav(data)


func _make_pop(duration: float) -> AudioStreamWAV:
	# "Pop" comico de boca: uma senoide que cai rapido de tom.
	var samples := int(duration * MIX_RATE)
	var data := PackedFloat32Array()
	data.resize(samples)
	var phase := 0.0
	for n in samples:
		var t := float(n) / MIX_RATE
		var f := 620.0 * exp(-t * 14.0) + 70.0
		phase += TAU * f / MIX_RATE
		data[n] = sin(phase) * exp(-t / (duration * 0.3)) * 0.4
	return _to_wav(data)


func _make_kettle(duration: float) -> AudioStreamWAV:
	# Chaleira apitando, para o superaquecimento.
	var samples := int(duration * MIX_RATE)
	var data := PackedFloat32Array()
	data.resize(samples)
	for n in samples:
		var t := float(n) / MIX_RATE
		var f := 1800.0 + 400.0 * t / duration
		var env: float = minf(t * 8.0, 1.0) * exp(-maxf(0.0, t - duration * 0.7) * 12.0)
		data[n] = (sin(TAU * f * t) + sin(TAU * f * 1.5 * t) * 0.4) * env * 0.14
	return _to_wav(data)


func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	return wav
