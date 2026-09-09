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
@export var description: String = ""
