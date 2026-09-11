# SCRAP-A-BOT — Registro da Sessão de 10/09/2026

> Complementado por `DOCUMENTACAO_IMPLEMENTACAO_ARTES_2026-09-10.md`:
> artes integradas, receitas, defesa, fases dos chefes e fechamento de áudio.
> As pendências abaixo descrevem o estado ao fim da sessão original.
**Propósito:** passagem de bastão completa para a próxima sessão de trabalho.
**Motor:** Godot 4.7.2 Forward+ · **Branch:** `main` · **Commit base:** `15b520a`
**Estado:** todas as mudanças descritas aqui estão **no working tree, sem commit**.

---

## 0. Resumo em uma tela

- A sessão teve duas etapas. Primeiro, uma **varredura completa** do projeto com diagnóstico de qualidade e propostas de diferenciação. Depois, a **implementação de todas as sugestões**, a pedido do usuário.
- A cena principal **não abria** no commit base. Havia dois scripts com erro de parse: `enemy.gd` e `garage_ui.gd`. Os dois foram corrigidos.
- Entraram cinco mecânicas novas: **robô rebatedor**, **chão do poço**, **parede de vapor**, **onda de bumpers** e **legenda de fim de run**. Entrou também o **desafio de hoje**, com semente diária.
- Entraram três suítes de teste headless e um executor único. **Todas passam.**
- O formato de **poço vertical** foi registrado como decisão vigente em `GDD_ADENDOS.md`, seção F. **Falta a confirmação explícita do dono do projeto.**
- **Incidente:** o teste de fumaça antigo sobrescrevia o save real do jogador, e foi rodado nesta sessão. O save atual não representa progresso real. Detalhes na seção 9.
- **Pendência técnica aberta:** o teste de fumaça acusa 5 objetos de áudio vazados ao fechar. Não afeta jogo nem CI. Investigação na seção 10.1.
- **Nada foi verificado visualmente com janela.** Toda validação foi headless. A primeira tarefa da próxima sessão deve ser abrir o jogo e olhar.

Para retomar:

```powershell
cd F:\GODOT\scrap_a_bot
git status
powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1
F:\GODOT\Godot_v4.7.2-stable_win64.exe --path .
```

---

## 1. Linha do tempo da sessão

1. **Leitura integral** do GDD (1.418 linhas), dos adendos, do relatório de 09/09, do README e dos 33 scripts.
2. **Smoke test original** rodado: passou. Isso escondia o problema, porque nenhum teste instanciava `Enemy`. Esta execução também sobrescreveu o save real (seção 9).
3. **Checagem de parse** por arquivo com `--check-only`, que revelou o erro em `enemy.gd:34`.
4. **Relatório de varredura** entregue: 9 problemas de qualidade e 5 propostas de diferenciação (seção 2).
5. O usuário respondeu **"vamos para todas as suas sugestões"**.
6. Foi criado primeiro um teste isolado de compilação, **antes** de corrigir qualquer coisa. Ele pegou 3 scripts quebrados: `enemy.gd`, `wave_director.gd` por dependência e `garage_ui.gd`.
7. Reescrita dos sistemas. Os arquivos foram escritos numa pasta de preparo e copiados, porque não há Python na máquina e heredocs grandes no Bash estouram o limite de linha de comando (seção 8).
8. O primeiro teste de compilação falhou por **cache de classes globais desatualizado**. A correção foi rodar `--import` (seção 8.1).
9. Smoke e gameplay passaram, exceto uma sonda de chão verificada cedo demais. O tempo da sonda foi corrigido.
10. Surgiram picos no benchmark e vazamentos de áudio. Isso levou a três correções no áudio e à descoberta de que `--fixed-fps` gera picos falsos (seção 8.3).
11. Foram escritos o README e a seção F dos adendos.
12. O executor completo passou. Foi feita uma bisseção parcial do vazamento de áudio (seção 10.1).

---

## 2. Diagnóstico da varredura e status

### 2.1 Problemas de qualidade encontrados

| # | Problema | Status |
|---|---|---|
| 1 | `enemy.gd:34` redeclarava `enemy_name`. A cena principal não carregava, e o smoke passava verde porque nunca instanciava inimigo. | **Corrigido.** Também foram achados e corrigidos 2 erros de inferência de tipo em `garage_ui.gd` (linhas 149 e 151 do original). |
| 2 | O GDD descrevia arena 2400×1350 com mira 360°, e o código implementa o poço 1000×1080. O painel de debug imprimia os limites antigos. | **Registrado** em `GDD_ADENDOS.md` F. O painel agora lê as constantes do `ArenaGenerator`. |
| 3 | Soft-lock: inimigo pousado em cima de obstáculo com o jogador embaixo ficava parado para sempre. `MAX_SILENCE` existia e nunca era lida. | **Corrigido** com anti-travamento (5.4). A constante morta foi removida, com comentário explicando por quê. |
| 4 | Menus sem foco, então teclado não funcionava, e sem pausa, então o robô atirava atrás do menu. | **Corrigido** (5.2). |
| 5 | Inimigo que invadia a base passava por `_die()` e dava Sucata, cura, contagem de abate e som. | **Corrigido** (5.5). |
| 6 | O raio em cadeia registrava dano como quique 0 e poluía a mediana do pilar 3. | **Corrigido** (5.16). |
| 7 | Itens sem efeito: Pólvora Grossa não era lida, `flees` era ignorado, `total_kills` ficava sempre 0, `daily_seed` não era usado, não havia fusão de duplicata nem venda. | **Todos corrigidos.** |
| 8 | Crítico e drop de cura usavam o `randf()` global. | **Corrigido**, com lint automático no smoke. |
| 9 | Menores: inimigo instanciado a cada spawn, `Sfx.play` alocando timer e lambda por som, vitrine sem raridade por setor, `.uid` faltando. | **Todos corrigidos.** |

### 2.2 Propostas de diferenciação

| Proposta | Status |
|---|---|
| Robô vira raquete, com restituição por chassi | **Implementado** (5.6, 5.7) |
| Purga constrói a mesa de pinball | **Implementado** como parede de vapor (5.8) |
| Legenda automática de morte (GDD 1.4 item 3) | **Implementado** (5.17) |
| Modo diário com semente compartilhada | **Implementado** (5.12, 5.18) |
| Onda de bumpers que pune matar rápido demais | **Implementado** (5.9, 5.10) |
| Decidir em uma página se o GDD passa a descrever o poço | **Registrado** em `GDD_ADENDOS.md` F, como vigente mas revogável |

### 2.3 Problemas extras achados durante a implementação

- **O smoke test apagava o save real** com `MetaManager.reset_save()` em `user://save.json`. Corrigido com `MetaManager.save_path`.
- **CI quebraria num clone limpo.** A pasta `.godot` está no `.gitignore`, então sem `--import` nenhum `class_name` resolve. O executor agora importa antes.
- **`_cycle_part` equipava o objeto do catálogo por referência**, e a Bancada alterava o tier da peça-modelo. Agora equipa `clone()`.
- **O tier de fusão do chassi não fazia nada**, porque o HP só usava a raridade. Agora usa `power_mult()`, raridade vezes fusão.
- **Estado do robô vazava entre runs**: calor, recargas e i-frames. Foi criado `Robot.reset_for_run()`.
- **O robô morto continuava atirando** durante os 1,2 s antes da Garagem. Há guarda em `_physics_process`.
- **`--fixed-fps` gera picos falsos** no benchmark (seção 8.3).
- **Vazamento de áudio na saída** do smoke. Continua aberto (10.1).

---

## 3. Estado do repositório

**24 arquivos rastreados modificados:** +1.905 / −486 linhas.
**17 arquivos novos:** 684 linhas, contando os `.uid`.
**Este documento** também é novo.

Modificados:
```
GDD_ADENDOS.md  README.md
actors/enemies/enemy.gd  actors/enemies/enemy_library.gd  actors/robot/robot.gd
autoload/game_rng.gd  autoload/meta_manager.gd  autoload/sfx.gd  autoload/telemetry.gd
combat/projectile_pool.gd  combat/projectile_type.gd  combat/wave_director.gd
data/behaviors/bhv_chain_lightning.gd  data/cpu_data.gd  data/part_data.gd  data/part_library.gd
generation/arena_generator.gd  generation/obstacle.gd
scenes/prototype.gd  tests/smoke.gd
ui/debug_overlay.gd  ui/garage_ui.gd  ui/hud.gd  ui/workbench_ui.gd
```

Novos:
```
combat/enemy_pool.gd       combat/steam_wall.gd       ui/run_caption.gd
tests/compile_check.gd     tests/compile_check.tscn
tests/gameplay.gd          tests/gameplay.tscn        tests/run_tests.ps1
.uid: autoload/meta_manager, combat/enemy_pool, combat/steam_wall, tests/compile_check,
      tests/gameplay, tests/smoke, ui/garage_ui, ui/run_caption, ui/workbench_ui
DOCUMENTACAO_2026-09-10.md
```

**Ao commitar:** inclua todos os `.uid`. O Git avisa `LF will be replaced by CRLF`, o que é esperado neste Windows e não é erro. Não havia nada em stage no fim da sessão.

---

## 4. Como rodar e verificar

### 4.1 Binários e comandos

| Uso | Comando |
|---|---|
| Jogo com janela | `F:\GODOT\Godot_v4.7.2-stable_win64.exe --path .` |
| Todos os testes (CI) | `powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1` |
| Importar e reconstruir o cache de classes | `Godot_..._console.exe --headless --path . --import` |
| Só compilação | `... --headless --path . res://tests/compile_check.tscn` |
| Só smoke, **sem** `--fixed-fps` | `... --headless --path . res://tests/smoke.tscn` |
| Só gameplay, **com** `--fixed-fps` | `... --headless --path . --fixed-fps 120 res://tests/gameplay.tscn` |

Binário de console: `F:\GODOT\Godot_v4.7.2-stable_win64_console.exe`. O executor aceita outro caminho em `-Godot`.

### 4.2 O que o executor faz

1. Roda `--import` e falha se o código de saída for diferente de zero.
2. Roda as três cenas em sequência. Só `gameplay` recebe `--fixed-fps 120`. Todas recebem `--quit-after 120000` como rede de segurança.
3. Cada cena só passa com **as três condições juntas**: código de saída 0, a linha `=== TUDO OK ===` e nenhum `SCRIPT ERROR`. O motivo: se o próprio script de teste não compila, o Godot abre a cena sem script, nunca chama `quit`, e o `--quit-after` sai com código 0.

### 4.3 Resultados de referência no fim da sessão

| Medida | Commit base | Fim da sessão |
|---|---|---|
| Scripts que compilam | 30 de 33 | 37 de 37 |
| Física por quadro, mediana, 800 projéteis | 1,96 ms | 2,02 ms |
| Física por quadro, p99 | 2,38 ms | 2,27 ms |
| Quadros acima de 8 ms | 0 | 0 |
| Quiques por projétil no benchmark | 11,8 | 11,2 |
| Contatos vazios | 0 | 1 em 8.984 casts bloqueados |

A arena do benchmark mudou porque o smoke agora ressemeia antes de gerá-la. Por isso quiques e contatos vazios não são comparáveis um a um.

Teste de gameplay, semente `20260910`:

| Medida | Valor |
|---|---|
| Anti-travamento, os dois casos resolvidos | 10,5 s de jogo |
| Setor 1 limpo atirando sem mirar | 30,4 s de jogo |
| Mediana de quique no setor 1 | x4,00 |
| Dano por ricochete | 98% |
| Rebatidas / perdidos no chão / invasões | 138 / 73 / 0 |

Semente do desafio de hoje, 10/09/2026 UTC: `E3FB039F`.

---

## 5. O que foi implementado, sistema por sistema

### 5.1 Testes

#### `tests/compile_check.gd`
- Percorre `res://` recursivamente, faz `load()` de cada `.gd` e exige `can_instantiate()`.
- **Não referencia nenhuma classe do jogo**, de propósito. Assim ele nunca deixa de compilar quando um script de gameplay quebra.

#### `tests/smoke.gd`, semente `20260908`

A primeira linha do `_ready` troca `MetaManager.save_path` para `user://smoke_test_save.json`. O arquivo é apagado no fim. Testes, em ordem:

| Teste | O que garante |
|---|---|
| `_test_bounce_table` | multiplicadores 1,00 / 1,25 / 1,5625 / 1,953125 / 4,00 e teto de 4,96 |
| `_test_hitstop_cap` | a regra de maior-valor e o teto de 130 ms |
| `_test_arena_constraints` | 40 salas, todas válidas |
| `_test_stream_isolation` | **novo:** a arena de uma semente não muda quando WAVES, SHOP, DROPS e COMBAT são consumidos |
| `_test_meta_manager` | conversão Sucata→Cobre, compra, persistência, `spend_scrap` e `refund_scrap`, Heat |
| `_test_daily_challenge` | **novo:** risco zero no diário, 150 uma vez por dia, vitória no diário não desbloqueia risco, persistência |
| `_test_workbench` | solda, reroll e, **novos**, fusão de duplicata e troca com reembolso |
| `_test_shop_rarity` | **novo:** setor 1 sem nada acima de Incomum, setor 5 sem Comum, receitas fora da vitrine, Olho Clínico, determinismo |
| `_test_enemy_and_boss_catalog` | chefes, geladeira bumper, todo inimigo com `article` |
| `_test_enemy_pool_recycling` | **novo:** um Rato Morto reciclado vira Parafuseta sem herdar ziguezague, sem alocar |
| `_test_bumper_and_breach` | **novo:** geladeira morta telegrafa 6 filhotes, invasão não paga Sucata nem conta abate |
| `_test_run_caption` | **novo:** a legenda contém autor, peças e setor, é determinística, e as contrações pelo/pela funcionam |
| `_test_determinism_lint` | **novo:** regex proíbe `randf(`, `randi(` e similares sem prefixo em `actors/`, `combat/`, `data/`, `generation/` e `scenes/` |
| benchmark, 900 quadros | tunelamento, contatos vazios abaixo de 1%, custo de física |

Detalhes:
- O benchmark usa `"ignore_floor": true`, porque mede o cast de varredura e não a regra do chão.
- Antes de gerar a arena do benchmark, o teste ressemeia com `GameRng.reseed(FIXED_SEED)`.
- O lint ignora o que vem depois de `#` na linha. Um `randf(` escrito em comentário não reprova.
- `quit_with` é assíncrono: chama `Sfx.stop_all()` e espera 30 quadros de 10 ms antes do `quit`.

#### `tests/gameplay.gd`, semente `20260910`

Usa `process_mode = ALWAYS` para continuar rodando com a árvore pausada. Save em `user://gameplay_test_save.json`, apagado no fim. É uma máquina de estágios com timeout de **180 s de jogo por estágio**, e estourar o timeout é o sintoma de soft-lock.

| Estágio | O que faz e verifica |
|---|---|
| `SOFTLOCK` | Antes de subir o jogo, cria 2 obstáculos soltos e 2 inimigos sem jogador na cena. Uma Parafuseta começa sobre um obstáculo de 300 px e precisa passar de y 640, contornando. A Fornalha Suprema, com raio 84, começa sobre um obstáculo de 900 px e precisa passar de y 420, espremendo-se. |
| `BOOT` | Instancia `scenes/prototype.tscn` com `start_seed`. Solta uma sonda caindo reto sobre o robô e outra caindo a 300 px dele, a partir de y 940. |
| `PADDLE` | Aos 0,35 s: rebatida registrada, sonda viva com pelo menos 1 quique, perda no chão registrada. Chama `_heat_purge()` e exige parede de vapor ativa. |
| `COMBAT` | Robô invulnerável, com `_iframes` forçado a 1,0 a cada quadro. Segura o fogo esquerdo e pulsa o direito a cada 30 quadros, até a Bancada abrir. |
| `WORKBENCH` | Com fogo segurado por 0,3 s: árvore pausada, nenhum projétil disparado, Bancada com foco. Envia ESPAÇO por `get_viewport().push_input()` e exige setor 2 e jogo despausado. |
| `BUMPERS` | Espera `wave_kind == &"bumpers"`, acha uma geladeira ativa, mata com dano gigante e exige pelo menos 6 telegrafias novas. |
| `DEATH` | Zera i-frames, HP em 1, e aplica dano com fonte "por uma Parafuseta de Teste". Quando a Garagem abre, exige legenda com o autor, semente correta, pausa e foco. Envia H. |
| `DAILY` | Exige Garagem fechada, `run_is_daily`, `GameRng.run_seed == daily_seed()` e jogo despausado. |

As teclas entram por `push_input` de propósito. Chamar `_gui_input` direto esconderia bug de foco.

### 5.2 Pausa e foco

Árvore da cena principal, montada em código em `scenes/prototype.gd`:

```
Prototype (Node2D, PROCESS_MODE_ALWAYS)
├── World (Node2D, PROCESS_MODE_PAUSABLE)   <- tudo que é simulação
│   ├── ArenaGenerator      (paredes e obstáculos são filhos dele)
│   ├── ProjectilePool      (MultiMeshInstance2D)
│   ├── EnemyPool           (128 Enemy inativos pré-alocados)
│   ├── WaveDirector        (grupo "wave_director")
│   ├── Robot
│   ├── SteamWall × 2
│   └── ArenaCamera
└── CanvasLayer             (herda ALWAYS)
    ├── Hud
    ├── DebugOverlay
    ├── GarageUI            (focus_mode FOCUS_ALL)
    └── WorkbenchUI         (focus_mode FOCUS_ALL)
Autoloads: CombatFeel, GameRng, GameInput, Sfx (ALWAYS), Vfx, Telemetry, MetaManager
```

- `_refresh_pause()` faz `get_tree().paused = garage.visible or workbench.visible`. É chamada em toda troca de tela.
- Garagem e Bancada conectam `visibility_changed` e chamam `grab_focus.call_deferred()` ao aparecer. Um clique também chama `grab_focus()`.
- **`Sfx` usa `PROCESS_MODE_ALWAYS`**, senão os sons de compra nos menus, que só existem com o jogo pausado, ficariam mudos.
- Os atalhos de debug B, G e F1 a F6 continuam em `_unhandled_input` do nó `Prototype`, que roda sempre. Os menus consomem as teclas 1 a 5, R, H e C antes, quando têm foco.
- As constantes `const GarageUI := preload(...)` foram removidas. Elas sombreavam as classes globais de mesmo nome.

### 5.3 Fluxo de run

```
_begin_run(daily, seed_override)
  semente: daily -> GameRng.daily_seed(), e o loadout volta aos índices 0
           senão -> seed_override, ou GameRng.fresh_seed() se for 0
  GameRng.reseed(semente) -> pool.reseed_rng() -> Telemetry.reset()
  MetaManager.start_new_run(-1, daily, semente)
  esconde menus -> _new_room(1) -> _refresh_pause()

_new_room(setor)
  enemy_pool.release_all(), director.stop(), pool.clear(), retract das paredes de vapor
  Vfx.clear_all(), CombatFeel.reset(), arena.generate(setor)
  reposiciona robô e câmera
  se setor == 1: set_cpu, equipa chassi[0] e os 3 slots por clone(), robot.reset_for_run()
  director.start_room(setor)

room_cleared -> setor >= 5 ? _finish_run(true) : espera 0,8 s -> Bancada, pausada
Bancada "prosseguir" -> _new_room(setor + 1)
robot.died -> _finish_run(false)

_finish_run(won)
  guarda contra reentrada com _run_over, director.stop()
  legenda = RunCaption.build(robot, won, setor, GameRng.run_seed)
  MetaManager.end_run(5 se venceu senão setor, won, {"caption": legenda})
  imprime telemetria, legenda e resumo -> espera 1,2 s -> Garagem, pausada
```

`@export var start_seed` na cena principal existe para testes. Zero sorteia uma semente nova.

### 5.4 Inimigos: ciclo de vida, pool e anti-travamento

**`combat/enemy_pool.gd`:** `PREWARM := 128`.
- `acquire(spec, at)` retira um inimigo livre e chama `activate`. Se o pool esgotar, cria mais um e incrementa `grown`.
- `release(e)` só age se o inimigo estiver ativo. `release_all()` libera todos. `active_count()` e `capacity()` informam o estado.
- **O inimigo inativo continua na árvore.** Ele fica fora dos grupos `enemies` e `damageable`, com `collision_layer` e `collision_mask` em 0, invisível, sem processamento de física e parado em (-10000, -10000).
- Motivo: o inimigo morre dentro de `ProjectilePool._resolve_bounce`. Tirar o nó da árvore ali exigiria adiar a operação, e o inimigo morto seguiria rebatendo projéteis até o fim do quadro.

**`Enemy.activate(spec, ai_group, at)`** substitui o antigo `setup()`:
1. Aplica o dicionário `FACTORY` com os valores de fábrica, depois o `spec`.
2. Zera todo o estado de execução, inclusive anti-travamento e `_player`.
3. Ajusta o raio do `CircleShape2D` compartilhado, liga camadas e grupos, reativa o processamento.
4. Usa `position` se o nó ainda não está na árvore, senão `global_position`.

`_ready` só cria a forma de colisão e a `_overlap_query`. Um inimigo avulso, fora do pool, faz `queue_free()` em `_release()`.

**Campos novos do `Enemy`:** `article`, `is_bumper`, `descent_factor` (padrão 0,40), `spawn_on_death`, `spawn_on_death_count`, `active` e `pool`, este sem tipo para evitar ciclo de classes.

**`flees`** agora funciona. Com o jogador a menos de 320 px na horizontal, o inimigo foge para o lado oposto a 60% da velocidade.

**Anti-travamento**, em `_update_stuck`, `_start_escape`, `_start_squeeze` e `_update_squeeze`:
1. Conta tempo parado quando o inimigo quer descer e desceu menos de 25% do esperado no quadro.
2. Com `STUCK_BEFORE_ESCAPE := 0.35` s, procura o corpo embaixo: uma colisão de deslizamento com normal y abaixo de -0,5.
   - Sem corpo embaixo, como no recuo de contato, não faz nada.
3. Calcula as bordas do bloqueador. Para `Obstacle` usa `size.x`; para outros corpos, como a parede de vapor, assume meia largura de 130 px.
4. Verifica se cabe à esquerda ou à direita, exigindo 2×(raio+6) de folga até a borda do poço. Vai para o lado que cabe e tem menor percurso.
   - Velocidade de fuga: `max(move_speed × 0,8, 80)`.
   - Duração: percurso dividido pela velocidade, mais 0,25 s.
5. Se nenhum lado cabe, ou depois de `MAX_ESCAPE_ATTEMPTS := 2` fugas sem sucesso, entra em **modo espremido**:
   - `collision_mask = 0`, com x preso manualmente dentro do poço.
   - Só sai depois de descer pelo menos um raio **e** sem sobrepor a camada de paredes, verificado por `intersect_shape`.
   - Motivo da primeira condição: no instante em que o modo começa, o inimigo está apoiado em cima do obstáculo, sem tocá-lo.
   - Rede de segurança: `SQUEEZE_TIMEOUT := 20` s.
6. Espremido, o inimigo é desenhado com 60% de alfa. Os projéteis continuam quicando nele, porque a camada dele não muda.

### 5.5 Invasão da base e morte

- `_check_contact()` usa `_player.call("body_center")` para o contato direto. Isso passa `source_text()` e `breach=false`.
- Em `global_position.y >= BASELINE_Y - 12`, chama `_breach()`. Ele causa dano com `breach=true`, tremor e efeito visual, incrementa `Telemetry.enemies_breached` e libera o inimigo. **Não dá Sucata, cura, abate nem som de morte.**
- `_die()`:
  - Chefe cura 50% do HP máximo.
  - Comum sorteia cura de 4% no fluxo **DROPS**. O sorteio acontece sempre, com ou sem jogador, para o consumo do fluxo ser estável.
  - Se tiver `spawn_on_death`, chama `get_tree().call_group(&"wave_director", &"spawn_minions", ...)`.
- `source_text()` devolve `RunCaption.by_whom(article, enemy_name)`.

### 5.6 `ProjectilePool`: rebatedor, chão e ajustes

Constantes novas:

| Constante | Valor | Função |
|---|---|---|
| `MAX_SPEED` | 1800 px/s | teto depois da restituição; pneu e rebatedor em ciclo dobravam a velocidade sem limite |
| `PADDLE_MAX_ANGLE` | 1,0821 rad, 62° | desvio máximo da vertical na borda do corpo |
| `PADDLE_MIN_SPEED` | 520 px/s | velocidade mínima de saída do rebatedor |

Array paralelo novo: `_floor_immune`, vindo de `ProjectileType.ignore_floor` e herdado pelos filhos de divisão.

**Máscara de colisão em `_step`:**
- Projétil do jogador colide com paredes e inimigos. Colide com o robô **só quando `vel.y > 0`**, ou seja, caindo. O tiro nasce sobreposto ao corpo e subindo, e sem esse filtro quicaria no cano.
- Projétil inimigo colide com paredes e jogador. Ainda não existe nenhum.

**`_resolve_bounce`**, antes de tudo, para facção do jogador:
- Colisor no grupo `player` vai para `_paddle(i, robot)`.
- Colisor com `is_floor` verdadeiro, em projétil sem `_floor_immune`, soma `Telemetry.projectiles_lost_floor` e mata com plop.

**`_paddle(i, robot)`:**
```
centro  = robot.body_center()
alcance = Robot.COLLISION_RADIUS + raio do projétil
offset  = clamp((pos.x - centro.x) / alcance, -1, 1)
ângulo  = -90° + offset × 62°
vel     = direção(ângulo) × clamp(|vel| × robot.paddle_restitution, 520, 1800)
pos.y   = min(pos.y, centro.y - alcance - 1)
quiques = min(quiques + 1, 12)
max_q   = min(max(max_q, quiques) + 1, 12)   # não gasta orçamento
idade   = 0                                  # rebatido não é esquecido
last_hit_id = 0
```
Depois disso, a função incrementa `Telemetry.paddle_catches`, chama `robot.on_paddle_hit(pos, quiques)` e roda os comportamentos `on_bounce` com o robô como colisor. Um Tesla ou uma divisão disparam no rebatedor. Por fim, VFX e som de quique.

**Outros ajustes:**
- **Pólvora Grossa:** acerto do jogador com quique 2 ou mais multiplica o dano por `1 + MetaManager.get_bounce_damage_bonus()`.
- `kill(i, plop)` **não conta mais telemetria**. Quem chama decide o contador: `projectiles_expired_slow` na velocidade mínima, `projectiles_lost_floor` no chão, nenhum no TTL.
- `reseed_rng()` é chamado em todo início de run, depois de `GameRng.reseed`.
- Acessores novos para testes: `get_velocity_of`, `get_bounces_of`, `is_alive`.

### 5.7 `Robot`

- `BODY_CENTER := Vector2(0, -36)`. A forma de colisão fica ali, não nos pés, para o projétil que cai bater no corpo desenhado. `body_center()` devolve a posição global correspondente.
- `MUZZLE_DISTANCE := 38`: o cano sai de `body_center() + mira × 38`. A mira por mouse e a assistência de mira também partem do centro do corpo.
- `paddle_restitution` vem de `chassis.restitution` em `_recompute_stats`.
- O HP do chassi agora é `(hp × power_mult() + bônus fixo) × multiplicador de bônus`.
- `total_tdp()` soma o TDP da CPU com a Fiação Grossa. HUD, painel e Bancada usam esse valor; antes ignoravam o bônus.
- **Crítico** usa `GameRng.randf_in(Stream.COMBAT)`.
- `reset_for_run()` zera calor, superaquecimento, recargas, i-frames, flashes, espasmo, dash, recuo, deformação e última fonte de dano. Também enche HP e cargas de dash e recolhe as paredes de vapor.
- `_physics_process` retorna cedo com `hp <= 0`.
- **Assinatura nova:** `take_damage(amount, from, bounce_index, source := "", breach := false)`. Grava `last_damage_source` e `last_damage_was_breach` só quando o dano é aplicado de fato, depois do teste de i-frames.
- `on_paddle_hit(at, quiques)`: deformação 1,22 por 0,80, flash do arco do rebatedor na cor do quique, tremor pequeno e som `paddle`.
- Desenho: arco sobre o corpo, amarelo quando o chassi acelera, piscando na cor do quique ao rebater. A linha de mira parte do centro do corpo.
- **Purga:** mantém o dano em área, agora medido a partir do centro do corpo, e chama `_deploy_steam_wall()`.
  - Alvo pelo mouse, ou `centro + mira × 420` no controle.
  - x preso em [60, 940] e y em [260, 820].
  - Rotação perpendicular à mira.
  - `_free_steam_wall()` usa uma parede livre ou recicla a de menor vida restante.

### 5.8 `SteamWall`

`combat/steam_wall.gd` é um `StaticBody2D` pré-alocado. A cena cria 2, em `STEAM_WALL_COUNT`.

| Parâmetro | Valor |
|---|---|
| `DURATION` | 3,0 s |
| `SIZE` | 240 × 26 px |
| `RESTITUTION` | 1,35, a mesma da Pilha de Pneus |
| `FADE_TIME` | 0,5 s |

- `deploy(at, angle)` liga `collision_layer = LAYER_WALLS`. `retract()` desliga. A vida só corre fora de hitstop.
- Não entra nos grupos `obstacles` nem `damageable`.
- Inimigos colidem com ela, porque usam a máscara de paredes. Ela segura o avanço por 3 s, e o anti-travamento trata esse caso.
- Desenho: 7 bolotas de fumaça sem gradiente, contorno ciano e 3 setas amarelas no espaço local.

### 5.9 `WaveDirector`

- Usa o **fluxo WAVES** em todos os sorteios. Antes dividia ROOMGEN com o gerador de arena.
- `active` agora começa `false`. `start_room()` liga. `stop()` desliga e limpa as telegrafias.
- Entra no grupo `wave_director` no `_ready`.
- `alive_enemies()` usa `enemy_pool.active_count()` quando existe pool, em vez de montar um array do grupo a cada quadro.
- Constantes: `NEXT_WAVE_SILENCE := 0.6`, `ROOM_CLEAR_DELAY := 1.2`, `BANNER_TIME := 2.5`, `MINION_TELEGRAPH_TIME := 0.25`.
- `BOSS_BY_SECTOR := {1: "mini_prensa", 3: "frostbyte", 5: "fornalha_suprema"}`.
- `BUMPER_WAVE_BY_SECTOR := {2: 2, 4: 2}`, ou seja, onda 2 dos setores 2 e 4.
- `wave_kind` pode ser `&"normal"`, `&"boss"` ou `&"bumpers"`, e `wave_banner_time` alimenta o letreiro da HUD.
- **Onda de bumpers:**
  - Nasce 1 geladeira a mais por setor 4 em diante: 2 nos setores 2 e 3, 3 a partir do 4.
  - Elas ficam distribuídas em x com variação de ±40 px e y entre 100 e 140. Cada uma custa 8 de ameaça.
  - O resto do orçamento vira só Fantasma de Disquete, com Parafuseta quando o custo não cabe.
- `spawn_minions(key, at, count)` telegrafa filhotes com deslocamento de ±60 em x e -30 a +10 em y. x fica preso em [30, 970] e y no máximo 80 px acima da baseline. Não faz nada se o diretor estiver inativo.
- As telegrafias agora guardam o próprio tempo em `"time"`.

### 5.10 `EnemyLibrary`

- Todo spec ganhou `article`: parafuseta "uma", rato_morto "um", vovo_geladeira "uma", fantasma_disquete "um", jato_preto "um", mini_prensa "a", frostbyte "o", fornalha_suprema "a".
- **"A Fornalha Suprema" virou "Fornalha Suprema"** com artigo "a", para a legenda dizer "pela Fornalha Suprema".
- "Vovo Geladeira" ganhou acento.
- Spec novo `geladeira_bumper`, "Vovó Geladeira Lotada": HP 420, velocidade 60, `descent_factor` 0,35, dano 20, restituição 1,35, raio 42, Sucata 30, `is_bumper`, e 6 Parafusetas ao morrer.
- Foram removidas as verificações inúteis `Engine.has_singleton(&"MetaManager")`.

### 5.11 `GameRng`

Fluxos e quem usa cada um:

| Fluxo | Usado por |
|---|---|
| DROPS | cura por abate em `Enemy._die` |
| ROOMGEN | `ArenaGenerator` |
| VFX | `Vfx`, `Sfx.play_varied`, tremor do retículo na HUD, teste de estresse F3 |
| COMBAT | crítico do robô; semente do RNG de jitter do pool |
| AI | fase inicial do inimigo |
| **SHOP**, novo | vitrine da Bancada |
| **WAVES**, novo | ondas, bumpers e filhotes |

SHOP e WAVES foram acrescentados **no fim** do enum, então os índices antigos não mudaram.

Funções novas:
- `fresh_seed()` gera um hash de milissegundos Unix e microssegundos de ticks.
- `utc_date_key()` devolve `"AAAA-MM-DD"` em UTC.
- `daily_seed()` devolve `hash("scrapabot-daily-" + data)`. A string é idêntica à antiga.
- `seed_label(s)` devolve 8 dígitos hexadecimais.

O teste de estresse F3 passou do fluxo COMBAT para VFX, para não mexer no fluxo de combate da run.

### 5.12 `MetaManager`

- `save_path`, com padrão `user://save.json`. **Os testes trocam antes de qualquer escrita.**
- `SAVE_VERSION := 2`. Campos novos: `daily_date`, `daily_best_sectors`, `daily_rewarded`. Um save v1 carrega com esses campos no padrão.
- Estado de run novo: `run_is_daily` e `run_seed`.
- `start_new_run(heat := -1, daily := false, seed_value := 0)`.
- `active_heat()` devolve 0 no diário, senão `selected_heat`. **Todos os getters de Heat usam isso.**
- `spend_scrap(n)` falha sem alterar nada se faltar saldo. `refund_scrap(n)` devolve sem aplicar o Ímã de Sucata.
- `refresh_daily()` zera o progresso do dia quando a data UTC muda.
- `end_run(sector_reached, won := false, extra := {})`:
  - soma `Telemetry.enemies_killed` em `total_kills`;
  - vitória no diário **não** sobe `highest_heat_beaten`;
  - calcula `sectors_cleared`, 5 se venceu, senão `sector_reached - 1`;
  - no diário, atualiza o melhor do dia e paga `DAILY_REWARD := 150` uma vez por dia quando `sectors_cleared >= DAILY_GOAL_SECTORS := 3`. Essa recompensa não é multiplicada pelo Heat;
  - o resumo ganha `sectors_cleared`, `daily`, `daily_reward`, `seed` e `kills`, e é mesclado com `extra`, onde vai a legenda.
- Falha de parse do save agora emite `push_warning` e mantém o estado, em vez de `print`.

### 5.13 `Sfx`

- `PROCESS_MODE_ALWAYS` (ver 5.2).
- **Limitador de vozes reescrito**, sem timer nem lambda por som:
  - Guarda por voz o som tocado e o instante de início em microssegundos.
  - A cada `play()`, percorre as 32 vozes: conta quantas tocam o mesmo som, acha a mais antiga desse som, a primeira livre e a mais antiga no geral.
  - Com 4 vozes do mesmo som, rouba a mais antiga, como pede o GDD 3.4.3. **Mas só se ela tiver pelo menos `STEAL_MIN_AGE_USEC := 25000`, ou 25 ms.** Sem esse intervalo, cada quique reiniciava um playback e o próprio limitador virava gargalo.
  - Sem voz livre, usa a mais antiga no geral.
- Som novo `paddle`, uma mola que sobe de tom.
- Os ruídos da síntese agora usam um RNG local com semente fixa, em vez do `randf()` global.
- `stop_all()` para todas as vozes. `_exit_tree()` chama `stop_all()`.

### 5.14 `Telemetry`

Contadores novos: `paddle_catches`, `projectiles_lost_floor` e `enemies_breached`. Os três entram no `summary()` e são zerados no `reset()`.

### 5.15 Dados das peças

**`PartData`** ganhou:
- `restitution`, lida só no chassi;
- `recipe_only`, que tira a peça da vitrine;
- `caption`, o texto da legenda;
- `power_mult()`, raridade vezes fusão;
- `sell_value()`, metade de `base_price()`, que depende só da raridade e ignora o tier.

`clone()` copia os campos novos. **`CpuData`** ganhou `caption`.

**Chassis e restituição do rebatedor:**

| Chassi | HP | Velocidade | Dash | Watts | Restituição |
|---|---|---|---|---|---|
| Molas de Sofá, o padrão | 85 | 312 | 1 | 22 | **1,35** |
| Esteiras de Trator | 240 | 195 | 1 | 30 | **1,15** |
| Rodinhas de Carrinho | 70 | 377 | 1 | 26 | **1,00** |
| Pernas de Manequim | 95 | 268 | 3 | 28 | **1,10** |
| **Chassi de Cofre**, novo | 320 | 169 | **0** | 36 | **1,60** |

O Cofre segue o GDD 4.6, mas **sem o bloqueio frontal de 70%**. Com 0 cargas, ele não tem dash.

**Legendas das peças:**
- ratoeira: "uma ratoeira de mouse"; furadeira: "uma furadeira gagá"; grampeador: "um grampeador metralhadora".
- fonte: "uma fonte de 500W que mente"; bazuca: "um cano de pia armado"; HD: "um HD dando o clique da morte".
- torradeira: "uma torradeira"; Tesla: "uma torradeira eletrificada".
- chassis: "molas de sofá", "esteiras de trator de brinquedo", "rodinhas de carrinho de mercado", "pernas de manequim", "um cofre de perninhas curtas".
- CPUs: "um Pentiun enferrujado", "um Ryzin frito", "uma placa de vídeo enfiada no soquete".

**TORRADA TESLA** agora tem `recipe_only = true`. **Como ainda não existe sistema de receitas, ela só é obtida pela tecla de debug 3.**

**Vitrine por setor**, GDD 3.1, em `SECTOR_RARITY_WEIGHTS`:

| Setor | Comum | Incomum | Rara | Lendária |
|---|---|---|---|---|
| 1 | 80 | 20 | 0 | 0 |
| 2 | 60 | 35 | 5 | 0 |
| 3 | 40 | 40 | 20 | 0 |
| 4 | 20 | 45 | 35 | 0 |
| 5 | 0 | 30 | 50 | 20 |

- `rarity_weights(setor, rare_bonus)`: o Olho Clínico tira `bonus × 100` pontos da raridade mais baixa presente e soma na Rara. No setor 1 fica 65 / 20 / 15 / 0.
- `roll_rarity(rng, pesos)` faz o sorteio ponderado.
- **Assinatura nova:** `roll_shop_offer(count, sector := 1, rare_bonus := 0.0)`, usando o fluxo SHOP.

### 5.16 `BhvChainLightning`

`_chain` recebe o índice de quique do projétil de origem. O índice vai para `take_damage`, então o arco de um projétil ricocheteado fere o Fantasma de Disquete. Vai também para `Telemetry.record_hit`, e a mediana do pilar 3 deixa de ser poluída.

### 5.17 `RunCaption`

`ui/run_caption.gd`, uma classe estática:
- `by_whom(artigo, nome)`: "o" vira "pelo", "a" vira "pela", "os" vira "pelos", "as" vira "pelas", vazio vira "por", e o resto fica "por <artigo> <nome>".
- `build(robot, won, setor, semente)`:
  - O RNG local usa `hash(semente|setor|won|fonte)`, então a mesma run gera a mesma frase.
  - **Derrota:** "<verbo> <fonte> no setor N enquanto pilotava <cabeça> com <chassi> e <braço direito> no braço."
    - Verbos de morte: Morto, Desmontado, Reciclado à força, Transformado em sucata, Mandado de volta pro ferro-velho.
    - Verbos de invasão: Atropelado na linha de defesa, Invadido, Pisoteado na própria base.
    - Sem fonte registrada, usa "pela própria gambiarra".
  - **Vitória:** "Venceu os 5 setores pilotando ... movido por <CPU>."
  - **Comentário final** pela telemetria, na primeira regra que bater:
    1. mediana ≥ 4 com pelo menos 20 acertos: "Pelo menos os quiques estavam magenta."
    2. mais de 30 perdas no chão e mais que 3× as rebatidas: "Deixou cair mais bala do que rebateu."
    3. 8 ou mais invasões: "A linha de defesa era mais sugestão do que regra."
    4. ricochete abaixo de 20% com pelo menos 20 acertos: "Mirou direto no inimigo, feito amador."

### 5.18 Interface

**`GarageUI`:**
- Sinal novo: `start_run_requested(daily: bool)`.
- Teclas: ESPAÇO, ENTER ou KP_ENTER para run normal; **H** para desafio de hoje; **C** para copiar a legenda com `DisplayServer.clipboard_set`, com o aviso "COPIADO!" por 1,5 s; 1 a 5 para upgrades; A, D, setas ou colchetes para o Heat.
- Layout:
  - resumo da última run em y 106, com semente e meta diária;
  - legenda entre aspas em y 130, em até 2 linhas com `draw_multiline_string`, e botão de copiar à direita;
  - abas em y 172;
  - painel do ramo em y 226;
  - botão do desafio de hoje à direita do INICIAR, mostrando a meta ou "meta cumprida" e o melhor do dia.
- O cálculo de bônus de cobre na barra de risco usa `selected_heat × 25`, e não o getter, porque o getter usa `active_heat` e seria 0 depois de um diário.
- Os emojis antigos do saldo foram removidos.

**`WorkbenchUI`:**
- `offer_mode(peça)` devolve `&"equip"` para slot vazio, `&"fuse"` para peça igual, `&"swap"` para peça diferente e `&"maxed"` para peça igual já no tier IV.
- Fusão sobe o tier da peça equipada e herda a raridade maior. Troca devolve `sell_value()` da peça que sai.
- Rótulos dos botões: "Equipar (preço)", "FUNDIR +TIER (preço)" em magenta, "Trocar (preço, volta X)" e "JÁ NO TIER IV".
- Todo gasto passa por `MetaManager.spend_scrap`.
- A linha de tier diz "poder" em vez de "Dano". O chassi mostra o multiplicador do rebatedor.
- `REROLL_INCREMENT` continua 30. **Diverge dos 40 do ADENDOS B.3.** Ver 10.2.

**`Hud`:**
- `MAX_PLATES := 32`: acima disso, cada chapa vale mais que 25 HP.
- O cabeçalho mostra rebatidas e uma linha com a semente, prefixada por "DESAFIO DE HOJE" no diário.
- **Letreiro de onda especial** por 2,5 s: "ONDA DE BUMPERS" com a explicação, ou "CHEFE NO POÇO".
- A Purga aparece como "E PURGA + PAREDE".
- O tremor do retículo usa o fluxo VFX.

**`DebugOverlay`:** limites da arena lidos das constantes, pool de inimigos com ativos, capacidade e crescimento, restituição do rebatedor, tier de cada peça, abates totais e semente.

### 5.19 Geração

- `Obstacle` ganhou `@export var is_floor := false`.
- `ArenaGenerator._build_walls` marca `o.is_floor = r.position.y >= ARENA_SIZE.y`, o que só é verdadeiro para a parede de baixo.

### 5.20 Documentos

- `README.md` foi reescrito com formato, controles da Garagem e da Bancada, testes, estrutura e o que está implementado.
- `GDD_ADENDOS.md` ganhou a **seção F**:
  - F.1: o que mudou, o status e o risco de comparação com BALL x PIT;
  - F.2: tabela das seções do GDD suspensas;
  - F.3: mecânicas do formato;
  - F.4: decisões menores;
  - F.5: pendências.
  - O rodapé virou "Adendos v1.1".
- `DOCUMENTACAO_2026-09-09.md` **não foi alterado** e está desatualizado em alguns pontos. Este documento o substitui onde divergirem.

---

## 6. Mudanças de API

| Antes | Agora |
|---|---|
| `Enemy.setup(spec, ai_group)` | `Enemy.activate(spec, ai_group, at)` e `Enemy.deactivate()` |
| `Robot.take_damage(amount, from, bounce)` | `take_damage(amount, from, bounce, source := "", breach := false)` |
| colisão do robô na origem, que é a base | colisão em `BODY_CENTER`; use `robot.body_center()` |
| `MetaManager.start_new_run(heat)` | `start_new_run(heat, daily, seed_value)` |
| `MetaManager.end_run(sector, won)` | `end_run(sector, won, extra)` |
| getters de Heat usavam `selected_heat` | usam `active_heat()` |
| `PartLibrary.roll_shop_offer(count, rare_bonus)` | `roll_shop_offer(count, sector, rare_bonus)` |
| `GarageUI.start_run_requested()` | `start_run_requested(daily: bool)` |
| `ProjectilePool.kill` contava `projectiles_expired_slow` | não conta; quem chama decide |
| `WaveDirector.active` começava `true` | começa `false`; `start_room` liga e `stop` desliga |
| `Sfx.play` recusava o som com 4 vozes ativas | rouba a mais antiga, com intervalo mínimo de 25 ms |
| `prototype.gd` tinha `const GarageUI` e `WorkbenchUI` com preload | usa as classes globais |
| `project.godot` | **não mudou** |

---

## 7. Decisões tomadas

### 7.1 Decisões de design com número ajustável

| Decisão | Valor | Onde |
|---|---|---|
| Formato de poço vigente | seção F dos adendos | `GDD_ADENDOS.md` |
| Meta do desafio diário | 3 setores limpos | `MetaManager.DAILY_GOAL_SECTORS` |
| Recompensa diária | 150 Cobre, uma vez por dia UTC | `MetaManager.DAILY_REWARD` |
| Restituição do rebatedor | 1,00 a 1,60 por chassi | `PartLibrary.chassis_parts()` |
| Ângulo máximo do rebatedor | 62° | `ProjectilePool.PADDLE_MAX_ANGLE` |
| Velocidade máxima de projétil | 1800 px/s | `ProjectilePool.MAX_SPEED` |
| Parede de vapor | 240×26, 3 s, restituição 1,35 | `SteamWall` |
| Onda de bumpers | onda 2 dos setores 2 e 4, 6 filhotes | `WaveDirector`, `EnemyLibrary` |
| Tier de fusão no chassi | multiplica HP | `Robot._recompute_stats` |
| Pool de inimigos | 128 pré-alocados | `EnemyPool.PREWARM` |

### 7.2 Limitações conhecidas dessas decisões

- **O desafio diário não é idêntico entre jogadores.** Os upgrades permanentes da Garagem continuam valendo. Semente, loadout e risco são iguais.
- Mesmo com a mesma semente, **os pontos de spawn podem divergir** se os jogadores estiverem em posições diferentes. `_pick_spawn_point` rejeita pontos perto do jogador e consome o fluxo WAVES de forma variável. A arena é idêntica, e o teste de isolamento prova isso.
- O rebatedor vale para qualquer projétil do jogador caindo sobre o robô, inclusive filhotes de divisão.

### 7.3 Decisão pendente do usuário

- **Confirmar ou reverter o formato de poço** antes do Vertical Slice. A seção F diz "vigente", mas a escolha foi feita durante a implementação das sugestões, não numa conversa específica sobre isso.

---

## 8. Descobertas técnicas sobre o ambiente e o Godot 4.7.2

### 8.1 Cache de classes globais
- Scripts novos com `class_name` **só ficam visíveis depois que o editor varre o projeto.**
- Headless, isso exige `--headless --path . --import`. O comando também gera os `.uid` que faltam.
- Sem isso, aparecem erros em cascata como `Could not find type "SteamWall"` e `Cannot infer the type of ...`.
- Como `.godot/` está no `.gitignore`, **toda CI e todo clone limpo precisam importar primeiro.**

### 8.2 Teste que não compila não falha sozinho
- Se o script da cena de teste tem erro de parse, o Godot abre a cena sem script e nunca chama `quit`.
- Com `--quit-after`, sai com **código 0**. Por isso o executor exige a linha `=== TUDO OK ===`.

### 8.3 `--fixed-fps` e áudio
- Com `--fixed-fps 120`, o laço principal roda muito mais rápido que o tempo real. As chamadas de som se acumulam contra a thread de áudio, e `TIME_PHYSICS_PROCESS` mostra **picos falsos de 8 a 10 ms**, entre 35 e 105 quadros por execução.
- `--verbose` **esconde** o efeito, porque deixa cada quadro mais lento. Não use verboso para medir.
- **Nunca rode dois testes Godot em paralelo** ao medir desempenho. A disputa de CPU também gera picos.
- Conclusão aplicada: o smoke roda sem a flag e o gameplay roda com ela.

### 8.4 Input em testes
- `get_viewport().push_input(evento)` entrega teclas pelo roteamento real de foco.
- `Input.action_press` feito no `_physics_process` do nó de teste vale no mesmo quadro para os filhos, porque o pai processa antes.

### 8.5 GDScript
- Valor lido de `Array` ou `Dictionary` sem tipo, atribuído com `:=`, dá erro de parse `Cannot infer the type`. Declare o tipo explicitamente.
- Enemy e EnemyPool se referenciam. O campo `Enemy.pool` ficou sem tipo e a chamada usa `pool.call("release", self)`.

### 8.6 Ferramentas da máquina
- **Não há Python.** `python`, `python3` e `py` não existem.
- Um heredoc muito grande numa única chamada do Bash falha com `ENAMETOOLONG`, por limite de linha de comando do Windows. Para arquivos grandes, escreva numa pasta de preparo e copie.
- O Git avisa conversão de LF para CRLF em todo arquivo tocado. Isso é inofensivo.

---

## 9. Incidente: save real sobrescrito

- **O que aconteceu:** o `tests/smoke.gd` do commit base chamava `MetaManager.reset_save()` e `end_run()` sem trocar o caminho do save. O teste foi rodado às 00:09 de 10/09/2026, durante a varredura, antes de o problema ser conhecido.
- **Arquivo:** `%APPDATA%\Godot\app_userdata\SCRAP-A-BOT\save.json`.
- **Conteúdo atual:** Cobre 590, Chapa 1, `highest_heat_beaten` 3, `total_runs` 2, `best_sector` 5, versão 1. É exatamente a sequência do teste.
- **Prova:** o mesmo teste, rodado depois numa cópia isolada do commit base com outro nome de projeto, gerou um save idêntico. Essa cópia e seus dados foram apagados em seguida.
- **Consequência:** o progresso anterior nesse arquivo se perdeu e não é recuperável. É possível que ele já fosse resultado de execuções anteriores do mesmo teste pelo próprio usuário.
- **Correção:** `MetaManager.save_path`. Smoke e gameplay usam saves próprios e os apagam no fim. O arquivo real manteve o horário 00:09 depois de todas as execuções posteriores.
- O save será migrado para a versão 2 na próxima vez que o jogo gravar.

---

## 10. Pendências e próximos passos

### 10.1 Vazamento de áudio na saída do smoke, aberto

**Sintoma:** `WARNING: 5 ObjectDB instances were leaked at exit`. Em modo verboso aparecem 8 `AudioStreamPlaybackWAV` e 1 `AudioStreamWAV`. O gameplay sai limpo. O CI não falha, porque o executor não olha esse aviso.

O que já foi verificado:

| Experimento | Resultado |
|---|---|
| Smoke do commit base, cópia isolada, sem `--fixed-fps` | **0 vazamentos** |
| Código novo sem roubo de voz, trocando a condição do roubo por `if true:` | **ainda vaza**, 7 objetos |
| `_exit_tree` com `stop()` e `stream = null` | ainda vaza |
| `stop_all()` e espera de 2 quadros com 80 ms antes do quit | gameplay limpo, smoke ainda vaza |
| `stop_all()` e 30 quadros de 10 ms antes do quit | smoke ainda vaza, 5 objetos |
| Sem `--fixed-fps` | ainda vaza, 7 objetos |

Hipóteses ainda não testadas, em ordem de custo:
1. `process_mode = ALWAYS` no `Sfx`. Teste removendo a linha e rodando o smoke.
2. A seleção de voz "primeira livre" substituiu o rodízio antigo e reusa sempre as vozes de índice baixo. Teste restaurando o rodízio.
3. Sons tocados dentro do `_ready` do smoke. O teste novo toca cerca de 5: solda, reroll, fusão, troca e morte da geladeira. O antigo tocava 2. Teste com `Sfx.play` retornando cedo durante o `_ready`.
4. Som novo `paddle` ou `_exit_tree` do Sfx.

Comando de bisseção, lembrando de restaurar o `sfx.gd` depois:
```bash
G="F:/GODOT/Godot_v4.7.2-stable_win64_console.exe"
"$G" --headless --path . --quit-after 120000 res://tests/smoke.tscn 2>&1 | grep -E "ObjectDB|TUDO OK"
```

### 10.2 Inconsistências conhecidas não resolvidas
- **Reroll:** o código incrementa 30 por uso (`WorkbenchUI.REROLL_INCREMENT`). `GDD_ADENDOS.md` B.3 e o relatório de 09/09 dizem 40.
- **TORRADA TESLA** está fora da vitrine e não existe sistema de receitas. Hoje só a tecla 3 de debug a equipa.
- **Hitstop de fusão de 350 ms** do GDD 3.4.1 não acontece. A Bancada roda com o jogo pausado.
- `sell_value()` ignora o tier. Uma peça no tier IV devolve o mesmo que no tier I.
- **`DOCUMENTACAO_2026-09-09.md`** diz reroll +40, chefes "no setor 1, 3 e 5" sem mencionar o poço, e não conhece nada desta sessão.

### 10.3 Não verificado
- **Visual com janela:** layout da Garagem com a legenda em 2 linhas, letreiro de onda, arco do rebatedor, parede de vapor, desenho da geladeira bumper. Tudo foi validado só headless.
- **Controle:** alvo da parede de vapor pela mira do analógico e assistência de mira a partir do centro do corpo.
- **Área de transferência:** `DisplayServer.clipboard_set` não faz nada em headless.
- **Fonte:** o emoji 🔩 da HUD talvez não renderize na fonte padrão. O problema já existia.
- **Sensação do rebatedor:** ângulo de 62°, velocidade mínima de 520 e restituições não foram testados por uma pessoa jogando.

### 10.4 Próximos passos sugeridos, por prioridade
1. **Abrir o jogo com janela** e jogar uma run completa, olhando os itens de 10.3.
2. **Commitar**, com todos os `.uid`, se o usuário aprovar.
3. **Confirmar o formato de poço** com o usuário (7.3).
4. Fechar o vazamento de áudio pela bisseção de 10.1.
5. Resolver o reroll, 30 ou 40, e atualizar o relatório de 09/09 ou marcá-lo como histórico.
6. Balancear restituições pela razão entre rebatidas e perdas no chão, que já está na HUD e no painel.
7. Redesenhar os chefes com fases para o poço (GDD 5.4 a 5.6).
8. Implementar o bloqueio frontal de 70% do Cofre.
9. Sistema de receitas de fusão (GDD 4.7.2), para a TESLA voltar a ser obtível.
10. Reescrever as seções 3.1, 3.2 e 3.3.4 do GDD na v1.1.

---

## 11. Glossário desta sessão

| Termo | Significado |
|---|---|
| **Rebatedor** | o corpo do robô como superfície que devolve para cima o projétil do jogador que cai |
| **Chão do poço** | a parede inferior da arena, marcada com `is_floor`; mata o projétil do jogador |
| **Parede de vapor** | superfície temporária criada pela Purga no ponto mirado |
| **Onda de bumpers** | onda 2 dos setores 2 e 4, com geladeiras que aceleram tiros e liberam enxame ao morrer |
| **Invasão** | inimigo que chega na linha de defesa; machuca e some sem recompensa |
| **Modo espremido** | estado do anti-travamento em que o inimigo atravessa obstáculos sem máscara de colisão |
| **Desafio de hoje** | run com semente da data UTC, loadout fixo e risco zero |
| **Legenda** | frase de fim de run gerada por `RunCaption`, copiável com C |
| **Executor** | `tests/run_tests.ps1` |
| **Fluxo** | cada `RandomNumberGenerator` separado dentro de `GameRng` |
