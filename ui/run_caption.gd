class_name RunCaption
extends RefCounted
## Legenda automatica de fim de run. GDD 1.4, item 3:
## "Ao morrer, o jogo gera uma frase de resumo na tela de fim [...] Esse texto
## e copiavel e e literalmente a legenda do post."
##
## A frase e montada a partir de dados que ja existem: nome e artigo do inimigo,
## a legenda de cada peca, a CPU e a telemetria da run. Nenhum texto por
## combinacao, entao 90 pecas e 12 inimigos nao multiplicam trabalho de roteiro.
##
## A variante e escolhida pela semente da run, e nao pelo RNG global: a mesma
## run do desafio diario gera a mesma frase para todo mundo.

const DEATH_VERBS := [
	"Morto", "Desmontado", "Reciclado à força", "Transformado em sucata",
	"Mandado de volta pro ferro-velho",
]
const BREACH_VERBS := [
	"Atropelado na linha de defesa", "Invadido", "Pisoteado na própria base",
]


## Preposicao contraida com o artigo: "por uma Parafuseta", "pela Mini-Prensa".
static func by_whom(article: String, who: String) -> String:
	match article:
		"o":
			return "pelo " + who
		"a":
			return "pela " + who
		"os":
			return "pelos " + who
		"as":
			return "pelas " + who
		"":
			return "por " + who
	return "por %s %s" % [article, who]


static func build(robot: Robot, won: bool, sector: int, seed_value: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d|%d|%s|%s" % [seed_value, sector, str(won), robot.last_damage_source])

	var head := _part(robot, PartData.Slot.HEAD, "uma cabeça vazia")
	var chassis := _part(robot, PartData.Slot.CHASSIS, "perna nenhuma")
	var arm := _part(robot, PartData.Slot.ARM_RIGHT, "nada")

	var text := ""
	if won:
		var soul := "uma CPU qualquer"
		if robot.cpu != null and robot.cpu.caption != "":
			soul = robot.cpu.caption
		text = "Venceu os 5 setores pilotando %s com %s e %s no braço, movido por %s." % [head, chassis, arm, soul]
	else:
		var verbs: Array = BREACH_VERBS if robot.last_damage_was_breach else DEATH_VERBS
		var verb: String = verbs[rng.randi_range(0, verbs.size() - 1)]
		var source := robot.last_damage_source
		if source == "":
			source = "pela própria gambiarra"
		text = "%s %s no setor %d enquanto pilotava %s com %s e %s no braço." % [verb, source, sector, head, chassis, arm]

	var jab := _jab()
	if jab != "":
		text += " " + jab
	return text


static func _part(robot: Robot, slot: int, fallback: String) -> String:
	var p: PartData = robot.equipped.get(slot)
	if p == null:
		return fallback
	return p.caption if p.caption != "" else p.display_name


## Um comentario final escolhido pela telemetria, quando ha algo digno de nota.
static func _jab() -> String:
	if Telemetry.total_hits >= 20 and Telemetry.median_bounce_multiplier() >= 4.0:
		return "Pelo menos os quiques estavam magenta."
	if Telemetry.projectiles_lost_floor > 30 and Telemetry.projectiles_lost_floor > Telemetry.paddle_catches * 3:
		return "Deixou cair mais bala do que rebateu."
	if Telemetry.enemies_breached >= 8:
		return "A linha de defesa era mais sugestão do que regra."
	if Telemetry.total_hits >= 20 and Telemetry.ricochet_damage_share() < 0.2:
		return "Mirou direto no inimigo, feito amador."
	return ""
