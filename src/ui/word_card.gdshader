shader_type canvas_item;
// 단어 카드 바탕: 속성 1~3개의 색을 대각선 띠로 나누고 경계는 그라데이션. 둥근 모서리와 테두리도 여기서 그린다.

uniform vec4 c0 : source_color = vec4(1.0);
uniform vec4 c1 : source_color = vec4(1.0);
uniform vec4 c2 : source_color = vec4(1.0);
uniform int n = 1;
uniform vec2 size = vec2(200.0, 60.0);
uniform float radius = 18.0;
uniform float border = 3.0;
uniform vec4 border_color : source_color = vec4(0.294, 0.247, 0.447, 1.0);
uniform float blend = 0.07;

void fragment() {
	vec2 p = UV * size;
	float u = (p.x + p.y) / (size.x + size.y);  // 왼쪽 위 0 → 오른쪽 아래 1, 경계선은 대각선
	vec4 col = c0;
	if (n == 2) {
		col = mix(c0, c1, smoothstep(0.5 - blend, 0.5 + blend, u));
	} else if (n >= 3) {
		col = mix(c0, c1, smoothstep(1.0 / 3.0 - blend, 1.0 / 3.0 + blend, u));
		col = mix(col, c2, smoothstep(2.0 / 3.0 - blend, 2.0 / 3.0 + blend, u));
	}
	vec2 h = size * 0.5;
	vec2 q = abs(p - h) - (h - vec2(radius));
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	float inside = 1.0 - smoothstep(-0.5, 0.5, d);
	float edge = smoothstep(-border - 0.5, -border + 0.5, d);
	COLOR = vec4(mix(col.rgb, border_color.rgb, edge), inside);
}
