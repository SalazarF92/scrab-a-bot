# Instruções do projeto

## Construção de mobs e bosses

Antes de criar, revisar ou animar qualquer mob ou boss, leia e aplique
[docs/METODO_CONSTRUCAO_MOBS.md](docs/METODO_CONSTRUCAO_MOBS.md).
Esse é o padrão de produção solicitado pelo usuário, inclusive para os próximos
personagens. Registros antigos de deformação de sprites ou animação a 12 poses/s
não são referência para trabalho novo.

- A imagem original é referência visual. Construa um conjunto de assets próprios
  para cada personagem, com peças articuladas completas e superfícies ocultas.
  Recortar a ilustração sem reconstruir o que falta não conclui essa etapa.
- Preserve identidade, proporções, materiais e silhueta da referência. Não
  substitua o personagem por um redesign genérico.
- Anime peças independentes em torno de pivôs anatômicos ou mecânicos reais.
  Encaixes devem continuar conectados nos extremos do movimento. Não simule
  articulação escalando, esticando ou deformando a imagem inteira.
- Construa boca, olhos e mecanismo de emissão como estruturas próprias.
  Abrir uma fenda no sprite não equivale a construir uma boca.
- Use interpolação contínua baseada em tempo. Não quantize a animação em poses
  espaçadas com aparência de stop motion.
- Produza VFX específicos para o personagem, presos ao emissor articulado e
  sincronizados com sua abertura. A qualidade do poder faz parte da entrega.
- Valide movimento, golpe e poder em cenas reutilizáveis e em prévias ampliadas
  a 60 fps. Verifique conexões, rigidez, olhos, boca, pausa e retorno ao ciclo.
- Registre assets, pivôs, construção, validação e prévias na documentação do mob.
  Diferencie o que foi implementado do que ainda precisa ser convertido.

Não trate os rigs existentes como modelos automaticamente corretos: os casos
Parafuseta e Rato Morto documentam também falhas de recorte e suas correções.
