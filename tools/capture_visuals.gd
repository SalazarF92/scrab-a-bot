extends Node
## Capturas reprodutíveis do renderer real. Nunca usa o save do jogador.
const TEST_SAVE := "user://visual_capture_save.json"
var prototype: Node2D
var failures := 0


class AtlasGallery extends Control:
	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(0, 0, 1920, 1080), Color("#211C24"))
		draw_string(font, Vector2(40, 52), "SCRAP-A-BOT / ARTE MODULAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("#FFD400"))
		draw_string(font, Vector2(40, 82), "Sprites raster originais • peças, inimigos e superfícies do poço", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#D6C9A8"))
		var labels := ["Ratoeira", "Furadeira", "Grampeador", "Fonte 500W", "Cano de pia", "Lançador de HD", "Torradeira", "Torrada Tesla", "Molas de sofá", "Esteiras", "Rodinhas", "Manequim", "Cofre", "Bateria de carro", "Pilha de pneus", "Carcaça de Fusca", "Parafuseta", "Rato Morto", "Vovó Geladeira", "Fantasma de Disquete", "Jato Preto", "Geladeira Lotada", "Mini-Prensa 500", "FROSTBYTE 500", "Fornalha Suprema", "Sugão (arte reserva)", "Formulário (arte reserva)", "Colchão velho"]
		for i in labels.size():
			var r := Rect2(35 + (i % 7) * 265, 105 + (i / 7) * 236, 250, 220)
			ArtDirector.panel(self, r)
			var image_rect := Rect2(r.position + Vector2(16, 8), Vector2(218, 174))
			ArtDirector.cell(self, ArtDirector.PARTS_PATH if i < 16 else ArtDirector.ENEMIES_PATH,
				i if i < 16 else i - 16, 4 if i < 16 else 3, image_rect)
			draw_string(font, r.position + Vector2(0, 204), labels[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 16, Color("#F5F0E1"))


class ExpansionGallery extends Control:
	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(0, 0, 1920, 1080), Color("#211C24"))
		draw_string(font, Vector2(40, 50), "SCRAP-A-BOT / BESTIARIO DA SUCATA", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("#FFD400"))
		if ArtDirector.texture(ArtDirector.EXPANSION_PATH) == null:
			draw_string(font, Vector2(40, 82), "ESTUDO DE ARTE / FUNDO OPACO PENDENTE DE CORRECAO", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#FF6B1A"))
			var preview := ArtDirector.texture("res://assets/art/expansion_atlas.png")
			if preview: draw_texture_rect(preview, Rect2(485, 105, 950, 950), false)
			return
		var labels := ["QWERTYpede", "Pop-Up Vivo", "Cadeado Chorao", "Olhudo", "Bipador", "Ze Ventoinha", "Cabo Cobra", "Fabricadora", "Barril toxico", "TV quebrada", "Bobina de cobre", "Tubulacao"]
		var descriptions := ["Oito impactos e uma rajada de teclas", "Divide-se por tres geracoes", "Bloqueia uma peca por oito segundos", "Laser com mira travada", "Explosao com aviso de um segundo", "Desvia seus tiros em um cone", "Funde um par e ataca com chicote", "Elite: fabrica quatro Parafusetas", "Destrutivel / quique 1,05", "Destrutivel / quique 0,90", "Superficie / quique 1,40", "Superficie / quique 0,80"]
		for i in 12:
			var r := Rect2(35 + (i % 4) * 465, 80 + (i / 4) * 325, 450, 310)
			ArtDirector.panel(self, r)
			ArtDirector.cell(self, ArtDirector.EXPANSION_PATH, i, 3, Rect2(r.position + Vector2(95, 8), Vector2(260, 245)))
			draw_string(font, r.position + Vector2(0, 273), labels[i], HORIZONTAL_ALIGNMENT_CENTER, 450, 22, Color("#F5F0E1"))
			draw_string(font, r.position + Vector2(0, 299), descriptions[i], HORIZONTAL_ALIGNMENT_CENTER, 450, 15, Color("#BDAE98"))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		push_error("Captura visual exige renderer com janela.")
		get_tree().quit(1)
		return
	MetaManager.save_path = TEST_SAVE
	MetaManager.reset_save()
	prototype = load("res://scenes/prototype.tscn").instantiate()
	prototype.start_seed = 20260910
	add_child(prototype)
	prototype.director.stop()
	prototype.enemy_pool.release_all()
	prototype.robot.set_physics_process(false)
	prototype.robot.aim_direction = Vector2(0.3, -1).normalized()
	prototype.camera.set_process(false)
	prototype.camera.snap_to(Vector2(500, 540))
	prototype.pool.set_physics_process(false)
	MetaManager.current_scrap = 740
	prototype.director.wave_index = 2
	var keys := ["parafuseta", "rato_morto", "vovo_geladeira", "fantasma_disquete", "jato_preto", "geladeira_bumper"]
	for i in 15:
		var e := Enemy.new()
		prototype.world.add_child(e)
		e.activate(EnemyLibrary.spec(keys[i % keys.size()]), i % 6, Vector2(145 + (i % 5) * 175, 165 + (i / 5) * 130))
		e.set_physics_process(false)
	for i in 15:
		var type := ProjectileType.make({"radius": 7.0, "base_color": ProjectilePool.BOUNCE_COLORS[i % 4]})
		prototype.pool.spawn(Vector2(190 + (i % 5) * 158, 565 + (i / 5) * 87), Vector2(0.4, -1), type)
	await _capture("gameplay")
	# Renderiza um chefe com telegrafia real.
	prototype.enemy_pool.release_all()
	var boss := Enemy.new()
	prototype.world.add_child(boss)
	boss.activate(EnemyLibrary.spec("mini_prensa"), 0, Vector2(500, 590))
	boss.set_physics_process(false)
	boss._player = prototype.robot
	boss._begin_boss_attack()
	prototype.director.wave_kind = &"boss"
	prototype.director.wave_banner_time = 2.0
	await _capture("boss")
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		enemy.queue_free()
	prototype.pool.clear()
	prototype.director.wave_kind = &"normal"
	prototype.director.wave_banner_time = 0
	for i in EnemyLibrary.EXPANSION_KEYS.size():
		var e := Enemy.new()
		prototype.world.add_child(e)
		e.activate(EnemyLibrary.spec(EnemyLibrary.EXPANSION_KEYS[i]), 0, Vector2(130 + (i % 4) * 240, 260 + (i / 4) * 360))
		e._player = prototype.robot
		e.set_physics_process(false)
		e._mob.target = prototype.robot.body_center()
		if i in [2, 3, 4, 7]: e._mob.warning = 1.0
	await _capture("expansion_combat")
	prototype.workbench.robot = prototype.robot
	prototype._show_workbench()
	prototype.workbench._try_buy_module(&"car_battery")
	await _capture("workbench")
	prototype.workbench._try_fuse_recipe(0)
	await _capture("fusion")
	prototype._show_garage()
	await _capture("garage")
	prototype.visible = false
	prototype.garage.visible = false
	prototype.workbench.visible = false
	prototype.hud.visible = false
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	layer.add_child(AtlasGallery.new())
	await _capture("gallery")
	for child in layer.get_children(): child.queue_free()
	layer.add_child(ExpansionGallery.new())
	await _capture("expansion_gallery")
	get_tree().paused = false
	Sfx.shutdown()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("=== CAPTURAS OK ===" if failures == 0 else "CAPTURA FALHOU")
	get_tree().quit(failures)


func _capture(label: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var bitmap := get_viewport().get_texture().get_image()
	var path := "res://docs/visual/" + label + ".png"
	var error := bitmap.save_png(path)
	if error != OK: failures += 1
	print("captura: ", path, " (", error, ")")
