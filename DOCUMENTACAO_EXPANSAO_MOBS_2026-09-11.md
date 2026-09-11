# Expansão do bestiário e cenário

Continuação do GDD, do relatório de 09/09 e de `DOCUMENTACAO_IMPLEMENTACAO_ARTES_2026-09-10.md`. Implementação iniciada em 10/09 e validada em 11/09/2026. Alterações locais anteriores preservadas; nenhum commit ou export de distribuição realizado.

## Monstros integrados

| Monstro | Primeiro setor | Comportamento |
|---|---:|---|
| QWERTYpede | 2 | Exige pelo menos oito impactos; dispara cinco teclas e libera três Parafusetas ao morrer. |
| Pop-Up Vivo | 2 | Divide em dois com metade da vida máxima por três gerações: até 15 indivíduos por ancestral. |
| Olhudo | 3 | Webcam estacionária; avisa por 0,8 s antes de disparar um laser de mira travada. Obstáculos interceptam o feixe. |
| Bipador | 3 | Aproxima, para e anuncia a explosão por 1 s. A esquiva permite escapar; autodetonação não concede recompensa de abate. |
| Cadeado Chorão | 4 | Bloqueia uma peça ofensiva por 8 s. A HUD informa o tempo; morte, reciclagem e fim de duração liberam o bloqueio. |
| Zé Ventoinha | 4 | Desvia projéteis do jogador em um cone de 250 px; preserva tiros hostis e os que estão fora do alcance. |
| Cabo Cobra | 5 | Chicote anunciado; dois cabos próximos fundem conservando HP e recompensa, com limite de uma fusão por indivíduo. |
| Fabricadora 3D | 5 | Elite que fabrica uma Parafuseta a cada 3 s após a preparação inicial, até quatro no total. |

As ondas normais apresentam cada novidade em uma onda definida e depois a incluem no sorteio dos setores permitidos. Pop-Up, Cadeado, Ventoinha e Fabricadora têm limite de um ancestral por onda. Orçamento de ameaça inclui o potencial de multiplicação; os filhotes também têm aviso de nascimento.

## Cenário e apresentação

Quatro entradas adicionadas ao catálogo de obstáculos a partir do setor 2:

| Objeto | Vida | Restituição |
|---|---:|---:|
| Barril tóxico | 180 | 1,05 |
| TV quebrada | 220 | 0,90 |
| Bobina de cobre | Indestrutível | 1,40 |
| Tubulação | Indestrutível | 0,80 |

Esses objetos são superfícies físicas; nomes e desenhos não implicam veneno, eletricidade ou vazamento com dano. O contorno da base indica a colisão real. Arte segue a direção cartunesca das peças anteriores, com contorno escuro, ferrugem, olhos exagerados e volume pintado.

O atlas de 12 desenhos (`assets/art/expansion_atlas_alpha.png`) foi gerado com extração automatizada de fundo e canais alfa limpos (726.006 pixels de fundo opaco e ilhas removidos). Mobs e novos obstáculos agora renderizam com transparência total no poço.

## Variações visuais dos 5 biomas

A arena (`ArtDirector.draw_arena`) agora apresenta diferenciação visual marcante e temática para cada setor, sem alterar colisões nem consumir RNG do gameplay:

1. **Setor 1 — Depósito de Sucata**: Estruturas de ferro fundido oxidado, rebites escuros com halo de ferrugem, linhas de perigo clássicas amarelo-asfalto e névoa industrial quente.
2. **Setor 2 — Esgoto Eletrônico**: Chapas com corrosão esverdeada (azeviche), trilhas e vias de circuito impresso (PCB) luminescentes ao longo das colunas verticais, marcas de escorrimento de e-waste e listras de perigo verde-tóxico.
3. **Setor 3 — Câmara Fria**: Chapas de liga criogênica azulada, estalactites e cristais de gelo nas nervuras laterais, dutos de fluido refrigerante e faixas de alerta subzero em ciano brilhante.
4. **Setor 4 — Escritório Morto**: Painéis brutalistas em grafite/ardósia anodizada, barramentos verticais de cabos com LEDs de servidor piscando em âmbar e magenta, iluminação de fósforo CRT e listras corporate synthwave.
5. **Setor 5 — A Fornalha**: Ferro basáltico carbonizado, fissuras de magma incandescente pulsando pelas colunas, frestas de calor térmico nas travessas de fundo e grelha de perigo em brasa viva.

A HUD (`ui/hud.gd`) e o topo do poço agora identificam expressamente o nome do bioma ativo a cada setor.

## Síntese de áudio procedural (SFX de habilidades)

Foram implementados 10 sintetizadores procedurais de áudio em tempo de carga (`autoload/sfx.gd`), sem carregar samples pesados nem alocar nós em tempo de execução:

- `laser_charge`: Subida de frequência senoidal com vibrato para a telegrafia do Olhudo.
- `laser_fire`: Disparo ionizado com varredura exponencial descendente e estalo elétrico.
- `beeper_countdown`: Duplo bipe de alta frequência ("BIP! BIP!") durante o aviso do Bipador.
- `beeper_detonate`: Explosão com sub-grave potente e estalo percussivo de sucata.
- `padlock_lock`: Dois cliques mecânicos de trinco pesado bloqueando armas do robô.
- `padlock_release`: Estalo de mola e tinido metálico de destravamento de slot.
- `wind_deflect`: Rajada de vento em ruído passa-baixa modulado para o cone do Zé Ventoinha.
- `printer_spawn`: Zumbido robótico escalonado em 3 passos para a Fabricadora 3D.
- `keycap_burst`: Estalo plástico seco simulando disparo de teclas mecânicas do QWERTYpede.
- `cable_whip`: Assobio rápido de ar e chicotada de fusão de cabos.

## Expansão de receitas na Bancada

O catálogo de fusões foi expandido com novas receitas avançadas de tier II e III na Bancada (`ui/workbench_ui.gd` e `data/part_library.gd`), com navegação completa por abas (`<`/`>`, setas, `Z`/`X`), compra com `[M]`, revenda com `[DEL]` e forja com `[F]`:
- **Perfuratriz Diamantada**: Perfuratriz Básica + Ponta de Broca Diamantada (120 Sucatas) — Perfuração de 3 alvos, 5 ricochetes e alta velocidade.
- **Bazuca Napalm do Seu Nildo**: Lança-Tubo + Botijão de Gás (140 Sucatas) — Dano massivo de 110, ricochetes explosivos com aceleração.

## Validação

A suíte completa (`powershell -ExecutionPolicy Bypass -File tests/run_tests.ps1`) foi executada e aprovada com código 0 em todas as 8 cenas de teste:
- `compile_check`: 47 scripts verificados, 0 erros.
- `integration_additions`: receitas de fusão, compras atômicas, armaduras de cofre, atlas alfa e cobertura de peças aprovados.
- `boss_combat`: contratos de chefe, fases, telegrafia e corredores aprovados.
- `mob_expansion`: comportamentos dos 8 novos monstros, colisões e ciclo de vida aprovados.
- `audio_cleanup`: 61 playbacks liberados, pausa e roubo de vozes sem vazamentos.
- `smoke`: integridade do gerador de arena, 40 salas validadas, física 60 FPS estável.
- `gameplay`: anti-travamento, rebatedor e percurso real aprovados.
- `run_completion`: vitória completa ao longo dos 5 setores, chefes e bancadas.
