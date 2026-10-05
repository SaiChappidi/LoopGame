shader_type canvas_item;
render_mode unshaded;
uniform vec4 base_color : source_color = vec4(0.07, 0.1, 0.17, 1.0);
uniform vec4 accent_color : source_color = vec4(0.6, 0.85, 0.9, 1.0);

float grain(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
void fragment() {
	vec2 p = UV;
	vec3 ink = base_color.rgb * 0.43;
	float atmosphere = exp(-length((p - vec2(0.57, 0.43)) * vec2(2.3, 1.7)) * 2.1);
	vec3 color = mix(ink, base_color.rgb * 1.6, atmosphere);
	float rim = exp(-length((p - vec2(0.77, 0.26)) * vec2(3.5, 2.2)) * 3.4);
	color += accent_color.rgb * rim * 0.12;
	float floor_light = exp(-length((p - vec2(0.48, 0.72)) * vec2(3.0, 6.0)) * 2.0);
	color += accent_color.rgb * floor_light * 0.035;
	color += (grain(FRAGCOORD.xy) - 0.5) * 0.009;
	float vignette = smoothstep(0.82, 0.17, length((p - 0.5) * vec2(0.7, 1.0)));
	color *= mix(0.7, 1.0, vignette);
	COLOR = vec4(color, 1.0);
}
