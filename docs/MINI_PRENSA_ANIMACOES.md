# Mini-Prensa 500 — asset articulado rígido

Esta versão substitui a malha deformável anterior.

Cena reutilizável: scenes/mini_prensa_rigid.tscn. Há 13 peças Polygon2D independentes, com contornos/UVs estáticos: cabeça, mandíbula inferior, placa traseira, dois pés, dois tornozelos, duas hastes, duas luvas tampa de pressão e tampa circular do queimador. As nove imagens-fonte são reaproveitadas para componentes simétricos.

Cada peça anima somente posição e rotação. A escala dos nós permanece (1, 1); as dimensões de montagem são definidas na geometria de repouso. As hastes entram nas luvas por sobreposição, mantendo comprimento e espessura fixos. Não existe skinning, deformação de malha ou animação de escala.

A arte foi preparada com a ferramenta integrada image_gen a partir de isolated_mini_prensa.png. Atlas: assets/art/mini_prensa_rigid_atlas.png; prompt: docs/mini_prensa_rigid_prompt.txt. O gerador entregou fundo quadriculado opaco; contornos estáticos em assets/art/mini_prensa_rigid_parts.json mascaram esse fundo no asset Godot. O PNG de atlas isolado não é transparente. Use a cena ou os polígonos UV fornecidos.

Visualizador: ver_animacoes_mini_prensa.bat.
1/2/3: movimento, golpe e poder. 4: todos. Espaço: pausa. S: câmera lenta. E: montagem desmontada. R: reiniciar.
Prévia atual: docs/visual/prensa-rigid-preview.mp4, 1280x720 a 60 fps.
O antigo prensa-preview.mp4 foi substituído pela mesma prévia atual.

Animações contínuas: caminhada 1,2 s; golpe 1,7 s; poder 2,6 s.
A integração existente com o combate usa a mesma montagem rígida; a descarga completa está disponível no visualizador e na cena reutilizável. A recuperação do boss continua sendo exposição de núcleo sem dano.

Verificações: tests/mini_prensa_motion.gd confere escala unitária, determinante unitário, 184.140 comprimentos de arestas preservados e continuidade nos limites dos ciclos. Testes de compilação e de combate dos bosses também executados.
Reconstruir a cena após ajustar os contornos: Godot --headless --path . --script tools/build_mini_prensa_rigid.gd.


Poder atualizado: a tampa circular abre de 0,22 a 0,74 s, a ignição começa em 0,82 s e termina em 2,18 s, e a tampa fecha entre 2,24 e 2,6 s. O fogo sai do centro do queimador, com chama volumosa de bordas suaves, turbulência animada, núcleo amarelo claro e 24 brasas. O shader art/press_flame.gdshader mantém a garganta estreita dentro do orifício e alarga o jato após a saída. O teste verifica que só há emissão com a tampa completamente aberta.

As pupilas originais se deslocam suavemente, mantendo tamanho fixo. Prévia ampliada: docs/visual/olhos-preview.mp4. A descarga atualizada está em docs/visual/prensa-poder-preview.mp4. O tempo do shader acompanha a animação, inclusive pausa e câmera lenta.
