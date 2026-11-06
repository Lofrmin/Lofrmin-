shader_type spatial;
render_mode unshaded;
float hash(highp vec2 p){highp vec3 p3=fract(vec3(p.xyx)*.1031);p3+=dot(p3,p3.yzx+33.33);return fract((p3.x+p3.y)*p3.z);}
float noise(highp vec2 p){highp vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec2 uv=UV+vec2(TIME*.0005,0.);
 float turbulence=noise(uv*vec2(22.,36.))*.016+sin(uv.x*40.)*.002;
 float stripe=sin((uv.y+turbulence)*125.)*.5+.5;
 vec3 base=mix(vec3(.24,.12,.075),vec3(.64,.47,.32),stripe);
 base=mix(base,vec3(.78,.66,.49),smoothstep(.4,.75,noise(uv*vec2(10.,85.)))*.5);
 float light=max(dot(normalize(NORMAL),normalize(vec3(-.6,.6,.4))),0.);
 ALBEDO=base*(.06+light*.65);
}
