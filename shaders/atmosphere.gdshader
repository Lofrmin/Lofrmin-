shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;
uniform vec4 tint: source_color = vec4(.08,.5,1.,.5);
void fragment(){
 float rim=pow(1.-abs(dot(normalize(NORMAL),VIEW)),4.);
 ALBEDO=tint.rgb;
 ALPHA=rim*tint.a;
}
