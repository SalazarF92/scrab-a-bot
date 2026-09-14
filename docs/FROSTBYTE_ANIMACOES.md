# FROSTBYTE 500 — articulação da arte original

Cena reutilizável: scenes/frostbyte_rigid.tscn.
Visualizador: ver_animacoes_frostbyte.bat.
Prévia: docs/visual/frostbyte-preview.mp4 (1280x720, 60 fps).
Comparação: docs/visual/frostbyte-comparacao.png.

A montagem usa diretamente assets/art/enemies_atlas.png, região (954, 402, 299, 403). Os recortes em assets/art/frostbyte_original_parts.json particionam o sprite original: gabinete, cabeça, mandíbula e base de gelo. Uma peça interna cobre as juntas abertas durante o movimento. O atlas gerado anteriormente permanece como histórico e não é usado nesta montagem.

Cada peça mantém suas dimensões e anima posição e rotação com interpolação contínua. O movimento preserva a silhueta da torre congelada, com balanço do gabinete e deslocamento da base. O golpe articula a boca; o poder abre a boca e emite o sopro glacial. As pupilas usam os pixels originais e se deslocam suavemente, sem mudar de tamanho.

Durações: movimento 1,4 s; golpe 1,9 s; poder 3,2 s.
Controles: 1/2/3 isolam ações; 4 mostra todas; Espaço pausa; S reduz a velocidade; E separa peças; R reinicia.

ArtDirector usa a montagem com relógio contínuo e transições interpoladas. Regras de combate e dano permanecem controladas pelo boss.

Reconstrução: execute tools/build_frostbyte_original_parts.gd e depois tools/build_frostbyte_rigid.gd com Godot --headless --path . --script.
Validação: tests/boss_revision.gd confere a região original, a área dos recortes e o olhar nas seis ações dos dois bosses. tests/frostbyte_motion.gd verifica rigidez, continuidade e sincronização da emissão. As cenas são verificadas por tests/compile_check.tscn e tests/boss_combat.tscn.