# Rato Morto — boca reconstruída e poder revisado

Prévia: docs/visual/rato_morto-preview.mp4 (1280x720, 60 fps).
Visualizador: ver_animacoes_rato_morto.bat.
Cena reutilizável: scenes/rato_morto_rigid.tscn.

Revisão das articulações: as três raízes das patas e a base do cabo receberam apoios internos sobrepostos. As superfícies usam a pintura original, com margem interna para evitar contornos duplicados, e respeitam a cavidade da boca. A rotação continua rígida e interpolada.

Revisão conjunta: docs/visual/juntas-preview.mp4; cena scenes/creature_joints_review.tscn. tests/creature_joint_contacts.gd verifica a cobertura opaca das conexões durante movimento, golpe e poder.

A pintura da boca antiga foi removida da geometria do corpo. A montagem nova tem cavidade, arcada superior e mandíbula completa com dentes, gengiva, língua e superfícies internas. A mandíbula usa posição e rotação interpoladas; seus vértices e UVs mantêm dimensões fixas. A cavidade é ocultada pela mandíbula durante o fechamento. O teste ampliado está em docs/visual/bocas-estrutura.png.

O corpo, as patas e o olho continuam usando assets/art/enemies_atlas.png. Somente a pequena região atrás da boca recebe o reparo de rosca ou pele de assets/art/mouth_mount_repairs.png. Os demais personagens dessa imagem gerada não são utilizados.

Peças da boca: assets/art/mouth_anatomy_atlas.png, criadas com a ferramenta integrada image_gen. O atlas veio com quadriculado opaco; contornos estáticos em assets/art/mouth_anatomy_contours.json excluem o fundo no Godot. A textura original do atlas não foi alterada. Prompts completos: docs/mouth_generation_prompts.txt.

Poder: carga azul-violeta nos fios expostos, arco principal de alta tensão, ramificações assimétricas, corona e partículas ionizadas. O shader art/creature_energy.gdshader possui tratamentos distintos para cada criatura. Carga, emissão e dissipação usam o relógio explícito da animação, respeitando pausa e câmera lenta. Não modifica regras de dano.

Controles: 1/2/3 isolam movimento, golpe e poder; 4 mostra todos; Espaço pausa; S reduz a velocidade; E separa as peças do corpo; R reinicia.

Reconstrução, nesta ordem, com Godot --headless --path . --script:
- tools/build_rato_morto_parts.gd
- tools/build_mouth_contours.gd
- tools/build_creature_mouth_mounts.gd
- tools/build_rato_morto_rigid.gd

Validação: tests/creature_mouths.gd verifica abertura, fechamento e rigidez da mandíbula; tests/rato_morto_motion.gd verifica área dos recortes restantes, escala unitária e continuidade; tests/compile_check.tscn verifica a compilação. As prévias são renderizações do Godot.
Revisão dedicada de VFX: docs/visual/poderes-criaturas-preview.mp4. Visualizador: ver_poderes_criaturas.bat. A integração verifica pausa, retorno ao mesmo instante e limpeza ao trocar de ação; execute tools/export_creature_vfx.ps1 -Mode Verify. Imagens das quatro fases: docs/visual/vfx-carga.png, vfx-pico.png, vfx-cauda.png e vfx-fim.png.

## Integração no combate (14/09)

Desde 14/09 este rig é o desenho do Rato Morto no poço, via `art/creature_rig_view.gd`.
O desenho imediato do puppet custava 2,9 ms por Rato Morto. No combate, as peças consecutivas
da mesma junta viram uma malha montada uma vez, e cada quadro só troca transformações.
Geometria, UVs, pivôs, ordem de desenho e curvas são as do rig.

- Anda enquanto desce em ziguezague, toca o golpe a partir do impacto quando encosta no robô e fica em repouso atordoado.
- A troca de ação é interpolada em 0,16 s. Hitstop e pausa congelam o rig no mesmo instante.
- A boca usa as peças de `CreatureMouth`, com o corte da cavidade feito em `art/mouth_clip.gdshader`.
- O arco elétrico não aparece no combate, porque o Rato Morto não tem essa habilidade.

Validação: `tests/rig_integration.tscn`. Capturas: `docs/visual/rigs-no-jogo.png` e `rigs-no-jogo-zoom.png`.
