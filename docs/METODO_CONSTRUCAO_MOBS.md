# Método de construção e animação de mobs

Padrão de produção registrado em 13/09/2026 a partir das orientações do usuário.
Aplica-se a todo mob e boss novo e à revisão dos existentes. Este documento
define o método; não declara que todo o bestiário já foi convertido.

## 1. Referência e planejamento das peças

Inspecionar a imagem aprovada em `docs/visual/gallery.png` e/ou o atlas original
correspondente. Identificar o personagem correto antes de produzir variantes.
Preservar sua identidade, proporções, silhueta, materiais e características
marcantes. A referência orienta a construção, mas a ilustração inteira não é o
asset final que será esticado para simular movimento.

Planejar as peças necessárias para repouso, deslocamento, golpe e poder:
tronco, cabeça, segmentos dos membros, pés, cabos, olhos, boca e mecanismos
particulares. Definir hierarquia, pivôs, ordem de desenho e pontos de emissão.
Cada mob exige uma montagem adequada à sua anatomia; não copiar os recortes e
eixos de outro personagem indiscriminadamente.

## 2. Assets próprios e superfícies completas

Construir peças independentes para o personagem. Reaproveitar a pintura original
onde ela já contém uma peça completa; criar ou reconstruir as áreas que a pose
original esconde: encaixes, fundos, cavidades, bases dos membros e interiores.
Recortes planos que deixam buracos ao girar são material intermediário.

É permitido compartilhar um atlas e usar UVs fixas para peças completas. Não é
necessário criar um PNG por peça, mas cada peça deve possuir geometria,
transformação e conteúdo visual próprios. O atlas compartilhado não dispensa
a construção dos assets ausentes. Quando for necessária pintura raster nova,
produzir componentes a partir da referência e conferir transparência, contorno,
resolução, textura e coerência visual antes de integrá-los.

Manter a referência preservada. Guardar os componentes produzidos, seus dados de
montagem e os scripts de construção de forma reproduzível.

## 3. Articulações com encaixes

Posicionar o pivô no eixo real da junta e conservar barras, cotovelos e carcaças
inteiros. Uma linha de corte conveniente não determina o eixo de rotação.
Separar segmentos onde a construção do personagem permite articular.

Construir sobreposição entre as peças, com apoio interno ou soquete por trás da
borda visível. Dimensionar essa superfície para os dois extremos do movimento,
incluindo as rotações acumuladas dos pais. Os apoios não podem duplicar o
contorno externo nem reintroduzir partes removidas, como a boca antiga.

As peças rígidas usam rotação e translação interpoladas, com dimensões e UVs
constantes. Uma escala constante para apresentar o personagem na cena é
permitida. Animar a escala da imagem para substituir o movimento das juntas não
é permitido. Cabos e apêndices devem ter uma construção articulada apropriada.

## 4. Boca, olhos e aberturas

A boca precisa de cavidade com profundidade, arcada superior, mandíbula e
superfícies internas coerentes. Dentes, gengiva e língua acompanham suas peças.
A mandíbula abre em torno de um encaixe e deve fechar sem deixar uma fenda.
Remover a boca pintada antiga da montagem, reconstruir a região de apoio e
conferir oclusão em todo o ciclo. Não deslocar duas metades da imagem para abrir
um buraco e chamar isso de boca.

Construir movimento dos olhos: direção do olhar e piscadas compatíveis com o
desenho. Os olhos acompanham a peça em que estão montados.

Portas, tampas, obturadores e bocais de poder também precisam de componentes
próprios, com interior visível quando abertos. Na Prensa, a emissão deve sair do
orifício central aberto, acompanhando seu mecanismo.

## 5. Animação e VFX

Criar curvas contínuas baseadas no tempo para movimento, antecipação, golpe,
recuperação, carga, emissão e dissipação. Preservar continuidade nas transições
e no retorno ao início dos ciclos. Não usar arredondamento de tempo ou troca
de poucas poses para produzir aparência de stop motion. Exportar prévias a
60 fps; o rig deve continuar independente da taxa de quadros em execução.

O poder exige tratamento visual próprio, coerente com o material e a identidade
do mob. Usar os assets, shaders e partículas necessários para dar forma, volume,
luz, movimento e dissipação ao efeito. Formas provisórias ou traços sem acabamento
não são a entrega final. Avaliar VFX isoladamente e junto do personagem.

Prender o emissor à transformação da peça articulada. Sincronizar a emissão com
a abertura física. O efeito deve respeitar pausa, câmera lenta, retorno ao mesmo
instante e troca de ação, sem partículas ou brilho indevidamente persistentes.

## 6. Validação e entrega

1. Comparar o personagem montado com a referência aprovada.
2. Inspecionar ciclos completos e os dois extremos de cada junta, em tamanho de
   jogo e ampliados, sobre fundo que revele transparência e cortes.
3. Conferir membros conectados, ausência de fragmentos soltos e bordas duplicadas,
   profundidade da boca, fechamento, olhos e encaixe do emissor.
4. Executar verificações pertinentes de rigidez, continuidade e cobertura das
   conexões. Testar também a cena reutilizável; a prévia deve representar esse rig.
5. Verificar VFX com abertura, pausa, repetição e troca de ação. Testes numéricos
   não substituem a avaliação visual.
6. Entregar a cena reutilizável, assets e dados próprios, construção reproduzível,
   prévias atualizadas e documentação específica do personagem.

O registro de cada mob deve identificar referência, peças novas e reaproveitadas,
pivôs/hierarquia, apoios ocultos, boca/olhos, emissor/VFX, comandos de construção,
validações realizadas e limitações pendentes. Não declarar integração no gameplay
quando apenas a cena de demonstração foi atualizada.

## Implementações de referência e falhas conhecidas

- [Parafuseta](PARAFUSETA_ANIMACOES.md): recortes atravessavam barras e cotovelos;
  foram reposicionados junto dos pivôs e receberam apoios internos.
- [Rato Morto](RATO_MORTO_ANIMACOES.md): apoios nas raízes das patas e do cabo;
  boca com componentes próprios.
- `tools/rig_joint_supports.gd`: exemplo de apoios obtidos da pintura original,
  com margem interna para evitar contornos duplicados. Não substitui criar uma
  peça nova quando a referência não contém a superfície necessária.
- `tools/build_creature_mouth_mounts.gd`: remove a boca antiga também dos apoios.
- `tests/creature_joint_contacts.gd`: verifica cobertura de conexões dos dois rigs;
  novos personagens exigem pontos de verificação próprios.
- `scenes/creature_joints_review.tscn` e `docs/visual/juntas-preview.mp4`: revisão
  ampliada de movimento, golpe e poder.


## Integração no combate

O desenho imediato de um puppet serve para revisão, não para o combate: medido headless, custava
5,2 ms por Parafuseta. O caminho de integração é `art/creature_rig_view.gd`. Ele monta, uma vez
por espécie, uma malha por trecho consecutivo de peças da mesma junta, e cada quadro só atualiza
transformações. Uma onda de 48 criaturas e 4 Olhudos custou cerca de 3 ms de pose e desenho num
build de editor. Cortes que o puppet faz por polígono viram shader com a mesma geometria.

Para ligar um personagem novo ao combate:

1. Expor no puppet `group_transforms(p)`, `eye_frame(p)`, `EYE_PUPIL`, `EYE_RADIUS` e
   `MOUTH_SPECIES`, e usar essas funções no próprio `frames()` e `draw_details()`.
2. Registrar a espécie em `CreatureRigView.SPECIES_BY_VISUAL` e a célula de referência.
3. Mapear o estado do combate para as ações do rig, sem alterar regra de dano.
4. Acrescentar casos em `tests/rig_integration.gd` e capturas com `tools/capture_rigs.tscn`.

Personagens com cena de nós própria, como o Olhudo, são instanciados uma vez por inimigo do pool.

Os arquivos antigos permanecem como histórico. Orientações de deformação global,
recorte simples sem reconstrução ou animação a 12 poses/s não são o padrão atual.
