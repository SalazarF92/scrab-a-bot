# SCRAP-A-BOT — Registro da sessão de 14/09/2026

Motor: Godot 4.7.2. Branch `main`. Commit de partida: `b78262f`.
Complementa os registros de 09/09, 10/09 e 11/09 sem reescrever sua história.

## Resumo

A sessão começou com uma auditoria de toda a documentação e do código, publicada como relatório,
e um roteiro de sete etapas. O usuário aprovou seguir. As sete etapas foram implementadas, cada uma
com testes automatizados e um commit próprio. A suíte termina verde em todos os commits.

| Etapa | Commit | Entrega |
|---|---|---|
| 0 | `dafcedb` | Investida do Olhudo commitada; os 8 testes de rig entram no executor |
| 1 | `9b80329` | 15 correções de robustez apontadas pela auditoria |
| 2 | `876a757` | Chefes por dados, Sugão 3000 e Formulário 27-B no poço, elites |
| 3 | `b5d0a3a` | Cabeças com habilidade, enxertos de sucata, prateleira de 8 CPUs |
| 4 | `c1266f7` | Rigs da Parafuseta, Rato Morto e Olhudo dentro do combate |
| 5 | `ac0192a` | Título, pausa, opções com remapeamento, save de estado de run |
| 6 | `a2b15e1` | Simulador de balanceamento e log de telemetria por run |

Para retomar:

```powershell
cd F:\GODOT\scrap_a_bot
git log --oneline -8
powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1
F:\GODOT\Godot_v4.7.2-stable_win64.exe --path .
```

## O que mudou, por etapa

### Etapa 1: robustez

- TDPs 132, 128 e 128. O piso de 1,15 vez a build mais barata (adendo A.5) virou teste.
- `Robot.reset_between_sectors()`: calor, recarga da Purga, cadeado, recargas e i-frames não
  atravessam mais a Bancada. HP e peças ficam.
- A barra de recarga da HUD usa a duração real do disparo, com CPU e subvoltagem.
- Zé Ventoinha só toca som quando empurra algum projétil, a no máximo 2 Hz.
- Filhos de divisão herdam a fonte de dano do pai, não a do ocupante anterior do slot.
- Projétil inimigo não danifica mais cenário destrutível.
- O nível de risco escala o dano inimigo em 6% por nível.
- F2 reabre a sala inteira. Receitas apontam peças por id. Clones têm recursos próprios.
- "Resetar Save" exige dois cliques. Mensagens da Bancada seguem a receita selecionada.

### Etapa 2: chefes

- Todo número de chefe vive em `EnemyLibrary.BOSS_PROFILES`. `Enemy` só interpreta o perfil.
- Tipos de ataque: colunas, estilhaços, sucção, cabeçote no trilho, esteira e bola de papel.
- Sugão 3000 no setor 2 e Formulário 27-B no setor 4, redesenhados para o poço. As arenas internas
  do GDD 5.4 e 5.5 ficaram de fora.
- Elite é um comum promovido, com 6 vezes o HP, aura e 8% de chance a partir do setor 3.
- A troca de fase pede o hitstop roteirizado de 350 ms.

### Etapa 3: modularidade

- `combat/head_ability.gd`: Câmera de Segurança, Boneca Queimada, Rádio-Relógio e Abajur.
- `PartLibrary.GRAFTS`: dez módulos que servem de ingrediente ou de enxerto, até 2 por peça,
  4 com a Cyrix Bode.
- Prateleira de CPUs na Garagem, com condição de desbloqueio visível. Save v3.
- `PartBehavior.on_tick` passou a ser chamado.

### Etapa 4: rigs no combate

- `art/creature_rig_view.gd` desenha os rigs agrupando peças consecutivas da mesma junta em malhas.
- O desenho imediato do puppet custava 5,2 ms por Parafuseta. O corpo em malha custa cerca de
  0,02 ms. Geometria, UVs, pivôs, ordem de desenho e curvas são as do rig.
- O corte da boca virou o semiplano equivalente em `art/mouth_clip.gdshader`.
- O Olhudo usa a cena reutilizável, com a carga sincronizada ao aviso e o laser mirado no alvo.
- Validação em `tests/rig_integration.tscn` e capturas `docs/visual/rigs-no-jogo*.png`.

### Etapa 5: front-end e save de run

- Autoload `Settings` com tremor, hitstop, flashes reduzidos, formas no quique, assistência de
  mira, volume, atalhos de desenvolvimento e teclas remapeadas.
- Título, pausa e opções. O jogo aberto normalmente mostra o título; testes com semente seguem
  direto na run.
- Atalhos de depuração só com a opção ligada, que vem ligada apenas em build de depuração.
- Save de estado de run (adendo B.7) ao abrir a Bancada e ao começar cada setor, com o estado de
  cada fluxo de RNG. Morte, vitória e desistência apagam o arquivo.
- Preset de exportação Linux.

### Etapa 6: balanceamento

- `tools/balance_sim.tscn`: piloto automático sem abate assistido, builds sorteadas por semente,
  relatório por CPU e por peça.
- Run sem abate, sem troca de onda e sem 100 de dano por 120 s de jogo termina como `stalled`,
  com a lista do que ficou vivo. O relatório é regravado a cada run, então uma execução
  interrompida não perde as runs concluídas.
- O primeiro lote travou no setor 3 diante de um Olhudo parado atrás de um obstáculo: o piloto
  só atirava direto. Agora, se o alvo passa 2,5 s sem perder HP, o piloto alterna entre tiro
  direto e ricochete nas paredes e no teto. Foi limitação do piloto, não travamento do jogo.
- `MetaManager` grava um log por run em `user://telemetry/` com o save real.

## Defeitos achados durante a sessão

| Defeito | Onde surgiu | Correção |
|---|---|---|
| A CPU escolhida na prateleira era ignorada: a run buscava a CPU por instância | Etapa 3 | Busca por id, com teste, na etapa 5 |
| Recarga das cabeças dependia do upgrade da Purga | Etapa 3 | Recarga própria, antes do commit |
| Atração da Câmera varria o pool inteiro a 120 Hz | Etapa 3 | 20 Hz, antes do commit |
| Rádio-Relógio disparava sem inimigos, aceitava Q e ignorava o Cadeado | Etapa 3 | Corrigido antes do commit |
| Marca da Câmera podia sobreviver à reciclagem do inimigo no pool | Etapa 3 | Guarda pelo sinal da marca |
| Formas no quique nasceriam desligadas pelas opções | Etapa 5 | Padrão ligado, como no Vfx |
| Simulador contava a parada na Bancada como zero setores limpos | Etapa 6 | Conta o setor limpo, com teste |

## Validação

- `tests/run_tests.ps1` roda 11 cenas e 8 testes de rig. `compile_check` verifica 110 scripts.
- Capturas com renderer real: `rigs-no-jogo.png`, `rigs-no-jogo-zoom.png`, `titulo.png`,
  `opcoes.png` e `pausa.png` em `docs/visual/`.
- Custo dos rigs numa onda de 48 criaturas e 4 Olhudos: cerca de 1 ms de pose e 1,8 ms de desenho
  por quadro, em build de editor.

### Benchmark de física

O teste de fumaça oscilou muito nesta máquina. No mesmo commit, a mediana variou de 1,77 a 2,52 ms
e o p99 de 2,25 a 4,40 ms. Um bisect com execuções alternadas entre `b78262f` e cada etapa não
mostrou regressão consistente. O alvo de 2,4 ms do GDD 7.2 fica dentro dessa faixa de ruído, então
comparar desempenho exige várias execuções alternadas ou um build exportado.

### Primeiro lote do simulador

Comando: `tools/balance_sim.tscn ++ --runs=8 --seed=1000 --max-sector=5`, com o piloto que alterna
tiro direto e ricochete. Sem upgrades da Garagem e com risco zero.

| Medida | Resultado |
|---|---|
| Vitórias | 0 de 8 |
| Setores limpos por run | média 2,63, de 1 a 4 |
| Runs travadas | nenhuma |
| Mortes por inimigo comum | 6 de 8: 3 Parafusetas, Rato Morto, Fantasma de Disquete e Bipador |
| Mortes por chefe | 2 de 8: Sugão 3000 e Formulário 27-B |
| Mediana do multiplicador de quique | ×1,00 a ×1,25 |
| Rebatidas por perda no chão | 0,24 a 0,58 |

Leitura:

- O piloto atira quase sempre direto e deixa cair de 2 a 4 projéteis para cada um que rebate. Os
  números descrevem esse piloto, não o pilar 3 jogado por uma pessoa.
- Por peça houve de 1 a 4 runs, abaixo das 10 que o relatório exige para marcar revisão. Chassi de
  Cofre e Ryzin chegaram a 3,67 setores limpos em média, contra 1,50 de Rodinhas e da Placa de
  Vídeo. É um indício a confirmar com mais runs, não uma conclusão.
- Para usar o relatório no balanceamento: rodar pelo menos 10 runs por peça, cerca de 120 runs, e
  melhorar o rebatedor do piloto antes.

## Pendências

Só o dono do projeto resolve:

1. Jogar uma run completa com janela e avaliar o feel do rebatedor e das restituições.
2. Confirmar o formato de poço. Com a confirmação, reescrever as seções 3.1, 3.2 e 3.3.4 do GDD na v1.1.

Bloqueado por produção de arte ou por ferramenta ausente:

- Converter o restante do bestiário pelo método de construção de mobs. Cada personagem exige
  assets novos; esta sessão não teve geração de imagem.
- Ciclos animados do robô, ilustrações das cabeças novas e dos módulos.
- Exportar e medir no Steam Deck: os templates de exportação não estão instalados.

Próximas implementações sugeridas:

- Remapeamento de controle, escala de fonte, auto-disparo e o modo Sem Perda de Controle (adendo C.3).
- Modificadores próprios de cada elite (GDD 5.3) e as arenas internas de Sugão e Formulário.
- Rodar o simulador com 10 ou mais runs por peça antes de mexer em números, e confirmar com
  sessões humanas, porque o piloto tem habilidade fixa.
