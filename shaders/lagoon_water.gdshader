shader_type spatial;
render_mode diffuse_burley;

uniform float water_time = 0.0;
uniform vec4 deep_color : source_color = vec4(0.045, 0.45, 0.66, 1.0);
uniform vec4 light_color : source_color = vec4(0.22, 0.78, 0.82, 1.0);
varying vec3 water_position;

void vertex() {
	water_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float a = sin(water_position.x * 11.0 + water_position.z * 6.0 + water_time * 1.3);
	float b = sin(water_position.z * 15.0 - water_position.x * 4.0 - water_time * 0.8);
	float ripple = pow(clamp((a + b) * 0.25 + 0.5, 0.0, 1.0), 6.0);
	float drift = sin(water_position.x * 1.4 + water_position.z * 2.1 + water_time * 0.24) * 0.12 + 0.25;
	ALBEDO = mix(deep_color.rgb, light_color.rgb, clamp(drift + ripple * 0.48, 0.0, 1.0));
	ROUGHNESS = 0.33;
	SPECULAR = 0.48;
}
