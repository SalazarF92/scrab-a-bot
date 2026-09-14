class_name CreatureRigView
extends Node2D
## Rigs articulados do bestiario desenhados dentro do combate.
##
## Os puppets de revisao desenham cada peca com draw_polygon, reconstruindo a
## geometria. Medido headless: 5,2 ms por Parafuseta e 2,9 ms por Rato Morto,
## inviavel para um enxame. Aqui as pecas consecutivas que dividem a mesma junta
## viram uma malha, montada uma vez por especie, e cada quadro so troca
## transformacoes: cerca de 0,02 ms por corpo. Geometria, UVs, pivos, ordem de
## desenho e curvas sao as do rig; nada e esticado nem deformado.
##
## A boca usa as mesmas pecas de CreatureMouth. O corte da cavidade pela
## mandibula, que la e recorte de poligono por quadro, aqui e o semiplano
## equivalente em art/mouth_clip.gdshader.
##
## O Olhudo usa a propria cena reutilizavel (scenes/olhudo_rigid.tscn), com o
## laser apontado para o alvo travado pela habilidade do combate.
##
## Fica atras do Enemy (show_behind_parent): telegrafia, marcas e barras de vida
## continuam por cima do corpo.

const ParafusetaRig = preload("res://art/parafuseta_puppet.gd")
const RatoRig = preload("res://art/rato_morto_puppet.gd")
const OlhudoRig = preload("res://art/olhudo_rigid.gd")
const OlhudoScene = preload("res://scenes/olhudo_rigid.tscn")
const CLIP_SHADER = preload("res://art/mouth_clip.gdshader")

enum Species { NONE = -1, PARAFUSETA = 0, RATO_MORTO = 1, OLHUDO = 2 }
const SPECIES_BY_VISUAL := {&"parafuseta": Species.PARAFUSETA, &"rato_morto": Species.RATO_MORTO, &"olhudo": Species.OLHUDO}
## Celula da ilustracao de referencia no atlas de inimigos. O rig ocupa o mesmo
## lugar e tamanho que o recorte estatico ocupava na tela.
const REFERENCE_CELL := {Species.PARAFUSETA: 0, Species.RATO_MORTO: 1}
const BLEND_TIME := 0.16
## O contato ja aplicou o dano; o golpe do rig entra logo antes do impacto.
const CONTACT_LEAD := 0.05
## Relogio do poder do Olhudo: a mira trava em 0,6 s e a emissao comeca em 1,4 s,
## o que casa os 0,8 s de aviso do combate com a carga do rig.
const OLHUDO_WARNING := 0.8
const OLHUDO_CHARGE_START := 0.6
const OLHUDO_EMISSION_START := 1.4
## O Olhudo so vira para o outro lado com o alvo claramente do outro lado.
const OLHUDO_TURN_MARGIN := 60.0
const OLHUDO_EXTENT_SCALE := 1.35

static var _meshes: Dictionary = {}
## Custo medido do desenho dos rigs, lido pelo teste de integracao.
static var draw_usec: int = 0
static var draw_calls: int = 0

var species: int = Species.NONE
var pose: Dictionary = {}
var action: int = -1
var playhead: float = 0.0
var _from_pose: Dictionary = {}
var _blend: float = 1.0
var _root := Transform2D.IDENTITY
var _radius: float = 12.0
var _cavity: MeshCanvas
var _jaw: MeshCanvas
var _arch: MeshCanvas
var _olhudo: Node2D
var _facing: float = 1.0


## Uma malha estatica desenhada no referencial do proprio no. Mover o no nao
## exige redesenhar.
class MeshCanvas extends Node2D:
	var mesh: Mesh
	var texture: Texture2D

	func _draw() -> void:
		if mesh != null:
			draw_mesh(mesh, texture)


func _init() -> void:
	show_behind_parent = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	visible = false
	_cavity = MeshCanvas.new()
	var clip := ShaderMaterial.new()
	clip.shader = CLIP_SHADER
	_cavity.material = clip
	_jaw = MeshCanvas.new()
	_arch = MeshCanvas.new()
	for piece in [_cavity, _jaw, _arch]:
		piece.texture = CreatureMouth.texture()
		add_child(piece)


static func has_rig(visual_id: StringName) -> bool:
	return SPECIES_BY_VISUAL.has(visual_id)


## Chamado a cada ativacao do inimigo no pool.
func bind(enemy: Node2D) -> void:
	species = SPECIES_BY_VISUAL.get(enemy.visual_id, Species.NONE)
	visible = species != Species.NONE
	action = -1
	pose = {}
	_from_pose = {}
	_blend = 1.0
	_facing = 1.0
	_radius = enemy.body_radius
	var creature := species == Species.PARAFUSETA or species == Species.RATO_MORTO
	for piece in [_cavity, _jaw, _arch]:
		piece.visible = creature
	if creature:
		var m := meshes(species)
		_cavity.mesh = m.cavity
		_jaw.mesh = m.jaw
		_arch.mesh = m.arch
		for piece in [_cavity, _jaw, _arch]:
			piece.queue_redraw()
	if species == Species.OLHUDO and _olhudo == null:
		_olhudo = OlhudoScene.instantiate()
		_olhudo.playing = false
		add_child(_olhudo)
	if _olhudo != null:
		_olhudo.visible = species == Species.OLHUDO
	if visible:
		sync(enemy, 0.0)


## Chamado pelo Enemy no fim de cada passo de fisica. Hitstop e pausa param o
## passo, entao congelam o rig no mesmo instante.
func sync(enemy: Node2D, delta: float) -> void:
	if species == Species.NONE:
		return
	modulate = Color(1.3, 1.3, 1.3) if enemy._flash > 0.0 else Color.WHITE
	_radius = enemy.body_radius
	var extent: float = enemy.body_radius * 3.0 + 18.0
	if species == Species.OLHUDO:
		_sync_olhudo(enemy, delta, extent)
	else:
		_sync_creature(enemy, delta, extent)
	queue_redraw()


func _sync_creature(enemy: Node2D, delta: float, extent: float) -> void:
	var m := meshes(species)
	var rig = m.rig
	var next_action: int = rig.Action.WALK
	var next_playhead: float = enemy._phase
	var attack_start: float = rig.IMPACT_TIME - CONTACT_LEAD
	if enemy.is_stunned():
		next_action = rig.Action.IDLE
	elif enemy.anim_since_contact < rig.ATTACK_DURATION - attack_start:
		next_action = rig.Action.ATTACK
		next_playhead = attack_start + enemy.anim_since_contact
	_advance(rig, next_action, next_playhead, delta)

	var cell: Array = m.cell
	var s := minf(extent / float(cell[2]), extent / float(cell[3]))
	var cell_center := Vector2(float(cell[0]) + float(cell[2]) * 0.5, float(cell[1]) + float(cell[3]) * 0.5)
	var pivot: Vector2 = m.pivot
	_root = Transform2D(0.0, Vector2(s, s), 0.0, Vector2(0.0, -extent * 0.1) + (pivot - cell_center) * s)

	var mouth: int = m.mouth_species
	var size: Vector2 = CreatureMouth.layout(mouth).size
	var openness := float(pose.mouth_open)
	var frame := _root * CreatureMouth.mouth_frame(mouth, pose)
	_cavity.transform = frame
	_arch.transform = frame
	_jaw.transform = frame * CreatureMouth.jaw_transform(size, openness)
	var clip := CreatureMouth.clip_half_plane(size, openness)
	var clip_material := _cavity.material as ShaderMaterial
	clip_material.set_shader_parameter("clip_origin", clip[0])
	clip_material.set_shader_parameter("clip_normal", clip[1])


func _sync_olhudo(enemy: Node2D, delta: float, extent: float) -> void:
	if _olhudo == null or not _olhudo.is_node_ready() or not is_inside_tree():
		return
	var mob = enemy._mob
	var next_action: int = OlhudoRig.Action.WATCH
	var next_playhead: float = enemy._phase
	var locked := false
	if mob.warning > 0.0:
		next_action = OlhudoRig.Action.POWER
		next_playhead = OLHUDO_CHARGE_START + (OLHUDO_WARNING - mob.warning)
		locked = true
	elif mob.since_execute < OlhudoRig.DURATION - OLHUDO_EMISSION_START:
		next_action = OlhudoRig.Action.POWER
		next_playhead = OLHUDO_EMISSION_START + mob.since_execute
		locked = true
	var target: Vector2 = enemy.global_position + Vector2(0.0, 400.0)
	if locked:
		target = mob.target
	elif enemy._player != null and is_instance_valid(enemy._player):
		target = enemy._player.body_center()
	if not locked:
		var dx := target.x - enemy.global_position.x
		if dx > OLHUDO_TURN_MARGIN:
			_facing = -1.0
		elif dx < -OLHUDO_TURN_MARGIN:
			_facing = 1.0
	_advance(OlhudoRig, next_action, next_playhead, delta)

	var bounds := OlhudoRig.rest_bounds()
	var s := extent * OLHUDO_EXTENT_SCALE / maxf(bounds.size.x, bounds.size.y)
	var center := bounds.get_center()
	# A lente olha para -x no rig. Espelhar e escala constante de apresentacao.
	_olhudo.transform = Transform2D(0.0, Vector2(s * _facing, s), 0.0,
		Vector2(0.0, -extent * 0.1) - Vector2(center.x * s * _facing, center.y * s))
	_olhudo.apply_pose_aimed(pose, _olhudo.to_local(target))
	enemy.emitter_offset = _olhudo.transform * OlhudoRig.lens_point(pose)


## Troca de acao com transicao continua: a pose de saida e interpolada para a
## nova ao longo de BLEND_TIME, sem saltos.
func _advance(rig, next_action: int, next_playhead: float, delta: float) -> void:
	if next_action != action:
		if not pose.is_empty():
			_from_pose = pose
			_blend = 0.0
		action = next_action
	playhead = next_playhead
	var target: Dictionary = rig.compute_pose(action, playhead)
	_blend = minf(1.0, _blend + delta / BLEND_TIME)
	if _blend < 1.0 and not _from_pose.is_empty():
		pose = rig.blend_pose(_from_pose, target, smoothstep(0.0, 1.0, _blend))
	else:
		pose = target


func _draw() -> void:
	var started := Time.get_ticks_usec()
	_draw_rig()
	draw_usec += Time.get_ticks_usec() - started
	draw_calls += 1


func _draw_rig() -> void:
	if species == Species.NONE:
		return
	ArtDirector.shadow(self, Vector2(3.0, _radius * 0.7), Vector2(_radius * 1.2, _radius * 0.35))
	if species == Species.OLHUDO or pose.is_empty():
		return
	var m := meshes(species)
	var rig = m.rig
	var tex: Texture2D = m.texture
	var joints: Dictionary = rig.group_transforms(pose)
	for batch in m.body:
		draw_mesh(batch.mesh, tex, _root * (joints[batch.group] as Transform2D))
	# Olho: remendo sobre a pupila pintada e iris propria deslocada pelo olhar.
	var eye_frame: Transform2D = _root * rig.eye_frame(pose)
	draw_set_transform_matrix(eye_frame)
	BossEyes.eye_patch(self, rig.EYE_PUPIL, rig.EYE_RADIUS, Color.WHITE)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_mesh(m.iris, tex, eye_frame * Transform2D(0.0, BossEyes.iris_center(rig.EYE_PUPIL, rig.EYE_RADIUS, pose.gaze)))
	# Colar que fecha a regiao da boca antiga; cavidade, mandibula e arcada
	# vem depois, como filhos, na mesma ordem de CreatureMouth.draw.
	draw_mesh(m.collar, CreatureMouth.repair_texture(), _root * CreatureMouth.collar_frame(m.mouth_species, pose))


# --- malhas estaticas por especie ---------------------------------------------

static func meshes(sp: int) -> Dictionary:
	if _meshes.has(sp):
		return _meshes[sp]
	var rig = ParafusetaRig if sp == Species.PARAFUSETA else RatoRig
	var joints: Dictionary = rig.group_transforms(rig.compute_pose(rig.Action.IDLE, 0.0))
	var body: Array = []
	var run_group := ""
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var parts: Dictionary = rig.parts()
	for key in parts:
		var group := str(parts[key].get("group", key))
		if not joints.has(group):
			group = "__body"
		if group != run_group and verts.size() > 0:
			body.append({"group": run_group, "mesh": _mesh(verts, uvs, idx)})
			verts = PackedVector2Array()
			uvs = PackedVector2Array()
			idx = PackedInt32Array()
		run_group = group
		var poly: PackedVector2Array = rig.polygon(key)
		var base := verts.size()
		for t in Geometry2D.triangulate_polygon(poly):
			idx.append(base + t)
		verts.append_array(poly)
		uvs.append_array(rig.uvs(key))
	if verts.size() > 0:
		body.append({"group": run_group, "mesh": _mesh(verts, uvs, idx)})

	var mouth: int = rig.MOUTH_SPECIES
	var pieces := CreatureMouth.parts_layout(mouth)
	var collar := CreatureMouth.collar_geometry(mouth)
	var iris := BossEyes.iris_geometry(rig.EYE_PUPIL, rig.EYE_RADIUS)
	var out := {
		"rig": rig,
		"texture": load(rig.ATLAS_PATH),
		"body": body,
		"cavity": _part_mesh(pieces[0]),
		"jaw": _part_mesh(pieces[1]),
		"arch": _part_mesh(pieces[2]),
		"collar": _polygon_mesh(collar[0], collar[1]),
		"iris": _polygon_mesh(iris[0], iris[1]),
		"mouth_species": mouth,
		"pivot": CreatureMouth.layout(mouth).pivot,
		"cell": ArtDirector.layout()["enemies"][REFERENCE_CELL[sp]],
	}
	_meshes[sp] = out
	return out


static func _part_mesh(piece: Dictionary) -> ArrayMesh:
	var geometry := CreatureMouth.part_geometry(piece.index, piece.at, piece.size)
	return _polygon_mesh(geometry[0], geometry[1])


static func _polygon_mesh(poly: PackedVector2Array, uv: PackedVector2Array) -> ArrayMesh:
	return _mesh(poly, uv, Geometry2D.triangulate_polygon(poly))


static func _mesh(verts: PackedVector2Array, uvs: PackedVector2Array, idx: PackedInt32Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if verts.is_empty() or idx.is_empty():
		push_error("CreatureRigView: peca sem triangulacao")
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
