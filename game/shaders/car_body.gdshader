shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;

// 차체(Kenney Car Kit) — 원래 텍스처 그대로 칠하되 옆·앞뒤 유리(색표의 아주 밝은 칸, 차체 허리 위, 옆을 보는 면)는 뚫는다.
// 운영자 2026-09-30: "아무도 안 타 있고" — 운전사(주민)가 앉아 있는데 유리가 불투명해 안 보였다. 뚫린 창 너머로 안쪽 면(cull_disabled)과 운전사가 보인다
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform float glass_y = 0.6;      // 모델 좌표 — 이 높이 위만 유리일 수 있다(전조등·번호판은 아래)
uniform float glass_min = 0.85;   // 유리 칸: 파랑이 꽉 차고(ff) 빨강·초록도 밝은 푸른 흰빛 — 선형 값이라 sRGB ef ≈ 0.86. 흰 차체(f1ecf1 등)는 파랑이 덜 차 남는다

varying float ly;
varying float ny;

void vertex() {
	ly = VERTEX.y;
	ny = NORMAL.y;
}

void fragment() {
	vec4 c = texture(albedo_tex, UV);
	if (c.b > 0.99 && min(c.r, c.g) > glass_min && ly > glass_y && abs(ny) < 0.85) {   // 앞·뒤 유리는 기울어 있다(위를 0.6~0.8 본다)
		discard;
	}
	ALBEDO = c.rgb;
	ROUGHNESS = 1.0;
}
