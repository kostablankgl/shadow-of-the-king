float fresnel_rim(vec3 normal, vec3 world_pos, vec3 player_pos, float power) {
	vec3 to_player = normalize(player_pos - world_pos);
	float facing = abs(dot(normalize(normal), to_player));
	return pow(1.0 - facing, power);
}
