# SCRAP-A-BOT
### *Monte. Ricocheteie. Exploda.*
**Game Design Document v1.0 — Documento de Produção**

| Campo | Definição |
|---|---|
| **Título de trabalho** | SCRAP-A-BOT |
| **Subtítulo Steam** | *Sucata Sem Licença* |
| **Gênero** | Arcade Roguelite de Física / Arena Battler com montagem modular |
| **Plataformas** | PC (Steam) no lançamento. Steam Deck verificado como meta obrigatória. Switch 2 e consoles no ano 2. |
| **Engine** | Godot 4.7.x (Forward+ no desktop, Mobile renderer no Deck) |
| **Classificação** | 16+ (humor grotesco cartunesco, violência de desenho animado sem sangue) |
| **Duração de sessão** | 10 a 15 minutos por run. Meta-loop de 25 a 40 horas até o final verdadeiro. |
| **Modo** | Single-player. Co-op local de 2 jogadores em atualização pós-lançamento. |
| **Preço-alvo** | US$ 9,99 / R$ 34,90. Sem DLC pago no ano 1. |
| **Equipe-alvo** | 4 pessoas em tempo integral, mais 2 contratados (áudio e marketing) |
| **Prazo-alvo** | 14 meses até Acesso Antecipado, mais 8 meses até a 1.0 |

---

# 1. VISÃO GERAL E PILARES DO JOGO

## 1.1 Elevator Pitch (versão página da Steam)

**Short Description (limite de 300 caracteres, é o texto do card):**

> Monte um robô de ferro-velho com uma CPU roubada como alma, entre numa arena e faça seus projéteis quicarem em TUDO. Torradeiras que cospem raio, discos rígidos serrilhados, pernas de mola enferrujada. Cada run é uma gambiarra nova. Cada gambiarra dá errado de um jeito engraçado.

**About This Game (abertura do texto longo):**

> Você é uma CPU. Uma CPU velha, arranhada, com os pinos tortos, jogada fora atrás de uma assistência técnica. E você quer voltar a rodar.
>
> **SCRAP-A-BOT** é um roguelite de arena onde você monta um corpo em volta de si mesmo usando o que sobrou do lixo eletrônico da humanidade. Um braço de desentupidor. Uma cabeça de monitor de tubo com dois olhos que não param quietos. Pernas de mola de sofá. Cada peça atira de um jeito diferente, e **cada tiro quica nas paredes, nos obstáculos e nos inimigos**, ganhando dano a cada quique.
>
> Uma build boa não é um robô forte. É um robô que transformou a arena inteira numa máquina de pinball com sotaque de moedor de carne.

**Cinco bullets de feature (formato Steam):**

- **RICOCHETE É O JOGO.** Projéteis ganham 25% de dano por quique, acumulando até 4 vezes. Uma sala apertada não é um problema, é uma multiplicadora.
- **MONTE O ABSURDO.** Cinco slots, mais de 90 peças, mais de 40 receitas de fusão. Torradeira mais Bateria de Carro dá Tempestade Elétrica em Cadeia. Testado. Funciona. Não devia.
- **A CPU É SUA ALMA.** Quatorze processadores jogáveis, cada um com uma passiva quebrada. A CPU Pirata às vezes dá tela azul no meio do tiro. Às vezes triplica o dano. Boa sorte.
- **DESENHADO À MÃO, QUADRO A QUADRO.** Animação tradicional na tradição dos anos 90. Se algo pode espremer, esticar, cuspir fumaça e arregalar os olhos, ele vai.
- **RUNS DE 12 MINUTOS.** Perdeu? Já está numa nova. Sem tela de carregamento, sem cutscene, sem desculpa.

## 1.2 Os Três Pilares de Design

Todo recurso proposto durante a produção precisa responder "sim" a pelo menos um pilar. Recurso que não serve a nenhum é cortado sem discussão. Recurso que fere um pilar é cortado mesmo que sirva aos outros dois.

### PILAR 1 — GAME FEEL: "Cada tecla é um soco"

O jogo tem que ser gostoso de jogar com o áudio no mudo e a tela em escala de cinza. A validação é física: o playtester sorri sem perceber no primeiro minuto.

**Contratos mensuráveis do pilar:**

| Métrica | Valor obrigatório | Verificação |
|---|---|---|
| Latência do input até o primeiro pixel de resposta | 50 ms ou menos (3 quadros a 60 fps) | Câmera de alta taxa de quadros, teste mensal |
| Hitstop em acerto normal | 40 ms | Log automático de combate |
| Quadros de antecipação antes do projétil sair | Zero. O projétil nasce no quadro 1, a animação alcança depois | Revisão de código |
| Buffer de input para dash e disparo | 133 ms (8 quadros) | Teste automatizado |
| Coyote time em bordas e plataformas | 100 ms (6 quadros) | Teste automatizado |
| Taxa de quadros na cena de estresse | 60 fps travados no Steam Deck com 800 projéteis vivos | Benchmark noturno de integração contínua |

### PILAR 2 — CUSTOMIZAÇÃO MODULAR: "Meu robô é uma piada que eu contei"

A build precisa ser explicável em voz alta em uma frase, e essa frase precisa ser engraçada. Se o jogador termina uma run e não consegue contar o que montou para um amigo, a build falhou como design.

**Contratos mensuráveis do pilar:**

- Toda peça muda a **silhueta** do robô. Nada de upgrade invisível. Se o jogador equipou, o público da live tem que ver.
- Toda peça muda o **som** do robô andando ou atirando. Áudio é leitura de build.
- Nenhuma peça é estritamente pior que outra. Peças fracas em dano são fortes em utilidade ou em sinergia de fusão.
- O tempo entre pegar uma peça e entender o que ela faz precisa ser **menor que 3 segundos**, sem ler texto. O ícone, o som e o primeiro tiro ensinam.
- Meta de variedade: em 20 runs consecutivas, um jogador não deve repetir a mesma combinação de quatro peças mais CPU.

### PILAR 3 — FÍSICA E RICOCHETE: "A arena é cúmplice"

Paredes não são limites, são ferramentas. O jogador competente mira no chão, não no inimigo.

**Contratos mensuráveis do pilar:**

- Setenta por cento ou mais de todos os projéteis do jogo quicam por padrão. Os que não quicam existem para dar contraste.
- Toda sala tem no mínimo **quatro superfícies de quique não periféricas**, ou seja, obstáculos internos. Pelo menos uma delas é móvel ou destrutível.
- O dano por quique é **legível**: o projétil muda de cor e de escala visivelmente a cada quique.
- Uma build focada em ricochete deve conseguir limpar uma sala **sem mirar diretamente em um único inimigo**. Isso é um cenário fixo de controle de qualidade.

## 1.3 Perfil do Jogador

**Persona A, "o Ricardo do intervalo" (núcleo, cerca de 55% da base).** Vinte e oito anos, joga 30 a 60 minutos por noite depois do trabalho. Tem 400 horas de Vampire Survivors e 90 de Brotato. Quer um jogo que abre em 4 segundos, dá uma run e fecha. Não lê tooltip longo. Compra a US$ 9,99 por impulso se o GIF for bom. Ele é o público principal, e todo o onboarding é desenhado para ele.

**Persona B, "a Mari que otimiza" (engajada, cerca de 20%).** Vai fazer planilha das sinergias, vai postar no Reddit que descobriu uma build infinita e vai reclamar de balanceamento no fórum. Ela sustenta a cauda longa e a reputação do jogo. Precisa de teto de complexidade, e é para ela que existem as fusões de nível 3 e as CPUs desbloqueáveis.

**Persona C, "o Léo de 15 anos que viu no TikTok" (aquisição, cerca de 25%).** Não conhece o gênero. Veio pela estética e pelo humor. Precisa que os primeiros 90 segundos sejam compreensíveis sem tutorial de texto. É o vetor de crescimento viral e o motivo pelo qual a direção de arte é o segundo maior item do orçamento.

## 1.4 Apelo para Streamers e Vídeo Curto

O jogo é desenhado com **momentos de clipe** como recurso de primeira classe, não como acidente feliz.

1. **Formato vertical funciona.** A arena é jogável com corte central de 9 por 16. Elementos críticos da interface ficam nos 60% centrais horizontais. Existe um modo de guias de enquadramento vertical para o criador de conteúdo.
2. **Todo momento absurdo tem um pico visual de 0,4 segundo.** Fusão de peça, superaquecimento, morte de chefe e falha da CPU Pirata disparam um flash de tela cheia com texto cartunesco. É o quadro da miniatura.
3. **Legenda automática.** Ao morrer, o jogo gera uma frase de resumo na tela de fim, do tipo *"Morto por um mouse zumbi enquanto pilotava uma torradeira com pernas de girafa."* Esse texto é copiável e é literalmente a legenda do post.
4. **Replay dos últimos 15 segundos.** Buffer circular gravado como sequência de comandos, re-renderizável em vídeo pelo próprio jogo. Botão único, chamado "Salvar Vergonha".
5. **Nomes de peça são o gancho.** Roomba Suicida, AMDeus Camelô, Bebê Chorão. Um streamer lendo o nome em voz alta já é conteúdo.
6. **Modo Caos para live.** Integração opcional com o chat. Espectadores votam a cada 90 segundos entre três modificadores idiotas, como gravidade invertida, todos os projéteis virarem torradas, ou o robô ficar com três metros de altura.

## 1.5 Análise Competitiva e Posicionamento

| Jogo | O que ele faz melhor | Nosso diferencial |
|---|---|---|
| **Vampire Survivors** | Onboarding zero, snowball absurdo | Nós temos mira ativa e física. Teto de habilidade maior. |
| **BALL x PIT** | Física de ricochete clara e satisfação tátil | Nós temos identidade visual autoral e humor. Ricochete é um sistema, não é o jogo inteiro. |
| **Brotato** | Construção de build profunda em sessão curta | Nós somos legíveis visualmente. O jogador vê a build no corpo do robô. |
| **Nova Drift** | Modularidade de nave elegante | Nós somos engraçados e acessíveis. Nova Drift é frio e denso. |
| **Let Me Poo!** | Humor viral com custo de produção baixo | Nós temos profundidade sistêmica real. O humor vende, o sistema retém. |

**Frase de posicionamento interno:** é o Vampire Survivors se o Doug TenNapel tivesse desenhado, e se as balas quicassem.

---

# 2. DIREÇÃO DE ARTE E ANIMAÇÃO

## 2.1 Referência Central e Filosofia

A referência primária é **Earthworm Jim (1994) e Earthworm Jim 2 (1995)**, da Shiny Entertainment, com apoio de **Ren & Stimpy**, **Cow and Chicken** e das ilustrações de Ed Roth. A referência **não é pixel art**. É animação tradicional rasterizada.

A tese estética em uma frase: tudo no jogo parece que foi desenhado com nanquim grosso por alguém que estava rindo, e depois deixado no sol até derreter um pouco.

**Os cinco mandamentos de arte:**

1. **Nenhuma linha reta que não precise ser reta.** Contornos tremem, superfícies planas têm barriga, o horizonte é torto.
2. **A silhueta vem primeiro.** Um objeto tem que ser identificável em preto sólido a 25% do tamanho. Teste obrigatório: exportar a silhueta preta, olhar de longe, adivinhar o que é.
3. **Se pode ter olhos, tem olhos.** Olhos são o vetor primário de comédia e de leitura de estado. Uma máquina de lavar tem olhos. Um projétil pode ter olhos. Os olhos são grandes, brancos, com pupila pequena e desalinhada.
4. **Nada em repouso está parado.** Toda entidade tem uma animação de espera de no mínimo 8 quadros com respiração, tremor ou gotejamento.
5. **A comédia vem do timing, não do desenho.** O desenho é engraçado. O timing é o que faz rir.

## 2.2 Especificação Técnica de Sprites

| Parâmetro | Valor |
|---|---|
| Resolução de autoria | 4K de trabalho no Clip Studio ou Toon Boom, exportado a 1440p |
| Resolução de destino | Canvas lógico de 1920 por 1080. Escalonamento inteiro desativado, filtragem linear com mipmap. |
| Altura do robô do jogador | 180 px na configuração base, variando de 140 a 260 px conforme o chassi |
| Altura de inimigo comum | 60 a 110 px |
| Altura de chefe | 500 a 900 px, ocupando de 45 a 70% da altura da tela |
| Espessura de contorno | 5 px na escala de destino, variando de 3 a 8 px ao longo da linha. Linha viva, nunca uniforme. O contorno é desenhado, não é shader. |
| Cor do contorno | Nunca preto puro. Use `#1A0F14` para peças frias e `#2B1400` para peças quentes ou enferrujadas. |
| Taxa de animação | Animação em "twos", ou seja, 12 quadros por segundo efetivos, como padrão. "Ones" a 24 apenas em dash, impacto, morte de chefe e transformação de fusão. A mistura é deliberada e é parte do sabor dos anos 90. |
| Contagem típica de quadros | Espera 8, caminhada 10, disparo 6, dash 5, dano 4, morte 14 |
| Formato de entrega | Atlas de textura em WebP sem perda, empacotado pelo importador do Godot. Um atlas de 4096 por 4096 por família de peça. |
| Pivô | Definido manualmente por sprite em arquivo JSON companheiro. Nunca o centro geométrico. |

## 2.3 Paleta de Cores

A paleta é tóxica e saturada, com um princípio rígido: **fundos dessaturados, atores saturados**. O cenário nunca compete com o jogador nem com os projéteis. A saturação máxima do cenário é 45%, e a saturação mínima de projéteis é 85%.

**Paleta primária, para atores e efeitos visuais:**

| Nome | Hex | Uso |
|---|---|---|
| Verde Radioativo | `#8CFF1A` | Malware, dano venenoso, barra de energia |
| Magenta Chiclete | `#FF2D95` | Dano crítico, fusão, destaque de interface |
| Amarelo Urina de Gato | `#FFD400` | Faíscas elétricas, números de dano, avisos |
| Laranja Ferrugem Quente | `#FF6B1A` | Fogo, superaquecimento, calor |
| Ciano Tela Azul | `#22E0FF` | Projéteis de gelo e água, a CPU Pirata, congelamento |
| Roxo Cano Estourado | `#7B2FBF` | Chefes, elites, gravidade |
| Branco Osso | `#F5F0E1` | Olhos, dentes, fumaça de desenho |

**Paleta secundária, para cenário e sucata:**

| Nome | Hex | Uso |
|---|---|---|
| Ferrugem Seca | `#8A4B2A` | Metal enferrujado, base de quase toda peça |
| Cinza Chumbo | `#4A4F52` | Metal são, chassi, gabinetes |
| Bege Impressora 1998 | `#D6C9A8` | Periféricos velhos amarelados. Cor-assinatura do jogo. |
| Verde Placa-Mãe | `#2E5943` | Placas de circuito, interiores, detalhes |
| Marrom Óleo | `#241A12` | Sombra de cenário, sujeira, poças |

**Regras de aplicação:**

- Máximo de quatro cores dominantes por sprite, mais contorno e mais realce.
- Sombreamento em dois tons chapados, base e sombra, nunca gradiente suave. Gradiente só em efeitos visuais.
- A sombra é sempre um multiply de `#3B2B4A` a 55%, nunca preto.
- O realce especular é uma única forma branca sólida, geralmente um retângulo torto ou uma elipse, imitando reflexo de plástico velho.

## 2.4 Squash and Stretch: Especificação Numérica

Deformação exagerada não é opcional e não é feita quadro a quadro. É feita em tempo de execução por shader de vértice, aplicada por cima da animação desenhada, o que economiza milhares de quadros de arte.

| Evento | Deformação | Duração | Curva |
|---|---|---|---|
| Início de dash | Estica 1,45 vezes no eixo do movimento e 0,70 no perpendicular | 100 ms | Ease-out cúbica |
| Fim de dash, a freada | Espreme 0,65 por 1,35 | 130 ms | Elástica com 1 overshoot |
| Aterrissagem de pulo | Espreme 0,55 vertical por 1,50 horizontal | 160 ms | Elástica com 2 overshoots |
| Tomar dano | Espreme 0,80 uniforme mais flash branco | 90 ms | Linear na ida, ease-out na volta |
| Disparo de arma pesada | Coice, espreme 0,85 no eixo do cano | 120 ms | Elástica |
| Superaquecimento | Incha 1,20 pulsando a 4 Hz | Enquanto durar | Senoidal |
| Morte | Estica 1,8 vertical e depois colapsa a 0,1 | 400 ms | Duas curvas encadeadas |
| Inimigo levando ricochete forte | Espreme 0,5 no eixo do impacto | 110 ms | Elástica com 3 overshoots |

**Nota de implementação:** o valor de deformação é guardado como um `Vector2` no nó raiz e consumido por um material de canvas customizado. O pivô da deformação é a **base do sprite**, ou seja, os pés, e não o centro. Se for o centro, o robô afunda no chão ao espremer.

## 2.5 Design de Personagens: O Robô do Jogador

O robô do jogador é **assimétrico por regra**. Nunca existe configuração em que os dois lados combinam, porque os dois braços vêm de famílias de conectores diferentes, como detalhado na seção 4.2. Isso é uma decisão estética antes de ser mecânica, porque assimetria lê como gambiarra.

**Anatomia de montagem:**

```
              [ CABEÇA ]          1 slot, pivô no pescoço, gira 35 graus seguindo a mira
                  |
  [BRAÇO E] -- [ CHASSI ] -- [BRAÇO D]    braços giram 360 graus, ancorados nos ombros
                  |                        a CPU vive dentro do chassi, visível por uma janelinha
              [ PERNAS ]        parte do mesmo sprite do chassi, 10 quadros de caminhada
```

**Cinco exemplos de configuração completa, para orientar os artistas:**

**1. O Café da Manhã Armado.** Cabeça de torradeira bege soltando fumaça preta por uma fenda, com dois olhos desenhados na lateral que piscam fora de sincronia. Braço esquerdo é um desentupidor de borracha vermelha com um cabo elétrico descascado enrolado, faiscando amarelo a cada dois segundos. Braço direito é o tambor de uma máquina de lavar, girando devagar mesmo parado. Pernas de mola de sofá enferrujadas, uma visivelmente mais curta que a outra, o que faz o robô mancar na caminhada.

**2. O Vigia Insone.** Cabeça de monitor de tubo bege, com a tela mostrando dois olhos arregalados em fósforo verde, e o brilho da tela ilumina o próprio robô com luz esverdeada. A tela pisca e mostra chuvisco quando o robô toma dano. Braço esquerdo é uma pistola de cola quente pingando. Braço direito é um martelo feito de antena parabólica. Chassi de gabinete de PC com a lateral aberta e cabos pendurados arrastando no chão.

**3. A Barata Tonta.** Cabeça de ventilador de teto com três pás girando, e os olhos estão nas pás, então giram junto e ficam tontos. Dois braços de furadeira. Chassi de aspirador robô circular que anda sozinho quando o jogador solta o controle, com expressão de pânico permanente.

**4. O Palhaço Elétrico.** Cabeça de boneca de plástico queimada, cabelo derretido de um lado, um olho fechado, boca aberta gritando permanentemente. Braço esquerdo é uma batedeira com dois batedores girando. Braço direito é uma bobina de Tesla feita de ferro de solda. Pernas de manequim de loja, perfeitamente lisas e brancas, contrastando com toda a ferrugem acima.

**5. O Gigante Lento.** Cabeça de micro-ondas com a porta funcionando como mandíbula, dentes desenhados no vidro e luz interna amarela pulsando. Braço esquerdo é uma mangueira de aspirador que serpenteia sozinha. Braço direito é uma bazuca feita de cano de pia com uma torneira servindo de mira. Esteiras de trator de brinquedo, grandes demais para o corpo, deixando marcas no chão.

## 2.6 Regras para Design de Inimigos

- **Todo inimigo é um objeto doméstico ou de escritório reconhecível**, deformado. Se o jogador não consegue nomear o aparelho original, o design falhou.
- **Regra dos olhos.** Inimigo comum tem dois olhos. Elite tem quatro ou mais, ou um gigante. Chefe tem olhos em lugares errados.
- **Leitura de ameaça por cor.** O ponto mais saturado do sprite indica de onde vem o dano. A boca do que morde é magenta. O cano do que atira é amarelo.
- **Telegrafia obrigatória.** Todo ataque tem antecipação de no mínimo 250 ms com deformação clara. O inimigo que vai avançar se espreme para trás como uma mola antes.

## 2.7 Efeitos Visuais: Catálogo e Especificação

Os efeitos visuais compram cerca de 60% do feel do jogo, e o orçamento de arte reflete isso.

### 2.7.1 Fumaça de Desenho Animado

Nuvens de contorno grosso, em formato de couve-flor, sem transparência gradiente. A fumaça some por escala decrescente e por quadros desenhados, nunca por fade de alfa. São 6 quadros desenhados à mão, com 3 variantes de forma, espelhadas e rotacionadas ao acaso.

- Duração de 500 ms.
- Escala: nasce a 0,3, cresce até 1,4 em 200 ms, encolhe até zero nos 300 ms restantes.
- Cor `#F5F0E1` para vapor, `#4A4F52` para queimado, `#8CFF1A` para tóxico.

### 2.7.2 Poeira de Ricochete

Disparada em todo quique. É o feedback mais importante do jogo.

- De 4 a 7 partículas de faísca num leque de 120 graus, centrado na normal da superfície.
- Um anel de choque desenhado, de escala 0,2 até 1,1 em 120 ms.
- Uma marca de impacto persistente no cenário, durando 3 segundos com desaparecimento gradual.
- **O anel muda de cor conforme o número do quique:** branco no primeiro, amarelo no segundo, laranja no terceiro, magenta do quarto em diante. É assim que o jogador lê a multiplicação de dano sem olhar número nenhum.

### 2.7.3 Faíscas Elétricas

Desenhadas como polilinhas em ziguezague de três segmentos, com espessura variável, geradas por procedimento mas renderizadas com aparência de nanquim.

- Nunca curvas suaves. Ângulos de 60 a 120 graus entre segmentos.
- Duração de 80 ms por raio, com 2 a 4 raios sobrepostos em tempos escalonados.
- Sempre acompanhadas de um flash de luz 2D com raio de 200 px por 60 ms.
- Cor `#FFD400` com núcleo `#F5F0E1`.

### 2.7.4 Números de Dano Cartunescos

Fonte customizada desenhada à mão, com contorno grosso e sombra dura deslocada 4 px.

- **Dano normal:** amarelo, escala 1,0, sobe 40 px, dura 700 ms.
- **Dano de ricochete:** escala proporcional ao multiplicador, de 1,0 até 1,9, com a cor progressiva do quique.
- **Crítico:** magenta, escala 2,2, rotação aleatória de mais ou menos 15 graus, com dois pontos de exclamação desenhados atrás.
- **Movimento:** arco balístico com gravidade, não linha reta. Nasce com velocidade horizontal aleatória entre menos 80 e mais 80, vertical de menos 350 px/s, gravidade de 900 px/s ao quadrado. Quica uma vez num chão invisível.
- **Agregação obrigatória:** acima de 12 números na tela, um novo dano se soma ao número existente mais próximo em vez de criar outro. Sem isso, builds tardias viram sopa ilegível.

### 2.7.5 Outros Efeitos de Assinatura

| Efeito | Descrição | Gatilho |
|---|---|---|
| Tela Azul Cômica | A tela inteira fica ciano por 180 ms com uma carinha triste gigante desenhada à mão | Falha da CPU Pirata |
| Estrelinhas de Tontura | Cinco estrelas amarelas orbitando a cabeça, desenhadas em 8 quadros | Atordoamento |
| Nuvem de Briga | Bola de poeira com braços e pernas saindo aleatoriamente | Corpo a corpo pesado |
| Fumaça de Superaquecimento | Vapor branco saindo em jatos pelas juntas, com apito de chaleira | Calor acima de 85% |
| Chuva de Parafusos | De 12 a 30 parafusos físicos caem e quicam no chão com som metálico | Morte de qualquer inimigo |
| Flash de Fusão | Congelamento de 350 ms, tela branca, silhueta preta das duas peças se fundindo, com um raio desenhado por cima | Fusão de peça |

## 2.8 Pipeline de Produção 2D

```
1. THUMBNAIL    Miniatura em papel ou tablet, 30 segundos por peça. Só silhueta.
                Aprovação do diretor de arte pela silhueta apenas.
2. LINE ART     Clip Studio Paint, pincel G-Pen com estabilização baixa.
                Contorno sempre em camada separada.
3. FLATS        Preenchimento chapado, uma camada por região de cor, todas nomeadas.
4. SHADE        Uma camada de multiply e uma de add. Formas chapadas, sem pincel macio.
5. ANIM         Toon Boom Harmony para caminhada e espera, com deformação por ossos.
                Quadro a quadro puro para disparo, morte e chefes.
6. EXPORT       Script Python exporta a sequência PNG mais o JSON de pivô e hitbox.
7. PACK         TexturePacker por linha de comando gera o atlas WebP.
8. IMPLEMENT    Cria ou atualiza o recurso .tres da peça. Nunca caminho de sprite no código.
```

**Orçamento de arte estimado.** São 90 peças por 4 estados animados por cerca de 7 quadros, o que dá aproximadamente 2.500 quadros de peça. Mais 22 inimigos por 5 estados por cerca de 8 quadros, cerca de 880 quadros. Mais 6 chefes por cerca de 140 quadros, cerca de 840. Mais efeitos visuais e interface.

| Item | Quadros estimados |
|---|---|
| Peças modulares | 2.500 |
| Inimigos | 880 |
| Chefes | 840 |
| Efeitos visuais | 600 |
| Interface e cenário animado | 400 |
| **Total** | **5.220** |

A doze quadros úteis por dia por artista, isso são cerca de 435 dias-artista. Com dois artistas em tempo integral por 14 meses, algo em torno de 600 dias-artista, sobra uma folga de 25% para retrabalho. **Este é o risco número 1 do projeto e está tratado na seção 7.6.**

---
# 3. CORE LOOP E MECÂNICAS DE GAMEPLAY

## 3.1 Fluxo da Partida

A run é dividida em **5 setores**. Cada setor tem 4 salas. A duração-alvo total é de **12 minutos**, com desvio aceitável de 10 a 15.

```
GARAGEM (meta) 
   |
   v
ESCOLHA DE CPU  (20 s)  -> define classe, energia, calor e passiva
   |
   v
SETOR 1  ..  SETOR 5
   |
   +-- Sala 1: Combate       (75 s)   3 ondas
   +-- Sala 2: Combate       (75 s)   3 ondas + hazard do bioma
   +-- Sala 3: Bancada       (25 s)   escolha de 3 peças, fusão, venda
   +-- Sala 4: Elite ou Chefe (60 a 110 s)
   |
   v
FIM DA RUN -> tela de resumo -> conversão de Sucata em Cobre -> GARAGEM
```

**Tabela de ritmo por setor:**

| Setor | Bioma | Duração-alvo | Inimigos por sala | HP médio do inimigo | Peças ofertadas | Chefe |
|---|---|---|---|---|---|---|
| 1 | Ferro-Velho do Zé | 2 min 10 s | 14 a 20 | 22 | Comum 80%, Incomum 20% | Elite |
| 2 | Lan House CyberBaiacu | 2 min 20 s | 20 a 28 | 45 | Comum 60%, Incomum 35%, Rara 5% | SUGÃO 3000 |
| 3 | Assistência Técnica do Seu Nildo | 2 min 30 s | 26 a 36 | 90 | Comum 40%, Incomum 40%, Rara 20% | Elite duplo |
| 4 | Esgoto de Lixo Eletrônico | 2 min 40 s | 32 a 46 | 180 | Comum 20%, Incomum 45%, Rara 35% | FORMULÁRIO 27-B |
| 5 | Datacenter "A Nuvem" | 2 min 50 s | 40 a 60 | 340 | Incomum 30%, Rara 50%, Lendária 20% | O ROTEADOR ETERNO |

**Regras de ritmo:**

- Nunca mais de **8 segundos sem um inimigo em tela** durante uma sala de combate. Se o jogador limpou rápido, a próxima onda é antecipada.
- A porta da sala abre **1,2 segundo** depois do último inimigo morrer, tempo suficiente para os parafusos caírem e a fumaça dissipar.
- A tela de escolha de peça **não pausa o tempo total da run**, mas pausa o combate. Ela tem um timer visível de 25 segundos que apenas destaca a opção recomendada quando esgota. Nunca escolhe sozinha.
- O jogador pode **pular** o setor 3 e 4 de bancada segurando um botão, ganhando 40 de Sucata como compensação. Isso serve para runs de velocidade.

## 3.2 Movimentação e Controle

**Esquema de controle padrão (controle analógico):**

| Ação | Controle | Teclado e mouse |
|---|---|---|
| Mover | Analógico esquerdo | WASD |
| Mirar | Analógico direito | Posição do mouse |
| Disparar braço esquerdo | Gatilho L2 | Botão esquerdo do mouse |
| Disparar braço direito | Gatilho R2 | Botão direito do mouse |
| Dash | A / botão sul | Barra de espaço ou Shift |
| Habilidade da cabeça | R1 | Botão do meio ou Q |
| Purga de calor | L1 | E |
| Mapa e status | Botão de opções | Tab |

**Valores de movimentação:**

| Parâmetro | Valor base | Observação |
|---|---|---|
| Velocidade máxima | 260 px/s | Modificada de 195 a 380 conforme o chassi |
| Aceleração | 2.600 px/s ao quadrado | Chega a 90% da velocidade máxima em 90 ms |
| Desaceleração | 3.400 px/s ao quadrado | Parada quase imediata, essencial para o feel arcade |
| Velocidade do dash | 900 px/s | Distância percorrida de 162 px |
| Duração do dash | 180 ms | Com 90 ms de invulnerabilidade no meio |
| Recarga do dash | 1,2 s | Reduzida por peças de perna |
| Cargas de dash | 1 base | Pode chegar a 3 com peças específicas |
| Raio de colisão do jogador | 26 px | Sempre menor que o sprite. Isso é intencional e melhora a sensação de esquiva. |

**Mira.** A mira é livre em 360 graus. O jogo aplica **assistência de mira leve** por padrão, ajustável nas opções de 0 a 100%:

- Um cone de 8 graus em volta do vetor de mira faz o projétil corrigir até 6 graus por segundo em direção ao inimigo mais próximo dentro de 500 px.
- No teclado e mouse, a assistência padrão é **0%**. No controle, é **45%**.
- A assistência é **desligada para projéteis já ricocheteados**. Depois do primeiro quique, a bala é livre. Isso preserva a legibilidade da física.

**Retículo.** O retículo é um alvo desenhado à mão que se deforma. Ele abre quando o robô está com dispersão alta e fecha quando está parado. Ele fica **vermelho e treme** quando o calor está acima de 80%.

## 3.3 Sistema de Física e Ricochete

Este é o coração mecânico do jogo e a seção mais importante do documento.

### 3.3.1 Modelo de Colisão

Projéteis **não são corpos rígidos da engine**. São entidades leves com integração manual, descritas em detalhe na seção 7.2. O modelo físico é deliberadamente simplificado e determinístico.

**Reflexão.** Ao colidir com uma superfície de normal `n`, a velocidade `v` é refletida pela fórmula padrão de reflexão, e depois multiplicada pelo coeficiente de restituição da superfície:

```
v_novo = (v - 2 * (v · n) * n) * restituicao_da_superficie * restituicao_do_projetil
```

**Coeficientes de restituição por superfície:**

| Superfície | Restituição | Observação |
|---|---|---|
| Parede de concreto | 1,00 | Padrão. O projétil não perde velocidade. |
| Pilha de pneus | 1,35 | Acelera o projétil. Presente no setor 1. |
| Colchão velho | 0,45 | Amortece. Usado como armadilha de posicionamento. |
| Vidro de datacenter | 1,10 e quebra | Quebra depois de 3 quiques, virando buraco |
| Corpo de inimigo comum | 0,85 | Sim, quica em inimigo. Isso é fundamental. |
| Corpo de inimigo elite | 1,00 | |
| Chefe | 1,20 | Chefes são superfícies de quique gigantes. Design deliberado. |
| Escudo de inimigo | 1,60 | Devolve o tiro contra o jogador se não houver mais quiques disponíveis |

**Jitter anti-loop.** Sem correção, um projétil pode entrar em um loop perpendicular eterno entre duas paredes paralelas. Toda reflexão adiciona um desvio angular aleatório de **mais ou menos 1,5 grau**, semeado pelo RNG da run. Isso é imperceptível e elimina o problema.

**Velocidade mínima.** Se a velocidade cair abaixo de **90 px/s**, o projétil morre com uma animação de "plop" desanimado e uma fumacinha. É uma piada e é uma proteção de performance.

### 3.3.2 A Multiplicação de Dano por Quique

Esta é a regra que define o jogo inteiro.

| Quique | Multiplicador de dano | Cor do projétil | Escala do projétil |
|---|---|---|---|
| 0, tiro direto | 1,00 | Cor base da peça | 1,00 |
| 1 | 1,25 | Branco `#F5F0E1` | 1,10 |
| 2 | 1,56 | Amarelo `#FFD400` | 1,22 |
| 3 | 1,95 | Laranja `#FF6B1A` | 1,35 |
| 4 ou mais | 4,00 (teto rígido) | Magenta `#FF2D95` | 1,50 |

A progressão é geométrica a 1,25 por quique, com **teto rígido em 4,00** para impedir combos infinitos degenerados. O salto do quique 3 para o 4 é grande de propósito: ele é a recompensa por dominar o sistema, e é o momento de clipe.

**Regras adicionais:**

- **Quiques máximos por projétil:** 3 na base. Peças e upgrades somam. O teto absoluto é 12, ponto em que o projétil vira um enxame errático e o desempenho fica em risco.
- **Imunidade de acerto repetido:** um projétil não pode acertar o mesmo inimigo duas vezes em menos de **220 ms**. Sem isso, uma bala presa dentro de um chefe faz dano infinito.
- **O contador de quiques é do projétil, não do inimigo.** Acertar um inimigo consome um quique e mantém o multiplicador.

### 3.3.3 O Efeito Bola de Neve

O snowball da build vem de quatro eixos multiplicativos, todos independentes. Uma build fica absurda quando combina três ou mais.

| Eixo | Como cresce | Teto | Exemplo de peça |
|---|---|---|---|
| **Contagem de quiques** | Peças e upgrades somam quiques | 12 | Disco Rígido Voador, mais 4 |
| **Multiplicação de projéteis** | Divisão no quique, projéteis extras por tiro | 8 projéteis por disparo | Fonte 500W Genérica, divide em 3 |
| **Cadência** | Percentual de velocidade de disparo | 400% do base | CPU Overclock, mais 35% |
| **Dano por projétil** | Percentual plano de dano | Sem teto, mas cresce devagar | Bateria de Carro, mais 22% |

**Curva de poder-alvo.** Medida em dano por segundo teórico contra um alvo parado no centro da arena:

| Momento da run | DPS esperado | HP total da onda | Tempo para limpar |
|---|---|---|---|
| Setor 1, início | 55 | 380 | 7 s |
| Setor 2, fim | 210 | 1.400 | 7 s |
| Setor 3, fim | 640 | 4.100 | 6 s |
| Setor 4, fim | 2.100 | 11.500 | 5 s |
| Setor 5, fim | 7.800 | 34.000 | 4 s |

O tempo para limpar **cai de propósito**. A sensação de aceleração é o produto. O jogador deve sentir que a run está fugindo do controle a favor dele.

### 3.3.4 Obstáculos e Geometria de Arena

Toda sala é montada por um gerador que respeita restrições fixas:

- Arena de 2400 por 1350 unidades, com câmera de 1920 por 1080 que dá zoom-out de até 1,25 vezes quando a ação se espalha.
- **Mínimo de 4 e máximo de 9 obstáculos internos**, cobrindo entre 12% e 22% da área.
- **Nenhum corredor mais estreito que 220 px**, senão o jogador fica preso.
- **Nenhum ponto da arena a mais de 700 px de uma superfície de quique.** Esta é a restrição que garante que o pilar 3 sempre funcione.
- Pelo menos um obstáculo é **móvel ou destrutível** por sala.
- O gerador roda validação por busca em largura para garantir que toda a arena é alcançável.

**Catálogo de obstáculos:**

| Obstáculo | Bioma | Comportamento |
|---|---|---|
| Pilha de Pneus | Ferro-Velho | Restituição 1,35, acelera o projétil |
| Carcaça de Fusca | Ferro-Velho | Sólido, destrutível com 400 de dano, cai desmontando |
| Mesa de Lan House | CyberBaiacu | Sólida, mas o jogador passa por baixo com dash |
| Cadeira Gamer Giratória | CyberBaiacu | Gira ao ser atingida, muda a normal de reflexão continuamente |
| Prateleira de Peças | Assistência | Cai quando destruída, criando parede nova |
| Esteira Transportadora | Assistência | Empurra projéteis e jogador a 120 px/s |
| Poça de Ácido | Esgoto | Não bloqueia, causa 8 de dano por segundo, projéteis passam |
| Cano Vertical | Esgoto | Cilíndrico, reflexão radial imprevisível, adora ricochete |
| Rack de Servidor | Datacenter | Sólido, restituição 1,0, com luzinhas que piscam ao ser atingido |
| Piso de Vidro | Datacenter | Quebra em 3 quiques e vira buraco intransponível |

## 3.4 Feedback Sensorial: A Especificação de Juiciness

### 3.4.1 Hitstop

O hitstop congela a simulação inteira, exceto os efeitos visuais e a interface. Isso é o que dá peso ao impacto.

| Evento | Duração do hitstop | Escopo |
|---|---|---|
| Acerto normal em inimigo comum | 40 ms | Global |
| Acerto crítico | 90 ms | Global |
| Acerto com multiplicador de quique 4 | 110 ms | Global |
| Morte de inimigo comum | 60 ms | Global |
| Morte de elite | 140 ms | Global, com zoom de 1,08 vezes |
| Jogador tomando dano | 130 ms | Global, mais flash branco |
| Mudança de fase de chefe | 350 ms | Global, com escurecimento de tela |
| Fusão de peça | 350 ms | Global, com tela branca |

**Regra de acúmulo.** Hitstop não soma. Vale sempre o maior valor pendente. Sem essa regra, uma build de alto DPS trava o jogo em câmera lenta permanente. Este é um bug clássico do gênero e precisa estar no código desde o primeiro dia.

**Teto de hitstop.** Nenhum quadro pode ter mais de 130 ms de congelamento, exceto os eventos roteirizados de chefe e fusão.

### 3.4.2 Screen Shake

Implementado por sistema de trauma, não por eventos diretos. Cada evento adiciona trauma, e o trauma decai. A amplitude é o trauma ao quadrado, o que deixa tremores pequenos sutis e grandes violentos.

| Evento | Trauma adicionado |
|---|---|
| Disparo de arma leve | 0,08 |
| Disparo de arma pesada | 0,22 |
| Acerto de ricochete com multiplicador 3 ou mais | 0,18 |
| Jogador tomando dano | 0,45 |
| Explosão | 0,35 |
| Pisada de chefe | 0,60 |

- Decaimento do trauma: 1,8 por segundo.
- Amplitude máxima: 14 px de deslocamento e 2,5 graus de rotação.
- **Slider de acessibilidade de 0 a 150%**, com 100% como padrão. Em 0%, o tremor é substituído por um pulso de vinheta na borda da tela, para não perder a informação.

### 3.4.3 Áudio Tátil

O áudio é o segundo canal de leitura de build e precisa de tanto cuidado quanto a arte.

**Filosofia de captação.** Nada de biblioteca genérica de tiro. Todo som base é **captado em campo com sucata real**: chapa de metal batendo, geladeira velha ligando, ventoinha de PC morrendo, mola de sofá, torradeira pulando, modem de discagem.

| Categoria | Descrição sonora | Camadas |
|---|---|---|
| Disparo leve | Chiado de ar comprimido mais clique de plástico | 3 camadas, 6 variantes por camada |
| Disparo pesado | Porta de geladeira batendo mais explosão abafada | 4 camadas |
| **Quique 1** | Batida de chapa fina, tom médio | 8 variantes |
| **Quique 2** | Mesma batida, afinada 2 semitons acima, mais brilho | 8 variantes |
| **Quique 3** | Afinada 4 semitons acima, com pequeno delay de eco | 8 variantes |
| **Quique 4** | Afinada 7 semitons acima, mais um sino agudo e um distorção | 8 variantes |
| Metal amassando | Lata de tinta sendo pisada, camada grave de contêiner | 6 variantes |
| Circuito estalando | Arco elétrico real de fonte queimada, mais crepitar de fritura | 5 variantes |
| Morte de inimigo | Desmonte de peças mais um "pop" cômico de boca | 10 variantes |
| Superaquecimento | Chaleira apitando, subindo de tom com o nível de calor | Contínuo, com parâmetro |

**Regras técnicas de áudio:**

- **A escala de quique é musical e ascendente.** Quatro quiques seguidos formam um arpejo. Isso é a razão pela qual acertar uma cadeia de ricochetes é prazeroso mesmo sem olhar.
- **Limitador de vozes:** máximo de 4 instâncias simultâneas por som, com roubo da mais antiga. Sem isso, uma build tardia vira ruído branco.
- **Ducking dinâmico:** a música abaixa 6 dB por 200 ms em eventos de trauma acima de 0,4.
- **Variação de pitch:** todo som avulso recebe variação aleatória de mais ou menos 4%, exceto os sons da escala de quique, que são afinados de propósito.

### 3.4.4 Outros Elementos de Feel

- **Flash de acerto:** o inimigo fica branco puro por 60 ms, e depois volta com um pulso de sua própria cor por mais 80 ms.
- **Congelamento de sprite ao disparar:** o robô "trava" no quadro de disparo por 50 ms antes de retomar a animação.
- **Recoil de câmera:** ao disparar arma pesada, a câmera desloca 12 px na direção contrária, voltando em 180 ms.
- **Zoom dinâmico:** a câmera afasta de 1,0 até 1,25 vezes conforme o número de inimigos vivos e a dispersão deles.
- **Números de dano com fila.** Ver seção 2.7.4.
- **Vibração de controle:** 3 padrões distintos, para disparo, quique de multiplicador alto e dano recebido. Com slider próprio.

---

# 4. SISTEMA MODULAR DO ROBÔ

## 4.1 A CPU: O Núcleo Central

A CPU é a alma do robô e a única coisa que persiste conceitualmente entre as runs. Ela define três coisas:

1. **O orçamento de energia**, medido em Watts. Cada peça equipada consome Watts. Passar do orçamento é possível mas gera penalidade severa.
2. **O sistema térmico**, ou seja, a capacidade de calor e a taxa de dissipação.
3. **A passiva**, que é uma regra maluca que muda como o jogo funciona.

### 4.1.1 Sistema de Energia

- A CPU fornece um TDP, entre 80 e 150 Watts.
- Cada peça equipada consome entre 12 e 65 Watts.
- **Se o consumo total passar do TDP**, o robô entra em **Subvoltagem**: menos 30% de cadência, e a cada 4 segundos ele tem um espasmo cômico que o deixa parado por 0,3 segundo. É jogável, mas ruim. A escolha de estourar o orçamento é uma decisão de build válida quando as peças são muito boas.
- Fontes de alimentação encontradas na run somam de 10 a 40 Watts ao orçamento.

### 4.1.2 Sistema de Calor

- Capacidade térmica base entre 80 e 140 unidades.
- Cada disparo gera calor conforme a peça, tipicamente de 0,8 a 9 unidades.
- Dissipação passiva base de 12 unidades por segundo, com atraso de 0,6 segundo após o último disparo.
- **Acima de 85% do calor**, o robô emite vapor e o retículo treme.
- **Ao chegar em 100%**, o robô **superaquece**: fica travado por 1,8 segundo com uma animação de derretimento, e sai com o calor zerado.
- **Purga de Calor**, no botão L1, é uma ação ativa que descarrega 60% do calor instantaneamente numa nuvem de vapor que causa 40 de dano em área de 200 px. Recarga de 8 segundos. É defesa e ataque ao mesmo tempo, e é o que separa jogador bom de jogador mediano.
- Coolers e dissipadores encontrados na run melhoram a dissipação em 15 a 60%.

### 4.1.3 Catálogo de CPUs

| # | CPU | TDP | Calor máx. | Dissipação | Passiva | Desbloqueio |
|---|---|---|---|---|---|---|
| 1 | **Pentiun Ferrugem 100 MHz** | 100 W | 100 | 12/s | Nenhuma. Mais 10% de dano geral por ser honesta. | Inicial |
| 2 | **Ryzin 9 Frito (Overclock)** | 90 W | 80 | 7/s | Mais 35% de cadência e mais 20% de velocidade de projétil. Dissipação 40% pior. Ao superaquecer, explode em área causando 150 de dano. | Inicial |
| 3 | **AMDeus Camelô (Pirata)** | 130 W | 110 | 14/s | Todo disparo tem 12% de chance de falhar com tela azul cômica, e 9% de chance de dar dano triplo. Uma vez por sala, copia a peça do braço esquerdo para o direito. | Matar 50 inimigos com projéteis ricocheteados |
| 4 | **Zilog Z-80 Bafo (Vintage 8-bit)** | 80 W | 90 | 16/s | Todos os projéteis viram blocos pixelados com dano fixo de 14, ignorando percentuais de dano. Em compensação, quiques são ilimitados e não perdem velocidade. Trilha sonora vira chiptune. | Terminar uma run usando só peças comuns |
| 5 | **Bitcorn Rig (Mineradora)** | 140 W | 130 | 9/s | Mais 2 de Sucata por inimigo morto e mais 25% de chance de peça rara. Menos 20% de dano e mais 100% de geração de calor. A ventoinha faz barulho o tempo todo. | Acumular 10.000 de Sucata no total |
| 6 | **Café Derramado (Molhada)** | 110 W | 100 | 11/s | Todo acerto solta um arco elétrico em cadeia para até 3 alvos em 250 px, causando 35% do dano. Cada disparo tem 4% de chance de curto-circuito, dando 15 de dano a você mesmo. | Morrer 3 vezes no setor 2 |
| 7 | **Y2K-Bug (Militar)** | 120 W | 120 | 13/s | A cada 60 segundos, o relógio interno "vira": todas as recargas zeram e você fica invulnerável por 2,5 segundos, com a tela em preto e branco. | Derrotar o FORMULÁRIO 27-B |
| 8 | **Cyrix Bode (Genérica)** | 150 W | 140 | 15/s | Mais 2 slots de módulo de sucata. Nenhum bônus de combate. É a CPU do jogador que quer stackar upgrades passivos. | Comprar 20 upgrades na Garagem |
| 9 | **Placa de Vídeo Enfiada no Soquete** | 85 W | 70 | 6/s | Não deveria funcionar. Todos os projéteis ganham mais 2 quiques e mais 40% de velocidade. Calor gerado é dobrado e a dissipação é péssima. | Alcançar multiplicador de quique 4 vinte vezes numa run |
| 10 | **Xeon do Servidor da Prefeitura** | 145 W | 150 | 18/s | Menos 25% de dano, mas mais 100% de vida e imunidade a atordoamento. É lenta, gorda e não morre. | Sobreviver a um setor sem tomar dano |
| 11 | **Chip de Cartão de Crédito Clonado** | 95 W | 90 | 12/s | Toda peça na bancada custa metade. Ao ser atingido, tem 20% de chance de "estornar" o dano para o inimigo mais próximo. | Comprar 15 peças em uma única run |
| 12 | **Arduíno com Fita Isolante** | 105 W | 95 | 13/s | Você começa a run com uma peça lendária aleatória, mas ela pode quebrar permanentemente a qualquer momento com 1% de chance por sala. | Fundir 25 peças no total |
| 13 | **Cooler Master Sem CPU (Vazia)** | 130 W | 200 | 30/s | Não tem processador nenhum, só um cooler. Você não tem passiva e não tem habilidade de cabeça. Em troca, superaquecer é praticamente impossível e a Purga de Calor recarrega em 3 segundos. | Superaquecer 40 vezes |
| 14 | **O NÚCLEO (final)** | 200 W | 180 | 20/s | Combina as passivas de duas CPUs já desbloqueadas, escolhidas no início da run. | Derrotar O ROTEADOR ETERNO |

## 4.2 Os Slots de Peças

O robô tem **cinco slots**: CPU, Cabeça, Braço Esquerdo, Braço Direito e Chassi com Pernas.

**Regra dos barramentos.** Braço esquerdo e braço direito usam conectores diferentes e incompatíveis, o que é justificado no jogo como "padrões de porta que ninguém padronizou". Isso força assimetria visual e cria duas famílias mecânicas distintas:

- **Barramento Serial (braço esquerdo):** armas de **cadência**. Disparo automático segurando o botão, dano por tiro baixo, calor por tiro baixo, muitos projéteis.
- **Barramento Paralelo (braço direito):** armas de **impacto**. Disparo por clique ou carga, dano alto, calor alto, projéteis lentos e pesados que quicam mais.

Essa divisão resolve três problemas de uma vez: garante assimetria visual, evita que o jogador equipe duas cópias da mesma arma dominante, e dá a toda build um ritmo de mão esquerda contínua com mão direita pontuada.

**Raridades e escalonamento:**

| Raridade | Cor da borda | Multiplicador de stats | Chance base |
|---|---|---|---|
| Comum | Cinza `#4A4F52` | 1,00 | 50% |
| Incomum | Verde `#8CFF1A` | 1,35 | 32% |
| Rara | Magenta `#FF2D95` | 1,80 | 14% |
| Lendária | Dourada com contorno animado | 2,50 mais efeito único | 4% |

## 4.3 Tabela de Peças: CABEÇA

A cabeça oferece uma **habilidade ativa** com recarga, mais um bônus passivo. Ela é a peça de utilidade e de identidade visual, porque é o que o público vê primeiro.

| Nome | Efeito visual e cômico | Ataque e projétil | Comportamento de ricochete | Dano | Recarga | Watts | Calor |
|---|---|---|---|---|---|---|---|
| **Monitor CRT "Olho Gordo"** | Tela de tubo bege com dois olhos em fósforo verde desenhados na tela, que se arregalam e tremem. Mostra chuvisco quando você toma dano. | Raio catódico contínuo por 1,5 s, em linha reta | Não quica, **atravessa** todos os inimigos na linha | 38/s | 6 s | 22 W | 3/s |
| **Torradeira "Cuspe-Torrada"** | Torradeira de duas fendas soltando fumaça preta. A alavanca sobe sozinha com um "TING" e ela pula 15 px no ar. | Lança 3 torradas queimadas em leque de 40 graus | Quica **3 vezes**, e cada quique deixa uma migalha em chamas no chão (4 de dano/s por 3 s) | 22 cada | 3,5 s | 18 W | 5 |
| **Micro-ondas "Boca Quente"** | A porta é uma mandíbula com dentes desenhados no vidro. Luz interna amarela pulsa. Faz "bip bip bip" antes de disparar. | Cone de micro-ondas de 90 graus e 350 px, que cozinha | Não quica. Aplica queimadura de 9/s por 4 s | 30 mais queimadura | 7 s | 26 W | 12 |
| **Ventilador de Teto "Hélice Tonta"** | Três pás girando, com um olho em cada pá, que giram junto e ficam visivelmente tontos e desalinhados. | Aura passiva de 400 px de raio | **Curva os seus próprios projéteis** que passam pela aura, redirecionando 25 graus por segundo para o inimigo mais próximo | 5/s de contato | Passiva | 20 W | 2/s |
| **Câmera de Segurança "Vigia Bêbado"** | Câmera de teto pendurada por um cabo, balançando bêbada. A lente estala quando foca. | Marca o inimigo mais próximo com uma mira desenhada à mão | O alvo marcado recebe **mais 30% de dano** e atrai projéteis ricocheteados num raio de 300 px | Nenhum direto | 4 s | 16 W | 1 |
| **Abajur "Farol da Depressão"** | Luminária de mesa com cúpula amassada e a lâmpada piscando. Emite um zumbido triste. | Cone de luz de 60 graus, 500 px, sempre ligado na direção da mira | Projéteis dentro da luz ganham **mais 1 quique** e mais 15% de velocidade | 6/s na luz | Passiva | 24 W | 4/s |
| **Boneca Queimada "Bebê Chorão"** | Cabeça de boneca com cabelo derretido de um lado, um olho fechado, boca escancarada em grito eterno. | Grito sônico em anel de 450 px | Empurra 400 px e atordoa por 0,9 s. Projéteis dentro do anel **invertem a direção** e voltam com dois quiques a mais | 45 | 8 s | 21 W | 8 |
| **Impressora de Cabeça "Cospe-Papel"** | Uma impressora jato de tinta pequena virada de lado, com o alimentador como boca. Faz aquele barulho de calibragem. | Cospe 6 folhas de papel giratórias em espiral | Quica **5 vezes** com restituição 1,2, ganhando velocidade a cada quique | 14 cada | 5 s | 19 W | 6 |
| **Rádio-Relógio "Alarme Eterno"** | Rádio-relógio de cabeceira com números vermelhos piscando 12:00 para sempre. | A cada 12 segundos dispara um alarme que causa dano em toda a tela | Não é projétil. Dano puro em área global. | 70 | 12 s, automático | 23 W | 0 |

## 4.4 Tabela de Peças: BRAÇO ESQUERDO (Barramento Serial, Cadência)

Armas automáticas. O jogador segura o gatilho. Dano por tiro baixo, volume alto.

| Nome | Efeito visual e cômico | Projétil | Comportamento de ricochete | Dano | Cadência | Watts | Calor/tiro |
|---|---|---|---|---|---|---|---|
| **Desentupidor Elétrico "Chupa-Cabo"** | Desentupidor de borracha vermelha com um cabo descascado enrolado, faiscando. Faz "PLOP" a cada tiro. | Ventosa que gruda no primeiro inimigo ou parede | Quica **1 vez** e então gruda. Explode em 1,2 s causando 40 de dano em 150 px. Máximo de 6 ventosas grudadas ao mesmo tempo. | 12 mais 40 na explosão | 3,3/s | 28 W | 3 |
| **Furadeira de Impacto "Broca Gagá"** | Furadeira laranja de obra com a broca entortada. Treme tanto que o braço inteiro borra na animação. | Brocas curtas em rajada contínua | Quica **2 vezes**, perfura 1 inimigo antes de quicar | 9 | 11/s | 34 W | 1,2 |
| **Mangueira de Aspirador "Sopra-Poeira"** | Mangueira corrugada que serpenteia sozinha e às vezes tenta fugir. Chia. | Modo duplo: suga por 1 s, depois cospe tudo que sugou | **Suga projéteis inimigos** num cone de 300 px e os devolve com o dobro do dano e mais 2 quiques | Devolve o dano original vezes 2 | Contínuo | 30 W | 2 |
| **Pistola de Cola Quente "Melequinha"** | Pistola de cola branca pingando permanentemente, com um fio de cola que balança. | Bolota de cola pegajosa | Quica **4 vezes**, e **cada quique deixa uma poça de cola** de 90 px que lentifica inimigos em 60% por 4 s | 11 | 5/s | 26 W | 2,5 |
| **Batedeira "Bate-Bate"** | Batedeira de bolo com dois batedores girando em direções opostas, jogando massa amarela para todo lado. | Corpo a corpo em cone de 180 graus e 160 px | Não dispara projétil. **Reflete projéteis inimigos** com mais 100% de dano e mais 3 quiques. | 26 por golpe | 4,5/s | 24 W | 2 |
| **Controle de Videogame "Combo Infinito"** | Controle de console genérico com fio cortado. Os botões voam como projéteis, com os símbolos desenhados. | Botões A, B, X e Y voando | Quica **3 vezes**. **A cada 5º disparo** sai um botão "START" gigante com dano triplo e mais 4 quiques. | 10, ou 30 no quinto | 8/s | 27 W | 1,5 |
| **Isqueiro de Churrasqueira "Pshhhh"** | Acendedor de churrasco com o gatilho travado. Chama azul e amarela desenhada em 8 quadros. | Lança-chamas curto de 280 px | Não quica, mas **incendeia superfícies**: a chama gruda em paredes por 3 s e queima quem encostar (12/s) | 18/s | Contínuo | 32 W | 4/s |
| **Metralhadora de Grampeador "Tec-Tec-Tec"** | Grampeador de escritório gigante, aberto no meio, cuspindo grampos. | Grampos finos e rápidos | Quica **2 vezes**. Ao acertar um inimigo, **grampeia ele no chão** por 0,6 s a cada 5 acertos. | 7 | 14/s | 36 W | 0,9 |
| **Ratoeira de Mouse "Clica Clica"** | Um mouse de bola dos anos 90 preso numa ratoeira. Os botões clicam sozinhos, nervosos. | Cliques de energia em forma de setinha de cursor | Quica **6 vezes** com restituição 1,15, ganhando velocidade | 6 | 10/s | 25 W | 1 |

## 4.5 Tabela de Peças: BRAÇO DIREITO (Barramento Paralelo, Impacto)

Armas pesadas. Clique único ou carga. Dano alto, calor alto, projéteis lentos que quicam muito.

| Nome | Efeito visual e cômico | Projétil | Comportamento de ricochete | Dano | Cadência | Watts | Calor/tiro |
|---|---|---|---|---|---|---|---|
| **Tambor de Máquina de Lavar "Centrífuga"** | Tambor inteiro de máquina de lavar preso ao ombro, girando devagar mesmo parado, com roupa saindo. | Lança o tambor giratório, que volta como bumerangue | Quica **8 vezes** sem perder velocidade e depois volta para você, quicando na volta também | 55 por acerto | 0,9/s | 44 W | 14 |
| **Canhão de Fonte "500W Genérica"** | Fonte de PC barata com um cabo grosso, que estufa e chia antes de disparar. Tem um adesivo escrito 500W que claramente mente. | Carrega 0,8 s e solta uma bola de plasma lenta | Ao **primeiro quique se divide em 3** sub-bolas, cada uma com 2 quiques próprios e 50% do dano | 90, ou 45 por sub-bola | 0,7/s carregado | 52 W | 22 |
| **Martelo de Antena Parabólica "Pratão"** | Uma antena de TV via satélite usada como marreta, ainda com o logo de uma operadora falida. | Golpe corpo a corpo pesado em arco de 200 px | **Rebate qualquer projétil inimigo** com mais 200% de dano e mais 5 quiques. É a peça de defesa perfeita. | 120 | 1,1/s | 40 W | 10 |
| **Lançador de HD "Disco Rígido Voador"** | Um disco rígido aberto, com o prato exposto girando como uma serra. Faz aquele click da morte. | Serra circular que atravessa o ar | Quica **infinitamente por 6 segundos**, depois cai no chão e pode ser recolhido para recarga instantânea | 42 por acerto | 1,4/s | 46 W | 16 |
| **Garra de Máquina de Pelúcia "Garra Trapaceira"** | Garra de fliperama pendurada num cabo, que desce tremendo. Ela tem 60% de chance de "escorregar" e soltar, o que é a piada. | Agarra o inimigo em 500 px e puxa | Ao arremessar, o inimigo vira um **projétil que quica 4 vezes** e dá dano em quem encostar | 80 mais 60 por colisão | 2,2/s | 42 W | 12 |
| **Bazuca de Cano de Pia "Encanamento Livre"** | Um pedaço de cano de PVC com uma torneira soldada como mira e fita isolante segurando tudo. | Foguete lento de 320 px/s | Quica **5 vezes**, e ganha **mais 40% de dano por quique**, acumulando com o multiplicador global. Explode em 180 px no fim. | 70, até 260 no quinto quique | 0,8/s | 50 W | 20 |
| **Bobina de Ferro de Solda "Zap Zap"** | Um ferro de solda com uma bobina de Tesla improvisada na ponta, chiando e cheirando a queimado. | Raio elétrico instantâneo em cadeia | Não é projétil físico. Salta entre até **6 alvos** em 280 px, perdendo 15% de dano por salto. Cada salto conta como quique para efeitos de sinergia. | 65 no primeiro | 1,6/s | 48 W | 18 |
| **Braço de Guindaste "Ferro-Velho Express"** | Um braço hidráulico de guindaste de ferro-velho com um eletroímã redondo na ponta. | Ativa o ímã por 2 s | **Puxa todos os projéteis seus na tela** para o ponto mirado, redefinindo o contador de quiques deles para zero mas mantendo o multiplicador de dano. Sinergia absurda. | Nenhum direto | 5 s | 38 W | 8 |
| **Botijão de Gás "Churrasco Final"** | Um botijão P13 com a válvula aberta, que ele arremessa girando e assobiando. | Arremessa o botijão, que rola no chão | Quica **3 vezes** e então explode em 300 px causando 320 de dano. Se acertar um inimigo diretamente antes do primeiro quique, não explode e a piada é essa. | 320 na explosão | 0,5/s | 56 W | 28 |

## 4.6 Tabela de Peças: CHASSI E PERNAS

Define mobilidade, vida, e o "modo de existir" do robô. É a peça que mais muda como o jogo se joga.

| Nome | Efeito visual e cômico | Efeito de movimento | Interação com ricochete e combate | HP | Velocidade | Watts |
|---|---|---|---|---|---|---|
| **Molas de Sofá "Boing Boing"** | Duas molas enferrujadas de sofá velho, uma nitidamente mais curta, o que faz o robô mancar. Fazem "boing" audível. | Pulo duplo. Mais 20% de velocidade. | Ao aterrissar, cria uma onda de choque de 250 px causando 35 de dano. **A onda serve como superfície de quique** por 0,3 s. | 85 | 312 px/s | 22 W |
| **Esteiras de Trator de Brinquedo "Lagarta Lenta"** | Esteiras plásticas laranja, grandes demais para o corpo, deixando marca no chão. Rangem. | Menos 25% de velocidade. Imune a empurrão. | Mais 60% de HP. **Esmaga inimigos com menos de 40 de HP** por contato. Projéteis inimigos que acertam a esteira quicam de volta. | 240 | 195 px/s | 30 W |
| **Rodinhas de Carrinho de Mercado "Roda Bamba"** | Quatro rodinhas de supermercado, uma travada, girando torto. O robô desliza e claramente não quer ir para onde você quer. | Mais 45% de velocidade, mas com deslize. Curvas são derrapagens. | Deixa um **rastro de faíscas** que causa 14 de dano por segundo e dura 2 s. Projéteis que passam pelo rastro ganham 1 quique. | 70 | 377 px/s | 26 W |
| **Pernas de Manequim "Passo de Modelo"** | Pernas de manequim de vitrine, brancas e lisas, ridiculamente elegantes debaixo de toda aquela ferrugem. | **Três cargas de dash**, com recarga de 0,9 s cada. | Cada dash dá 0,25 s de invulnerabilidade e **reflete projéteis inimigos tocados** com 2 quiques a mais. | 95 | 268 px/s | 28 W |
| **Chassi de Aspirador Robô "Roomba Suicida"** | Disco achatado com uma carinha de pânico permanente e um adesivo de "propriedade da vovó". | **Anda sozinho** quando você solta o controle, vagando na direção do inimigo mais próximo. | Imune a dano de contato. Ao chegar abaixo de 20% de HP, **explode** causando 250 de dano em 350 px e se recompõe com 25% de HP. Uma vez por sala. | 110 | 245 px/s | 32 W |
| **Pernas de Antena "Pernaltas"** | Duas hastes finíssimas de antena de TV, altas demais, que balançam. O robô fica com 2,5 vezes a altura normal. | Velocidade normal, mas o robô é muito alto e fino. | **Os seus projéteis passam por cima de obstáculos baixos.** Hitbox 40% mais alta, ou seja, você é mais fácil de acertar. Você enxerga 20% mais longe. | 80 | 260 px/s | 24 W |
| **Hovercraft de Secador "Flutuante Barulhento"** | Três secadores de cabelo virados para baixo, soprando. Faz um barulho insuportável e levanta poeira. | Flutua. Ignora poças de ácido, esteiras e todo terreno perigoso. | É **empurrado por qualquer knockback**, inclusive o próprio coice das armas, o que é usável como mobilidade. Menos 15% de HP. | 88 | 290 px/s | 34 W |
| **Chassi de Cofre "Fofinho Blindado"** | Um cofre de banco pequeno com a porta amassada e pernas curtinhas de metal. Anda com dificuldade visível. | Menos 35% de velocidade. Não pode dar dash. | **Bloqueia frontalmente 70% do dano.** Projéteis inimigos que acertam a frente quicam de volta com o dobro do dano. Mais 120% de HP. | 320 | 169 px/s | 36 W |
| **Pernas de Cadeira Gamer "RGB Extremo"** | Uma base de cadeira gamer de cinco pés com rodinhas, iluminada com LED colorido que pulsa. Gira sem parar. | Rotaciona continuamente. Mais 10% de velocidade. | A luz RGB dá **mais 12% de dano a cada cor do ciclo**, alternando a cada 2 s entre vermelho (dano), verde (cadência) e azul (velocidade de projétil). Piada de gamer aplicada mecanicamente. | 100 | 286 px/s | 29 W |

## 4.7 Sistema de Fusão e Evolução

A fusão é o motor de progressão dentro da run e é o momento mais espetacular do jogo. Existem três mecanismos.

### 4.7.1 Fusão de Duplicata (automática)

Pegar a mesma peça duas vezes a promove um nível. É a fusão preguiçosa, mas garante que nenhum drop repetido é lixo.

| Nível | Multiplicador de stats | Mudança visual |
|---|---|---|
| I | 1,00 | Base |
| II | 1,40 | Mais uma peça de sucata soldada e um pouco de fumaça |
| III | 1,90 | Fica maior, ganha um LED piscando e um som mais grave |
| IV, máximo | 2,60 | Contorno dourado animado, mais 2 quiques, fumaça constante |

### 4.7.2 Fusão de Receita (a estrela do sistema)

Combinações específicas de peça mais peça, ou peça mais módulo, geram uma peça única que não existe na tabela de drops. A receita é revelada quando o jogador tem os dois componentes, com um ícone piscando na bancada.

**Módulos de sucata** são consumíveis encontrados na run que servem de ingrediente: Bateria de Carro, Ímã de Alto-Falante, Placa de Vídeo Queimada, Bobina de Cobre, Cristal de Quartzo de Relógio, Fita Cassete, Lente de Projetor, Óleo de Motor.

| Receita | Resultado | Efeito |
|---|---|---|
| **Torradeira "Cuspe-Torrada" + Bateria de Carro** | **TORRADA TESLA** | As torradas ficam eletrificadas. **Cada quique dispara um arco em cadeia** para 3 alvos em 250 px causando 45 de dano. Dispara 5 torradas em vez de 3. O robô ganha um cabo de bateria pendurado que arrasta faíscas no chão. |
| **Lançador de HD + Pistola de Cola Quente** | **SERRA MELADA** | O disco deixa um rastro de cola contínuo enquanto voa. Inimigos presos na cola sofrem 25 de dano por segundo e o disco **quica neles como se fossem parede**. |
| **Mangueira de Aspirador + Ventilador de Teto** | **CICLONE DOMÉSTICO** | Cria um tornado persistente de 300 px que dura 8 segundos, puxa inimigos e **captura todos os projéteis, seus e inimigos, fazendo eles orbitarem e acumularem quiques**. Ao acabar, cospe tudo para fora com multiplicador 4. |
| **Micro-ondas + Canhão de Fonte 500W** | **FORNO DE FUSÃO** | Vira um feixe contínuo de 900 px que atravessa tudo, causando 190 de dano por segundo. Gera calor absurdo, 45 por segundo. A cabeça fica vermelha incandescente e o vidro racha. |
| **Roomba Suicida + Molas de Sofá** | **ROOMBA PULA-PULA** | O aspirador quica pela arena como uma bola de pinball quando você segura o dash, causando 90 de dano por colisão. **Você mesmo vira um projétil com contador de quiques.** |
| **Tambor de Máquina de Lavar + Lançador de HD** | **CENTRÍFUGA DE SERRAS** | O tambor lançado libera 4 discos serrilhados a cada quique. Cada disco tem 3 quiques próprios. |
| **Desentupidor + Bobina de Ferro de Solda** | **VENTOSA CHOCANTE** | As ventosas grudadas viram nós de uma rede elétrica. **Arcos permanentes ligam todas as ventosas entre si**, causando 60 de dano por segundo a quem cruzar as linhas. Com 6 ventosas, a arena vira uma teia. |
| **Bebê Chorão + Câmera de Segurança** | **VIGILÂNCIA MATERNA** | O grito marca todos os inimigos atingidos. Alvos marcados **atraem projéteis ricocheteados** e recebem mais 50% de dano. O sprite ganha três olhos extras. |
| **Bazuca de Cano + Botijão de Gás** | **ENCANAMENTO EXPLOSIVO** | O foguete deixa um rastro de gás inflamável. Qualquer dano de fogo posterior acende a linha inteira, causando 400 de dano em cadeia. |
| **Rodinhas de Carrinho + Óleo de Motor** | **DERRAPAGEM PERPÉTUA** | O rastro vira uma poça de óleo permanente. **Seus projéteis quicam na poça em vez de atravessá-la**, transformando a arena numa mesa de sinuca. Inimigos escorregam sem controle. |
| **Monitor CRT + Fita Cassete** | **NOSTALGIA MORTAL** | O raio catódico grava os últimos 3 segundos de combate e **rebobina**, repetindo todo o dano que você causou nesse período contra os inimigos vivos. |
| **Controle de Videogame + Cristal de Quartzo** | **CÓDIGO KONAMI** | A cada 30 disparos, o robô executa "cima, cima, baixo, baixo" na tela e ganha 10 segundos de cadência dobrada e projéteis infinitos sem calor. |
| **Martelo de Antena + Ímã de Alto-Falante** | **PARABÓLICA MAGNÉTICA** | O golpe puxa todos os projéteis da tela para o arco do martelo antes de rebatê-los todos de uma vez, com mais 300% de dano. |
| **Garra de Pelúcia + Braço de Guindaste** | **A GARRA HONESTA** | Nunca escorrega. Agarra até 3 inimigos ao mesmo tempo e os usa como projéteis simultâneos, com 6 quiques cada. |
| **Pernas de Antena + Lente de Projetor** | **TORRE DE VIGIA** | O robô fica com 4 metros de altura. Todos os seus projéteis **ignoram obstáculos** e o alcance de mira dobra. Você vira um alvo gigante. |

**Meta de conteúdo:** 40 receitas na 1.0, sendo 15 no Acesso Antecipado. Cada receita é uma peça de arte única, então o número é limitado pelo orçamento de animação, não por design.

### 4.7.3 Enxerto de Sucata (modificadores)

Módulos que não foram usados em receitas podem ser enxertados diretamente numa peça, dando um modificador simples. Cada peça aceita até 2 enxertos, ou 4 com a CPU Cyrix Bode.

| Módulo | Enxerto |
|---|---|
| Bateria de Carro | Mais 22% de dano, mais 15% de calor |
| Ímã de Alto-Falante | Mais 1 quique, projéteis buscam levemente após quicar |
| Placa de Vídeo Queimada | Mais 30% de velocidade de projétil, mais 20% de calor |
| Bobina de Cobre | Menos 25% de calor gerado |
| Cristal de Quartzo | Mais 18% de cadência |
| Fita Cassete | Todo 8º disparo é duplicado |
| Lente de Projetor | Mais 35% de alcance e mais 20% de tamanho do projétil |
| Óleo de Motor | Menos 15% de Watts consumidos |

---
# 5. INIMIGOS, CHEFES E CENÁRIOS

## 5.1 Filosofia de Design de Inimigos

Inimigos existem para três funções, e todo inimigo precisa declarar qual é a sua:

1. **Preencher espaço.** Dar volume, morrer bonito, alimentar o snowball.
2. **Forçar movimento.** Punir o jogador que fica parado no canto atirando.
3. **Testar a build.** Ter uma resistência ou um comportamento que algumas builds resolvem e outras não.

**Regra de superfície.** Como inimigos são superfícies de quique, o tamanho do corpo é uma variável de design deliberada. Inimigos grandes e lentos existem em parte para o jogador quicar neles.

## 5.2 Catálogo de Inimigos Comuns

| Nome | Arquétipo | HP (setor 1) | Velocidade | Dano | Comportamento | Restituição |
|---|---|---|---|---|---|---|
| **Parafuseta** | Preenchimento | 12 | 210 px/s | 6 contato | Enxame. Corre reto na direção do jogador. Um parafuso com dois olhinhos e perninhas. Morre em uma bala e explode em confete de arruelas. | 0,85 |
| **Rato Morto** | Forçar movimento | 25 | 290 px/s | 9 contato | Mouse de bola dos anos 90, arrastando o cabo que chicoteia. Corre em ziguezague com amplitude de 80 px, o que atrapalha a mira direta e recompensa ricochete. | 0,85 |
| **QWERTYpede** | Teste de build | 90 | 140 px/s | 12 por tecla | Um teclado que virou centopeia, com as teclas como pernas. Cospe teclas individuais em rajada de 5. Precisa ser atingido 8 vezes para quebrar em segmentos, e cada segmento vira uma Parafuseta. | 0,90 |
| **Jato Preto** | Forçar movimento | 60 | 100 px/s | 8/s poça | Cartucho de impressora vazando. Deixa poças de tinta que cegam parcialmente e lentificam. Foge do jogador. | 0,80 |
| **Pop-Up Vivo** | Teste de build | 40 | 180 px/s | 10 contato | Uma janela de propaganda dos anos 2000, com o botão de fechar fugindo do cursor. **Ao morrer se divide em 2 cópias com metade do HP**, até 3 gerações. Diz "PARABÉNS VOCÊ GANHOU" ao morrer. | 1,00 |
| **Cadeado Chorão** | Teste de build | 150 | 120 px/s | 0 direto | Ransomware. **Encripta uma das suas peças por 8 segundos**, desativando ela. Chora enquanto faz isso. Matá-lo antes libera na hora. Prioridade máxima de ameaça. | 0,85 |
| **Olhudo** | Forçar movimento | 55 | 0, fixo | 22 por laser | Webcam presa no teto ou parede. Mira com um ponto vermelho por 0,8 s e dispara laser reto. Não se move, então força o jogador a se cobrir. | 1,20 |
| **Bipador** | Preenchimento agressivo | 45 | 340 px/s | 60 na explosão | Um nobreak que corre gritando "BIP BIP BIP" cada vez mais rápido e explode em 200 px. Telegrafia de 1 s com inchaço visível. | 0,70 |
| **Zé Ventoinha** | Teste de build | 80 | 160 px/s | 5/s vento | Cooler de PC voando. **Empurra os seus projéteis para longe** num cone de 250 px. Anula builds de projétil lento se ignorado. | 0,95 |
| **Cabo Cobra** | Forçar movimento | 70 | 200 px/s | 14 chicote | Um emaranhado de cabos HDMI que rasteja. Chicoteia em arco de 180 px. Se dois se encontram, se enroscam e viram um Cabo Cobra grande. | 0,85 |
| **Fantasma de Disquete** | Teste de build | 35 | 150 px/s | 11 contato | Disquete flutuante translúcido. **Imune a projéteis com zero quiques.** Só pode ser morto por ricochete. É o inimigo que ensina o pilar 3. | 1,00 |
| **Vovó Geladeira** | Preenchimento tanque | 260 | 90 px/s | 20 contato | Uma geladeira pequena e gorda que anda balançando. Lenta, muito HP, boa superfície de quique. Ao morrer, derrama comida vencida que causa 6/s. | 1,15 |

**Escalonamento entre setores.** O HP multiplica por 2,05 a cada setor. O dano multiplica por 1,55. A velocidade multiplica por 1,08, com teto em 420 px/s. Estes três números são as alavancas primárias de balanceamento e ficam num único arquivo de configuração.

## 5.3 Inimigos de Elite

Aparecem na sala 4 dos setores 1 e 3, e aleatoriamente com 8% de chance em qualquer sala a partir do setor 3. Têm 6 vezes o HP de um comum do mesmo setor, uma aura visual roxa, e um modificador.

| Elite | Descrição | Modificador |
|---|---|---|
| **Gabinete Gamer RGB** | Um gabinete de PC transparente com fitas de LED, ventoinhas demais e um sticker de "overclockado". Anda com pose de valentão. | Ganha 15% de dano por cada ventoinha ainda viva. São 4 ventoinhas destrutíveis separadamente. |
| **Impressora 3D "Fabricadora"** | Uma impressora 3D que cospe filamento quente e monta inimigos na sua frente, camada por camada. | Gera um inimigo comum a cada 3 s. Se não for morta, a sala nunca termina. |
| **Nobreak Barrigudo** | Um nobreak enorme e obeso, com fios saindo como pelos. Respira pesado. | Tem um escudo de energia com restituição 1,6. Projéteis que quicam no escudo voltam contra você com dano dobrado. |
| **Scanner Vira-Lata** | Um scanner de mesa que corre de quatro como um cachorro, com a luz verde varrendo. | Ao ser atingido, a luz de varredura passa e **copia a sua peça de braço direito** por 10 s. |

## 5.4 Chefe do Setor 2: SUGÃO 3000

**Conceito visual.** Um aspirador de pó vertical de 1985, cor bege e laranja desbotado, com 7 metros de altura. O bocal de sucção foi substituído por uma **boca de monstro** com dentes de plástico amarelados e uma língua feita de escova rotativa. O saco de pó é uma barriga imensa que **incha e murcha respirando**, com veias de poeira desenhadas. Dois olhos ficam nos mostradores de potência, e os ponteiros são as pupilas. A mangueira é um braço serpenteante independente com vida própria e uma expressão sonsa.

**Estatísticas gerais.** HP total 13.500, dividido em 3 fases. Arena de 2400 por 1350 com 3 pilares de pneus fixos, cada um com restituição 1,35. Duração-alvo de 95 segundos.

### Fase 1: "A Sucção" (6.000 HP)

| Ataque | Telegrafia | Efeito | Cooldown |
|---|---|---|---|
| **Sugadão** | A barriga murcha e ele abre a boca inteira por 1,2 s | Cone de 120 graus e 900 px puxa o jogador a 400 px/s. **Puxa também os seus projéteis.** Segurar dash contra a sucção é a resposta. | 7 s |
| **Cusparada de Bola de Pelo** | Ele engasga, com o pescoço inchando visivelmente | Cospe 5 bolas de pelo que **quicam 4 vezes** pela arena a 260 px/s, causando 30 de dano cada | 5 s |
| **Passeio Doméstico** | O cabo de energia estica | Ele passa pela arena da esquerda para a direita a 300 px/s, aspirando tudo no caminho | 12 s |
| **Chicote de Mangueira** | A mangueira se ergue como uma cobra e sibila | Golpe em arco de 500 px causando 45 de dano e empurrando | 4 s |

**Ponto fraco.** O **filtro HEPA nas costas**, um retângulo verde-limão sujo. Recebe 2,5 vezes de dano. Fica exposto por 3 segundos depois de todo Sugadão, porque ele fica ofegante. Isso ensina o jogador a rodear o chefe.

### Fase 2: "A Barriga Estufada" (4.500 HP)

Gatilho aos 55% de HP. Ele suga tudo de uma vez, a barriga incha até o dobro do tamanho e fica translúcida, mostrando o lixo lá dentro. A animação de transição tem 40 quadros e é o momento de clipe do chefe.

| Ataque | Telegrafia | Efeito |
|---|---|---|
| **Explosão de Pó** | A barriga fica vermelha e treme por 1,5 s | Nuvem de poeira em toda a arena por 4 s. Reduz a visibilidade a 400 px. Causa 8/s se você ficar parado. |
| **Mangueira Solta** | A mangueira se desprende com um "pop" | A mangueira vira um **inimigo independente** com 900 de HP, rastejando e chicoteando. Enquanto viva, o chefe tem menos 30% de dano. |
| **Chuva de Sucata** | Ele aponta a boca para cima | 12 objetos caem do teto em posições marcadas com sombras. Cada um causa 50 e **quica 2 vezes** ao bater no chão. |
| **Aspirar Inimigos** | Zumbido agudo | Ele suga inimigos comuns da arena e os cospe como projéteis de 70 de dano. |

**Ponto fraco.** A barriga inchada. Recebe 3 vezes de dano, mas **explode com 1.200 de dano acumulado**, causando 200 de dano em área de 600 px. Punir demais é perigoso.

### Fase 3: "Dentro do Saco" (3.000 HP)

Gatilho aos 22% de HP. Ele **engole o jogador** numa animação de 25 quadros com a câmera indo para dentro da boca.

- A tela vira o interior do saco de pó: fundo marrom, iluminação de lanterna, poeira flutuando.
- Arena circular de 800 px de raio, **inteiramente feita de superfícies de quique com restituição 1,4**. É a sala mais favorável a ricochete do jogo inteiro, de propósito, como recompensa.
- Existem 3 **Bolotas de Cabelo** com 1.000 de HP cada, pulsando. O jogador tem 18 segundos.
- Se falhar, ele é cuspido de volta com 40% de HP perdido e a fase reinicia.
- Se acertar, o SUGÃO 3000 **explode de dentro para fora** numa nuvem de 60 quadros, com pó cobrindo a tela inteira, e chove sucata por 4 segundos.

**Recompensa.** Uma peça rara garantida, 200 de Sucata, e um módulo aleatório.

## 5.5 Chefe do Setor 4: FORMULÁRIO 27-B

**Conceito visual.** Uma impressora matricial de escritório de 1991, cor bege-encardido, do tamanho de um carro, montada sobre um trilho horizontal que atravessa a arena. O cabeçote de impressão é uma **cabeça com olhos**, deslizando de um lado para o outro no trilho e fazendo aquele ruído de serra. Do alimentador sai um **formulário contínuo infinito** de papel serrilhado que se enrola pela arena como uma cobra de papel. Ela tem uma expressão de burocrata exausto, e uma placa escrita "FORA DE SERVIÇO" pendurada que ela mesma ignora.

**Estatísticas gerais.** HP total 16.000 em 3 fases. Arena de 2400 por 1350, aberta no começo. Duração-alvo de 110 segundos.

### Fase 1: "Expediente Normal" (5.500 HP)

| Ataque | Telegrafia | Efeito |
|---|---|---|
| **Cabeçote Correndo** | Aquele som de calibragem, "vrrr-vrrr" | O cabeçote percorre o trilho a 500 px/s. Dano de contato de 60. O trilho muda de altura a cada passagem. |
| **Formulário Contínuo** | O papel começa a sair com um chiado | Uma esteira de papel serrilhado de 300 px de largura desce pela arena a 180 px/s, empurrando o jogador. Não causa dano, mas atrapalha o posicionamento. |
| **Cusparada de Fita de Tinta** | Ela treme e o carretel gira | Lança 8 tiras de fita de tinta preta que **quicam 3 vezes** e deixam manchas que reduzem a velocidade em 40% |
| **Grampeamento** | Um "clac" seco | Dispara 4 grampos gigantes que prendem o jogador no chão por 1 s se acertarem |

**Ponto fraco.** O **carretel de fita** na lateral. Recebe 2 vezes de dano, mas gira para o outro lado a cada 8 segundos, alternando qual lateral está exposta.

### Fase 2: "Ela Engasga" (6.000 HP)

Gatilho aos 65%. O papel amassa dentro dela. A impressora inteira treme violentamente por 2 segundos, o painel pisca "PC LOAD LETTER", e a tampa superior **se abre expondo o cabeçote e as engrenagens**.

- **Janela de dano de 6 segundos** onde ela recebe 3 vezes de dano e não ataca. Ela ofega.
- Depois da janela, ela fecha com raiva e entra em modo agressivo por 12 segundos, com todos os cooldowns pela metade.
- Esse ciclo se repete. É um chefe de ritmo: aguentar, punir, aguentar.

| Ataque novo | Efeito |
|---|---|
| **Formulário Enfurecido** | O papel serrilhado agora tem dentes desenhados e persegue o jogador ativamente, causando 35 de dano |
| **Impressão de Multa** | Ela imprime uma folha que voa até o jogador. Se acertar, ele fica com menos 25% de dano por 10 s, "multado" |
| **Carrossel de Cabeçote** | O cabeçote sai do trilho e voa livre pela arena por 8 s |

### Fase 3: "PAPER JAM RAGE" (4.500 HP)

Gatilho aos 25%. Ela para de imprimir e começa a **encher a arena de papel amassado**.

- A cada 4 segundos, uma bola de papel amassado de 200 px cai e vira um **obstáculo permanente com restituição 1,5**.
- Ao fim da fase, a arena tem 12 a 18 bolas de papel. **O espaço vai fechando, e o ricochete fica devastador.** Esta fase é uma carta de amor ao pilar 3: quanto mais desesperador o espaço fica, mais forte o jogador fica.
- Ela imprime **clones em preto e branco** de inimigos que o jogador já enfrentou. Eles são achatados, bidimensionais, e se movem em 6 quadros por segundo, como animação barata.
- Ataque final, "Relatório Anual": ela cospe um formulário de 3.000 páginas que cobre 80% da arena em faixas, deixando corredores estreitos. Duração de 6 segundos.

**Morte.** Ela para. Silêncio total por 1,5 segundo. O painel pisca. Ela imprime uma última folha, que voa em câmera lenta até a tela e mostra: **"ERRO. PAPEL ATOLADO. CONTATE O ADMINISTRADOR."** E então explode, cobrindo a tela de papel picado.

**Recompensa.** Uma peça lendária garantida, 400 de Sucata, e desbloqueio da CPU Y2K-Bug.

## 5.6 Outros Chefes

**Setor 3: FROSTBYTE 500, a Geladeira Mãe.** Uma geladeira duplex com ímãs de geladeira que são fotos dos inimigos que ela já matou. Abre as duas portas como braços e cospe comida vencida. A porta do freezer congela a arena, criando piso escorregadio onde o jogador desliza e os projéteis ganham mais 2 quiques. Fase final: ela abre a porta e revela que está vazia por dentro, exceto por um único pote de maionese que é o verdadeiro chefe.

**Setor 5: O ROTEADOR ETERNO.** Chefe final. Um roteador Wi-Fi doméstico do tamanho de um prédio, com quatro antenas que são tentáculos de cabo Ethernet, e as luzinhas de status piscando num padrão que claramente significa alguma coisa terrível. Fala em pacotes de dados. Ataques incluem **"Sem Conexão"**, que desativa aleatoriamente uma das suas peças por 5 segundos, e **"Ping de 999 ms"**, que faz os seus inputs terem meio segundo de atraso, o que é hostil de um jeito delicioso. Fase final acontece dentro do sinal de Wi-Fi, num espaço abstrato de ondas concêntricas que funcionam como superfícies de quique móveis.

## 5.7 Cenários e Biomas

| Setor | Bioma | Paleta dominante | Obstáculos característicos | Hazard |
|---|---|---|---|---|
| 1 | **Ferro-Velho do Zé** | Ferrugem seca e céu alaranjado de fim de tarde | Pilhas de pneus, carcaças de Fusca, prensa hidráulica ao fundo | Nenhum. Setor de ensino. |
| 2 | **Lan House CyberBaiacu** | Roxo, neon, monitores de tubo acesos, carpete manchado | Mesas, cadeiras giratórias, torres de CPU | Carpete pegajoso em manchas, menos 30% de velocidade |
| 3 | **Assistência Técnica do Seu Nildo** | Bege 1998, prateleiras infinitas, luz fluorescente piscando | Prateleiras de peças, esteiras transportadoras, bancadas | Ferro de solda solto no chão, 25 de dano de contato |
| 4 | **Esgoto de Lixo Eletrônico** | Verde tóxico e marrom, névoa baixa | Canos verticais, plataformas de sucata, cachoeiras de lixo | Poças de ácido, 8/s. Nível de água que sobe e desce. |
| 5 | **Datacenter "A Nuvem"** | Ciano frio, azul escuro, luzes de rack, piso de vidro | Racks de servidor, piso de vidro quebrável, cabos suspensos | Descargas elétricas telegrafadas no piso a cada 6 s |

**Regra de composição visual.** Todo bioma tem 4 camadas de paralaxe: fundo distante a 0,15 de velocidade, fundo médio a 0,4, camada de jogo a 1,0, e primeiro plano a 1,25 com elementos que passam na frente do jogador para dar profundidade. O primeiro plano nunca cobre mais de 15% da tela nem esconde inimigos.

---

# 6. METAPROGRESSÃO: A GARAGEM DO FERRO-VELHO

## 6.1 Conceito do Espaço

A Garagem é um galpão de ferro-velho desenhado numa única tela lateral, sem carregamento, com o jogador andando entre as estações. É noite. Chove lá fora. Tem um rádio velho tocando. O robô do jogador fica no centro, sobre uma plataforma giratória, sendo montado.

O personagem que administra o lugar é o **Seu Nildo**, um velho de macacão sujo, óculos de fundo de garrafa e uma expressão de quem já viu de tudo. Ele não fala com voz. Ele fala em balões de fala desenhados à mão, com letra torta, e comenta a sua última run com desdém.

**Tempo-alvo na Garagem entre runs: 45 a 90 segundos.** Se o jogador está passando mais de 2 minutos, o menu está complexo demais e precisa ser simplificado.

## 6.2 Economia

Duas moedas, com propósitos separados.

**Sucata (dentro da run).** Cai de inimigos, é gasta nas salas de bancada. Zera ao fim da run. Ganho típico por run: 900 a 2.400.

**Cobre (permanente).** Convertido da Sucata ao fim da run, na taxa de **1 Cobre para cada 8 de Sucata**, mais bônus fixos:

| Fonte | Cobre |
|---|---|
| Conversão de Sucata | Sucata dividido por 8 |
| Cada setor completado | 40 |
| Primeira derrota de cada chefe | 250, uma única vez |
| Derrota repetida de chefe | 60 |
| Desafio diário completo | 150 |
| Morrer | Zero de penalidade. Nunca punir a derrota. |

**Ganho de Cobre por run:** cerca de 180 na primeira hora, chegando a 500 ou 600 quando o jogador domina o jogo. A árvore completa custa cerca de 42.000 de Cobre, o que dá aproximadamente 90 runs, ou 22 horas. Esse é o alvo de retenção principal.

## 6.3 As Estações da Garagem

### 6.3.1 A Bancada (upgrades passivos permanentes)

Uma árvore de upgrades desenhada como um quadro de ferramentas na parede, com as peças penduradas em pregos. Cinco ramos.

| Ramo | Foco | Nós | Custo do 1º nó | Custo do último |
|---|---|---|---|---|
| **Chapa** | Sobrevivência: HP, armadura, invulnerabilidade | 8 | 150 | 3.200 |
| **Pólvora** | Dano: dano base, crítico, dano de explosão | 8 | 200 | 4.000 |
| **Mola** | Mobilidade: velocidade, cargas de dash, recarga | 7 | 180 | 2.800 |
| **Cobre** | Térmico e energético: TDP, dissipação, purga | 7 | 220 | 3.400 |
| **Sorte** | Economia: chance de raridade, Sucata, opções na bancada | 8 | 250 | 4.200 |

**Exemplos de nós concretos:**

| Nó | Ramo | Efeito | Custo |
|---|---|---|---|
| Solda Reforçada | Chapa | Mais 15 de HP base | 150 |
| Para-Choque de Caminhão | Chapa | Mais 25% de HP e menos 8% de velocidade | 900 |
| Airbag Vencido | Chapa | Uma vez por run, sobrevive a um golpe fatal com 1 de HP | 3.200 |
| Pólvora Caseira | Pólvora | Mais 8% de dano | 200 |
| Mira do Seu Nildo | Pólvora | Mais 10% de chance de crítico | 1.100 |
| **Terceiro Quique Grátis** | Pólvora | Todo projétil começa com 1 quique já contado, ou seja, o primeiro acerto já vale 1,25 vezes | 4.000 |
| Graxa Boa | Mola | Menos 12% de recarga de dash | 180 |
| Perna Extra | Mola | Mais 1 carga de dash | 2.800 |
| Ventoinha de Verdade | Cobre | Mais 20% de dissipação | 220 |
| **Purga Dupla** | Cobre | A Purga de Calor tem 2 cargas | 3.400 |
| Ímã de Sucata | Sorte | Sucata é atraída de 400 px de distância | 250 |
| **Quarta Opção** | Sorte | A bancada oferece 4 peças em vez de 3 | 4.200 |

**Regra de balanceamento.** Nenhum nó pode dar mais de 25% de aumento em uma única estatística de combate. A soma de toda a árvore dá cerca de **2,4 vezes de poder** em relação a um jogador zerado. Isso é forte o bastante para o jogador sentir progresso, mas não tanto que a habilidade deixe de importar.

### 6.3.2 A Prateleira de CPUs

Uma estante com as 14 CPUs em bandejas antiestáticas, com etiquetas escritas à mão. As bloqueadas aparecem como silhuetas cinzas, com a condição de desbloqueio visível. Isso é importante: **condições visíveis geram objetivos**. Nada de desbloqueio surpresa.

Cada CPU também tem 3 níveis de aprimoramento, comprados com Cobre, que melhoram o TDP e a dissipação em 10% por nível. Custos de 600, 1.400 e 3.000.

### 6.3.3 O Rack de Coolers

O jogador escolhe **um cooler permanente** para levar na run, entre os desbloqueados. É uma escolha de loadout que muda o ritmo do jogo.

| Cooler | Efeito | Custo |
|---|---|---|
| Ventoinha de Fonte Velha | Mais 15% de dissipação | Inicial |
| Cooler de Torre com Heatpipe | Mais 40% de dissipação, menos 10% de velocidade | 1.200 |
| Water Cooler de Mangueira de Jardim | Mais 25% de dissipação e mais 20 de capacidade térmica. Tem 5% de chance por sala de vazar e causar 30 de dano. | 2.000 |
| Pasta Térmica Vencida | Menos 20% de dissipação, mas mais 30% de dano. Para quem quer viver perigosamente. | 1.800 |
| Nitrogênio Líquido do Sorvete | A Purga de Calor congela inimigos por 2 s | 3.500 |
| Só um Ventilador Apontado pra Lá | Mais 60% de dissipação. É literalmente um ventilador de mesa apoiado no robô com fita. | 4.500 |

### 6.3.4 O Baú de Cosméticos

Cosméticos são puramente visuais, comprados com Cobre ou desbloqueados por conquista. São o vetor de expressão do jogador e de conteúdo de vídeo.

- **Adesivos:** 40 adesivos aplicáveis em qualquer peça, incluindo "TURBO", "Baby on Board", um sol sorridente, e um código de barras.
- **Tintas:** 18 esquemas de pintura, incluindo Ferrugem Autêntica, Verde Militar, Rosa Chiclete, e Camuflagem de Escritório.
- **Chapéus:** 22 chapéus que encaixam em qualquer cabeça. Cone de trânsito, coador de café, abajur, capacete de obra, e uma peruca.
- **Rastros e efeitos:** 12 rastros de partícula, incluindo migalhas de pão e uma trilha de óleo.
- **Vozes de robô:** 8 conjuntos de grunhidos, incluindo modem de discagem e um saxofone triste.

### 6.3.5 O Mural de Contratos

Um quadro de cortiça com papéis pregados. Três desafios diários e um semanal, com semente compartilhada globalmente.

Exemplos: "Termine o setor 2 sem usar o braço direito", "Cause 5.000 de dano só com projéteis de quique 3 ou mais", "Sobreviva 90 segundos com a CPU Pirata sem tomar dano". Recompensa de 150 de Cobre por diário e 600 pelo semanal.

### 6.3.6 O Rádio

Um rádio de pilha em cima de uma caixa. O jogador troca a trilha sonora e ouve os comentários do locutor de uma rádio pirata de ferro-velho, que dá dicas de jogo disfarçadas de anúncio publicitário. É onde vivem as dicas de tutorial que ninguém quer ler numa tela de carregamento.

## 6.4 Curva de Progressão-Alvo

| Horas jogadas | Marco esperado |
|---|---|
| 0 a 1 | Primeira vitória contra o SUGÃO 3000. 3 CPUs desbloqueadas. |
| 1 a 4 | Primeiro run completo até o setor 4. Metade do ramo Chapa e Pólvora. |
| 4 a 10 | Primeira derrota do ROTEADOR ETERNO. Cerca de 8 CPUs. |
| 10 a 22 | Árvore de upgrades completa. Todas as CPUs. Todas as receitas de fusão descobertas. |
| 22 a 40 | Modo Ferro-Velho Infernal, com 12 níveis de dificuldade ascendente ao estilo de Ascensão. Caça a conquistas e ranking de contratos. |

**Modo Ferro-Velho Infernal.** Doze níveis, desbloqueados um a um ao vencer o anterior. Cada nível adiciona um modificador cumulativo, como "inimigos têm mais 20% de HP", "a bancada oferece 2 opções", "o calor dissipa 30% mais devagar", "chefes ganham uma quarta fase". O nível 12 é o teto de dificuldade e existe para a Persona B.

---

# 7. ESCOPO E VIABILIDADE TÉCNICA

## 7.1 Recomendação de Engine: Godot 4.7

**Recomendação: Godot 4.7.x, com GDScript para lógica de jogo e GDExtension em C++ apenas para o sistema de projéteis, se o profiling exigir.**

Justificativa contra Unity 2D:

| Critério | Godot 4.7 | Unity 6 |
|---|---|---|
| Custo e licenciamento | MIT, zero royalties, zero risco de mudança de termos | Histórico recente de mudança unilateral de termos. Risco de negócio real para um indie. |
| Tempo de iteração | Recarga instantânea de cena, editor leve, build de teste em segundos | Compilação de domínio lenta, o que num jogo de feel custa caro |
| Pipeline 2D | 2D nativo de verdade, com coordenadas em pixels e sem camada 3D por baixo | 2D é uma camada sobre o 3D. Funciona, mas com atrito. |
| Tamanho do executável | Cerca de 60 MB, ótimo para download por impulso na Steam | 150 MB ou mais |
| Steam Deck | Excelente. Exportação Linux nativa. | Bom, via Proton |
| Física customizada | Acesso direto ao PhysicsServer2D. Fácil ignorar a física da engine quando conveniente. | Possível, mas mais burocrático |
| Risco | Comunidade menor, menos plugins de terceiros | Ecossistema maior |

O ponto decisivo é o **tempo de iteração**. Um jogo cujo pilar número 1 é game feel será ajustado milhares de vezes. Godot ganha essa corrida.

**Configuração do projeto:**

```
Renderer:              Forward+ no desktop, Mobile no Steam Deck
Resolução base:        1920 x 1080
Stretch mode:          canvas_items
Stretch aspect:        expand
Physics tick:          120 Hz  (fixo, com interpolação de render)
Max FPS:               desbloqueado, com VSync adaptativo
Physics interpolation: ativada
Thread model:          Multi-threaded
```

**Por que 120 Hz de física.** O jogo tem projéteis rápidos, e a detecção de colisão precisa ser confiável a 900 px por segundo. A 60 Hz, um projétil rápido anda 15 px por passo, e pode atravessar uma parede fina. A 120 Hz, ele anda 7,5 px. Combinado com o cast de varredura descrito abaixo, isso elimina o tunelamento. O custo é aceitável porque a simulação de projéteis é barata.

## 7.2 A Arquitetura de Projéteis: O Problema Central de Performance

**Requisito de desempenho:** 800 projéteis ativos, 250 inimigos e 60 quadros por segundo estáveis num Steam Deck.

**Isso é impossível com `RigidBody2D`.** Um nó `RigidBody2D` por projétil, com 800 projéteis, colapsa a árvore de cena e o solver de física. Medições em projetos comparáveis mostram queda para 15 a 20 quadros por segundo bem antes disso.

**A solução: simulação manual com dados em vetores paralelos.**

Projéteis não são nós. São índices em um conjunto de arrays. Uma única classe gerencia todos eles.

```gdscript
class_name ProjectilePool
extends Node2D

const MAX_PROJECTILES := 2048

# Vetores paralelos. Um índice, muitos arrays. Cache-friendly e sem alocação.
var _pos     : PackedVector2Array
var _vel     : PackedVector2Array
var _alive   : PackedByteArray
var _bounces : PackedInt32Array
var _damage  : PackedFloat32Array
var _radius  : PackedFloat32Array
var _type_id : PackedInt32Array      # índice na tabela de ProjectileTypeData
var _ttl     : PackedFloat32Array
var _free    : PackedInt32Array      # pilha de índices livres

# Reutilizado a cada passo. Zero alocação por quadro.
var _query := PhysicsShapeQueryParameters2D.new()
var _shape := CircleShape2D.new()

func _physics_process(delta: float) -> void:
    var space := get_world_2d().direct_space_state
    for i in MAX_PROJECTILES:
        if _alive[i] == 0:
            continue
        _step_projectile(i, delta, space)
    _upload_to_multimesh()
```

**Detecção de colisão por varredura.** Em vez de mover e depois testar, o projétil faz um cast do ponto atual para o ponto futuro. Isso é o que impede tunelamento.

```gdscript
func _step_projectile(i: int, delta: float, space: PhysicsDirectSpaceState2D) -> void:
    var motion := _vel[i] * delta
    _shape.radius = _radius[i]
    _query.shape = _shape
    _query.transform = Transform2D(0.0, _pos[i])
    _query.motion = motion
    _query.collision_mask = MASK_WALLS | MASK_ENEMIES

    # cast_motion devolve [fração_segura, fração_de_contato]
    var result := space.cast_motion(_query)
    var safe := result[0]

    if safe >= 1.0:
        _pos[i] += motion
        return

    # Avança até o ponto de contato, depois resolve o quique.
    _pos[i] += motion * safe
    var contacts := space.get_rest_info(_query)
    if contacts.is_empty():
        _pos[i] += motion * (1.0 - safe)
        return

    var normal: Vector2 = contacts["normal"]
    _resolve_bounce(i, normal, contacts["collider_id"])
```

**A resolução do quique**, incluindo o jitter anti-loop e a multiplicação de dano:

```gdscript
const BOUNCE_MULT := [1.0, 1.25, 1.5625, 1.953125, 4.0]

func _resolve_bounce(i: int, normal: Vector2, collider_id: int) -> void:
    var type: ProjectileTypeData = TypeTable.get_type(_type_id[i])

    var target := instance_from_id(collider_id)
    if target is Damageable:
        var mult: float = BOUNCE_MULT[mini(_bounces[i], 4)]
        target.take_damage(_damage[i] * mult, _pos[i])
        CombatFeel.request_hitstop(40 if _bounces[i] < 3 else 110)

    _bounces[i] += 1
    if _bounces[i] > type.max_bounces:
        _kill(i)
        return

    # Reflexão, restituição e o jitter que impede loops perpendiculares eternos.
    _vel[i] = _vel[i].bounce(normal) * type.restitution
    _vel[i] = _vel[i].rotated(_rng.randf_range(-0.026, 0.026))  # +/- 1.5 graus

    if _vel[i].length() < 90.0:
        _kill(i)
        return

    VFX.spawn_bounce(_pos[i], normal, _bounces[i])
    Audio.play_bounce(_bounces[i])
```

**Renderização por MultiMesh.** Todos os projéteis do mesmo tipo desenham numa única chamada de desenho.

```gdscript
func _upload_to_multimesh() -> void:
    for type_id in _multimesh_by_type:
        var mm: MultiMesh = _multimesh_by_type[type_id]
        var count := 0
        for i in _indices_by_type[type_id]:
            if _alive[i] == 0:
                continue
            var scale := 1.0 + _bounces[i] * 0.11
            var xf := Transform2D(_vel[i].angle(), _pos[i]).scaled(Vector2(scale, scale))
            mm.set_instance_transform_2d(count, xf)
            mm.set_instance_color(count, BOUNCE_COLOR[mini(_bounces[i], 4)])
            count += 1
        mm.visible_instance_count = count
```

**Orçamento de desempenho medido, com alvo no Steam Deck:**

| Sistema | Orçamento por quadro a 60 fps |
|---|---|
| Simulação de projéteis, 800 ativos | 2,4 ms |
| Inteligência artificial de inimigos, 250 ativos | 1,8 ms |
| Física de inimigos e jogador | 1,5 ms |
| Renderização e chamadas de desenho | 6,0 ms |
| Partículas na GPU | 2,0 ms |
| Áudio | 0,8 ms |
| Interface | 0,7 ms |
| Folga | 1,4 ms |
| **Total** | **16,6 ms** |

**Otimizações obrigatórias, não negociáveis:**

1. **Pool de tudo.** Zero instanciação durante o combate. Projéteis, inimigos, números de dano e efeitos visuais nascem pré-alocados na carga da sala.
2. **Inimigos com IA em fatias.** A inteligência de cada inimigo roda a 20 Hz, não a 120. São 12 grupos, um por quadro. O movimento interpola entre as decisões.
3. **Números de dano em MultiMesh com fonte em atlas.** Nunca um nó `Label` por número.
4. **Partículas exclusivamente na GPU**, com `GPUParticles2D`. Nenhuma partícula em CPU.
5. **Quadtree para consultas de proximidade**, reconstruída uma vez por passo de física. Nunca `get_overlapping_bodies` em laço.
6. **Batching de dano.** Múltiplos acertos no mesmo inimigo no mesmo quadro somam antes de aplicar, disparando um único número e um único flash.

## 7.3 Estruturação de Dados Modular

O equivalente de Godot ao ScriptableObject do Unity é o **`Resource` customizado**, salvo em arquivos `.tres`. Ele é a escolha certa aqui, e não JSON, por quatro motivos: é tipado, é editável no inspetor do editor, referencia outros recursos e texturas diretamente, e serializa sem código de conversão.

**A regra arquitetural central: composição, não herança.** Uma peça não é uma subclasse. Uma peça é um contêiner de comportamentos. Isso é o que permite criar centenas de peças sem tocar no código base.

```gdscript
# res://data/parts/part_data.gd
class_name PartData
extends Resource

enum Slot { CPU, HEAD, ARM_LEFT, ARM_RIGHT, CHASSIS }
enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY }

@export var id: StringName                      # "arm_l_plunger"
@export var display_name_key: String            # chave de tradução
@export var slot: Slot
@export var rarity: Rarity

@export_group("Custo")
@export var watts: int = 25
@export var heat_per_shot: float = 2.0

@export_group("Disparo")
@export var fire_rate: float = 3.0              # tiros por segundo
@export var projectile: ProjectileTypeData      # outro Resource

@export_group("Visual")
@export var sprite_frames: SpriteFrames
@export var pivot_offset: Vector2
@export var muzzle_offset: Vector2
@export var silhouette_tag: StringName          # para o verificador de silhueta

@export_group("Comportamento")
## A lista que faz o sistema inteiro funcionar. Cada entrada é um Resource
## com um único método virtual. Uma peça nova é uma combinação nova de
## comportamentos existentes, sem uma linha de código novo.
@export var behaviors: Array[PartBehavior] = []

@export_group("Fusão")
@export var fusion_recipes: Array[FusionRecipe] = []
```

```gdscript
# res://data/behaviors/part_behavior.gd
class_name PartBehavior
extends Resource

## Chamado quando a peça dispara. Pode alterar o projétil antes de nascer.
func on_fire(_ctx: FireContext) -> void: pass
## Chamado quando um projétil desta peça quica.
func on_bounce(_ctx: BounceContext) -> void: pass
## Chamado quando um projétil desta peça acerta algo danificável.
func on_hit(_ctx: HitContext) -> void: pass
## Chamado a cada passo de física enquanto a peça está equipada.
func on_tick(_ctx: TickContext, _delta: float) -> void: pass
## Chamado ao equipar e ao desequipar.
func on_equip(_robot: Robot) -> void: pass
func on_unequip(_robot: Robot) -> void: pass
```

**Exemplos de comportamentos reutilizáveis.** Estes oito cobrem cerca de 70% de todas as peças do jogo:

```gdscript
class_name BhvSpread extends PartBehavior
@export var count: int = 3
@export var angle_deg: float = 40.0
func on_fire(ctx: FireContext) -> void:
    ctx.extra_shots = count - 1
    ctx.spread_radians = deg_to_rad(angle_deg)

class_name BhvSplitOnBounce extends PartBehavior
@export var split_count: int = 3
@export var damage_ratio: float = 0.5
@export var only_on_bounce_index: int = 1
func on_bounce(ctx: BounceContext) -> void:
    if ctx.bounce_index != only_on_bounce_index: return
    ctx.spawn_children(split_count, damage_ratio)

class_name BhvLeavePuddle extends PartBehavior
@export var puddle: PuddleData
func on_bounce(ctx: BounceContext) -> void:
    Field.spawn_puddle(puddle, ctx.position)

class_name BhvChainLightning extends PartBehavior
@export var jumps: int = 3
@export var falloff: float = 0.15
@export var range_px: float = 250.0
func on_hit(ctx: HitContext) -> void:
    Combat.chain(ctx.target, jumps, ctx.damage * (1.0 - falloff), range_px)
```

Com esse desenho, a **TORRADA TESLA** da seção 4.7 é literalmente o `PartData` da Torradeira com `BhvChainLightning` acrescentado ao array de comportamentos, `count` do spread mudado de 3 para 5, e um novo `SpriteFrames`. **Zero código novo.** Um designer cria isso no editor em dez minutos.

**Onde JSON entra, e só aí.** Uma planilha de balanceamento exportada como CSV alimenta um importador que sobrescreve os campos numéricos dos `.tres` na hora do build. Isso permite ao designer ajustar 300 números no Google Sheets sem abrir o editor, mantendo o recurso como fonte de verdade estrutural e a planilha como fonte de verdade numérica.

```
res://data/balance/parts_balance.csv   ->  BalanceImporter (EditorScript)  ->  *.tres
```

**Estrutura de pastas:**

```
res://
├── actors/
│   ├── robot/            Robot.tscn, RobotAssembler.gd, PartSocket.gd
│   ├── enemies/          uma cena por inimigo, herdando de EnemyBase.tscn
│   └── bosses/
├── combat/
│   ├── ProjectilePool.gd
│   ├── CombatFeel.gd     hitstop, trauma de câmera, tempo de jogo
│   └── DamageNumbers.gd
├── data/
│   ├── parts/            ~90 arquivos .tres
│   ├── cpus/             14 arquivos .tres
│   ├── behaviors/        ~35 scripts de comportamento
│   ├── projectiles/      ~50 ProjectileTypeData
│   ├── enemies/          ~22 EnemyData
│   ├── fusions/          ~40 FusionRecipe
│   └── balance/          CSVs e o importador
├── generation/           gerador de sala, validador de arena
├── meta/                 Garagem, salvamento, economia, contratos
├── ui/
├── vfx/
└── audio/
```

**Sistema de salvamento.** Um único arquivo JSON em `user://save.json`, com um número de versão e migradores explícitos. Nunca `ConfigFile` binário, porque é opaco para depurar e para o suporte a jogadores. O arquivo guarda apenas o estado da metaprogressão, já que runs não são salvas no meio.

**Determinismo e semente.** Toda a aleatoriedade da run passa por um único `RandomNumberGenerator` semeado, com fluxos separados por sistema, um para drops, um para geração de sala, um para variação de efeitos visuais. Isso permite runs com semente fixa para os contratos diários e reprodução exata de bugs a partir de um relatório.

## 7.4 Escopo de Conteúdo

| Item | Acesso Antecipado | Versão 1.0 |
|---|---|---|
| Peças jogáveis | 55 | 90 |
| CPUs | 8 | 14 |
| Receitas de fusão | 15 | 40 |
| Inimigos comuns | 8 | 12 |
| Elites | 2 | 4 |
| Chefes | 3 | 6 |
| Biomas | 3 | 5 |
| Nós de upgrade | 24 | 38 |
| Cosméticos | 30 | 92 |
| Níveis de dificuldade ascendente | 5 | 12 |

## 7.5 Cronograma

| Fase | Duração | Entregável |
|---|---|---|
| **Protótipo** | 2 meses | Um retângulo cinza atirando bolas que quicam. **A meta é única: o ricochete precisa ser divertido sem arte nenhuma.** Se não for, o projeto é cancelado aqui, e isso é barato. |
| **Vertical Slice** | 3 meses | Um setor completo com arte final, 12 peças, 1 chefe, o loop de bancada. É o material do trailer e do wishlist. |
| **Produção A** | 5 meses | Setores 1 a 3, 55 peças, 8 CPUs, a Garagem, o sistema de fusão |
| **Polimento pré-EA** | 2 meses | Balanceamento, otimização no Steam Deck, localização, conquistas |
| **Acesso Antecipado** | 8 meses | Três atualizações de conteúdo, cada uma com um bioma, um chefe e cerca de 12 peças, guiadas por dados de telemetria |
| **1.0** | — | Lançamento completo |

**Marcos de wishlist.** Meta de 25.000 wishlists no lançamento do Acesso Antecipado, o que exige que o trailer do vertical slice esteja pronto no mês 5 e que a conta de vídeo curto publique três vezes por semana a partir dali.

## 7.6 Riscos e Mitigações

| Risco | Probabilidade | Impacto | Mitigação |
|---|---|---|---|
| **Volume de animação quadro a quadro estoura o prazo** | Alta | Crítico | Deformação por shader em vez de quadros desenhados. Reaproveitamento de bibliotecas de quadros entre peças da mesma família. Corte planejado de 90 para 70 peças com o conteúdo restante indo para atualização gratuita. **Este é o risco número 1.** |
| **Performance com muitos projéteis** | Média | Crítico | Arquitetura da seção 7.2 desde o primeiro dia. Benchmark automatizado noturno com falha da integração contínua se cair de 60 fps. Nunca "otimizamos depois". |
| **Ricochete vira sopa ilegível no fim da run** | Média | Alto | Agregação de números de dano, limite de vozes de áudio, teto rígido de multiplicador, teto de 12 quiques. Teste de legibilidade obrigatório com jogadores no setor 5. |
| **O humor não traduz fora do Brasil** | Média | Médio | O humor é visual e situacional antes de ser textual. Nomes de peça são localizados com adaptação cultural, não tradução literal. Orçamento de localização criativa para inglês, espanhol, chinês simplificado, japonês e russo. |
| **Balanceamento de 90 peças é intratável manualmente** | Alta | Médio | Simulador headless que roda 10.000 runs por noite com builds aleatórias e reporta taxa de vitória por peça. Toda peça com taxa fora da faixa de 35 a 65% entra numa fila de revisão automática. |
| **Comparação desfavorável com BALL x PIT** | Média | Médio | Diferenciação por direção de arte autoral e por profundidade da modularidade. O marketing lidera com o robô, não com a bola. |

## 7.7 Métricas de Sucesso

**Telemetria obrigatória desde o vertical slice:**

- Duração média da run, por setor.
- Taxa de mortes por setor, por inimigo, por chefe.
- Taxa de escolha e taxa de vitória por peça, por CPU e por receita de fusão.
- Distribuição do multiplicador de quique no momento do dano. **Se a mediana ficar abaixo de 1,25, o pilar 3 falhou e o jogo precisa de intervenção de design.**
- Quadros por segundo no percentil 1, por sessão e por hardware.
- Taxa de retenção no dia 1, dia 7 e dia 30.

**Metas comerciais:**

| Métrica | Meta |
|---|---|
| Wishlists no lançamento do Acesso Antecipado | 25.000 |
| Vendas na primeira semana | 8.000 unidades |
| Avaliação na Steam | 88% ou mais de positivas |
| Tempo mediano de jogo | 9 horas |
| Retenção no dia 7 | 22% |
| Vendas no primeiro ano | 60.000 unidades |

---

## APÊNDICE A: Glossário de Produção

| Termo | Definição neste documento |
|---|---|
| **Quique** | Uma colisão de projétil que resulta em reflexão, incrementando o contador e o multiplicador de dano |
| **Snowball** | O crescimento exponencial de poder ao longo da run |
| **Hitstop** | Congelamento momentâneo da simulação no momento do impacto |
| **Trauma** | Valor acumulado de zero a um que dirige o tremor de câmera |
| **Barramento Serial** | A família de conectores do braço esquerdo, com armas de cadência |
| **Barramento Paralelo** | A família de conectores do braço direito, com armas de impacto |
| **Subvoltagem** | Estado penalizado por consumo de Watts acima do TDP da CPU |
| **Purga de Calor** | Habilidade ativa que descarrega calor causando dano em área |
| **Sucata** | Moeda gasta dentro da run |
| **Cobre** | Moeda permanente da metaprogressão |

## APÊNDICE B: Checklist de Aprovação de Peça Nova

Toda peça nova precisa passar por estes nove itens antes de entrar no jogo:

1. A silhueta é reconhecível em preto sólido a 25% do tamanho.
2. O objeto doméstico de origem é identificável sem legenda.
3. Tem olhos, ou uma razão explícita para não ter.
4. Tem um som próprio, distinto de qualquer peça existente.
5. O comportamento de ricochete está declarado e é diferente de pelo menos uma peça do mesmo slot.
6. Os valores de Watts e calor foram preenchidos e cabem numa build viável.
7. Participa de no mínimo uma receita de fusão, como ingrediente ou como resultado.
8. É explicável em uma frase engraçada.
9. Foi reutilizada de comportamentos existentes, ou o comportamento novo é reutilizável por pelo menos três outras peças futuras.

**Fim do documento. Versão 1.0.**
