class_name FusionInventory
extends RefCounted
## Mochila de modulos da run, separada dos slots equipados (GDD_ADENDOS B.3).
## Uma unidade ocupa um espaco. Ingredientes so saem quando a receita e valida.

const BASE_CAPACITY := 4

var capacity: int = BASE_CAPACITY
var _modules: Array[StringName] = []


func size() -> int:
	return _modules.size()


func count(module_id: StringName) -> int:
	return _modules.count(module_id)


func is_full() -> bool:
	return size() >= capacity


func add(module_id: StringName) -> bool:
	if module_id == &"" or is_full():
		return false
	_modules.append(module_id)
	return true


func consume(module_id: StringName) -> bool:
	var index := _modules.find(module_id)
	if index < 0:
		return false
	_modules.remove_at(index)
	return true


func clear() -> void:
	_modules.clear()
	capacity = BASE_CAPACITY
