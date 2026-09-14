shader_type canvas_item;
render_mode unshaded;
uniform float playhead = 0.0;
uniform float intensity = 0.0;
uniform float residual = 0.0;
uniform float charge = 0.0;
uniform int species = 0;
varying vec2 pixel;
void vertex(){pixel=VERTEX;}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float fbm(vec2 p){return noise(p)*.54+noise(p*2.03+7.1)*.27+noise(p*4.07-8.3)*.13+noise(p*8.13)*.06;}
float segment(vec2 p,vec2 a,vec2 b){vec2 v=b-a;return length(p-a-v*clamp(dot(p-a,v)/max(dot(v,v),.001),0.0,1.0));}
vec4 plasma(vec2 p,float t){
 float u=clamp(p.y/170.0,0.0,1.0);
 float front=35.0+135.0*sqrt(intensity);
 float axial=smoothstep(-6.0,7.0,p.y)*(1.0-smoothstep(front-45.0,front+8.0,p.y));
 vec2 flow=vec2(p.x*.045,p.y*.035-t*3.8);
 vec2 warp=vec2(fbm(flow+vec2(0,t*.4)),fbm(flow+vec2(19,4)))-.5;
 float curl=sin(u*10.0-t*7.0)*u*9.0+warp.x*25.0*u;
 float width=7.0+32.0*pow(u,.65);
 float radial=abs(p.x-curl)/width;
 float field=fbm(flow+warp*2.8);
 float density=smoothstep(.08,.65,1.0-radial+(field-.5)*1.9)*axial;
 float hot=pow(clamp(1.0-radial,0.0,1.0),2.2)*(1.0-u*.75);
 float knots=smoothstep(.50,.72,field)*density;
 float core=density*hot*(.72+field*.7)+knots*.5;
 vec3 col=mix(vec3(.33,.025,.008),vec3(1,.23,.015),smoothstep(.05,.45,core));
 col=mix(col,vec3(1,.76,.12),smoothstep(.28,.75,core));
 col=mix(col,vec3(1,.98,.77),smoothstep(.7,1.0,core));
 float glow=exp(-radial*radial*.55)*axial*.24*intensity;
 vec3 light=col*density*intensity+vec3(1,.29,.025)*glow;
 float a=density*intensity+glow;
 float smoke=exp(-pow((p.x-curl)/(width*1.7),2.0))*smoothstep(35.0,100.0,p.y)*(1.0-smoothstep(145.0,205.0,p.y))*smoothstep(.37,.70,field)*(.18*intensity+.29*residual);
 light+=vec3(.20,.11,.075)*smoke;a+=smoke;
 float source=exp(-length(p/vec2(10,13)))*(intensity+charge*.65);
 light+=vec3(1,.77,.35)*source;a+=source;
 for(int i=0;i<21;i++){
  float id=float(i),seed=hash(vec2(id,7));
  float age=fract(t*(.72+seed*.65)+id*.618);
  float speed=110.0+seed*68.0;
  vec2 pos=vec2((seed-.5)*(14.0+100.0*age)+sin(age*9.0+id)*age*9.0,age*speed);
  float life=sin(age*3.14159)*pow(1.0-age,.7)*(intensity+.4*residual);
  float d=segment(p,pos,pos-vec2((seed-.5)*4.0,4.0+age*6.0));
  float spark=exp(-d*d/1.6)*life,halo=exp(-d*d/21.0)*life*.17;
  light+=vec3(1,.82,.35)*spark+vec3(1,.19,.015)*halo;a+=spark+halo;
 }
 return vec4(light/max(a,.001),clamp(a,0.0,1.0));
}
vec2 arc_point(float u,float arm,float t){
 float angle=arm*1.13+.16*sin(t*2.0+arm);
 vec2 direction=vec2(sin(angle),cos(angle));
 float reach=(arm<.5?130.0:mix(34.0,79.0,hash(vec2(arm,5.0))))*pow(max(intensity,.001),.24);
 vec2 side=vec2(direction.y,-direction.x);
 float jag=(noise(vec2(u*12.0,t*4.0+arm*8.0))-.5)*19.0;
 jag+=(noise(vec2(u*31.0,t*6.0+arm))-.5)*6.0;
 return direction*u*reach+side*jag*sin(u*3.14159);
}
vec4 discharge(vec2 p,float t){
 float r=length(p);
 float pulse=.78+.22*pow(sin(t*13.0),2.0);
 float energized=intensity+charge*.8;
 float corona=exp(-r*r/390.0)*energized;
 float mist=exp(-r*r/1700.0)*smoothstep(.24,.7,fbm(p*.07+vec2(t,-t*.8)))*.38*energized;
 float shell=exp(-pow((r-14.0-(noise(p*.15+vec2(t*3.0))-.5)*7.0)/3.0,2.0))*.16*energized;
 vec3 light=vec3(.12,.24,1.0)*(corona*.55+mist)+vec3(.40,.24,1.0)*shell;
 float a=corona*.55+mist+shell;
 for(int k=0;k<6;k++){
  float arm=float(k);
  float strength=intensity*(arm<.5?1.0:(.12+.65*pow(.5+.5*sin(t*9.0+arm*3.8),3.0)));
  float d=999.0,branch=999.0;
  vec2 old=vec2(0);
  for(int j=1;j<=26;j++){
   float u=float(j)/26.0;
   vec2 next=arc_point(u,arm,t);
   d=min(d,segment(p,old,next));old=next;
  }
  vec2 joint=arc_point(.52,arm,t),tip=arc_point(.92,arm,t);
  vec2 axis=normalize(tip-joint),side=vec2(axis.y,-axis.x);
  vec2 elbow=joint+axis*12.0+side*(9.0+4.0*sin(t*8.0+arm));
  branch=min(segment(p,joint,elbow),segment(p,elbow,elbow+axis*19.0-side*5.0));
  float edge=exp(-d*d/1.0)*strength;
  float bloom=exp(-d*d/22.0)*strength*.43;
  float fork=exp(-branch*branch/.6)*strength*.48;
  light+=vec3(.82,.94,1.0)*(edge+fork)+vec3(.15,.4,1.0)*bloom;
  a+=edge+fork+bloom;
 }
 float core=exp(-r*r/(14.0+30.0*intensity))*energized*pulse;
 light+=vec3(.9,.97,1)*core;a+=core;
 for(int i=0;i<22;i++){
  float id=float(i),seed=hash(vec2(id,31));
  float age=fract(t*(.8+seed*.5)+id*.618);
  float angle=id*2.39996;
  vec2 dir=vec2(cos(angle),sin(angle));
  vec2 pos=dir*(12.0+age*(45.0+seed*48.0));
  float d=segment(p,pos,pos-dir*(2.0+age*4.0));
  float life=sin(age*3.14159)*pow(1.0-age,1.5)*(intensity+.35*residual);
  float spark=exp(-d*d/.7)*life;
  float glow=exp(-d*d/12.0)*life*.25;
  light+=vec3(.7,.93,1)*spark+vec3(.09,.30,1)*glow;a+=spark+glow;
 }
 return vec4(light/max(a,.001),clamp(a,0.0,1.0));
}
void fragment(){
 vec4 effect;
 if(species==0){effect=plasma(pixel,playhead);}else{effect=discharge(pixel,playhead);}
 float bounds=(1.0-smoothstep(101.0,114.0,abs(pixel.x)))*smoothstep(-95.0,-83.0,pixel.y)*(1.0-smoothstep(202.0,215.0,pixel.y));
 COLOR=vec4(effect.rgb,effect.a*bounds);
}
