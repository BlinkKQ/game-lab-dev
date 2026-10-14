shader_type spatial;
render_mode diffuse_burley;

uniform vec4 turf_color : source_color = vec4(0.29, 0.58, 0.24, 1.0);
uniform float stripe_phase = 0.0;
varying vec3 ground_position;
varying float top_face;

void vertex() {
	ground_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	top_face = clamp(NORMAL.y, 0.0, 1.0);
}

void fragment() {
	// Broad mowing bands and a quiet grain; no borrowed checkerboard texture.
	float mowing = smoothstep(-0.12, 0.12, sin(ground_position.z * 3.0 + stripe_phase));
	float grain = fract(sin(dot(floor(ground_position.xz * 145.0), vec2(12.9898, 78.233))) * 43758.5453);
	float organic = sin(ground_position.x * 1.7 + ground_position.z * 0.8) * 0.018;
	ALBEDO = turf_color.rgb * (0.92 + mowing * 0.075 + (grain - 0.5) * 0.036 + organic);
	ALBEDO *= mix(0.58, 1.0, top_face);
	ROUGHNESS = 0.94;
	SPECULAR = 0.15;
}
