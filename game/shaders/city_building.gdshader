shader_type spatial;
render_mode diffuse_toon, specular_disabled;

// 도시 건물 벽(운영자 2026-10-06: 위에서 봤을 때 SimCity 같은 도시) — MultiMesh 인스턴스 색이 벽 색, 층(3.2m)마다 창 줄, 창은 2.6m 간격.
// 일부 창은 불이 켜져 있다(위치 해시 — 같은 건물은 늘 같은 창). 1층은 창 대신 진한 띠(가게·현관), 지붕은 조금 어둡게. 텍스처 없이 세계 좌표로만
varying vec3 wp;
varying vec3 wn;
varying vec4 col;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	col = COLOR;
}

float h(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 base = col.rgb;
	if (wn.y > 0.5) {
		ALBEDO = base * 0.78;
	} else {
		float u = abs(wn.x) > 0.5 ? wp.z : wp.x;
		vec2 g = vec2(u / 2.6, wp.y / 3.2);
		vec2 f = fract(g);
		float win = step(0.2, f.x) * step(f.x, 0.8) * step(0.28, f.y) * step(f.y, 0.82);
		float ground = step(wp.y, 3.0);
		float lit = step(0.72, h(floor(g) + floor(wp.xz * 0.05)));
		vec3 glass = mix(vec3(0.32, 0.42, 0.52), vec3(0.98, 0.88, 0.58), lit);
		vec3 c = mix(base, glass, win * (1.0 - ground));
		c = mix(c, base * 0.55, ground * step(0.6, f.y));   // 1층 위 띠(차양)
		ALBEDO = c;
	}
	ROUGHNESS = 1.0;
}
