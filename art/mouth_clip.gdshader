shader_type canvas_item;
// Cavidade da boca no combate. Faz por pixel o mesmo corte que
// CreatureMouth.draw faz por poligono: descarta o que fica abaixo da borda
// superior da mandibula, no referencial da propria cavidade.
// A borda e um semiplano: some o que tiver dot(p - clip_origin, clip_normal) > 0.
uniform vec2 clip_origin = vec2(0.0, 0.0);
uniform vec2 clip_normal = vec2(0.0, 1.0);
varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	COLOR = texture(TEXTURE, UV) * COLOR;
	COLOR.a *= step(dot(local_position - clip_origin, clip_normal), 0.0);
}
