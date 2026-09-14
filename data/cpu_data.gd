class_name CpuData
extends Resource
## GDD 4.1. A CPU e a alma do robo: define orcamento de energia, sistema termico
## e uma passiva que muda como o jogo funciona.

@export var id: StringName = &""
@export var display_name: String = ""

@export_group("Energia")
## GDD 4.1.1: a CPU fornece um TDP entre 80 e 150 Watts.
@export var tdp: int = 100

@export_group("Termico")
## GDD 4.1.2: capacidade termica base entre 80 e 140 unidades.
@export var heat_capacity: float = 100.0
## Dissipacao passiva base, com atraso de 0,6 s apos o ultimo disparo.
@export var heat_dissipation: float = 12.0

@export_group("Passiva")
@export var damage_mult: float = 1.0
@export var fire_rate_mult: float = 1.0
@export var projectile_speed_mult: float = 1.0
@export var bonus_bounces: int = 0
@export var heat_gen_mult: float = 1.0
@export var hp_mult: float = 1.0
## AMDeus Camelo: chance de o disparo falhar com tela azul / de dar dano triplo.
@export var misfire_chance: float = 0.0
@export var triple_damage_chance: float = 0.0
## Bitcorn Rig: Sucata extra por abate e chance extra de peca rara na vitrine.
@export var scrap_per_kill: int = 0
@export var rare_chance_bonus: float = 0.0
## Cafe Derramado: curto-circuito com chance por disparo, dano no proprio robo.
@export var self_shock_chance: float = 0.0
@export var self_shock_damage: float = 0.0
## Cyrix Bode: enxertos a mais por peca.
@export var extra_graft_slots: int = 0
## Comportamentos que entram em todo projetil do jogador (Cafe: arco em cadeia).
@export var behaviors: Array[PartBehavior] = []
@export var description: String = ""
## Como a CPU aparece na legenda de fim de run, por exemplo "um Pentiun enferrujado".
@export var caption: String = ""

@export_group("Desbloqueio")
## GDD 6.3.2: condicao visivel na prateleira. `unlock_stat` e um campo
## persistido do MetaManager; vazio = disponivel desde o inicio.
@export var unlock_stat: StringName = &""
@export var unlock_value: int = 0
@export var unlock_text: String = "Inicial"
