# Expansão de assets — procedência

Geração em 10/09 e revisão em 11/09/2026 pela ferramenta integrada `image_gen`, sem CLI/API. Referência de estilo: `assets/art/enemies_atlas.png`, já pertencente ao projeto. Não foram incorporados sprites de Earthworm Jim.

Primeira saída: `assets/art/expansion_atlas.png`, 1254 × 1254. Arte aprovada visualmente, mas o fundo quadriculado veio opaco. Não utilizar essa versão como sprite final.

## Prompt original

```text
Use case: stylized-concept. Asset type: NEW transparent raster expansion atlas for the Godot game SCRAP-A-BOT. The attached image is STYLE REFERENCE ONLY: match its thick irregular dark plum outlines, painterly cel shading, rusty electronics, grotesque huge eyes and exaggerated 1990s cartoon monsters inspired by Earthworm Jim. Do not copy any monster from the reference. Create twelve NEW isolated assets on a square canvas, ideally 2048x2048, exactly FOUR columns by THREE rows, evenly spaced invisible cells. Genuine transparent alpha background, NO checkerboard painted, NO text, labels, grids, floor or shadows. Every asset completely inside its cell, with generous 16% TRANSPARENT PADDING on every edge. Never touch or cross cell boundaries. Front/three-quarter view slightly from above, two-tone painted volume for 2.5D, readable silhouettes, no pixel art or vector icons. Exact reading order: row 1: QWERTYpede, a snarling beige computer keyboard centipede with keycap legs and fangs; Pop-Up Vivo, a magenta old computer dialog window monster with protruding eyes, folded angular limbs, NO readable text inside; Cadeado Chorao, a green brass padlock crying chunky cartoon tears with cable legs and open jaw; Olhudo, an articulated dark navy webcam on a short clamp, single huge bloodshot camera-lens eye and red recording light. Row 2: Bipador, a squat old beige UPS power supply monster with red alarm lamp, big panicked mouth and running stubby feet; Ze Ventoinha, flying orange PC cooling fan with rotor blades around a crazy eyeball, tiny wire arms; Cabo Cobra, a coiled purple and green snake made of tangled HDMI wires with connector fangs; Fabricadora, a monstrous rusty open-frame 3D printer with two big eyes on the top rail, hot orange nozzle and a small emerging robot on its bed. Row 3 ENVIRONMENT PROPS (no walking feet): squat toxic chemical barrel with bulging lid and small grotesque eye, muted olive green; broken wide beige CRT television with shattered glass and slack jaw; fat copper electrical coil on a dented transformer base with twisted insulators; a horizontal rusted pipe manifold with crooked valves and a leaky pressure gauge. Muted colors on environment props, saturated accents on monsters. All 12 full objects, visible complete silhouettes, consistent detail and no extra floating fragments. Protect the clear padding, particularly around antennae and cables. Same line quality and eye design as the reference.
```

## Correções de transparência

A primeira solicitação foi bloqueada pelo limite do serviço; repetida após o horário de liberação. A saída da repetição ainda tinha alpha 255 no fundo e foi rejeitada.

```text
Use case: background-extraction. Edit target: attached twelve-sprite atlas. Remove ONLY the painted gray-white checkerboard background and replace it with GENUINE transparent alpha (alpha=0), including holes between cables, limbs, printer frame, padlock loop. Preserve all twelve monsters and props, exact style, colors, outlines, arrangement and full silhouettes. Do not paint a checkerboard, white or solid background. Output transparent PNG. Keep each sprite separated in its existing 4-column 3-row layout, no overlapping neighbors.
```

Segunda revisão: também rejeitada, alpha 255 no pixel (0, 0). Arquivo original mantido no diretório de geração; não substituiu nenhum sprite do projeto. Correção local aguarda resposta explícita do usuário.

```text
undefined
```
