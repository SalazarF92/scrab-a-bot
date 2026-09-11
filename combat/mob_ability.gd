class_name MobAbility
extends RefCounted
## Comportamentos do lote 02, adaptados ao poço. Estado por instância do pool;
## nunca mantém referência forte ao dono/jogador e sempre libera bloqueios.
var timer := 2.0
var warning := 0.0
var strike := 0.0
var target := Vector2.ZERO
var spawned := 0
var merged := false
var wind_clock := 0.0
var shot: ProjectileType


func reset(owner: Node2D) -> void:
	if is_instance_valid(owner._player) and owner._player.has_method("release_jam"):
		owner._player.release_jam(owner.get_instance_id())
	timer = 2.0
	warning = 0.0
	strike = 0.0
	target = Vector2.ZERO
	spawned = 0
	merged = false
	wind_clock = 0.0
	shot = null


func tick(owner: Node2D, delta: float) -> void:
	if owner.mob_kind == &"" or not is_instance_valid(owner._player): return
	var player: Node2D = owner._player
	if player.get("hp") != null and player.hp <= 0.0: return
	strike = maxf(0.0, strike - delta)
	if owner.mob_kind == &"fan":
		wind_clock += delta
		if wind_clock >= 0.10:
			if player.get("pool") != null:
				player.pool.deflect_in_cone(owner.global_position, Vector2.DOWN, 250.0, 900.0, 0.10)
			wind_clock = 0.0
		return
	if warning > 0.0:
		warning = maxf(0.0, warning - delta)
		if warning <= 0.0: _execute(owner, player)
		return
	timer = maxf(0.0, timer - delta)
	if timer > 0.0: return
	var distance: float = owner.global_position.distance_to(player.body_center())
	match owner.mob_kind:
		&"popup": return
		&"bomber":
			if distance > 210.0: return
		&"cable":
			_try_merge(owner)
			if distance > 180.0: return
		&"printer":
			if spawned >= 4: return
	target = player.body_center()
	warning = 1.0 if owner.mob_kind == &"bomber" else 0.8
	if owner.mob_kind == &"printer": warning = 0.7
	if owner.mob_kind == &"bomber": Sfx.play("overheat", -15.0)


func _execute(owner: Node2D, player: Node2D) -> void:
	strike = 0.22
	timer = 4.2
	match owner.mob_kind:
		&"keyboard":
			var pool: ProjectilePool = player.get("pool")
			if pool == null: return
			if shot == null:
				shot = ProjectileType.make({"id": &"keycap", "damage": owner.contact_damage,
					"speed": 310.0, "radius": 7.0, "max_bounces": 1, "ttl": 5.0,
					"base_color": Color("#FF6B1A"), "damage_source": owner.source_text()})
			var direction := (target - owner.global_position).normalized()
			for i in 5:
				pool.spawn(owner.global_position + direction * (owner.body_radius + 12.0),
					direction.rotated(deg_to_rad((i - 2) * 10.0)), shot, ProjectilePool.FACTION_ENEMY)
		&"laser":
			# A parede intercepta o feixe. A mira não persegue o jogador no aviso.
			var query := PhysicsRayQueryParameters2D.create(owner.global_position, target, ProjectilePool.LAYER_WALLS)
			var hit := owner.get_world_2d().direct_space_state.intersect_ray(query)
			if not hit.is_empty(): target = hit["position"]
			if Geometry2D.get_closest_point_to_segment(player.body_center(), owner.global_position, target).distance_to(player.body_center()) <= Robot.COLLISION_RADIUS + 5.0:
				player.take_damage(owner.contact_damage, owner.global_position, 0, owner.source_text())
		&"lock":
			if player.has_method("jam_slot"):
				var slots: Array[int] = []
				for slot in [PartData.Slot.ARM_LEFT, PartData.Slot.ARM_RIGHT, PartData.Slot.HEAD]:
					if player.equipped.has(slot): slots.append(slot)
				if not slots.is_empty():
					var pick := GameRng.stream(GameRng.Stream.AI).randi_range(0, slots.size() - 1)
					player.jam_slot(slots[pick], owner.get_instance_id(), 8.0)
			timer = 11.0
		&"bomber":
			if owner.global_position.distance_to(player.body_center()) <= 200.0 + Robot.COLLISION_RADIUS:
				player.take_damage(owner.contact_damage, owner.global_position, 0, owner.source_text())
			Vfx.spawn_death(owner.global_position, Color("#FF6B1A"))
			Sfx.play("fire_heavy", -6.0)
			owner._dying = true
			owner._release() # Detonar sozinho não paga recompensa de abate.
		&"cable":
			var offset: Vector2 = player.body_center() - owner.global_position
			if offset.length() <= 180.0 and offset.normalized().dot((target - owner.global_position).normalized()) > 0.5:
				player.take_damage(owner.contact_damage, owner.global_position, 0, owner.source_text())
			timer = 2.4
		&"printer":
			owner.get_tree().call_group(&"wave_director", &"spawn_minions", "parafuseta", owner.global_position + Vector2(0, 35), 1)
			spawned += 1
			timer = 2.3 # 2,3 + 0,7 de aviso = três segundos entre construções.


func _try_merge(owner: Node2D) -> void:
	if merged: return
	for other in owner.get_tree().get_nodes_in_group(&"enemies"):
		if other == owner or not other.active or other.mob_kind != &"cable" or other._mob.merged: continue
		if owner.get_instance_id() > other.get_instance_id(): continue
		if owner.global_position.distance_to(other.global_position) > 65.0: continue
		merged = true
		owner.max_hp += other.max_hp
		owner.hp += other.hp
		owner.scrap_value += other.scrap_value
		owner.body_radius *= 1.35
		owner._shape.radius = owner.body_radius
		other._dying = true
		other._release()
		Vfx.spawn_bounce(owner.global_position, Vector2.UP, 3)
		return


func draw_warning(canvas: Node2D, owner: Node2D) -> void:
	if owner.mob_kind == &"fan":
		canvas.draw_arc(Vector2.ZERO, 250, PI * 0.29, PI * 0.71, 20, Color("#22E0FF", 0.17), 2.0)
	if warning <= 0.0 and strike <= 0.0: return
	var color := Color("#FF6B1A") if strike > 0.0 else Color("#FFD400")
	var endpoint := target - owner.global_position
	match owner.mob_kind:
		&"bomber", &"cable":
			var radius := 200.0 if owner.mob_kind == &"bomber" else 180.0
			canvas.draw_circle(Vector2.ZERO, radius, Color(color, 0.06))
			canvas.draw_arc(Vector2.ZERO, radius, 0, TAU, 40, Color(color, 0.6), 2.0)
		&"laser":
			canvas.draw_line(Vector2.ZERO, endpoint, Color(color, 0.9), 8.0 if strike > 0.0 else 2.0)
			canvas.draw_circle(endpoint, 7, color)
		_:
			canvas.draw_arc(Vector2.ZERO, owner.body_radius + 12, 0, TAU, 24, color, 3.0)
	var labels := {&"keyboard": "RAJADA!", &"lock": "ENCRIPTANDO", &"bomber": "BIP! BIP!", &"cable": "CHICOTE!", &"printer": "FABRICANDO"}
	if labels.has(owner.mob_kind):
		canvas.draw_string(ThemeDB.fallback_font, Vector2(-90, -owner.body_radius - 25),
			labels[owner.mob_kind], HORIZONTAL_ALIGNMENT_CENTER, 180, 14, color)
