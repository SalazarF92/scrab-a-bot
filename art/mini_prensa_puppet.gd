class_name MiniPrensaPuppet
extends RefCounted
## Rig mecânico 2D articulado da Mini-Prensa 500 (Boss do Setor 1).
## Implementa o padrão de 10 passos de animação modular rígida:
## 1. Peças isoladas e ordenadas rigidamente (chassi, mandíbula superior, pistões, núcleo, engrenagem, chaminé e pés)
## 2. Posições e ângulos calculados estritamente pelo playhead (linha do tempo absoluta)
## 3. Rotações e deslocamentos rígidos com Transform2D em torno dos pivôs (dobradiça traseira, montagens dos pistões)
## 4. Sem deformações volumétricas elásticas de chapas de aço nem cross-fade borrado de transparência
## 5. Z-order correto: sombra -> shockwaves/poeira -> pés -> chassi -> núcleo de fornalha -> mandíbula superior -> pistões -> chaminé -> vapor

enum Action { WALK, ATTACK, POWER, IDLE }

const ATLAS_PATH := "res://assets/art/mini_prensa_pieces.png"

# Regiões no atlas mini_prensa_pieces.png:
const RECT_HEAD := Rect2(0, 0, 320, 240)
const RECT_CHASSIS := Rect2(330, 0, 320, 240)
const RECT_CORE := Rect2(660, 0, 160, 140)
const RECT_GEAR := Rect2(830, 0, 70, 70)
const RECT_FOOT_L := Rect2(0, 250, 110, 85)
const RECT_FOOT_R := Rect2(120, 250, 110, 85)
const RECT_CHIMNEY := Rect2(240, 250, 120, 60)
const RECT_PISTON_SLEEVE := Rect2(370, 250, 40, 90)
const RECT_PISTON_ROD := Rect2(420, 250, 24, 100)

# Duração dos ciclos em segundos:
const WALK_DURATION := 0.75
const ATTACK_DURATION := 1.70
const POWER_DURATION := 2.60


## Calcula analiticamente todas as poses das peças para o tempo playhead:
static func compute_pose(action: Action, playhead: float) -> Dictionary:
	var pose := {
		"body_offset": Vector2.ZERO,
		"body_tilt": 0.0,
		"head_angle": 0.0,
		"head_extra_offset": Vector2.ZERO,
		"foot_l_offset": Vector2.ZERO,
		"foot_r_offset": Vector2.ZERO,
		"foot_l_rot": 0.0,
		"foot_r_rot": 0.0,
		"core_glow": 0.0,
		"gear_rot": 0.0,
		"chimney_offset": Vector2.ZERO,
		"shake_request": 0.0,
		"footstep": -1,
		"impact_event": false,
		"steam_intensity": 0.0,
	}

	match action:
		Action.WALK:
			_compute_walk(playhead, pose)
		Action.ATTACK:
			_compute_attack(playhead, pose)
		Action.POWER:
			_compute_power(playhead, pose)
		Action.IDLE:
			_compute_idle(playhead, pose)

	return pose


static func _compute_walk(playhead: float, p: Dictionary) -> void:
	var phase := fmod(playhead, WALK_DURATION) / WALK_DURATION
	var tau_phase := phase * TAU

	# Balanço lateral mecânico e bobbing dos pistões:
	var sway := sin(tau_phase) * 9.0
	var bob := -absf(sin(tau_phase)) * 8.0
	var tilt := -sin(tau_phase) * 0.035

	p["body_offset"] = Vector2(sway, bob)
	p["body_tilt"] = tilt

	# Mandíbula oscila suavemente com compressão pneumática (respiração de máquina):
	p["head_angle"] = -absf(sin(tau_phase * 2.0)) * 0.05
	p["gear_rot"] = playhead * 1.5

	# Passada mecânica dos pés/esteiras:
	# Fase 0.0 a 0.5: Pé esquerdo avança no ar e pousa; pé direito recua apoiado no chão
	# Fase 0.5 a 1.0: Pé direito avança no ar e pousa; pé esquerdo recua apoiado no chão
	if phase < 0.5:
		var p_sub := phase / 0.5
		var stride_x := lerpf(-22.0, 22.0, p_sub)
		var lift_y := -sin(p_sub * PI) * 14.0
		var foot_pitch := sin(p_sub * PI) * 0.12
		p["foot_l_offset"] = Vector2(stride_x, lift_y)
		p["foot_l_rot"] = -foot_pitch
		p["foot_r_offset"] = Vector2(lerpf(22.0, -22.0, p_sub), 0.0)
		p["foot_r_rot"] = 0.0
		if p_sub > 0.88 and p_sub < 0.95:
			p["footstep"] = 0
	else:
		var p_sub := (phase - 0.5) / 0.5
		var stride_x := lerpf(-22.0, 22.0, p_sub)
		var lift_y := -sin(p_sub * PI) * 14.0
		var foot_pitch := sin(p_sub * PI) * 0.12
		p["foot_r_offset"] = Vector2(stride_x, lift_y)
		p["foot_r_rot"] = foot_pitch
		p["foot_l_offset"] = Vector2(lerpf(22.0, -22.0, p_sub), 0.0)
		p["foot_l_rot"] = 0.0
		if p_sub > 0.88 and p_sub < 0.95:
			p["footstep"] = 1

	# Vibração da tampa da chaminé:
	p["chimney_offset"] = Vector2(0.0, -sin(tau_phase * 2.0) * 3.0)


static func _compute_attack(playhead: float, p: Dictionary) -> void:
	var cycle := fmod(playhead, ATTACK_DURATION)

	# FASE 1: Antecipação / Levantamento Hidráulico (0.00s a 0.70s)
	if cycle < 0.70:
		var prog := cycle / 0.70
		var ease_p := smoothstep(0.0, 1.0, prog)
		var squat := 14.0 * ease_p
		var shudder := sin(playhead * 55.0) * 1.5 * prog
		p["body_offset"] = Vector2(shudder, squat)
		p["body_tilt"] = -0.04 * ease_p

		# Mandíbula abre amplamente para trás em torno da dobradiça traseira:
		p["head_angle"] = lerpf(0.0, -0.45, ease_p)
		p["core_glow"] = ease_p * 0.75
		p["gear_rot"] = playhead * 4.0
		p["chimney_offset"] = Vector2(0, -6.0 * ease_p)

	# FASE 2: O Golpe Hidráulico / Descida Acelerada (0.70s a 0.88s)
	elif cycle < 0.88:
		var prog := (cycle - 0.70) / 0.18
		var cubic := prog * prog * prog # Aceleração cúbica violenta (p^3)
		var squat := lerpf(14.0, 32.0, cubic)
		p["body_offset"] = Vector2(0.0, squat)
		p["body_tilt"] = lerpf(-0.04, 0.02, prog)

		# Mandíbula bate com velocidade esmagadora:
		p["head_angle"] = lerpf(-0.45, 0.04, cubic)
		p["core_glow"] = (1.0 - prog) * 0.75
		p["gear_rot"] = playhead * 8.0

		if prog >= 0.92:
			p["impact_event"] = true
			p["shake_request"] = 18.0

	# FASE 3: Impacto, Esmagamento e Rebote Amortecido (0.88s a 1.30s)
	elif cycle < 1.30:
		var prog := (cycle - 0.88) / 0.42
		# Mola com amortecimento exponencial e oscilação cosenoidal:
		var spring := exp(-7.5 * prog) * cos(17.0 * prog)
		p["body_offset"] = Vector2(0.0, 24.0 * spring)
		p["body_tilt"] = 0.03 * spring
		p["head_angle"] = 0.05 * spring
		p["chimney_offset"] = Vector2(0.0, -12.0 * spring)

	# FASE 4: Recuperação e Retorno ao Neutro (1.30s a ATTACK_DURATION)
	else:
		var prog := (cycle - 1.30) / (ATTACK_DURATION - 1.30)
		var ease_p := smoothstep(0.0, 1.0, prog)
		p["body_offset"] = Vector2.ZERO
		p["body_tilt"] = 0.0
		p["head_angle"] = 0.0
		p["core_glow"] = 0.0
		p["chimney_offset"] = Vector2.ZERO


static func _compute_power(playhead: float, p: Dictionary) -> void:
	var cycle := fmod(playhead, POWER_DURATION)

	# FASE 1: Destravamento das Travas & Abertura da Fornalha (0.00s a 0.50s)
	if cycle < 0.50:
		var prog := cycle / 0.50
		var ease_p := smoothstep(0.0, 1.0, prog)
		p["body_offset"] = Vector2(sin(playhead * 40.0) * 1.5 * ease_p, -6.0 * ease_p)
		p["head_angle"] = lerpf(0.0, -0.38, ease_p)
		p["core_glow"] = ease_p * 1.0
		p["gear_rot"] = playhead * (2.0 + 8.0 * ease_p)
		p["chimney_offset"] = Vector2(0, -18.0 * ease_p)
		p["steam_intensity"] = ease_p * 0.4

	# FASE 2: Sobrecarga Térmica Contínua & Jatos de Vapor (0.50s a 2.10s)
	elif cycle < 2.10:
		var t_active := cycle - 0.50
		var pulse := sin(t_active * 12.0)
		var shiver := Vector2(sin(playhead * 60.0) * 1.8, cos(playhead * 45.0) * 1.2)
		var float_bob := -8.0 + sin(t_active * 7.0) * 4.0
		p["body_offset"] = shiver + Vector2(0, float_bob)
		p["head_angle"] = -0.38 + pulse * 0.04
		p["core_glow"] = 1.0 + pulse * 0.35 # Brilho intenso pulsante
		p["gear_rot"] = playhead * 10.0 # Giro veloz em rotação máxima
		p["chimney_offset"] = Vector2(0, -18.0 + sin(t_active * 20.0) * 4.0)
		p["steam_intensity"] = 1.0

	# FASE 3: Fechamento das Válvulas e Resfriamento (2.10s a POWER_DURATION)
	else:
		var prog := (cycle - 2.10) / (POWER_DURATION - 2.10)
		var ease_p := smoothstep(0.0, 1.0, prog)
		p["body_offset"] = Vector2(0, lerpf(-8.0, 0.0, ease_p))
		p["head_angle"] = lerpf(-0.38, 0.0, ease_p)
		p["core_glow"] = lerpf(1.0, 0.0, ease_p)
		p["gear_rot"] = playhead * lerpf(10.0, 1.0, ease_p)
		p["chimney_offset"] = Vector2(0, lerpf(-18.0, 0.0, ease_p))
		p["steam_intensity"] = lerpf(1.0, 0.0, ease_p)


static func _compute_idle(playhead: float, p: Dictionary) -> void:
	var breath := sin(playhead * 3.0)
	p["body_offset"] = Vector2(0, breath * 2.5)
	p["head_angle"] = -absf(breath) * 0.02
	p["chimney_offset"] = Vector2(0, -breath * 1.5)
	p["gear_rot"] = playhead * 0.5


## Renderiza o puppet modular completo com sobreposição de camadas estrita:
static func draw_puppet(canvas: CanvasItem, tex: Texture2D, center: Vector2, scale_factor: float, pose: Dictionary, tint: Color = Color.WHITE) -> void:
	if tex == null:
		return

	var body_pos: Vector2 = center + (pose.get("body_offset", Vector2.ZERO) as Vector2) * scale_factor
	var body_tilt: float = float(pose.get("body_tilt", 0.0))
	var head_angle: float = float(pose.get("head_angle", 0.0))
	var head_extra: Vector2 = (pose.get("head_extra_offset", Vector2.ZERO) as Vector2) * scale_factor
	var foot_l_off: Vector2 = (pose.get("foot_l_offset", Vector2.ZERO) as Vector2) * scale_factor
	var foot_r_off: Vector2 = (pose.get("foot_r_offset", Vector2.ZERO) as Vector2) * scale_factor
	var foot_l_rot: float = float(pose.get("foot_l_rot", 0.0))
	var foot_r_rot: float = float(pose.get("foot_r_rot", 0.0))
	var core_glow: float = float(pose.get("core_glow", 0.0))
	var gear_rot: float = float(pose.get("gear_rot", 0.0))
	var chimney_off: Vector2 = (pose.get("chimney_offset", Vector2.ZERO) as Vector2) * scale_factor

	# Matriz do chassi inferior:
	var chassis_xform := Transform2D(body_tilt, Vector2.ONE * scale_factor, 0.0, body_pos)

	# Pivô da dobradiça traseira onde a mandíbula superior gira:
	# Localizado na quina inferior traseira do chassi (x=-75, y=10)
	var hinge_local := Vector2(-75.0, 10.0)
	var hinge_world: Vector2 = chassis_xform * hinge_local

	# Matriz da mandíbula superior (rotacionada estritamente em torno da dobradiça):
	var head_rot := body_tilt + head_angle
	var head_xform := Transform2D(head_rot, Vector2.ONE * scale_factor, 0.0, hinge_world)
	# No sprite da cabeça, a dobradiça fica no canto inferior esquerdo: Vector2(-75, 198) relativo ao centro
	var head_center_rel_hinge := Vector2(75.0, -198.0) + head_extra

	# Pontos de ancoragem dos pistões hidráulicos (calculados rigidamente):
	var p_base_l: Vector2 = chassis_xform * Vector2(-114.0, 15.0)
	var p_base_r: Vector2 = chassis_xform * Vector2(106.0, 18.0)
	var p_head_l: Vector2 = head_xform * (head_center_rel_hinge + Vector2(-114.0, 148.0))
	var p_head_r: Vector2 = head_xform * (head_center_rel_hinge + Vector2(98.0, 152.0))

	# =========================================================================
	# CAMADA 1: Pés / Esteiras de Apoio
	# =========================================================================
	# Pé esquerdo:
	var pos_foot_l: Vector2 = (chassis_xform * Vector2(-95.0, 75.0)) + foot_l_off
	var xf_foot_l := Transform2D(body_tilt + foot_l_rot, Vector2.ONE * scale_factor, 0.0, pos_foot_l)
	canvas.draw_set_transform_matrix(xf_foot_l)
	canvas.draw_texture_rect_region(tex, Rect2(-55, -42, 110, 85), RECT_FOOT_L, tint)

	# Pé direito:
	var pos_foot_r: Vector2 = (chassis_xform * Vector2(95.0, 75.0)) + foot_r_off
	var xf_foot_r := Transform2D(body_tilt + foot_r_rot, Vector2.ONE * scale_factor, 0.0, pos_foot_r)
	canvas.draw_set_transform_matrix(xf_foot_r)
	canvas.draw_texture_rect_region(tex, Rect2(-55, -42, 110, 85), RECT_FOOT_R, tint)

	# =========================================================================
	# CAMADA 2: Cavidade Traseira e Núcleo da Fornalha (Interior da Boca)
	# =========================================================================
	# O núcleo fica no interior entre as mandíbulas:
	var core_pos: Vector2 = chassis_xform * Vector2(6.0, -45.0)
	var xf_core := Transform2D(body_tilt, Vector2.ONE * scale_factor, 0.0, core_pos)
	canvas.draw_set_transform_matrix(xf_core)

	# Se a boca estiver abrindo ou houver fogo:
	if core_glow > 0.01:
		var pulse_scale := 1.0 + core_glow * 0.12
		canvas.draw_set_transform_matrix(Transform2D(body_tilt, Vector2.ONE * (scale_factor * pulse_scale), 0.0, core_pos))
		var core_col := Color(1.0 + core_glow * 0.5, 0.9 + core_glow * 0.4, 0.7 + core_glow * 0.3, 1.0)
		canvas.draw_texture_rect_region(tex, Rect2(-80, -70, 160, 140), RECT_CORE, core_col * tint)

		# Engrenagem interna em rotação real:
		var gear_pos: Vector2 = core_pos + Vector2(10.0, 8.0) * scale_factor
		var xf_gear := Transform2D(gear_rot, Vector2.ONE * scale_factor, 0.0, gear_pos)
		canvas.draw_set_transform_matrix(xf_gear)
		canvas.draw_texture_rect_region(tex, Rect2(-35, -35, 70, 70), RECT_GEAR, tint)
	else:
		# Fundo escuro de metal ferrugem
		canvas.draw_texture_rect_region(tex, Rect2(-80, -70, 160, 140), RECT_CORE, Color(0.25, 0.2, 0.18, 1.0) * tint)

	# =========================================================================
	# CAMADA 3: Chassi Inferior (Mandíbula Inferior, Dentes e Caixa de Britagem)
	# =========================================================================
	canvas.draw_set_transform_matrix(chassis_xform)
	canvas.draw_texture_rect_region(tex, Rect2(-160, -120, 320, 240), RECT_CHASSIS, tint)

	# =========================================================================
	# CAMADA 4: Mandíbula Superior (Cabeça, Olhos, Faixa de Risco e Dentes Superiores)
	# =========================================================================
	canvas.draw_set_transform_matrix(head_xform)
	var head_rect := Rect2(head_center_rel_hinge.x - 160.0, head_center_rel_hinge.y - 120.0, 320.0, 240.0)
	canvas.draw_texture_rect_region(tex, head_rect, RECT_HEAD, tint)

	# =========================================================================
	# CAMADA 5: Tampa da Chaminé (Topo da Cabeça)
	# =========================================================================
	var chimney_world: Vector2 = (head_xform * (head_center_rel_hinge + Vector2(0.0, -118.0))) + chimney_off
	var xf_chimney := Transform2D(head_rot, Vector2.ONE * scale_factor, 0.0, chimney_world)
	canvas.draw_set_transform_matrix(xf_chimney)
	canvas.draw_texture_rect_region(tex, Rect2(-60, -30, 120, 60), RECT_CHIMNEY, tint)

	# =========================================================================
	# CAMADA 6: Pistões Hidráulicos Articulados (Conectam Base à Mandíbula)
	# =========================================================================
	_draw_piston(canvas, tex, p_base_l, p_head_l, scale_factor, tint)
	_draw_piston(canvas, tex, p_base_r, p_head_r, scale_factor, tint)

	# Restaura matriz limpa:
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


## Desenha um pistão telescópico rígido perfeitamente conectado entre dois pontos:
static func _draw_piston(canvas: CanvasItem, tex: Texture2D, p_base: Vector2, p_head: Vector2, scale_factor: float, tint: Color) -> void:
	var delta := p_head - p_base
	var dist := delta.length()
	if dist < 1.0:
		return
	var angle := delta.angle() - PI * 0.5 # Rotação alinhada ao eixo Y

	# Haste interna de aço cromado (vai da ponta do cilindro até a cabeça):
	var rod_xform := Transform2D(angle, Vector2.ONE * scale_factor, 0.0, p_base)
	canvas.draw_set_transform_matrix(rod_xform)
	var rod_len := dist / scale_factor
	var rod_rect := Rect2(-8, 0, 16, rod_len)
	# Desenha a haste com brilho metálico cromado:
	canvas.draw_rect(rod_rect, Color("#3A4048") * tint)
	canvas.draw_rect(Rect2(-6, 0, 12, rod_len), Color("#D2D8DF") * tint)
	canvas.draw_rect(Rect2(-2, 0, 4, rod_len), Color("#FFFFFF") * tint)

	# Luva cilíndrica laranja (comprimento fixo saindo da base):
	var sleeve_len := minf(55.0, rod_len * 0.65)
	var sleeve_rect := Rect2(-15, 0, 30, sleeve_len)
	canvas.draw_rect(sleeve_rect.grow(1.5), Color("#1B120E") * tint)
	canvas.draw_rect(sleeve_rect, Color("#D35400") * tint)
	# Tampa de vedação e parafusos da luva:
	canvas.draw_rect(Rect2(-17, sleeve_len - 6, 34, 6), Color("#2C1D16") * tint)
	canvas.draw_rect(Rect2(-16, sleeve_len - 5, 32, 4), Color("#E67E22") * tint)
