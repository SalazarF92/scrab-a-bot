extends Node
## Rigs articulados dentro do combate (CreatureRigView): equivalencia com os
## rigs de revisao, corte da boca, reciclagem do pool, golpe de contato, laser
## do Olhudo sincronizado com a habilidade, congelamento no hitstop e custo.

const TEST_SAVE := "user://rig_integration_save.json"
const ParafusetaRig = preload("res://art/parafuseta_puppet.gd")
const RatoRig = preload("res://art/rato_morto_puppet.gd")
const OlhudoRig = preload("res://art/olhudo_rigid.gd")
## Pose e desenho de uma onda densa: 36 Parafusetas, 12 Ratos e 4 Olhudos.
## Custo de CPU num build de editor headless, sem o renderer.
const DENSE_CREATURES := 48
const DENSE_OLHUDOS := 4
const DRAW_BUDGET_MS := 4.0

var failures: Array[String] = []
var robot: Robot
var pool: ProjectilePool
var enemies: EnemyPool


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func _ready() -> void:
	MetaManager.save_path = TEST_SAVE
	MetaManager.reset_save()
	MetaManager.start_new_run(0, false, 20260914)
	GameRng.reseed(20260914)
	pool = ProjectilePool.new()
	add_child(pool)
	pool.set_physics_process(false)
	robot = Robot.new()
	robot.pool = pool
	add_child(robot)
	robot.position = Vector2(700, 960)
	robot.set_physics_process(false)
	enemies = EnemyPool.new()
	add_child(enemies)
	print("=== SCRAP-A-BOT :: rigs articulados no combate ===")
	_test_batches_match_rig()
	_test_mouth_clip_matches_mask()
	_test_pool_rebinding()
	_test_creature_actions()
	await _test_olhudo_laser()
	await _test_freeze()
	await _test_draw_cost()
	enemies.release_all()
	pool.clear()
	CombatFeel.reset()
	Sfx.shutdown()
	for i in 30:
		await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	for message in failures:
		push_error(message)
	if failures.is_empty():
		print("=== TUDO OK ===")
	get_tree().quit(0 if failures.is_empty() else 1)


func _acquire(key: String, at: Vector2) -> Enemy:
	var e := enemies.acquire(EnemyLibrary.spec(key), at)
	e._player = robot
	e.set_physics_process(false)
	return e


func _test_batches_match_rig() -> void:
	for sp in [CreatureRigView.Species.PARAFUSETA, CreatureRigView.Species.RATO_MORTO]:
		var m := CreatureRigView.meshes(sp)
		var rig = m.rig
		var label: String = "parafuseta" if sp == CreatureRigView.Species.PARAFUSETA else "rato_morto"
		var parts: Dictionary = rig.parts()
		var expected_vertices := 0
		var expected_indices := 0
		var unit_fit := true
		var runs := 0
		var last := ""
		var joints0: Dictionary = rig.group_transforms(rig.compute_pose(rig.Action.IDLE, 0.0))
		for key in parts:
			var poly: PackedVector2Array = rig.polygon(key)
			expected_vertices += poly.size()
			expected_indices += Geometry2D.triangulate_polygon(poly).size()
			unit_fit = unit_fit and is_equal_approx(float(parts[key].fit), 1.0)
			var g := str(parts[key].get("group", key))
			if not joints0.has(g):
				g = "__body"
			if g != last:
				runs += 1
				last = g
		var got_vertices := 0
		var got_indices := 0
		for batch in m.body:
			var arrays: Array = (batch.mesh as ArrayMesh).surface_get_arrays(0)
			got_vertices += arrays[Mesh.ARRAY_VERTEX].size()
			got_indices += arrays[Mesh.ARRAY_INDEX].size()
		check(unit_fit, label + ": o posicionamento do rig no combate supoe fit 1,0 em todas as pecas")
		check(got_vertices == expected_vertices and got_indices == expected_indices,
			"%s: malhas cobrem %d/%d vertices e %d/%d indices" % [label, got_vertices, expected_vertices, got_indices, expected_indices])
		check(m.body.size() == runs, "%s: uma malha por trecho consecutivo de junta (%d malhas, %d trechos)" % [label, m.body.size(), runs])
		var mismatches := 0
		var samples := 0
		for act in 4:
			for step in 12:
				var p: Dictionary = rig.compute_pose(act, float(step) * 0.27)
				var joints: Dictionary = rig.group_transforms(p)
				for item in rig.frames(p):
					var g := str(parts[item.part].get("group", item.part))
					if not joints.has(g):
						g = "__body"
					samples += 1
					if not (joints[g] as Transform2D).is_equal_approx(item.transform):
						mismatches += 1
		check(samples > 1000 and mismatches == 0, "%s: %d de %d pecas com transformacao diferente do rig" % [label, mismatches, samples])
	print("  malhas por junta equivalentes aos rigs de revisao: OK")


func _test_mouth_clip_matches_mask() -> void:
	var probes := 0
	var disagreements := 0
	for boss in 2:
		var piece: Dictionary = CreatureMouth.parts_layout(boss)[0]
		var geometry := CreatureMouth.part_geometry(piece.index, piece.at, piece.size)
		var cavity: PackedVector2Array = geometry[0]
		var size: Vector2 = CreatureMouth.layout(boss).size
		for step in 11:
			var openness := float(step) / 10.0
			var rotation := CreatureMouth.jaw_transform(size, openness)
			var mask := PackedVector2Array()
			for point in [Vector2(-1000, -1000), Vector2(1000, -1000), Vector2(1000, size.y * .32), Vector2(-1000, size.y * .32)]:
				mask.append(rotation * point)
			var kept := Geometry2D.intersect_polygons(cavity, mask)
			var clip := CreatureMouth.clip_half_plane(size, openness)
			for gx in 24:
				for gy in 24:
					var point := Vector2(-size.x * .5 + size.x * (gx + .5) / 24.0, -size.y * .5 + size.y * (gy + .5) / 24.0)
					if not Geometry2D.is_point_in_polygon(point, cavity):
						continue
					var side: float = (point - (clip[0] as Vector2)).dot(clip[1])
					if absf(side) < 0.5:
						continue
					var by_mask := false
					for poly in kept:
						if Geometry2D.is_point_in_polygon(point, poly):
							by_mask = true
					probes += 1
					if by_mask != (side <= 0.0):
						disagreements += 1
	check(probes > 500 and disagreements == 0, "Corte da boca no shader diverge da mascara em %d de %d pontos" % [disagreements, probes])
	print("  corte da cavidade no shader igual ao recorte de CreatureMouth: OK")


func _test_pool_rebinding() -> void:
	enemies.release_all()
	var screw := _acquire("parafuseta", Vector2(500, 400))
	var view := screw.rig_view
	check(view.visible and view.species == CreatureRigView.Species.PARAFUSETA and not view.pose.is_empty(), "Parafuseta nasce com o rig de combate e pose calculada")
	enemies.release(screw)
	var fridge := _acquire("vovo_geladeira", Vector2(500, 400))
	check(fridge == screw, "O pool deveria reutilizar o mesmo inimigo")
	check(not fridge.rig_view.visible, "Especie sem rig volta ao recorte estatico")
	enemies.release(fridge)
	var rat := _acquire("rato_morto", Vector2(500, 400))
	check(rat.rig_view.visible and rat.rig_view.species == CreatureRigView.Species.RATO_MORTO, "Rato Morto reusa a mesma vista com outra especie")
	var views := 0
	for child in rat.get_children():
		if child is CreatureRigView:
			views += 1
	check(views == 1, "Reciclagem nao pode criar vistas novas (%d)" % views)
	enemies.release_all()
	print("  vista pre-alocada e reciclada entre especies: OK")


func _test_creature_actions() -> void:
	enemies.release_all()
	var e := _acquire("parafuseta", Vector2(500, 400))
	var view := e.rig_view
	view.sync(e, 0.016)
	check(view.action == ParafusetaRig.Action.WALK, "Descendo, a Parafuseta anda")
	var extent := e.body_radius * 3.0 + 18.0
	check(absf(view._root.get_scale().x - extent / 350.0) < 0.0005, "Rig ocupa a altura do recorte de referencia")
	var before: Dictionary = view.pose
	e.anim_since_contact = 0.0
	view.sync(e, 0.016)
	check(view.action == ParafusetaRig.Action.ATTACK and is_equal_approx(view.playhead, ParafusetaRig.IMPACT_TIME - CreatureRigView.CONTACT_LEAD),
		"Contato toca o golpe a partir do impacto")
	check((view.pose.body_offset - before.body_offset).length() < 1.0 and absf(float(view.pose.head) - float(before.head)) < 0.02,
		"Troca de acao interpola a pose em vez de saltar")
	for i in 20:
		e.anim_since_contact += 0.016
		view.sync(e, 0.016)
	check(view._blend >= 1.0, "Transicao termina em 0,16 s")
	e.anim_since_contact = 5.0
	e.apply_stun(0.9, Vector2.ZERO)
	view.sync(e, 0.016)
	check(view.action == ParafusetaRig.Action.IDLE, "Atordoada, a Parafuseta para de andar")
	enemies.release_all()
	print("  andar, golpe de contato, atordoamento e transicao: OK")


func _test_olhudo_laser() -> void:
	enemies.release_all()
	robot.position = Vector2(700, 960)
	robot._iframes = 99.0
	var eye := _acquire("olhudo", Vector2(300, 200))
	var view := eye.rig_view
	await get_tree().process_frame
	view.sync(eye, 0.016)
	var rig: Node2D = view._olhudo
	check(view.species == CreatureRigView.Species.OLHUDO and rig != null and rig.visible, "Olhudo usa a cena reutilizavel do rig")
	if rig == null:
		return
	check(view.action == OlhudoRig.Action.WATCH and not rig.laser.visible, "Em vigilancia o laser fica desligado")
	check(rig.transform.x.x < 0.0, "Com o robo a direita, a lente vira para a direita")
	eye._mob.timer = 0.0
	eye._mob.tick(eye, 0.001)
	check(eye._mob.warning > 0.0, "Olhudo deveria estar avisando")
	var charge_peak := 0.0
	var emitted_early := false
	var guard := 0
	while eye._mob.warning > 0.0 and guard < 200:
		guard += 1
		eye._mob.tick(eye, 1.0 / 60.0)
		if eye._mob.warning > 0.0:
			view.sync(eye, 1.0 / 60.0)
			charge_peak = maxf(charge_peak, float(view.pose.charge))
			emitted_early = emitted_early or float(view.pose.emission) > 0.01
	check(view.action == OlhudoRig.Action.POWER and charge_peak > 0.8, "Carga do rig cresce durante os 0,8 s de aviso (pico %.2f)" % charge_peak)
	check(not emitted_early, "O laser nao pode emitir antes do golpe do combate")
	for i in 6:
		view.sync(eye, 1.0 / 60.0)
		eye._mob.tick(eye, 1.0 / 60.0)
	check(float(view.pose.emission) > 0.5 and rig.laser.visible, "Laser emite logo apos o golpe do combate")
	var lens_world: Vector2 = rig.to_global(OlhudoRig.lens_point(view.pose))
	var beam: Vector2 = rig.laser.global_transform.x.normalized()
	var wanted: Vector2 = (eye._mob.target - lens_world).normalized()
	check(absf(beam.angle_to(wanted)) < deg_to_rad(3.0), "Feixe aponta para o alvo travado (erro de %.1f graus)" % rad_to_deg(absf(beam.angle_to(wanted))))
	var reach_px: float = rig.laser_reach * rig.global_transform.x.length()
	check(absf(reach_px - lens_world.distance_to(eye._mob.target)) < 2.0, "Alcance do feixe termina no alvo")
	check(eye.emitter_offset.distance_to(eye.to_local(lens_world)) < 0.5, "Aviso do combate sai da lente do rig")
	for i in 150:
		eye._mob.tick(eye, 1.0 / 60.0)
		view.sync(eye, 1.0 / 60.0)
	check(view.action == OlhudoRig.Action.WATCH and not rig.laser.visible, "Laser desliga e o Olhudo volta a vigiar")
	robot._iframes = 0.0
	enemies.release_all()
	print("  Olhudo: carga no aviso, emissao no golpe, mira, alcance e retorno: OK")


func _test_freeze() -> void:
	enemies.release_all()
	CombatFeel.reset()
	var e := enemies.acquire(EnemyLibrary.spec("rato_morto"), Vector2(500, 300))
	e._player = robot
	await get_tree().physics_frame
	await get_tree().physics_frame
	var moving: float = e.rig_view.playhead
	await get_tree().physics_frame
	check(e.rig_view.playhead > moving, "Rig anima junto com o passo de fisica")
	CombatFeel.request_hitstop(120.0)
	var frozen_at: float = e.rig_view.playhead
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(is_equal_approx(e.rig_view.playhead, frozen_at), "Hitstop congela o rig no mesmo instante")
	CombatFeel.reset()
	enemies.release_all()
	print("  rig congela no hitstop e retoma com a fisica: OK")


func _test_draw_cost() -> void:
	enemies.release_all()
	var views: Array[CreatureRigView] = []
	for i in DENSE_CREATURES:
		var key := "rato_morto" if i % 4 == 3 else "parafuseta"
		var e := _acquire(key, Vector2(60 + (i % 12) * 80, 120 + (i / 12) * 110))
		views.append(e.rig_view)
	for i in DENSE_OLHUDOS:
		var o := _acquire("olhudo", Vector2(150 + i * 230, 700))
		views.append(o.rig_view)
	for i in 5:
		await get_tree().process_frame
	CreatureRigView.draw_usec = 0
	CreatureRigView.draw_calls = 0
	var sync_usec := 0
	var frames := 90
	for f in frames:
		var started := Time.get_ticks_usec()
		for view in views:
			view.sync(view.get_parent(), 1.0 / 120.0)
		sync_usec += Time.get_ticks_usec() - started
		await get_tree().process_frame
	var draw_ms := float(CreatureRigView.draw_usec) / 1000.0 / float(frames)
	var sync_ms := float(sync_usec) / 1000.0 / float(frames)
	print("  %d criaturas + %d Olhudos: pose %.2f ms, desenho %.2f ms por quadro (%d desenhos)" % [
		DENSE_CREATURES, DENSE_OLHUDOS, sync_ms, draw_ms, CreatureRigView.draw_calls])
	check(CreatureRigView.draw_calls >= frames * (DENSE_CREATURES + DENSE_OLHUDOS) - views.size(), "Os rigs devem ser redesenhados a cada quadro")
	check(sync_ms + draw_ms < DRAW_BUDGET_MS, "Rigs de uma onda densa custam %.2f ms, acima de %.1f ms" % [sync_ms + draw_ms, DRAW_BUDGET_MS])
	enemies.release_all()
