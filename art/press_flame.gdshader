shader_type canvas_item;
render_mode unshaded;
uniform float playhead = 0.0;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
varying vec2 pixel;
void vertex() { pixel = VERTEX; }
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i+vec2(1,0)), f.x),
		mix(hash21(i+vec2(0,1)), hash21(i+vec2(1,1)), f.x), f.y);
}
float fbm(vec2 p) {
	return noise(p)*.55 + noise(p*2.03 + 12.4)*.28 + noise(p*4.11 - 9.7)*.17;
}
void fragment() {
	vec2 p = pixel;
	float length_px = 335.0 * intensity;
	float y = max(0.0, p.y + 10.0);
	float u = clamp(y / max(1.0, length_px), 0.0, 1.0);
	float advect = playhead * 3.2;
	float n = fbm(vec2(p.x * .034, y * .020 - advect));
	float fine = fbm(vec2(p.x * .080 + 13.0, y * .045 - advect * 1.8));
	float wander = (noise(vec2(y * .028 - advect, 7.2)) - .5) * 25.0 * u;
	float throat = mix(12.0, 43.0, smoothstep(0.0, .48, u));
	float tail = 1.0 - smoothstep(.50, 1.05, u);
	float width = throat * tail * (.72 + .50*n);
	float distance_to_jet = abs(p.x - wander) - width;
	float turbulent_edge = (n - .5) * 23.0 * smoothstep(.05, .65, u);
	float density = 1.0 - smoothstep(-5.0, 8.0, distance_to_jet - turbulent_edge);
	float tips = 1.0 - smoothstep(length_px * (.78 + .25*n), length_px + 8.0, y);
	float source = smoothstep(-18.0, -6.0, p.y);
	// Inside the circular throat the flame is recessed; outside it flows forward.
	float throat_clip = p.y < 8.0 ? 1.0 - smoothstep(27.0, 32.0, length(p)) : 1.0;
	float heat = clamp(density * (.52 + .6*fine) * (1.0 - u*.62), 0.0, 1.0);
	vec3 flame = mix(vec3(.75,.035,.003), vec3(1.0,.28,.012), smoothstep(.10,.42,heat));
	flame = mix(flame, vec3(1.0,.72,.075), smoothstep(.38,.70,heat));
	flame = mix(flame, vec3(1.0,.98,.72), smoothstep(.68,.94,heat));
	float core = exp(-pow((p.x-wander)/max(2.0,width*.38),2.0)) * (1.0-smoothstep(.12,.52,u));
	flame = mix(flame, vec3(1.0,.97,.79), core*.88);
	float alpha = density * tips * source * throat_clip * intensity;
	float halo = exp(-abs(p.x-wander)/max(1.0,width*1.6)) * tail * source * .065 * intensity;
	COLOR = vec4(flame + vec3(1,.12,.005)*halo, clamp(alpha + halo,0.0,1.0));
}
