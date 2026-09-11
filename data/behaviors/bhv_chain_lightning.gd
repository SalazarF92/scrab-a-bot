class_name BhvChainLightning
extends PartBehavior
## Arco eletrico em cadeia a partir do alvo atingido.
## Reutilizado por: CPU "Cafe Derramado" (3 alvos, 35% do dano), Bobina de Ferro
## de Solda "Zap Zap" (6 saltos, -15% por salto) e a fusao TORRADA TESLA, que
## no GDD 7.3 e citada como o caso que prova a arquitetura: e a Torradeira com
## este comportamento acrescentado ao array, sem uma linha de codigo novo.
##
## O arco herda o indice de quique do projetil que o disparou. Antes ele era
## registrado como tiro direto, e uma build de TORRADA TESLA, que so existe por
## causa do quique, puxava para baixo a mediana que decide o pilar 3. Pelo mesmo
## motivo o arco de um projetil ricocheteado tambem fere o Fantasma de Disquete.

@export var jumps: int = 3
@export var falloff: float = 0.15
@export var range_px: float = 250.0
@export var damage_ratio: float = 0.35
## Se verdadeiro, dispara no quique e nao no acerto. E o que a TORRADA TESLA faz:
## "cada quique dispara um arco em cadeia".
@export var trigger_on_bounce: bool = false


func on_hit(ctx) -> void:
	if trigger_on_bounce:
		return
	_chain(ctx.pool, ctx.position, ctx.damage * damage_ratio, ctx.target, ctx.bounce_index)


func on_bounce(ctx) -> void:
	if not trigger_on_bounce:
		return
	var pool: ProjectilePool = ctx.pool
	_chain(pool, ctx.position, pool.get_damage_of(ctx.index) * damage_ratio, null, ctx.bounce_index)


func _chain(pool: ProjectilePool, from: Vector2, damage: float, exclude: Node, bounce_index: int) -> void:
	var hit: Array[Node] = []
	if exclude != null:
		hit.append(exclude)
	var origin := from
	var dmg := damage

	for j in jumps:
		var target := _nearest(pool, origin, hit)
		if target == null:
			return
		hit.append(target)
		target.call("take_damage", dmg, target.global_position, bounce_index)
		Vfx.spawn_bounce(target.global_position, (target.global_position - origin).normalized(), 2)
		Telemetry.record_hit(bounce_index, dmg)
		origin = target.global_position
		dmg *= (1.0 - falloff)


func _nearest(pool: ProjectilePool, from: Vector2, exclude: Array[Node]) -> Node:
	var best: Node = null
	var best_d := range_px
	for e in pool.get_tree().get_nodes_in_group(&"enemies"):
		if e in exclude or not is_instance_valid(e):
			continue
		var d: float = (e.global_position as Vector2).distance_to(from)
		if d < best_d:
			best_d = d
			best = e
	return best
