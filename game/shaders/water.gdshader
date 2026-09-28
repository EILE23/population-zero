shader_type spatial;
render_mode diffuse_toon, specular_disabled;

// 찰랑이는 수면(운영자 2026-09-28: "헤엄칠 때 물이 찰랑찰랑") — 두 톤의 파랑이 띠를 이루며 +x 로 흐르고, 가끔 밝은 빛줄기가 스친다.
// 전부 sin 으로 만든다(텍스처 없음, GL Compatibility 에서 돈다). 정점도 살짝 오르내려 가장자리와 헤엄치는 사람이 함께 흔들린다.
uniform vec4 shallow : source_color = vec4(0.60, 0.76, 0.84, 1.0);
uniform vec4 deep : source_color = vec4(0.47, 0.66, 0.77, 1.0);
uniform vec4 glint : source_color = vec4(0.88, 0.94, 0.96, 1.0);
uniform float flow : hint_range(0.0, 2.0) = 0.35;   // 흐르는 속도(m/s, +x)
uniform float bob : hint_range(0.0, 0.05) = 0.008;  // 정점 오르내림(m)

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(wpos.x * 2.1 + TIME * 1.7) * bob + sin(wpos.z * 3.3 - TIME * 1.2) * bob * 0.6;
}

void fragment() {
	float x = wpos.x - TIME * flow;
	float w1 = sin(x * 1.6 + sin(wpos.z * 2.2 + TIME * 0.6) * 1.4) * 0.5 + 0.5;
	float w2 = sin(wpos.z * 3.8 + x * 0.7 - TIME * 1.1) * 0.5 + 0.5;
	float band = smoothstep(0.52, 0.62, w1 * 0.6 + w2 * 0.4);   // 두 톤 사이의 날카로운 경계 = 잉크 선 느낌
	vec3 col = mix(deep.rgb, shallow.rgb, band);
	float streak = smoothstep(0.965, 0.985, sin(x * 5.0 + wpos.z * 2.6 + TIME * 0.9) * sin(wpos.z * 1.3 + TIME * 0.4));
	col = mix(col, glint.rgb, streak * 0.8);
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
