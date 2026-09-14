# Parafuseta — boca reconstruída e poder revisado

Prévia: docs/visual/parafuseta-preview.mp4 (1280x720, 60 fps).
Visualizador: ver_animacoes_parafuseta.bat.
Cena reutilizável: scenes/parafuseta_rigid.tscn.

Revisão das articulações: os recortes das pernas preservam as barras e os cotovelos inteiros. Os eixos dos joelhos, ombro esquerdo, pé central e pescoço foram reposicionados. As conexões têm apoios internos sobrepostos, obtidos da pintura original e recuados do contorno externo para evitar bordas duplicadas. Esses apoios também respeitam a cavidade da boca. Nenhuma peça muda de escala durante a animação.

Revisão conjunta: docs/visual/juntas-preview.mp4; cena scenes/creature_joints_review.tscn (1/2/3 selecionam ação, Espaço pausa, R reinicia). tests/creature_joint_contacts.gd verifica a cobertura opaca das conexões durante os três ciclos dos dois personagens.

A pintura da boca antiga foi removida da geometria do corpo. A montagem nova tem cavidade, arcada superior e mandíbula completa com dentes, gengiva, língua e superfícies internas. A mandíbula usa posição e rotação interpoladas; seus vértices e UVs mantêm dimensões fixas. A cavidade é ocultada pela mandíbula durante o fechamento. O teste ampliado está em docs/visual/bocas-estrutura.png.

O corpo, as patas e o olho continuam usando assets/art/enemies_atlas.png. Somente a pequena região atrás da boca recebe o reparo de rosca ou pele de assets/art/mouth_mount_repairs.png. Os demais personagens dessa imagem gerada não são utilizados.

Peças da boca: assets/art/mouth_anatomy_atlas.png, criadas com a ferramenta integrada image_gen. O atlas veio com quadriculado opaco; contornos estáticos em assets/art/mouth_anatomy_contours.json excluem o fundo no Godot. A textura original do atlas não foi alterada. Prompts completos: docs/mouth_generation_prompts.txt.

Poder: jato de plasma quente com núcleo de pressão, volume turbulento, brasas com cauda e fumaça residual. O shader art/creature_energy.gdshader possui tratamentos distintos para cada criatura. Carga, emissão e dissipação usam o relógio explícito da animação, respeitando pausa e câmera lenta. Não modifica regras de dano.

Controles: 1/2/3 isolam movimento, golpe e poder; 4 mostra todos; Espaço pausa; S reduz a velocidade; E separa as peças do corpo; R reinicia.

Reconstrução, nesta ordem, com Godot --headless --path . --script:
- tools/build_parafuseta_parts.gd
- tools/build_mouth_contours.gd
- tools/build_creature_mouth_mounts.gd
- tools/build_parafuseta_rigid.gd

Validação: tests/creature_mouths.gd verifica abertura, fechamento e rigidez da mandíbula; tests/parafuseta_motion.gd verifica área dos recortes restantes, escala unitária e continuidade; tests/compile_check.tscn verifica a compilação. As prévias são renderizações do Godot.
Revisão dedicada de VFX: docs/visual/poderes-criaturas-preview.mp4. Visualizador: ver_poderes_criaturas.bat. A integração verifica pausa, retorno ao mesmo instante e limpeza ao trocar de ação; execute tools/export_creature_vfx.ps1 -Mode Verify. Imagens das quatro fases: docs/visual/vfx-carga.png, vfx-pico.png, vfx-cauda.png e vfx-fim.png.
