extends Node
## Verifica transições dos cinco setores com abate assistido; não é benchmark
## de balanceamento nem simulação da habilidade de um jogador.
const TEST_SAVE := "user://run_completion_save.json"
var prototype: Node
var elapsed := 0.0
var bench_count := 0
var boss_count := 0
var finished := false
var seen_mobs: Dictionary = {}
var failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	MetaManager.save_path = TEST_SAVE
	MetaManager.reset_save()
	prototype = load("res://scenes/prototype.tscn").instantiate()
	prototype.start_seed = 20260910
	add_child(prototype)
	print("=== SCRAP-A-BOT :: percurso completo de cinco setores ===")


func _process(delta: float) -> void:
	if finished: return
	elapsed += delta
	if elapsed > 1000.0:
		failures.append("Run nao chegou ao fim dentro do limite")
		_finish()
		return
	# Exercita diretor, mortes, drops, chefes, bancada e retorno à garagem.
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		if enemy is Enemy and enemy.active:
			seen_mobs[enemy.visual_id] = true
			if enemy.is_boss: boss_count += 1
			enemy.take_damage(enemy.max_hp * 20.0, enemy.global_position, 4)
	if prototype.workbench.visible:
		bench_count += 1
		if bench_count == 1:
			MetaManager.current_scrap = maxi(MetaManager.current_scrap, 180)
			prototype.workbench._try_buy_module(&"car_battery")
			prototype.workbench._try_buy_module(&"car_battery")
			prototype.workbench._try_fuse_recipe(0)
		var head: PartData = prototype.robot.equipped[PartData.Slot.HEAD]
		if head.id != &"head_toaster_tesla" or prototype.workbench.inventory.size() != 1:
			failures.append("Receita/mochila nao persistiu entre setores")
		prototype.workbench._proceed()
	if prototype.garage.visible:
		if not MetaManager.last_run_summary.get("won", false):
			failures.append("Percurso terminou sem vitoria")
		if bench_count != 4 or boss_count != 5:
			failures.append("Esperava 4 bancadas e 5 chefes, recebeu %d/%d" % [bench_count, boss_count])
		prototype._begin_run(false, 20260910)
		for key in EnemyLibrary.EXPANSION_KEYS:
			if not seen_mobs.has(StringName(key)):
				failures.append("Monstro ausente do percurso: " + key)
		var head: PartData = prototype.robot.equipped[PartData.Slot.HEAD]
		if prototype.workbench.inventory.size() != 0 or head.id != &"head_toaster":
			failures.append("Nova run herdou mochila/receita anterior")
		_finish()


func _finish() -> void:
	finished = true
	prototype.director.stop()
	prototype.pool.clear()
	prototype.world.process_mode = Node.PROCESS_MODE_DISABLED
	prototype.queue_free()
	Sfx.shutdown()
	# --fixed-fps comprime o tempo de jogo; a thread de áudio precisa de tempo
	# real para drenar o último playback, mesmo com novos sons já bloqueados.
	for i in 30:
		OS.delay_msec(10)
		await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	for message in failures: push_error(message)
	print("  %d bancadas, %d chefes; vitoria e reinicio em %.1fs simulados" % [bench_count, boss_count, elapsed])
	if failures.is_empty(): print("=== TUDO OK ===")
	get_tree().quit(0 if failures.is_empty() else 1)
