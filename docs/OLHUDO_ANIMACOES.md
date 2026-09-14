# Olhudo — construção articulada

Mob da expansão de 11/09: webcam estacionária, com preparação de 0,8 s e laser
de mira travada. Construído em 13/09 seguindo [o método](METODO_CONSTRUCAO_MOBS.md).

Referência: primeira linha, quarta coluna de `assets/art/expansion_atlas_alpha.png`.
Preservados: cilindro azul enferrujado, aros da lente, olho único, LED vermelho,
suporte de mesa e cabo USB.

## Componentes próprios

Nove peças produzidas com a ferramenta integrada `image_gen`, em
`assets/art/olhudo_components.png`: carcaça com cavidade óptica, globo sem pupila,
pupila, base completa, dois elos com discos completos nas extremidades, pálpebra
superior, pálpebra inferior e cabo USB. A pintura original serve de referência;
não é usada como corpo deformável do novo rig.

O atlas gerado tem 1254 × 1254 e veio com quadriculado opaco. O construtor extrai
contornos estáticos em `assets/art/olhudo_contours.json`, mantendo o raster intacto
e excluindo o fundo pela geometria. Cada peça é um Polygon2D independente.
Não utilizar o atlas inteiro como sprite. [Prompt e procedência](OLHUDO_PROMPT.md).

Hierarquia: base → elo inferior → elo superior → carcaça → olho, pupila,
pálpebras, cabo e emissor. Os discos completos dos elos se sobrepõem nas juntas.
Dimensões de montagem constantes; só rotação e translação são animadas. O cabo
é uma peça rígida com oscilação leve na conexão; não simula flexão distribuída.

| Conexão | Coordenadas no atlas / rig |
|---|---|
| Base–elo inferior | base (400,610), elo (585,720), ponto comum no rig (50,100) |
| Elo inferior–superior | elo inferior (762,545), elo superior (1195,635) |
| Elo superior–carcaça | elo superior (920,635), montagem da carcaça (330,395) |
| Centro óptico | carcaça (157,253) |

O Olhudo não tem boca na referência. Sua abertura é a lente com duas pálpebras
metálicas próprias. As placas deslizam rigidamente e se sobrepõem no fechamento;
um shader limita a parte visível à abertura da lente. Olho e pupila são peças
distintas, com movimento do olhar. Nenhuma peça estica para simular articulação.

## Ciclos e poder

Três ciclos de 3,6 s: vigilância estacionária, golpe/recuo mecânico e mira/laser.

Revisão do ataque em 14/09: investida mecânica com preparação até 0,62 s,
retenção até 0,74 s e avanço da lente de aproximadamente 135 pixels do rig em 0,11 s.
A base permanece fixa. A extensão adicional abre os dois elos e coloca a junta da cabeça 95 pixels à frente da base, compensando a rotação da carcaça para manter o ângulo do golpe. Os dois elos lançam a carcaça à frente, o olho abre no
ataque e o cabo reage com atraso. O recuo tem contramovimento de mola e acomoda
o conjunto até 2,02 s. Não há escala animada nem deslocamento artificial da base.
Revisão ampliada em `scenes/olhudo_attack_review.tscn` e
`docs/visual/olhudo-ataque-preview.mp4`, com velocidade normal e câmera lenta a 25%.
Curvas interpoladas por tempo, sem quantização em poses. A vigilância substitui
caminhada porque esse mob é estacionário.

No poder, a montagem trava a mira em 0,6 s. A preparação vai de 0,6 a 1,4 s
(0,8 s), seguida da emissão e dissipação. Shader próprio com guia de mira,
carga óptica, núcleo luminoso, halo vermelho, filamentos e clarão com faíscas no
ponto terminal da demonstração. O emissor acompanha a pupila e a carcaça.
Distância e direção são propriedades `laser_reach` e `laser_angle`.
O clarão terminal desta prévia não executa colisão de gameplay.

## Entrega e reprodução

- Cena reutilizável: `scenes/olhudo_rigid.tscn`.
- Visualizador: `ver_animacoes_olhudo.bat`.
- Controles: Espaço pausa, S câmera lenta, R reinicia, C mostra construção.
- Vídeo: `docs/visual/olhudo-preview.mp4` (1280 × 720, 60 fps).
- Prancha: `docs/visual/olhudo-construcao.png`.

Construir: `Godot --headless --path . --script tools/build_olhudo.gd`; depois
`Godot --headless --path . --editor --import`. A cena monta os nove Polygon2D
a partir dos contornos ao iniciar. Exportar: `tools/export_olhudo.ps1`.

`tests/olhudo_motion.gd` verifica rigidez em 1299 poses, coincidência dos pivôs,
continuidade dos ciclos, preparação e fechamento das pálpebras.
`scenes/olhudo_showcase.tscn -- --verify-olhudo` compara capturas em pausa e após
retornar ao mesmo instante; verifica limpeza do laser ao trocar de ação.

Escopo: assets, rig reutilizável, VFX e demonstração. O desenho antigo no gameplay
não foi substituído nesta etapa; dano, alcance, obstáculos e lógica do Olhudo da
expansão permanecem nos arquivos de combate existentes.
