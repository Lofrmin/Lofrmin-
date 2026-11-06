shader_type canvas_item;
render_mode unshaded;

uniform sampler2D scene : hint_screen_texture, filter_linear_mipmap;
uniform float transition : hint_range(0.0, 1.0) = 0.0;
uniform float defocus : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 delta = uv - vec2(0.5);
	float scan = exp(-abs(uv.y - fract(TIME * 0.57)) * 28.0);
	uv.x += transition * scan * 0.011 * sin(uv.y * 185.0);
	vec3 original = textureLod(scene, uv, defocus * 3.8).rgb;
	float vignette = smoothstep(0.31, 0.73, length(delta * vec2(1.05, 0.87)));
	vec3 color = original * vec3(0.98, 1.00, 1.02);
	color *= 1.0 - 0.22 * vignette;
	color += transition * scan * vec3(0.08, 0.19, 0.23);
	COLOR = vec4(color, 1.0);
}
