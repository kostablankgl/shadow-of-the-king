shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform vec4 base_color : source_color = vec4(0.18, 0.22, 0.3, 1.0);
uniform vec4 wave_color : source_color = vec4(0.45, 0.85, 1.0, 1.0);
uniform vec3 echo_origin = vec3(0.0);
uniform float echo_age = -100.0;
uniform float wave_speed = 18.0;
uniform float wave_width = 1.4;
uniform float memory_time = 10.0;
uniform float max_distance = 28.0;
uniform sampler2D visibility_map : filter_linear, repeat_enable;
uniform bool echo_active = false;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 col = vec3(0.0);
	if (echo_active) {
		vec3 to_frag = world_pos - echo_origin;
		float dist = length(to_frag);
		vec3 dir = to_frag / max(dist, 0.0001);

		float u = atan(dir.z, dir.x) / (2.0 * PI) + 0.5;
		float v = acos(clamp(dir.y, -1.0, 1.0)) / PI;
		float vis_dist = texture(visibility_map, vec2(u, v)).r * max_distance;

		float travelled = echo_age * wave_speed;
		float front = travelled - dist;

		if (dist <= vis_dist + 0.5 && front >= 0.0) {
			float since = front / wave_speed;
			float memory = clamp(1.0 - since / memory_time, 0.0, 1.0);
			memory = memory * memory;
			float band = exp(-pow(front / wave_width, 2.0));
			col = base_color.rgb * memory;
			col += wave_color.rgb * band * 1.5;
		}
	}
	ALBEDO = col;
}
