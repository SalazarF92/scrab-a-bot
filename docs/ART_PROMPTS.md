# Prompts e procedência das artes

Data: 10/09/2026. Ferramenta integrada `image_gen` (não CLI/API). Três gerações novas, sem imagem-fonte enviada. PNGs copiados para o projeto mantendo os originais. Os tamanhos solicitados são especificações do prompt; saída real: atlas 1254×1254 e cenário 1672×941. A grade não veio uniforme; o jogo usa os recortes do JSON companheiro.

Referência visual consultada: [galeria de Earthworm Jim 2 na Steam Community](https://steamcommunity.com/app/38490/screenshots/). Nenhum sprite do jogo de referência foi incorporado.

## parts

Destino: `assets/art/parts_atlas.png`.

```text
Use case: stylized-concept. Asset type: actual transparent raster sprite atlas for a Godot 2D/2.5D junk robot game SCRAP-A-BOT, not a mockup. Make a square 2048x2048 atlas with exactly 4 columns and 4 rows of equal 512x512 invisible cells, each object completely isolated and centered within its cell with at least 40 pixels clear transparent padding. True transparent alpha background, no grid lines, no text, no labels, no cast shadows. Consistent late 1990s hand inked grotesque cartoon aesthetic inspired by Earthworm Jim: wobbly thick dark plum ink, absurd asymmetry, two flat cel shade tones, bone white crazy eyes, aged beige electronics, orange rust, toxic green/cyan accents. Not pixel art, not vector icons, not 3D renders. Readable bold silhouettes with worn chips and bolts. Exact objects in reading order: row 1: computer mouse mousetrap gun aiming right; orange electric drill gun aiming right; oversized stapler machine gun aiming right; chunky PC power supply plasma cannon aiming right. Row 2: rusty drain pipe bazooka aiming right; hard drive circular saw launcher aiming right; beige toaster robot head with bulging funny eyes and burnt toast; electrified toaster robot head with cyan coil and yellow sparks. Row 3: PC case torso on mismatched rusty sofa spring legs; toy tractor tread torso; shopping cart caster wheeled metal torso; metal torso on absurd white mannequin legs. Row 4: green bank safe torso on tiny metal legs; old car battery with dangling cables; stack of three crooked old tires; squashed rusty abandoned cartoon car carcass. Torsos have no head and no arms, have small visible green CPU in chest window. Weapons have no hands or people. Match all pieces for modular assembly. These are production sprites with genuine transparency.
```

## enemies

Destino: `assets/art/enemies_atlas.png`.

```text
Use case: stylized-concept. Asset type: transparent enemy sprite atlas for original junk robot game. Square 2048x2048 image, exactly 4 columns by 3 rows equally spaced invisible cells (each one fourth width and one third height). Entire background genuinely transparent alpha, no ground shadows, no labels or text or grid. Each of 12 monsters centered in own cell with 12 percent transparent margin, nothing crosses cell. Art direction: hand drawn 1990s grotesque cel animation inspired by Earthworm Jim. Living electronics, irregular thick dark plum ink, flat two tone shading, asymmetry, huge bone-white bloodshot silly eyes, lively snarling silhouettes. Not pixel art, not vector, no 3D render. View from slightly above and in front, 2.5D painted volume, monsters face the viewer. Exact reading order: row 1: rusty screw creature with tiny metal legs; zombie computer mouse with cord tail and teeth; elderly beige refrigerator monster with crooked teeth; haunted cyan floppy disk ghost. Row 2: black ink cartridge squid creature; overstuffed beige refrigerator bursting with screw creatures; huge angry orange hydraulic press monster with open jaw and metal teeth; frosted blue cryogenic mainframe tower monster with icy vents. Row 3: huge furious purple and orange furnace with a flaming mouth; giant vacuum cleaner monster with a flexible trunk; monstrous beige office printer spewing blank crumpled paper; disgusting sagging green mattress with springs and big eyes. Individual sprites isolated and clearly separated, high polish production sprite artwork.
```

## background

Destino: `assets/art/junkyard.png`.

```text
Use case: stylized-concept. Asset type: actual 2D game environment background for SCRAP-A-BOT. Wide 16:9 1920x1080 illustration, a vertical industrial junkyard pit seen directly from above with slight painted depth, center 52 percent of image is a dark empty vertical flat grimy metal playing floor running uninterrupted from top edge to bottom edge. Very important: empty unobstructed center floor for ricocheting projectiles, muted desaturated dark plum and olive brown, low contrast scratches. Outer left and right 24 percent contain elaborate stacked mountains of discarded crooked CRT monitors with dead silly eyes, tires, tangled pipes, rusty girders, robot scrap and dangling cables. Asymmetric hand-inked perspective retaining the straight clear central vertical playable corridor. Lower corners massive foreground rusty ductwork; far upper corners hazy distant junk silhouettes and dim acidic green sky. Fine watercolor/grain texture with thick irregular dark ink contours and flat painted shadows, hand drawn grotesque 1990s cartoon aesthetic inspired by Earthworm Jim, original junkyard world. Rich artistic detail concentrated on margins, subdued warm rust, old printer beige, charcoal, olive green. No characters in playing area, no floating platforms, no HUD, no words or text, no logos, no pixel art, no gradients on objects, no shiny 3D. Background itself must remain desaturated to keep game actors legible.
```

