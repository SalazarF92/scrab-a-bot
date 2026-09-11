extends Node
## Audio do prototipo, sintetizado em tempo de carga.
##
## O GDD 3.4.3 exige captacao de campo com sucata real na producao. Nada disso
## existe ainda, mas a REGRA que importa para o prototipo e testavel sem asset
## nenhum: "A escala de quique e musical e ascendente. Quatro quiques seguidos
## formam um arpejo." Se o arpejo nao for prazeroso aqui, nenhum sample resolve.
##
## Roda com a arvore pausada (PROCESS_MODE_ALWAYS). Os menus so existem com o
## jogo pausado, e sem isso o clique de compra da Garagem ficaria mudo.

const MIX_RATE := 22050
const VOICE_COUNT := 32
const MAX_VOICES_PER_SOUND := 4
## Intervalo minimo antes de roubar uma voz do mesmo som. Roubar reinicia um
## playback, o que aloca no servidor de audio; numa build tardia sao dezenas de
## quiques por quadro e, sem este intervalo, o proprio limitador vira o gargalo.
const STEAL_MIN_AGE_USEC := 25000

## Semitons acima da fundamental por indice de quique. GDD 3.4.3:
## quique 1 base, 2 = +2, 3 = +4, 4 = +7. Um arpejo maior aberto.
const BOUNCE_SEMITONES := [0.0, 2.0, 4.0, 7.0, 12.0]
const BOUNCE_ROOT_HZ := 392.0  # Sol4. Trilha em La menor, ver GDD_ADENDOS E.2.

var master_volume_db: float = -6.0

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _voice_sound: Array[String] = []
var _voice_started: PackedInt64Array
var _shutting_down := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_voice_started.resize(VOICE_COUNT)
	for i in VOICE_COUNT:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_voices.append(p)
		_voice_sound.append("")

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
	_streams["paddle"] = _make_boing(0.16)
	_streams["laser_charge"] = _make_laser_charge(0.65)
	_streams["laser_fire"] = _make_laser_fire(0.22)
	_streams["beeper_countdown"] = _make_beeper(0.18)
	_streams["beeper_detonate"] = _make_beeper_detonate(0.40)
	_streams["padlock_lock"] = _make_padlock(0.22)
	_streams["padlock_release"] = _make_padlock_release(0.16)
	_streams["wind_deflect"] = _make_wind(0.24)
	_streams["printer_spawn"] = _make_printer(0.20)
	_streams["keycap_burst"] = _make_mechanical_click(0.08)
	_streams["cable_whip"] = _make_whip(0.18)


## Limitador de vozes, GDD 3.4.3: "maximo de 4 instancias simultaneas por som,
## com roubo da mais antiga." A versao anterior recusava o som novo em vez de
## roubar, e criava um temporizador e uma funcao anonima por som tocado, o que
## numa build tardia sao centenas de alocacoes por segundo.
func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if _shutting_down or not _streams.has(sound):
		return

	var now := Time.get_ticks_usec()
	var same := 0
	var oldest_same := -1
	var free_voice := -1
	var oldest_any := -1
	for v in VOICE_COUNT:
		if not _voices[v].playing:
			if free_voice < 0:
				free_voice = v
			continue
		if oldest_any < 0 or _voice_started[v] < _voice_started[oldest_any]:
			oldest_any = v
		if _voice_sound[v] == sound:
			same += 1
			if oldest_same < 0 or _voice_started[v] < _voice_started[oldest_same]:
				oldest_same = v

	var target := free_voice
	if same >= MAX_VOICES_PER_SOUND:
		if now - _voice_started[oldest_same] < STEAL_MIN_AGE_USEC:
			return
		target = oldest_same
	elif target < 0:
		target = oldest_any

	var player := _voices[target]
	player.stream = _streams[sound]
	player.volume_db = master_volume_db + volume_db
	player.pitch_scale = pitch
	player.play()
	_voice_sound[target] = sound
	_voice_started[target] = now


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
	var noise := RandomNumberGenerator.new()
	noise.seed = int(freq_hz * 1000.0)
	for n in samples:
		var t := float(n) / MIX_RATE
		var env := exp(-t / (duration * 0.28))
		var v := 0.0
		for pi in partials.size():
			var amp: float = brightness if pi > 0 else 1.0
			v += sin(TAU * freq_hz * partials[pi] * t) * amp / (pi + 1.0)
		# Estalo inicial: 4 ms de ruido, e o que da o "tac" antes do tom.
		if t < 0.004:
			v += (noise.randf() * 2.0 - 1.0) * 2.0
		data[n] = v * env * 0.22
	return _to_wav(data)


func _make_noise_burst(duration: float, cutoff_hz: float, decay: float) -> AudioStreamWAV:
	var samples := int(duration * MIX_RATE)
	var data := PackedFloat32Array()
	data.resize(samples)
	var noise := RandomNumberGenerator.new()
	noise.seed = int(cutoff_hz)
	var lp := 0.0
	var alpha: float = clampf(cutoff_hz / float(MIX_RATE), 0.0, 1.0)
	for n in samples:
		var t := float(n) / MIX_RATE
		var env := exp(-t / (duration * decay))
		lp += alpha * ((noise.randf() * 2.0 - 1.0) - lp)
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


func _make_boing(duration: float) -> AudioStreamWAV:
	# Mola de sofa: o tom sobe e oscila. E o som do rebatedor.
	var samples := int(duration * MIX_RATE)
	var data := PackedFloat32Array()
	data.resize(samples)
	var phase := 0.0
	for n in samples:
		var t := float(n) / MIX_RATE
		var f := 180.0 + 260.0 * (1.0 - exp(-t * 18.0)) + sin(t * 60.0) * 14.0
		phase += TAU * f / MIX_RATE
		data[n] = sin(phase) * exp(-t / (duration * 0.35)) * 0.35
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


func _make_laser_charge(duration: float) -> AudioStreamWAV:
	# Carga do Olhudo: tom senoidal subindo de 240 Hz a 900 Hz com vibrato e rampa de ganho.
	var samples := int(duration * MIX_RATE)
	var data := PackedFloat32Array()
	data.resize(samples)
	var phase := 0.0
	for n in samples:
		var t := float(n) / MIX_RATE
		var progress := t / duration
		var freq: float = 240.0 + 660.0 * pow(progress, 1.6) + sin(t * 50.0) * 12.0
		phase += TAU * freq / MIX_RATE
		var env: float = (1.0 - cos(minf(progress * PI, PI * 0.5))) * 0.28
		data[n] = (sin(phase) + sin(phase * 2.0) * 0.25) * env
	return _to_wav(data)


func _make_laser_fire(duration: float) -> AudioStreamWAV:
	# Disparo de laser: sweep exponencial descendente de 1600 Hz para 120 Hz + estalo elétrico.
	var samples := int(duration * MIX_RATE)
	var data := PackedFloat32Array()
	data.resize(samples)
	var noise := RandomNumberGenerator.new()
	noise.seed = 44210
	var phase := 0.0
	for n in samples:
		var t := float(n) / MIX_RATE
		var freq: float = 1600.0 * exp(-t * 22.0) + 120.0
		phase += TAU * freq / MIX_RATE
		var env := exp(-t / (duration * 0.35))
		var wave: float = sin(phase)
		wave = clampf(wave * 1.5, -1.0, 1.0)
		if t < 0.015:
			wave += (noise.randf() * 2.0 - 1.0) * 0.6
		data[n] = wave * env * 0.35
	return _to_wav(data)


func _make_beeper(duration: float) -> AudioStreamWAV:
	# BIP! BIP! do Bipador: dois pulsos agudos curtos (1760 Hz / La6).
	var samples := int(duration * MIX_RATE)
	var data := PackedFloat32Array()
	data.resize(samples)
	var p1_len := duration * 0.32
	var p2_start := duration * 0.50
	var p2_len := duration * 0.32
	for n in samples:
		var t := float(n) / MIX_RATE
		var env := 0.0
		if t < p1_len:
			env = sin((t / p1_len) * PI)
		elif t >= p2_start and t < p2_start + p2_len:
			env = sin(((t - p2_start) / p2_len) * PI)
		var s := sin(TAU * 1760.0 * t)
		data[n] = s * env * 0.28
	return _to_wav(data)


func _make_beeper_detonate(duration: float) -> AudioStreamWAV:
	# Explosão autodestrutiva: sub-grave caindo + crunch percussivo de sucata.
	var samples := int(duration * MIX_RATE)
	var data := PackedFloat32Array()
	data.resize(samples)
	var noise := RandomNumberGenerator.new()
	noise.seed = 99823
	var phase := 0.0
	for n in samples:
		var t := float(n) / MIX_RATE
		var f: float = 140.0 * exp(-t * 10.0) + 45.0
		phase += TAU * f / MIX_RATE
		var env := exp(-t / (duration * 0.32))
		var sub := sin(phase) * 0.5
		var crunch: float = (noise.randf() * 2.0 - 1.0) * exp(-t / (duration * 0.18)) * 0.5
		var sample := clampf((sub + crunch) * 1.4, -1.0, 1.0)
		data[n] = sample * env * 0.42
	return _to_wav(data)


func _make_padlock(duration: float) -> AudioStreamWAV:
	# Tranca do Cadeado Chorão: dois impactos mecânicos metálicos (latch trancando).
	var samples := int(duration * MIX_RATE)
	var data := PackedFloat32Array()
	data.resize(samples)
	var noise := RandomNumberGenerator.new()
	noise.seed = 77123
	for n in samples:
		var t := float(n) / MIX_RATE
		var v := 0.0
		if t < 0.05:
			var env1 := exp(-t / 0.012)
			v += (sin(TAU * 880.0 * t) * 0.4 + (noise.randf() * 2.0 - 1.0) * 0.6) * env1
		if t >= 0.055:
			var t2 := t - 0.055
			var env2 := exp(-t2 / (duration * 0.28))
			var metal := sin(TAU * 420.0 * t2) + sin(TAU * 1150.0 * t2) * 0.6 + sin(TAU * 2280.0 * t2) * 0.35
			if t2 < 0.005:
				metal += (noise.randf() * 2.0 - 1.0) * 1.5
			v += metal * env2 * 0.5
		data[n] = clampf(v * 0.32, -1.0, 1.0)
	return _to_wav(data)


func _make_padlock_release(duration: float) -> AudioStreamWAV:
	# Cadeado destrancando: estalo de mola e ressonância metálica aguda (tinido).
	var samples := int(duration * MIX_RATE)
	var data := PackedFloat32Array()
	data.resize(samples)
	for n in samples:
		var t := float(n) / MIX_RATE
		var env := exp(-t / (duration * 0.35))
		var chime := sin(TAU * 1480.0 * t) * 0.6 + sin(TAU * 2960.0 * t) * 0.4
		data[n] = chime * env * 0.25
	return _to_wav(data)


func _make_wind(duration: float) -> AudioStreamWAV:
	# Rajada de vento do Zé Ventoinha: ruído filtrado passa-baixa modulado em amplitude.
	var samples := int(duration * MIX_RATE)
	var data := PackedFloat32Array()
	data.resize(samples)
	var noise := RandomNumberGenerator.new()
	noise.seed = 33112
	var lp := 0.0
	for n in samples:
		var t := float(n) / MIX_RATE
		var progress := t / duration
		var env := sin(progress * PI)
		var cutoff: float = 700.0 + 400.0 * sin(progress * PI)
		var alpha: float = clampf(cutoff / float(MIX_RATE), 0.0, 1.0)
		lp += alpha * ((noise.randf() * 2.0 - 1.0) - lp)
		data[n] = lp * env * 0.35
	return _to_wav(data)


func _make_printer(duration: float) -> AudioStreamWAV:
	# Fabricadora 3D: zumbido de motor de passo com 3 degraus de frequência.
	var samples := int(duration * MIX_RATE)
	var data := PackedFloat32Array()
	data.resize(samples)
	for n in samples:
		var t := float(n) / MIX_RATE
		var step := int((t / duration) * 3.0)
		var freqs := [520.0, 780.0, 1040.0]
		var f: float = freqs[clampi(step, 0, 2)]
		var env := 1.0 - (t / duration) * 0.3
		var wave := sin(TAU * f * t) + sin(TAU * f * 2.0 * t) * 0.3
		data[n] = wave * env * 0.22
	return _to_wav(data)


func _make_mechanical_click(duration: float) -> AudioStreamWAV:
	# Tecla mecânica (QWERTYpede): estalo percussivo seco de plástico reforçado.
	var samples := int(duration * MIX_RATE)
	var data := PackedFloat32Array()
	data.resize(samples)
	var noise := RandomNumberGenerator.new()
	noise.seed = 11055
	for n in samples:
		var t := float(n) / MIX_RATE
		var env := exp(-t / (duration * 0.22))
		var v := sin(TAU * 1350.0 * t) * 0.5
		if t < 0.003:
			v += (noise.randf() * 2.0 - 1.0) * 1.8
		data[n] = v * env * 0.30
	return _to_wav(data)


func _make_whip(duration: float) -> AudioStreamWAV:
	# Chicote de cabos: assobio rápido de ar seguido de estalo elétrico.
	var samples := int(duration * MIX_RATE)
	var data := PackedFloat32Array()
	data.resize(samples)
	var noise := RandomNumberGenerator.new()
	noise.seed = 66120
	var lp := 0.0
	for n in samples:
		var t := float(n) / MIX_RATE
		var env := exp(-t / (duration * 0.40))
		var alpha: float = clampf((1800.0 - 1200.0 * (t / duration)) / float(MIX_RATE), 0.0, 1.0)
		lp += alpha * ((noise.randf() * 2.0 - 1.0) - lp)
		var v: float = lp * 0.4
		if t >= 0.03 and t < 0.045:
			v += (sin(TAU * 2200.0 * t) + (noise.randf() * 2.0 - 1.0) * 0.8) * 0.6
		data[n] = v * env * 0.36
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


## Para as vozes atuais, mas permite tocar novamente na mesma sessao.
func stop_all() -> void:
	for p in _voices:
		p.stop()


## Fecha a entrada de sons antes de liberar o audio. Durante a espera de saida
## a fisica ainda pode produzir quiques: so stop_all() permitiria criar novos
## playbacks apos a limpeza, causando o vazamento observado no smoke.
## E definitivo para esta instancia; nao usar para pausar ou trocar de setor.
func shutdown() -> void:
	_shutting_down = true
	stop_all()
	for p in _voices:
		p.stream = null
	_streams.clear()


func _exit_tree() -> void:
	shutdown()
