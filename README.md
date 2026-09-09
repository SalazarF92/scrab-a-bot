# SCRAP-A-BOT — Protótipo

Implementação do marco **Protótipo** do GDD (seção 7.5):

> *"Um retângulo cinza atirando bolas que quicam. A meta é única: o ricochete precisa
> ser divertido sem arte nenhuma. Se não for, o projeto é cancelado aqui, e isso é barato."*

Nenhum sprite, nenhum áudio gravado, nenhuma animação desenhada. Tudo é `_draw` e som
sintetizado em tempo de carga. O que **é** definitivo aqui é a arquitetura da seção 7.2
e 7.3, porque o GDD é explícito em 7.6: *"Nunca otimizamos depois."*

## Rodar

```
Godot_v4.7.2-stable_win64.exe --path .
```

| Tecla | Ação |
|---|---|
| WASD | mover |
| mouse | mirar |
| botão esquerdo / direito | disparar braço esquerdo / direito |
| espaço ou shift | dash |
| Q | habilidade da cabeça |
| E | Purga de Calor |
| G | abrir / fechar a Garagem (Árvore de Upgrades do Seu Nildo) |
| B | abrir / fechar a Bancada (Vitrine, Fusões e Solda) |
| F1 | painel de desenvolvimento |
| F2 | gerar nova arena |
| F3 | teste de estresse: 800 projéteis |
| F4 | alternar formas de quique para daltonismo |
| F5 | trocar CPU |
| 1 / 2 / 3 | trocar braço esquerdo / braço direito / cabeça |
| F6 | tremor de tela em 0%, para ver a vinheta substituta |
| R | zerar telemetria |

## Teste de fumaça e benchmark

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/smoke.tscn
```

Sai com código 0 ou 1, então serve direto como passo de integração contínua.
Verifica, com semente fixa:

- **tunelamento** — 800 projéteis a 1400 px/s por 7,5 s, nenhum pode escapar da arena;
- **restrições de arena do GDD 3.3.4** — 40 salas geradas, todas precisam passar em
  cobertura, largura de corredor, alcançabilidade e distância máxima até uma superfície;
- **tabela de multiplicador de quique** do GDD 3.3.2, incluindo o teto rígido;
- **regra de acúmulo de hitstop** do GDD 3.4.1, o bug clássico do gênero;
- **metaprogressão e persistência** do GDD 6.1 a 6.3, salvamento e aplicação de bônus;
- **sistema da Bancada** do GDD 4.7 e GDD_ADENDOS B.1/B.3, vitrine, fusões (+Tier), reroll e solda;
- **custo de física por quadro**, comparado ao orçamento de 2,4 ms da tabela do GDD 7.2.

Última medição, binário de editor com depuração ligada, 800 projéteis:
**mediana 2,14 ms, p99 2,81 ms, zero quadros acima de 8 ms.**
O número do Steam Deck precisa de um template de exportação e ainda não foi medido.

## Estrutura

```
autoload/     combat_feel (hitstop e trauma), game_rng (fluxos semeados),
              sfx (síntese), vfx (pools de efeito), telemetry (GDD 7.7), game_input,
              meta_manager (economia de Cobre/Sucata e árvore de 5 ramos salva em user://save.json)
combat/       projectile_pool (o coração), projectile_type, fire_context, wave_director
data/         part_data, cpu_data, part_behavior + comportamentos, part_library
actors/       robot, enemies, arena_camera
generation/   arena_generator, obstacle
ui/           hud, debug_overlay, garage_ui (menu da Garagem), workbench_ui (menu da Bancada)
tests/        smoke
scenes/       prototype
```

## O que está implementado

**Física e ricochete (GDD 3.3, o pilar 3).** Vetores paralelos, sem nós por projétil.
Detecção por `cast_motion` com resolução no ponto de contato. Multiplicador de dano por
quique com teto rígido, jitter anti-loop, velocidade mínima, imunidade de acerto repetido,
restituição por superfície, facção, perfuração, divisão com linhagem limitada e política
explícita de estouro do pool. Renderização por `MultiMesh` com interpolação no lado do
render.

**Feel (GDD 3.4, o pilar 1).** Hitstop com regra de maior-valor-vence e teto de 130 ms,
trauma de câmera com amplitude quadrática, escala musical ascendente de quique com
limitador de 4 vozes por som, squash and stretch por evento com pivô na base, coice,
zoom dinâmico e antecipação de câmera na direção da mira.

**Modularidade (GDD 4, o pilar 2).** Peça é dado, não código: `PartData` com array de
`PartBehavior`. A TORRADA TESLA existe como prova — é a Torradeira com um comportamento
a mais no array e o leque de 3 para 5, sem uma linha de código nova. Sistema de Watts com
subvoltagem, sistema de calor com superaquecimento e Purga.

**Arena (GDD 3.3.4).** Gerador com validação de todas as restrições, incluindo busca em
largura, com o relatório visível no painel.

**Telemetria (GDD 7.7).** A métrica que decide o pilar 3 — mediana do multiplicador de
quique no momento do dano — está na tela durante o jogo, em verde ou magenta.

## Documentos e Especificações

- `DOCUMENTACAO_2026-09-09.md` — Relatório técnico completo de arquitetura, formato vertical *Ball x Pit*, metaprogressão, chefes e validações.
- `GDD_SCRAP-A-BOT.md` — O GDD v1.0.
- `GDD_ADENDOS.md` — Lacunas, contradições e riscos levantados sobre o GDD.

# scrab-a-bot
