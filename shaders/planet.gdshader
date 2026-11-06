shader_type canvas_item;
uniform sampler2D surface_map: source_color, filter_linear, repeat_enable;
uniform sampler2D clouds: source_color, filter_linear, repeat_enable;
uniform bool gas_giant=false;
uniform float rotation=0.;
uniform float engine_power=0.;
float hash(highp vec2 p){highp vec3 p3=fract(vec3(p.xyx)*.1031);p3+=dot(p3,p3.yzx+33.33);return fract((p3.x+p3.y)*p3.z);}
float noise(highp vec2 p){highp vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec2 p=(UV-.5)*2.4;
 float r=length(p);
 vec3 col=vec3(0.);float alpha=0.;
 if(r<1.){
  vec3 n=vec3(p.x,-p.y,sqrt(max(0.,1.-r*r)));
  float lon=atan(n.z,n.x)/6.2831853+.5+rotation;
  float lat=asin(n.y)/3.14159265+.5;
  float light=max(dot(n,normalize(vec3(-.65,.55,.6))),0.);
  float rim=pow(1.-n.z,3.);
  if(gas_giant){
   float swirl=noise(vec2(lon*22.,lat*28.))*.018;
   float band=sin((lat+swirl)*100.)*.5+.5;
   vec3 base=mix(vec3(.27,.14,.09),vec3(.72,.53,.35),band);
   base=mix(base,vec3(.85,.73,.55),smoothstep(.45,.8,noise(vec2(lon*10.,lat*70.)))*.6);
   float spot=exp(-length((vec2(lon,lat)-vec2(.64,.43))*vec2(33.,90.)));
   base=mix(base,vec3(.48,.18,.09),spot);
   col=base*(.08+.8*light)+rim*vec3(.12,.13,.16);
  }else{
   vec2 uv=vec2(lon,1.-lat);
   vec3 base=texture(surface_map,uv).rgb;
   float cloud=texture(clouds,vec2(lon+TIME*.001,1.-lat)).a;
   base=mix(base,vec3(.82,.91,.97),cloud*.68);
   col=base*(.08+light*.95);
   col+=vec3(.02,.4,.8)*rim*(.4+light);
   float grid=pow(max(0.,sin(lon*180.)),48.)+pow(max(0.,sin(lat*100.)),48.);
   col+=vec3(.02,.13,.17)*grid*.2;
   float city=step(.83,noise(vec2(lon*600.,lat*600.)))*step(.20,base.g)*pow(1.-light,4.);
   col+=vec3(.2,.75,1.)*city*(.06+engine_power*.2);
  }
  alpha=1.;
 }else{
  float glow=exp(-(r-1.)*(gas_giant?35.:35.))*smoothstep(1.19,1.,r);
  col=(gas_giant?vec3(.35,.25,.17):vec3(.06,.55,1.))*glow;
  alpha=glow*.65;
 }
 COLOR=vec4(col,alpha);
}
