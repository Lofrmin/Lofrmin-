shader_type canvas_item;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec2 p=UV*vec2(1.667,1.);
 float n=noise(p*4.+TIME*.003)*.5+noise(p*9.)*.25+noise(p*23.)*.125;
 float cloud=exp(-pow((p.y-.55+p.x*.22)*3.,2.))*n;
 vec3 col=vec3(.006,.013,.028)+vec3(.025,.08,.12)*cloud;
 col+=vec3(.035,.018,.055)*noise(p*7.)*exp(-length(p-vec2(1.2,.25))*2.);
 float vignette=1.-.5*length(UV-.5);
 COLOR=vec4(col*vignette,1.);
}
