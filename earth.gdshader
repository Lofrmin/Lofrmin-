shader_type spatial;
render_mode unshaded, fog_disabled;

uniform sampler2D surface_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D cloud_map : filter_linear_mipmap, repeat_enable;
uniform vec3 sun_direction = vec3(-0.52, 0.58, 0.62);
varying vec3 world_normal;

void vertex() {
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 world_n = normalize(world_normal);
	float sun = dot(world_n, normalize(sun_direction));
	float day = smoothstep(-0.045, 0.81, sun);
	float edge = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 4.0);
	vec2 cloud_uv = UV + vec2(TIME * 0.001, 0.0);
	vec3 land = texture(surface_map, UV).rgb;
	float cloud = texture(cloud_map, cloud_uv).a;
	float cloud_shadow = texture(cloud_map, cloud_uv + vec2(0.0024, -0.0012)).a;
	land *= 1.0 - 0.22 * cloud_shadow * day;
	land = mix(land, vec3(dot(land, vec3(0.2126, 0.7152, 0.0722))), 0.25);
	vec3 lit = mix(land, vec3(0.87, 0.89, 0.87), pow(cloud, 1.48) * 0.82);
	float limb = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 15.0);
	ALBEDO = lit * (0.019 + day * 1.15) + vec3(0.022, 0.11, 0.23) * edge * (0.06 + day)
		+ vec3(0.035, 0.24, 0.34) * limb * smoothstep(-0.10, 0.51, sun);
}
