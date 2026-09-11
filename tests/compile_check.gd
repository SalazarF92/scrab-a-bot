extends Node
## Todo script do projeto precisa compilar.
##
## Existe separado do teste de fumaca de proposito: este arquivo nao referencia
## nenhuma classe do jogo, entao ele mesmo nunca deixa de compilar quando um
## script de gameplay quebra. O teste de fumaca original passava verde com
## enemy.gd com erro de parse, porque nada nele instanciava um inimigo, e a cena
## principal nem abria.


func _ready() -> void:
	print("=== SCRAP-A-BOT :: compilacao de scripts ===")
	var paths: Array[String] = []
	_collect("res://", paths)
	var broken: Array[String] = []
	for p in paths:
		var s := load(p) as Script
		if s == null or not s.can_instantiate():
			broken.append(p)
	print("  %d scripts verificados, %d quebrados" % [paths.size(), broken.size()])
	for b in broken:
		print("  - " + b)
	print("")
	if broken.is_empty():
		print("=== TUDO OK ===")
		get_tree().quit(0)
	else:
		print("=== %d FALHAS ===" % broken.size())
		get_tree().quit(1)


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			pass
		elif dir.current_is_dir():
			_collect(dir_path.path_join(entry), out)
		elif entry.ends_with(".gd"):
			out.append(dir_path.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
