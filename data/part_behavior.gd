class_name PartBehavior
extends Resource
## GDD 7.3, a regra arquitetural central: composicao, nao heranca.
## Uma peca nao e uma subclasse. Uma peca e um conteiner de comportamentos.
## E isso que permite criar centenas de pecas sem tocar no codigo base.
##
## Cada comportamento tem um unico metodo virtual e e reutilizavel. O checklist
## do APENDICE B, item 9, exige que todo comportamento novo sirva a pelo menos
## tres outras pecas futuras.

## Chamado quando a peca dispara. Pode alterar o projetil antes de nascer.
func on_fire(_ctx) -> void:
	pass

## Chamado quando um projetil desta peca quica.
func on_bounce(_ctx) -> void:
	pass

## Chamado quando um projetil desta peca acerta algo danificavel.
func on_hit(_ctx) -> void:
	pass

## Chamado a cada passo de fisica enquanto a peca esta equipada.
func on_tick(_robot, _delta: float) -> void:
	pass

func on_equip(_robot) -> void:
	pass

func on_unequip(_robot) -> void:
	pass
