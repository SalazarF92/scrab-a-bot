# SCRAP-A-BOT — Relatório de Desenvolvimento e Arquitetura
**Data:** 09 de Setembro de 2026  
**Versão do Motor:** Godot 4.7.2 Forward+  
**Status do Marco:** Protótipo Jogável Vertical (Estilo *Ball x Pit*) + Metaprogressão Completa

---

## 1. Visão Geral do Projeto e Pivot de Design

O **SCRAP-A-BOT** é um roguelite de arena com física de ricochete de alta velocidade e modularidade de peças.

### O Pivot para o Formato *Ball x Pit*
Inicialmente estruturado como uma arena aberta 360° twin-stick, o projeto foi reestruturado para o autêntico formato **vertical pit / brick-breaker roguelite** (no estilo de *Ball x Pit*, Devolver Digital / Kenny Sun):
- **O Poço Vertical ("The Pit"):** Corredor vertical fechado de `1000 x 1080` centralizado na tela.
- **Movimentação na Baseline:** O robô opera exclusivamente na linha de defesa inferior (`Y = 960.0`), movendo-se horizontalmente com `A` / `D` ou analógico esquerdo.
- **Disparos Ascendentes:** A mira é restrita ao hemisfério superior (`-172°` a `-8°`), lançando rajadas de projéteis para cima dentro do poço.
- **Descida de Hordas:** Inimigos nascem telegrafados no topo do poço (`Y: 60..240`) e marcham em direção à base do jogador. Inimigos que alcançam a linha de defesa causam dano à integridade do robô e explodem.

---

## 2. Pilares de Gameplay e Arquitetura Técnica

### Pilar 1: Feel e Feedback de Impacto (`autoload/combat_feel.gd`, `autoload/sfx.gd`, `autoload/vfx.gd`)
- **Hitstop com Regra do Maior-Valor:** Múltiplos impactos simultâneos não somam tempo; o maior valor pendente prevalece, com teto estrito de 130 ms.
- **Trauma de Câmera:** Tremor quadrático suave (`trauma^2`) com antecipação sutil na direção da mira.
- **Arpejo Musical Ascendente:** Cada quique de projétil eleva o tom sonoro da escala afinada em Lá menor, fornecendo leitura auditiva imediata do multiplicador de ricochete.
- **Squash and Stretch:** Deformação elástica com pivô ancorado na base dos robôs e inimigos.

### Pilar 2: Modularidade de Peças (`data/part_data.gd`, `data/part_library.gd`)
- **Peça é Dado, Não Código:** Modelada via recursos `PartData` combinados com comportamentos polimórficos `PartBehavior`.
- **Sistema de Slots:** Braço Esquerdo, Braço Direito, Cabeça e Chassi.
- **Sistema de Energia e Subvoltagem:** Gerenciamento de Watts e TDP da CPU. Subvoltagem penaliza cadência e gera espasmos periódicos.
- **Sistema de Calor:** Disparos contínuos geram calor. Atingir 100% trava o robô em superaquecimento; a tecla `E` executa a **Purga de Calor** em área.

### Pilar 3: O Poço e a Física de Ricochete (`combat/projectile_pool.gd`, `generation/arena_generator.gd`)
- **Zero Alocação por Projétil:** Pool com vetores paralelos contíguos (`Transform2D`, `Vector2`, tempos e contadores).
- **Zero Tunelamento:** Varredura contínua via `cast_motion` do `PhysicsServer2D` com avanço de sobreposição para leitura da normal exata no ponto de contato.
- **Multiplicador de Quique do GDD 3.3.2:**
  - 0 quiques: 1.00x
  - 1 quique: 1.25x
  - 2 quiques: 1.56x
  - 3 quiques: 1.95x
  - 4 quiques: 4.00x (magenta)
  - 5 a 12 quiques: +0.12 por quique adicional até o teto rígido de 4.96x.
- **Geração Procedural Válida:** Algoritmo que gera de 3 a 6 obstáculos/bumpers no poço intermediário (`Y: 220..800`), validando conectividade via busca em largura (BFS) e distância máxima de 700 px até uma superfície.

---

## 3. Loop de Metaprogressão e Retenção de 1+ Semana

Para garantir longevidade de jogo por pelo menos 1 semana de sessões diárias, foram implementados três sistemas integrados:

### A. A Garagem do Seu Nildo (`autoload/meta_manager.gd`, `ui/garage_ui.gd`)
- **Economia Persistente:** Ao fim de cada partida, a Sucata coletada é convertida em Cobre (`floor(Sucata / 8)` + bônus de setor + bônus de vitória) e gravada em disco (`user://save.json`).
- **Árvore de Upgrades com 5 Ramos e 25 Nós:**
  1. **Chapa (Vida & Blindagem):** Solda Reforçada (+15 HP), Chapas Dobradas (+15% HP), Blindagem de Estrada (-10% dano), Para-Choque de Caminhão (+25% HP, -5% vel), Airbag Vencido (salva-vidas de 1 golpe fatal).
  2. **Pólvora (Dano & Balística):** Pólvora Caseira (+8% dano), Pinos Polidos (+12% vel projétil), Mira do Seu Nildo (+12% crítico), Pólvora Grossa (+15% dano em quique 2+), Terceiro Quique Grátis (projéteis nascem em 1.25x).
  3. **Mola (Mobilidade):** Graxa Boa (-15% recarga dash), Rodízio Lubrificado (+10% vel), Amortecedor Rápido (+20% dash), Freio de Borracha (-60% recuo), Perna Extra (+1 carga máxima de dash).
  4. **Cobre (Energia & Calor):** Ventoinha de Verdade (+25% dissipação), Fiação Grossa (+15 W TDP), Dissipador de Alumínio (-15% calor/tiro), Válvula de Alívio (-25% recarga purga), Purga Turbinada (+50% raio e dano da purga).
  5. **Sorte (Economia & Vitrine):** Ímã de Sucata (+20% sucata), Olho Clínico (+15% chance de peças raras), Barganha do Ferro (-25% custo reroll), Reciclagem Eficiente (+25% Cobre pós-run), Quarta Opção (Bancada oferece 4 peças).

### B. Modo Ferro-Velho Infernal ("Calibragem de Risco" / Heat System)
- **Níveis de Risco de 0 a 10:** Selecionáveis na Garagem antes de cada run através de `<` / `>` ou teclas `A` / `D`.
- **Modificadores Crescentes:**
  - Inimigos recebem +12% de HP por nível.
  - Velocidade de marcha e descida aumentadas em +5% a +8% por nível.
  - Orçamento de hordas aumentado em +15% por nível.
- **Recompensa de Escala:** Cada nível de Risco concede **+25% de Cobre adicional** ao final da partida.
- **Progressão Linear:** Vencer o Setor 5 desbloqueia o próximo nível de Risco máximo.

### C. A Bancada Intermediária ("In-Run Progression", `ui/workbench_ui.gd`)
- Entre cada setor concluído, o jogador acessa a Bancada para gastar a Sucata coletada na run:
  - **Vitrine:** 3 a 4 peças aleatórias baseadas no setor e raridade (Comum 90, Incomum 160, Rara 280, Lendária 480 Sucata).
  - **Fusão de Peças:** Aprimoramento contínuo das peças equipadas:
    - **Tier I:** 1.00x poder base.
    - **Tier II:** 1.40x poder (+40%, custo 80 Sucata).
    - **Tier III:** 1.90x poder (+90%, custo 140 Sucata).
    - **Tier IV:** 2.60x poder (+160%, custo 220 Sucata).
  - **Solda de Reparo:** Recupera 35% do HP máximo por 120 de Sucata.
  - **Reroll:** Permite atualizar a vitrine por 60 Sucata (aumentando 40 por uso).

---

## 4. Chefes e Sustentabilidade de Combate (`actors/enemies/enemy_library.gd`, `actors/enemies/enemy.gd`)

### Chefes de Setor
- **Setor 1 — Mini-Prensa 500:** Compressor industrial blindado com 480 HP base e placa frontal de alta restituição (1.30), ensinando o jogador a ricochetear nas paredes laterais para atingir suas costas.
- **Setor 3 — FROSTBYTE 500:** Mainframe criogênico resistente com 1.250 HP base.
- **Setor 5 — A Fornalha Suprema:** Núcleo de incinerador com 3.000 HP base e aura de estilhaços.

### Fontes de Sustentação de Vida (GDD_ADENDOS B.1 e B.2)
- **Drop de Sucata de Reparo:** 6% de chance por inimigo comum (+ bônus do ramo Sorte) de recuperar 4% de HP.
- **Recompensa de Chefe:** Derrotar qualquer chefe recupera 50% de HP máximo garantido.
- **Invulnerabilidade Pós-Dano:** 600 ms de i-frames ao receber qualquer dano de contato ou projétil inimigo com piscar visual a 12 Hz.

---

## 5. Resultados dos Testes Automatizados de Fumaça (`tests/smoke.gd`)

Comando executado:
```powershell
& "F:\GODOT\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/smoke.tscn
```

### Métricas Consolidadas:
- **Tunelamento:** 0 projéteis escaparam com 800 projéteis ativos a 1.400 px/s.
- **Eventos de Quique:** 9.451 quiques registrados com 0 contatos vazios.
- **Conformidade de Salas:** 40 salas geradas sequencialmente com semente fixa; 0 reprovadas em cobertura, largura de corredor, alcançabilidade e distância máxima de superfície.
- **Desempenho de Física:**
  - Mediana: **2.42 ms** por quadro.
  - Percentil 99 (p99): **2.98 ms** por quadro.
  - Quadros com pico acima de 8 ms: **0**.
- **Metaprogressão e Economia:** Persistência de save JSON, compra de upgrades, mitigação de dano, vitrine, fusão de tiers e níveis de Heat todos validados com sucesso.

---

## 6. Mapeamento de Arquivos Principais

| Arquivo | Descrição |
|---|---|
| `autoload/meta_manager.gd` | Gerenciador global de persistência, economia (Cobre/Sucata), árvore de 25 nós e Níveis de Risco. |
| `autoload/combat_feel.gd` | Controlador desacoplado de congelamento (hitstop) e trauma de câmera. |
| `combat/projectile_pool.gd` | Pool contígua de projéteis com varredura sweep-cast e multiplicação de ricochete. |
| `combat/wave_director.gd` | Orquestrador de ondas, spawn no topo do poço e despacho de chefes na onda 3. |
| `actors/robot/robot.gd` | Robô jogador com movimentação horizontal na baseline e mira vertical. |
| `actors/enemies/enemy.gd` | Comportamento de descida dos inimigos, colisão com a baseline e drops de cura. |
| `actors/enemies/enemy_library.gd` | Especificações e escalonamento de inimigos comuns e chefes de setor. |
| `generation/arena_generator.gd` | Gerador procedural do poço vertical com trilhos, paredes maciças e bumpers. |
| `actors/arena_camera.gd` | Câmera fixa centralizada no poço com amortecimento e trauma. |
| `ui/garage_ui.gd` | Interface visual do balcão do Seu Nildo, compras de Cobre e seletor de Risco. |
| `ui/workbench_ui.gd` | Interface da bancada intermediária com vitrine de peças, solda e fusões. |
| `ui/hud.gd` | HUD nas calhas laterais (HP em chapas, sucata, peças equipadas e purga). |
| `scenes/prototype.gd` | Cena principal de combate e transições de sala/vitória/derrota. |
| `tests/smoke.gd` | Teste de fumaça headless para verificação contínua do projeto. |
