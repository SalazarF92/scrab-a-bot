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

Estado da arte: atlas de 12 desenhos criado em `assets/art/expansion_atlas.png`; fundo opaco rejeitado para uso final. Correção de alpha pendente. Prompts e tentativas registrados em [ART_PROMPTS_EXPANSION.md](docs/ART_PROMPTS_EXPANSION.md).

Enquanto isso, o jogo usa a arte anterior como marcador provisório, acompanhada pelo nome de cada novo monstro. O carregador está preparado para `assets/art/expansion_atlas_alpha.png`; esse arquivo ainda não existe. A galeria mostra o estudo original com aviso explícito de fundo pendente, sem apresentá-lo como sprite final.

Captura do renderer OpenGL concluída sem erros: [combate com apresentação provisória](docs/visual/expansion_combat.png) e [estudo dos 12 desenhos](docs/visual/expansion_gallery.png).

## Validação

`powershell -ExecutionPolicy Bypass -File tests/run_tests.ps1`: oito cenas aprovadas, 47 scripts compilados, sem erros de script ou vazamentos de objetos reportados pelo runner.

O teste `mob_expansion` cobre introdução por setor, rajadas, oito impactos, gerações, bloqueios concorrentes e expiração, esquiva de laser e explosão, colisão do laser com obstáculo, autoria de dano, vento por alcance/facção, fusão de cabos, limite da Fabricadora e limpeza de estado no pool.

O teste de percurso chegou à vitória passando pelos cinco setores, quatro bancadas, três chefes e todos os oito novos tipos de inimigo. Usa abate assistido; não valida dificuldade para jogadores humanos. Todos os saves de teste são isolados.

Teste de fumaça: 40 salas aprovadas; 800 projéteis a 1400 px/s; mediana de física 2,34 ms, p99 3,00 ms e nenhum quadro acima de 8 ms nessa execução. Medição local de editor, sem promessa de desempenho em outras máquinas.

## Limites e adaptações

A expansão continua sendo protótipo. Os desenhos têm uma pose por criatura, animada por transformação e deformação; animações desenhadas por ação, efeitos exclusivos e balanceamento humano ainda faltam. O mínimo de oito impactos do QWERTYpede não substitui seu HP. Pop-Up e Fabricadora possuem limites explícitos para evitar crescimento ilimitado. Não representa conclusão de todo o escopo 1.0 do GDD.
