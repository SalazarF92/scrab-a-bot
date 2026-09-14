shader_type canvas_item;
uniform vec2 slide;
varying vec2 local_position;
void vertex() { local_position = VERTEX + slide; }
void fragment() {
	vec2 p = (local_position - vec2(-86.5,-71.0))/vec2(39.0,51.0);
	float mask = 1.0-smoothstep(.97,1.0,length(p));
	COLOR = texture(TEXTURE,UV)*COLOR;
	COLOR.a *= mask;
}
