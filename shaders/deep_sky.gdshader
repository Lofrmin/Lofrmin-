shader_type sky;
float hash(highp vec3 p){p=fract(p*.1031);p+=dot(p,p.yzx+33.33);return fract((p.x+p.y)*p.z);}
void sky(){
 vec3 d=normalize(EYEDIR);
 float band=exp(-pow((d.y*.7+d.x*.23+.1)*5.,2.));
 float dust=sin(d.x*14.+sin(d.z*15.)*.8)*sin(d.z*23.+d.y*17.)*.5+.5;
 vec3 color=vec3(.003,.007,.017)+vec3(.018,.045,.065)*band*(.25+dust*.6);
 vec3 p=d*750.;
 float star=step(.9984,hash(floor(p)))*pow(max(0.,1.-length(fract(p)-.5)*2.),5.);
 color+=vec3(.58,.8,1.)*star*1.5;
 COLOR=color;
}
