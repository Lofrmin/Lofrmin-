shader_type spatial;
render_mode unshaded;
uniform sampler2D surface_map: source_color, filter_linear_mipmap;
uniform sampler2D clouds: source_color, filter_linear;
uniform float phase = 0.;
void fragment(){
 vec2 uv=vec2(fract(UV.x+phase),UV.y);
 vec3 surface=texture(surface_map,uv).rgb;
 float cloud=texture(clouds,vec2(fract(uv.x+TIME*.001),uv.y)).a;
 vec3 n=normalize(NORMAL);
 float light=max(dot(n,normalize(vec3(-.5,.7,.55))),0.);
 float rim=pow(1.-max(0.,dot(n,VIEW)),3.5);
 vec3 base=mix(surface,vec3(.82,.9,1.),cloud*.7);
 ALBEDO=base*(.065+light*1.3)+vec3(.03,.28,.65)*rim;
}
