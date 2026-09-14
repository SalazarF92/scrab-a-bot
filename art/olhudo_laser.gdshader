shader_type canvas_item;
render_mode unshaded, blend_add;
uniform float clock = 0.0;
uniform float charge = 0.0;
uniform float emission = 0.0;
uniform float reach = 235.0;
varying vec2 point;
float hash(float n) { return fract(sin(n*127.1)*43758.5453); }
float noise(float x) { float a=floor(x); float f=fract(x); return mix(hash(a),hash(a+1.0),f*f*(3.0-2.0*f)); }
void vertex() { point=VERTEX; }
void fragment() {
	float x=point.x; float y=point.y;
	float inside=step(0.0,x)*(1.0-smoothstep(reach-8.0,reach+9.0,x));
	float bend=sin(x*.07-clock*30.0)*.8+sin(x*.13+clock*23.0)*.45;
	float d=abs(y-bend);
	float pulse=.87+.13*sin(clock*79.0+x*.016);
	float core=exp(-d*d/2.1)*emission*inside;
	float sheath=exp(-d*d/26.0)*emission*inside*pulse;
	float halo=exp(-y*y/250.0)*emission*inside;
	float filament=exp(-pow(abs(y-5.0*sin(x*.09-clock*16.0)),2.0)/1.6)*emission*.35*inside;
	float aim=exp(-y*y/.5)*charge*.38*inside;
	float r=length(point);
	float orb=exp(-r*r/(28.0+charge*100.0))*(charge+emission)*.9;
	float ring=exp(-pow(r-(16.0+5.0*sin(clock*9.0)),2.0)/2.8)*charge*.45;
	float impact=exp(-pow((x-reach)/12.0,2.0)-pow(y/24.0,2.0))*emission;
	float sparks=0.0;
	for(int i=0;i<16;i++) {
		float seed=float(i); float age=fract(clock*(.9+hash(seed)*.5)+hash(seed+21.0));
		vec2 pos=vec2(reach-age*(20.0+hash(seed+4.0)*60.0),(hash(seed+9.0)-.5)*age*110.0);
		vec2 q=point-pos;
		sparks += exp(-q.x*q.x/9.0-q.y*q.y/2.0)*(1.0-age)*emission;
	}
	vec3 color=vec3(1.0,.025,.08)*(halo*.42+sheath+aim+ring)+vec3(1.0,.58,.52)*(filament+sparks)+vec3(1.0,.93,.85)*(core+orb+impact);
	float alpha=clamp(max(max(color.r,color.g),color.b),0.0,1.0);
	COLOR=vec4(color,alpha);
}
