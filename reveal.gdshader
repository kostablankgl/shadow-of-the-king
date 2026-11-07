shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform vec3 player_position = vec3(0.0);
uniform float cane_radius = 0.5;
uniform float cane_strength = 0.8;
uniform vec4 cane_color : source_color = vec4(0.55, 0.65, 0.78, 1.0);

uniform vec4 fresh_color : source_color = vec4(0.18, 0.88, 0.94, 1.0);
uniform vec4 memory_color : source_color = vec4(0.42, 0.36, 1.0, 1.0);
uniform vec3 echo_origin = vec3(0.0);
uniform float echo_age = -100.0;
uniform float wave_speed = 20.0;
uniform float wave_width = 1.2;
uniform float fresh_time = 2.0;
uniform float memory_time = 18.0;
uniform float max_distance = 18.0;
uniform sampler2D visibility_map : filter_nearest, repeat_enable;
uniform bool echo_active = false;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_pos);
	float facing = abs(dot(n, view_dir));
	float fresnel = pow(1.0 - facing, 1.5);
	float edge = smoothstep(0.12, 0.55, length(fwidth(n)));
	float contour = clamp(0.15 + 0.55 * fresnel + 0.7 * edge, 0.0, 1.3);
	float fresh_contour = clamp(0.45 + 0.55 * fresnel + 0.5 * edge, 0.0, 1.3);
	float cane_contour = 0.35 + 0.65 * fresnel;

	float dist_player = length(world_pos - player_position);
	float cane = (1.0 - smoothstep(0.0, cane_radius, dist_player)) * cane_strength;
	vec3 col = cane_color.rgb * cane * cane_contour;

	if (echo_active) {
		vec3 to_frag = world_pos - echo_origin;
		float dist = length(to_frag);
		vec3 dir = to_frag / max(dist, 0.0001);

		float u = atan(dir.z, dir.x) / (2.0 * PI) + 0.5;
		float v = acos(clamp(dir.y, -1.0, 1.0)) / PI;
		float vis_dist = texture(visibility_map, vec2(u, v)).r * max_distance;

		float front = echo_age * wave_speed - dist;

		if (dist <= vis_dist + 0.5 && front >= 0.0) {
			float since = front / wave_speed;
			float fresh = pow(max(1.0 - since / fresh_time, 0.0), 2.5);
			float memory = pow(max(1.0 - since / memory_time, 0.0), 1.5);
			float fresh_w = fresh;
			float memory_w = memory * 0.35;
			float total = fresh_w + memory_w;
			vec3 echo_col = (fresh_color.rgb * fresh_w + memory_color.rgb * memory_w) / max(total, 0.0001);
			float fresh_b = fresh_w * fresh_contour;
			float memory_b = memory_w * contour;
			float brightness = max(fresh_b, memory_b);
			float band = exp(-pow(front / wave_width, 2.0));
			col += echo_col * brightness;
			col += fresh_color.rgb * band * 1.2;
		}
	}

	ALBEDO = col;
}
