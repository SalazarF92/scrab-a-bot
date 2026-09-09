# SCRAP-A-BOT — Adendos ao GDD v1.0
### Levantamento de lacunas, contradições e riscos não cobertos
*Documento complementar. Não substitui o GDD, aponta o que falta nele.*

---

## A. CONTRADIÇÕES INTERNAS (resolver antes de produzir conteúdo)

### A.1 Quantidade e posição dos chefes
A tabela de ritmo (3.1) diz que o setor 1 termina em **Elite** e o setor 3 em **Elite duplo**.
A seção 5.6 diz que o setor 3 tem o chefe **FROSTBYTE 500**. O escopo (7.4) pede **6 chefes na 1.0**,
mas só 5 setores existem e 2 deles terminam em elite.

**Resolução proposta:** 5 setores, 5 chefes (um por setor), sendo o do setor 1 um "mini-chefe"
de 90 segundos que serve de ensino. O 6º chefe é o **chefe secreto do final verdadeiro**
(a fábrica que produziu a sua CPU), acessível com condição especial. Elites voltam a ser
o que a 5.3 diz: encontros aleatórios, não fecho de setor.

### A.2 O teto de 4,00 torna quiques 5 a 12 mudos
O multiplicador trava em 4,00 no quique 4, mas o teto de quiques é 12. Do 5º ao 12º quique
o projétil não ganha dano nem muda de cor, ou seja, **oito níveis de upgrade sem feedback**.
O jogador que investiu em "mais quiques" não vê retorno.

**Resolução proposta:** quiques 5+ mantêm o multiplicador 4,00 mas passam a somar
**+3% do dano base por quique** (4,00 no 4º, +0,12 por quique, chegando a 4,96 no 12º)
e o projétil ganha
um **rastro que engrossa**, mais uma partícula orbital por quique acima de 4. O teto rígido
de 4,00 continua protegendo contra combo degenerado, mas o investimento não é morto.

### A.3 Peças base nunca alcançam o quique 4
Base = 3 quiques máximos. Com 3 quiques o multiplicador máximo alcançado é 1,95.
O tier magenta 4,00 — que o GDD chama de "o momento de clipe" — é **inalcançável sem upgrade**.

**Resolução proposta:** ou a base sobe para 4 quiques, ou o nó de Bancada
"Terceiro Quique Grátis" (4.000 de Cobre) é movido para muito cedo na árvore.
Recomendo **base 4 quiques** e rebalancear as peças que dizem "quica 2 vezes" para cima.

### A.4 "Quiques infinitos" versus teto de 12
O Z-80 Bafo (CPU 4) dá quiques ilimitados. O Disco Rígido Voador quica infinitamente por 6 s.
O GDD também declara teto absoluto de 12 por risco de desempenho.

**Resolução proposta:** "infinito" passa a significar **quiques não consomem o contador**,
ou seja, o projétil não morre, mas o multiplicador continua travado no teto e o
**TTL vira o limitador** (6 s no HD, 4 s no Z-80). Assim o custo de simulação fica limitado
por tempo, não por contagem, e o benchmark continua previsível.

### A.5 Nenhuma build cabe no TDP da CPU inicial
Somando a peça **mais barata em Watts de cada slot**, pelas tabelas do próprio GDD (4.3 a 4.6):

| Slot | Peça mais barata | Watts |
|---|---|---|
| Braço esquerdo | Ratoeira de Mouse "Clica Clica" | 25 |
| Braço direito | Braço de Guindaste "Ferro-Velho Express" | 38 |
| Cabeça | Câmera de Segurança "Vigia Bêbado" | 16 |
| Chassi | Molas de Sofá "Boing Boing" | 22 |
| | **Mínimo possível** | **101 W** |

O TDP da **Pentiun Ferrugem**, a CPU inicial e a única disponível na primeira run, é **100 W**.
Ou seja: **não existe uma única combinação de quatro peças que caiba no orçamento da CPU inicial.**
A Subvoltagem, que o GDD 4.1.1 descreve como "uma decisão de build válida quando as peças são
muito boas", é na verdade o **estado padrão obrigatório** do jogador na primeira hora de jogo.
Uma penalidade de menos 30% de cadência mais um espasmo a cada 4 segundos, permanente,
é exatamente o oposto do que a curva de onboarding da Persona A pede.

Isso foi detectado ao rodar o protótipo: o carregamento padrão marca 117 / 100 W e entra em
Subvoltagem antes do primeiro tiro.

**Resolução proposta:** fixar a regra de que **o TDP de toda CPU tem que ser no mínimo 1,15 vez
o custo da build mais barata legal**, ou seja, no mínimo 116 W. A Pentiun sobe para **120 W**
e as demais sobem proporcionalmente, mantendo a ordem relativa. Alternativa equivalente e mais
trabalhosa: baixar o custo em Watts de todo o braço direito em cerca de 25%.
Sem uma das duas, o sistema de energia não é uma escolha, é um imposto.

A regra dos 1,15 vira um item do APÊNDICE B, o checklist de aprovação de peça nova:
uma peça cujo Watts quebre o piso de nenhuma CPU não entra no jogo.

---

## B. SISTEMAS AUSENTES (o GDD não os menciona e o jogo não funciona sem)

### B.1 Recuperação de vida — lacuna crítica
O GDD define HP no chassi (85 a 320) e dano de inimigo, mas **não existe uma única fonte de cura**.
Numa run de 12 minutos com 5 setores, sem cura, a build mais forte perde para atrito.

**Proposta:**
| Fonte | Valor | Frequência |
|---|---|---|
| Sucata de reparo (drop) | 4% de HP máximo | 6% de chance por inimigo morto |
| Solda na Bancada | 35% de HP máximo por 120 de Sucata | 1 compra por bancada |
| Recompensa de chefe | 50% de HP máximo | Garantida |
| Enxerto "Fita Isolante" | Regenera 1% de HP a cada 8 s | Módulo raro |
| Nó de Bancada "Reciclagem" | Purga de Calor cura 6 de HP por inimigo atingido | 2.600 de Cobre |

### B.2 Invulnerabilidade após tomar dano
Só existe i-frame de dash. Sem i-frame pós-dano, um enxame de Parafusetas mata o jogador
em 4 quadros e o jogador não entende o que aconteceu.

**Proposta:** 600 ms de invulnerabilidade após qualquer dano recebido, com o sprite piscando
a 12 Hz. Dano de área contínuo (poça de ácido) ignora i-frame mas tem tique de 1 s.

### B.3 Inventário de módulos e economia da Bancada
A fusão de receita exige ter dois componentes ao mesmo tempo, mas o robô tem 5 slots.
**Onde os módulos ficam guardados não está definido.** Também não há preço de peça em Sucata,
custo de reroll, nem valor de venda — apesar de a CPU 11 dizer "toda peça custa metade".

**Proposta:**
- **Mochila de módulos:** 4 espaços, 6 com a CPU Cyrix Bode. Cheia, o jogador escolhe descartar.
- **Preço de peça:** Comum 90, Incomum 160, Rara 280, Lendária 480 de Sucata.
- **Reroll:** 60 de Sucata, aumentando 40 a cada uso na mesma bancada.
- **Venda / substituir peça equipada:** devolve 50% do preço.
- **Solda de reparo:** 120 de Sucata (ver B.1).

### B.4 HUD e leitura de estado
A seção 1.4 diz que o crítico fica nos 60% centrais, mas **não existe especificação de HUD**.
Num jogo com HP, calor, Watts, cargas de dash, recarga de cabeça e recarga de purga,
isso são 6 leituras simultâneas.

**Proposta de layout:**
- **No robô, não na borda:** barra de calor é um anel em volta do robô; Watts em subvoltagem
  é um ícone piscando no chassi. Isso mantém os olhos no centro.
- **Canto inferior esquerdo:** HP em chapas de metal (1 chapa = 25 HP), cargas de dash como parafusos.
- **Canto inferior direito:** ícones das 4 peças com sombra de recarga radial.
- **Topo central:** onda atual e setor, discreto. Nunca minimapa durante o combate.

### B.5 Diretor de ondas (spawn)
"3 ondas" e "nunca 8 s sem inimigo" estão definidos, mas não as **regras de posicionamento**.

**Proposta:** nenhum inimigo nasce a menos de 400 px do jogador nem no campo de visão direto
sem telegrafia. Todo spawn tem 0,5 s de antecipação (uma sombra, um buraco, uma porta abrindo).
Orçamento de ameaça por onda em pontos, não em contagem bruta, para o gerador escalar
sem quebrar o ritmo.

### B.6 Regras de empilhamento de modificadores
O sistema inteiro é composição de comportamentos, mas o GDD **nunca diz se dois "+22% de dano"
somam ou multiplicam.** Sem essa regra, o balanceamento de 90 peças é indecidível.

**Proposta, ordem de aplicação fixa:**

```
dano_final = dano_base
           * (1 + soma_de_aditivos_percentuais)     <- peças, enxertos, árvore
           * multiplicador_de_quique                 <- 1,00 a 4,96
           * multiplicador_de_raridade               <- 1,00 / 1,35 / 1,80 / 2,50
           * multiplicador_de_nivel_de_fusao         <- 1,00 / 1,40 / 1,90 / 2,60
           * (critico ? 2,0 : 1,0)
```

Aditivos somam entre si. Multiplicadores nomeados multiplicam. Nada mais multiplica.

### B.7 Pausa, suspensão e save de run
"Runs não são salvas no meio" é hostil ao Steam Deck, que é uma meta obrigatória do projeto.
Um jogador fecha o console no meio da sala 3 e perde a run.

**Proposta:** save de estado de run em `user://run_state.json` a cada transição de sala,
descartado ao terminar a run. Não é save-scumming, porque não permite recarregar após a morte:
o arquivo é apagado no instante em que o jogador toma o golpe fatal.

### B.8 Onboarding dos primeiros 90 segundos
A Persona C é 25% da base e não conhece o gênero, mas o único ensino planejado são
dicas no rádio da Garagem, que ele só vê **depois** da primeira run.

**Proposta:** o setor 1, sala 1, na primeiríssima run, é um corredor roteirizado de 40 segundos:
uma parede que pede um tiro, um inimigo atrás de uma quina que só morre por ricochete
(o Fantasma de Disquete, que já existe para isso), e uma peça no chão. Sem texto.

---

## C. ACESSIBILIDADE (lacuna de conformidade, não de gosto)

### C.1 Daltonismo — problema estrutural, não cosmético
**A mecânica central do jogo é comunicada por cor.** Quique 1 branco, 2 amarelo, 3 laranja,
4 magenta. Para deuteranopia e protanopia, amarelo e laranja são quase o mesmo estímulo.
Cerca de 8% dos homens não conseguem ler o pilar 3.

**Proposta, canal redundante obrigatório:**

| Quique | Cor | Forma do anel | Pips |
|---|---|---|---|
| 1 | Branco | Círculo | · |
| 2 | Amarelo | Quadrado | ·· |
| 3 | Laranja | Triângulo | ··· |
| 4+ | Magenta | Estrela | ···· |

O projétil carrega o mesmo número de pips orbitando. A escala já cresce (1,0 a 1,5),
e o arpejo de áudio já é ascendente. Com forma, escala, pips e som, a cor vira o quarto canal,
não o único.

### C.2 Fotossensibilidade
Tela Azul Cômica (tela cheia, 180 ms), Flash de Fusão (tela branca), flash branco a cada
acerto e faíscas a 4 Hz. Numa build tardia com 800 projéteis isso é um risco real de convulsão.

**Proposta:** modo "Flashes Reduzidos" que substitui flash de tela cheia por vinheta de borda,
limita a taxa de flash global a 3 Hz e reduz o contraste do flash de acerto para 40%.
Detecção automática de excesso: se a luminância média variar mais de 20% por mais de
3 quadros por segundo, o limitador entra sozinho.

### C.3 Restante do pacote mínimo
- Auto-disparo com opção de segurar ou alternar. O gênero exige, e é ergonomia, não facilidade.
- Remapeamento completo de teclado e de controle.
- Slider de hitstop de 0 a 150%, separado do de tremor.
- Escala de fonte da interface de 100 a 150%.
- Modo "Sem Perda de Controle": Ping de 999 ms do Roteador Eterno e Sem Conexão viram
  penalidades de dano em vez de roubo de input. Roubar input é o único ataque do jogo
  que é hostil por natureza e não tem contra-jogo.

---

## D. RISCOS TÉCNICOS NÃO LISTADOS NA SEÇÃO 7.6

### D.1 O replay "Salvar Vergonha" exige determinismo total — e o jogo não é determinístico
Gravar 15 segundos como sequência de comandos e re-renderizar exige simulação determinística
bit a bit. O GDD tem, contra isso: aritmética de ponto flutuante, ordem de iteração dependente
de uma pilha de índices livres, IA fatiada em 12 grupos por quadro, e partículas na GPU.
Qualquer divergência de um bit e o replay mostra outra coisa.

**Mitigação:** gravar **quadros de vídeo**, não comandos. Buffer circular de 15 s a 30 fps em
resolução reduzida, codificado por `FFmpeg` embarcado ou pelo `MovieWriter` do Godot.
Custa memória e não custa determinismo. Alternativa barata: gravar só um GIF de 6 segundos.

### D.2 Faltam campos na estrutura de dados do pool
A `ProjectilePool` da seção 7.2 não tem como implementar regras que o próprio GDD exige:
- **Imunidade de acerto repetido de 220 ms:** exige `_last_hit_id` e `_last_hit_time` por projétil.
- **Projéteis inimigos:** várias peças rebatem tiro inimigo, mas não há campo de facção.
- **Multiplicação de projéteis:** `spawn_children` precisa de linhagem para não estourar o teto.
- **Perfuração, homing, dano de dono:** sem campos.

**Mitigação:** os arrays estão implementados neste repositório já com esses campos.

### D.3 Bug na sequência `cast_motion` seguida de `get_rest_info`
O trecho da seção 7.2 chama `get_rest_info` com a transformada **de origem** do projétil,
não com a do ponto de contato. Nessa posição o projétil ainda não toca em nada,
então `get_rest_info` retorna vazio e o código cai no caminho de "atravessa a parede".

**Mitigação:** mover a transformada para o ponto de contato com um avanço de sobreposição
antes de consultar. Corrigido na implementação deste repositório.

### D.4 Hitstop e o passo fixo de 120 Hz
"Congela a simulação exceto efeitos visuais e interface" não pode ser `Engine.time_scale = 0`,
porque isso congela também os efeitos. E não pode ser um `await`, porque quebra o passo fixo.

**Mitigação:** um relógio de combate separado. `CombatFeel` mantém `frozen` e os sistemas de
jogo pulam o passo; efeitos visuais e interface usam `_process` com delta real.
Implementado neste repositório.

### D.5 Custo real de `cast_motion` a 120 Hz
800 projéteis a 120 Hz são 96.000 consultas de varredura por segundo, cada uma
atravessando o broadphase do servidor de física. O orçamento de 2,4 ms por quadro é otimista
e não foi medido em Steam Deck.

**Mitigação:** o benchmark existe desde o primeiro dia neste repositório (teclas F3 e F4).
Se estourar: hash espacial próprio para paredes estáticas, com o servidor de física
consultado apenas para inimigos.

### D.6 Cadeado Chorão pode desarmar o jogador por completo
Ele encripta uma peça por 8 segundos. Se encriptar a única arma de uma build de braço único,
o jogador fica 8 segundos sem poder jogar.

**Mitigação:** nunca encripta a peça que causou mais dano nos últimos 10 segundos.
Prefere cabeça, depois chassi, depois o braço menos usado.

---

## E. OMISSÕES MENORES, PARA A v1.1 DO GDD

1. **Câmera:** falta especificar zona morta, antecipação na direção da mira
   (proposta: 120 px na direção do analógico direito) e suavização.
2. **Música:** existe o rádio, mas não há especificação de trilha dinâmica por camadas
   nem de tonalidade. A escala de quique é afinada, então a trilha precisa estar na mesma
   tonalidade ou o arpejo vai soar desafinado. Proposta: tudo em Lá menor.
3. **Co-op local:** planejado para pós-lançamento, mas câmera compartilhada, divisão de
   Sucata e o pool de projéteis com dois donos precisam existir na arquitetura desde já,
   ou o retrabalho é grande.
4. **Contratos diários:** a semente global precisa ser derivável da data em UTC, sem servidor.
5. **Conquistas:** nenhuma listada. Meta de 40 para o Acesso Antecipado.
6. **Política de estouro do pool:** com 2048 slots e o pool cheio, o GDD não diz o que acontece.
   Proposta: mata o projétil vivo mais antigo com menos quiques.
7. **Curva de sobrevivência:** existe curva de DPS por setor, mas não a curva espelhada de
   dano recebido por segundo esperado. Sem ela, não há como balancear a árvore Chapa.
8. **Modo Caos com o chat:** nenhum plano técnico. Exige OAuth de Twitch e um servidor
   intermediário ou IRC direto.
9. **Peça "Batedeira" ocupa o braço esquerdo mas é corpo a corpo** sem projétil.
   O contrato do pilar 3 diz que 70% dos projéteis quicam; peças sem projétil precisam
   ficar fora desse denominador, o que deve ser dito.

---

*Adendos v1.0. Cada item aqui é uma decisão pendente, não uma decisão tomada.*
