shader_type canvas_item;
render_mode unshaded;

// Silhueta cel-shaded sobre o QuadMesh existente, sem nós por projétil.
void fragment() {
	vec4 ink_color = COLOR;
	vec2 p = UV * 2.0 - 1.0;
	float radius = length(p);
	float edge = 1.0 - smoothstep(0.88, 0.99, radius);
	float fill = 1.0 - smoothstep(0.69, 0.81, radius);
	vec3 shade = ink_color.rgb * (p.y > 0.20 ? 0.68 : 1.0);
	vec3 painted = mix(vec3(0.102, 0.059, 0.078), shade, fill);
	float shine = 1.0 - smoothstep(0.14, 0.22, length(p - vec2(0.05, -0.35)));
	painted = mix(painted, vec3(0.96, 0.94, 0.88), shine * 0.95);
	COLOR = vec4(painted, ink_color.a * edge);
}
