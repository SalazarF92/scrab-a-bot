class_name EnemyPool
extends Node2D
## Pool de inimigos. GDD 7.2, otimizacao obrigatoria 1: "Pool de tudo. Zero
## instanciacao durante o combate."
##
## O inimigo inativo continua na arvore: fora dos grupos, sem camada de colisao,
## invisivel e sem processar. Tirar e recolocar da arvore tambem funcionaria, mas
## o inimigo morre no meio da resolucao de um quique, e mexer na arvore ali
## exige adiar para o fim do quadro. Ate la o inimigo morto continuaria sendo
## superficie e rebatendo projetil.
##
## Se o pool esgotar, ele cresce e conta em `grown`. Maior que zero numa sessao
## e sinal de que PREWARM esta baixo, nao um erro.

const PREWARM := 128

var grown: int = 0

var _all: Array[Enemy] = []
var _free: Array[Enemy] = []


func _ready() -> void:
	for i in PREWARM:
		_make()


func _make() -> void:
	var e := Enemy.new()
	e.pool = self
	add_child(e)
	e.deactivate()
	_all.append(e)
	_free.append(e)


func acquire(spec: Dictionary, at: Vector2) -> Enemy:
	if _free.is_empty():
		_make()
		grown += 1
	var e: Enemy = _free.pop_back()
	e.activate(spec, active_count(), at)
	return e


func release(e: Enemy) -> void:
	if not e.active:
		return
	e.deactivate()
	_free.append(e)


func release_all() -> void:
	for e in _all:
		release(e)


func active_count() -> int:
	return _all.size() - _free.size()


func capacity() -> int:
	return _all.size()
