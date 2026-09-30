class_name Figure
extends Node2D
## 졸라맨 — 발끝이 원점. site/src/lib/stickman.ts 의 이식(좌표·길이·위상 그대로).
## 관절: 엉덩이(0,-16) · 어깨(0,-34) · 머리(0,-42). face 는 draw 변환으로 뒤집고, 깊이 배율은 노드 scale 로 준다.
## 자세 이름은 웹과 같다(6자 이하). 여기 없는 이름은 'stand' 로 그린다 — 새 자세는 여기 match 에 한 가지씩 더한다.

@export var pose: String = "stand"
@export var face: int = 1
@export var color: Color = Color("1b0c15")
@export var arms: bool = false
## 초 단위 시간 — 걸음·숨쉬기 위상. 방(멀티)에서는 벽시계로 맞춘다
var t: float = 0.0

const LW := 2.4
const THIGH := 11.0
const SHIN := 10.0
const UPPER := 9.0
const FORE := 9.0
const D := PI / 2.0
const SEATED := ["sit", "seat", "swing", "eat"]

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

static func seg(p: Vector2, len: float, ang: float) -> Vector2:
	return p + Vector2(cos(ang), sin(ang)) * len

func _ln(a: Vector2, b: Vector2, c = null) -> void:
	draw_line(a, b, color, LW, true)
	if c != null:
		draw_line(b, c, color, LW, true)

func _head(p: Vector2) -> void:
	draw_circle(p, 7.0, color)

func _legs_stand(hip: Vector2) -> void:
	_ln(hip, Vector2(-4, -8), Vector2(-5, 0))
	_ln(hip, Vector2(4, -8), Vector2(5, 0))

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(float(face), 1.0))
	var hip := Vector2(0, -16)
	var shoulder := Vector2(0, -34)
	var head := Vector2(0, -42)
	match pose:
		"run":
			var ph := t * 13.0
			var sw := sin(ph)
			var cw := cos(ph)
			var bob := absf(cw) * 2.6
			var lean := 0.32
			hip = Vector2(0, -16 - bob)
			shoulder = seg(hip, 18.0, -D + lean)
			head = seg(shoulder, 8.0, -D + lean)
			_ln(hip, shoulder)
			for side: float in [1.0, -1.0]:
				var a := D + side * sw * 0.9
				var knee := seg(hip, THIGH, a)
				var bend := 1.4 if side * sw < 0.0 else 0.2
				_ln(hip, knee, seg(knee, SHIN, a + bend))
			for side: float in [1.0, -1.0]:
				var a := D - side * sw * 1.05 + lean
				var elbow := seg(shoulder, UPPER, a)
				_ln(shoulder, elbow, seg(elbow, FORE, a - 1.7))
			_head(head)
		"charge":
			hip = Vector2(0, -11); shoulder = Vector2(3, -27); head = Vector2(4, -35)
			_ln(hip, shoulder)
			_ln(hip, Vector2(7, -6), Vector2(5, 0)); _ln(hip, Vector2(-5, -6), Vector2(-6, 0))
			_ln(shoulder, Vector2(-2, -20), Vector2(-6, -12)); _ln(shoulder, Vector2(8, -21), Vector2(10, -13))
			_head(head)
		"jump":
			hip = Vector2(0, -18); shoulder = Vector2(1, -36); head = Vector2(2, -44)
			_ln(hip, shoulder)
			_ln(hip, Vector2(7, -12), Vector2(4, -4)); _ln(hip, Vector2(-2, -10), Vector2(-6, -2))
			_ln(shoulder, Vector2(7, -44), Vector2(10, -52)); _ln(shoulder, Vector2(-6, -42), Vector2(-8, -50))
			_head(head)
		"fall", "hurt":
			var fl := sin(t * 22.0) * 0.5
			hip = Vector2(0, -16); shoulder = Vector2(-1, -34); head = Vector2(-2, -42)
			_ln(hip, shoulder)
			_ln(hip, Vector2(8, -6), Vector2(10, 2)); _ln(hip, Vector2(-9, -8), Vector2(-12, 0))
			_ln(shoulder, seg(shoulder, 8.0, -D - 0.6 + fl), seg(shoulder, 15.0, -D - 0.9 + fl))
			_ln(shoulder, seg(shoulder, 8.0, -D + 0.9 - fl), seg(shoulder, 15.0, -D + 1.3 - fl))
			_head(head)
			if pose == "hurt":
				draw_arc(head, 12.0, 0.0, TAU, 24, Color("ff2d55"), LW, true)
		"punch":
			hip = Vector2(0, -16); shoulder = Vector2(4, -34); head = Vector2(5, -42)
			_ln(hip, shoulder)
			_ln(hip, Vector2(-7, -8), Vector2(-9, 0)); _ln(hip, Vector2(8, -8), Vector2(10, 0))
			_ln(shoulder, Vector2(12, -34), Vector2(24, -35))
			_ln(shoulder, Vector2(-4, -28), Vector2(-8, -22))
			_head(head)
		"kick":
			hip = Vector2(0, -16); shoulder = Vector2(-5, -34); head = Vector2(-6, -42)
			_ln(hip, shoulder)
			_ln(hip, Vector2(-4, -8), Vector2(-6, 0))
			_ln(hip, Vector2(10, -18), Vector2(24, -20))
			_ln(shoulder, Vector2(-12, -30), Vector2(-16, -22)); _ln(shoulder, Vector2(3, -30), Vector2(8, -26))
			_head(head)
		"throw":
			var p := fmod(t * 3.3, 1.0)
			var back := p < 0.45
			hip = Vector2(-3, -16) if back else Vector2(3, -16)
			shoulder = Vector2(-8, -33) if back else Vector2(7, -33)
			head = Vector2(-9, -41) if back else Vector2(10, -40)
			_ln(hip, shoulder)
			_ln(hip, Vector2(-9, -8), Vector2(-12, 0)); _ln(hip, Vector2(6, -8), Vector2(9, 0))
			if back:
				_ln(shoulder, Vector2(-16, -40), Vector2(-22, -50)); _ln(shoulder, Vector2(0, -28), Vector2(4, -22))
			else:
				_ln(shoulder, Vector2(16, -38), Vector2(26, -44)); _ln(shoulder, Vector2(-2, -28), Vector2(-6, -20))
			_head(head)
		"trip":
			hip = Vector2(-2, -7); shoulder = Vector2(-16, -6); head = Vector2(-23, -5)
			_ln(hip, shoulder)
			_ln(hip, Vector2(7, -16), Vector2(12, -24)); _ln(hip, Vector2(4, -14), Vector2(7, -22))
			_ln(shoulder, Vector2(-20, -12), Vector2(-26, -18)); _ln(shoulder, Vector2(-18, 0), Vector2(-12, 5))
			_head(head)
		"swim":
			# 헤엄(크롤) — stickman.ts 와 같은 점
			var a := t * 5.0; var k := sin(t * 9.0) * 2.0
			_ln(Vector2(-2, -3), Vector2(22, -5))
			_ln(Vector2(-2, -3), Vector2(-10, -2 + k), Vector2(-19, -1 - k)); _ln(Vector2(-2, -3), Vector2(-10, -4 - k), Vector2(-19, -5 + k))
			var s1 := seg(Vector2(22, -5), 9.0, a); var s2 := seg(Vector2(22, -5), 9.0, a + PI)
			_ln(Vector2(22, -5), s1, seg(s1, 8.0, a + 0.6)); _ln(Vector2(22, -5), s2, seg(s2, 8.0, a + PI + 0.6))
			_head(Vector2(30, -9))
		"sky":
			# 풀밭에 누워 하늘 보기 — 한 무릎 세우고 두 손은 머리 뒤
			var br := sin(t * 1.6) * 0.8
			_ln(Vector2(-2, -4), Vector2(-24, -5 - br))
			_ln(Vector2(-2, -4), Vector2(8, -5), Vector2(18, -3)); _ln(Vector2(-2, -4), Vector2(6, -12), Vector2(14, -3))
			_ln(Vector2(-24, -5 - br), Vector2(-20, -13 - br), Vector2(-31, -12 - br)); _ln(Vector2(-24, -5 - br), Vector2(-26, -13 - br), Vector2(-35, -10 - br))
			_head(Vector2(-33, -9 - br))
		"pet":
			# 쓰다듬기 — stickman.ts 와 같은 점
			var st := sin(t * 5.5) * 3.0
			hip = Vector2(-2, -9); shoulder = Vector2(5, -24); head = Vector2(8, -31)
			_ln(hip, shoulder)
			_ln(hip, Vector2(7, -11), Vector2(5, 0)); _ln(hip, Vector2(3, -12), Vector2(1, 0))
			_ln(shoulder, Vector2(12 + st, -16), Vector2(16 + st, -7)); _ln(shoulder, Vector2(2, -18), Vector2(6, -12))
			_head(head)
		"sit":
			var br := sin(t * 1.6) * 0.8
			_ln(Vector2(-2, -4), Vector2(-24, -5 - br))
			_ln(Vector2(-2, -4), Vector2(8, -5), Vector2(18, -3))
			_ln(Vector2(-2, -4), Vector2(6, -9), Vector2(14, -3))
			_ln(Vector2(-24, -5 - br), Vector2(-18, -11 - br), Vector2(-30, -12 - br))
			_ln(Vector2(-24, -5 - br), Vector2(-14, -7 - br))
			_head(Vector2(-33, -9 - br))
		"seat", "eat":
			var br := sin(t * 1.6) * 0.6
			hip = Vector2(0, -15); shoulder = Vector2(-1, -33 - br); head = Vector2(-1, -41 - br)
			_ln(hip, shoulder)
			_ln(hip, Vector2(11, -15), Vector2(12, 0)); _ln(hip, Vector2(9, -14), Vector2(8, 0))
			_ln(shoulder, Vector2(3, -26 - br), Vector2(10, -18 - br))
			if pose == "eat":
				var m := (sin(t * 4.0) + 1.0) / 2.0
				_ln(shoulder, Vector2(6, -28 - br), Vector2(10 - m * 5, -18 - m * 18 - br))
			else:
				_ln(shoulder, Vector2(1, -27 - br), Vector2(8, -19 - br))
			_head(head)
		"chew":
			var m := (sin(t * 4.0) + 1.0) / 2.0
			head = Vector2(1, -42)
			_ln(hip, shoulder); _legs_stand(hip)
			_ln(shoulder, Vector2(7, -29), Vector2(9 - m * 5, -22 - m * 15)); _ln(shoulder, Vector2(-5, -26), Vector2(-6, -18))
			_head(head)
		"read":
			shoulder = Vector2(1, -34); head = Vector2(4, -41)
			_ln(hip, shoulder); _legs_stand(hip)
			_ln(shoulder, Vector2(7, -28), Vector2(11, -31)); _ln(shoulder, Vector2(5, -27), Vector2(11, -29))
			draw_rect(Rect2(9, -36, 9, 8), color, false, 1.6)
			_head(head)
		"lean":
			var br := sin(t * 1.4) * 0.5
			hip = Vector2(3, -16); shoulder = Vector2(-3, -34 - br); head = Vector2(-4, -42 - br)
			_ln(hip, shoulder)
			_ln(hip, Vector2(9, -7), Vector2(12, 1)); _ln(hip, Vector2(-6, -9), Vector2(-14, -6))
			_ln(shoulder, Vector2(4, -27 - br), Vector2(-5, -25 - br)); _ln(shoulder, Vector2(-9, -27 - br), Vector2(-1, -26 - br))
			_head(head)
		"watch":
			var nod := sin(t * 1.3) * 1.2
			head = Vector2(3, -41 + nod)
			_ln(hip, shoulder); _legs_stand(hip)
			_ln(shoulder, Vector2(6, -28), Vector2(-3, -25)); _ln(shoulder, Vector2(-5, -28), Vector2(4, -25))
			_head(head)
		"phone":
			head = Vector2(2, -42)
			_ln(hip, shoulder); _legs_stand(hip)
			_ln(shoulder, Vector2(7, -29), Vector2(6, -40)); _ln(shoulder, Vector2(-5, -27), Vector2(-3, -20))
			_head(head)
		"water":
			shoulder = Vector2(8, -30); head = Vector2(13, -36)
			_ln(hip, shoulder)
			_ln(hip, Vector2(-4, -8), Vector2(-5, 0)); _ln(hip, Vector2(5, -8), Vector2(6, 0))
			_ln(shoulder, Vector2(15, -24), Vector2(18, -16)); _ln(shoulder, Vector2(4, -24), Vector2(6, -18))
			draw_polyline(PackedVector2Array([Vector2(15, -16), Vector2(25, -16), Vector2(23, -8), Vector2(17, -8), Vector2(15, -16)]), color, LW, true)
			for k in 3:
				var p := fmod(t * 2.0 + float(k) / 3.0, 1.0)
				draw_circle(Vector2(27 + k * 3, -10 + p * 10), 1.4, Color("8fb8cc"))
			_head(head)
		"knead":
			var pr := (sin(t * 7.0) + 1.0) / 2.0
			shoulder = Vector2(6, -31); head = Vector2(9, -38)
			_ln(hip, shoulder)
			_ln(hip, Vector2(-4, -8), Vector2(-5, 0)); _ln(hip, Vector2(5, -8), Vector2(6, 0))
			_ln(shoulder, Vector2(13, -25 + pr * 2.0), Vector2(17, -18 + pr * 3.0)); _ln(shoulder, Vector2(11, -25 + (1.0 - pr) * 2.0), Vector2(15, -18 + (1.0 - pr) * 3.0))
			draw_line(Vector2(10, -14), Vector2(26, -14), color, 1.6, true)
			draw_circle(Vector2(17, -16.5 + pr), 3.2 - pr * 0.6, Color("e6d3a5"))
			_head(head)
		"hammer":
			# 망치질(run 80, 구두장이 작업대) — 3D 는 stick3d_poses.gd hammer: 한 바퀴 1.5초(0.3 든다 · 0.3 씩 세 번 두드림 · 0.3 내린다). 왼손은 구두골 위 구두, 오른손 망치
			var c := fmod(t, 1.5)
			var tap := 0.6 if c < 0.3 or c > 1.2 else sin(fmod(c - 0.3, 0.3) / 0.3 * PI)
			shoulder = Vector2(5, -31); head = Vector2(8, -38)
			_ln(hip, shoulder); _legs_stand(hip)
			_ln(shoulder, Vector2(11, -25), Vector2(16, -19))
			var hand := Vector2(14 - tap * 2.0, -20 - tap * 9.0)
			_ln(shoulder, Vector2(12, -27 - tap * 4.0), hand)
			draw_line(hand, hand + Vector2(4, 2 - tap * 3.0), color, 1.6, true)
			draw_line(Vector2(12, -17), Vector2(22, -17), color, 1.6, true)
			draw_rect(Rect2(Vector2(14, -19.5), Vector2(6, 2.5)), Color("ad7096"))
			_head(head)
		"shade":
			# 손차양(run 73, 전망 자리) — stickman.ts 'shade' 와 같은 수: 6초 한 바퀴, 0.35 손이 이마로(예비) · 둘러보기(유지, 고개·어깨가 천천히 좌우) · 끝 0.4 내린다(회수)
			var c := fmod(t, 6.0)
			var k := (c / 0.35) if c < 0.35 else ((1.0 - (c - 5.6) / 0.4) if c > 5.6 else 1.0)
			var g := sin(t * 0.9) * 3.0 * k
			shoulder = Vector2(g * 0.4, -34); head = Vector2(g, -42)
			_ln(hip, shoulder)
			_ln(hip, Vector2(-4, -8), Vector2(-5, 0)); _ln(hip, Vector2(5, -9 + k), Vector2(4, 0))
			_ln(shoulder, Vector2(-5 - 3 * k, -26 - k), Vector2(-6 + 3 * k, -18 - k))
			_ln(shoulder, Vector2(5 + 5 * k, -26 - 15 * k), Vector2(6 + (g - 3) * k, -18 - 30 * k))
			_head(head)
		"storm":
			# 처마 밑 비 구경(run 74, 비 오는 문 앞) — stickman.ts 'storm' 과 같은 수: 3초 한 바퀴, 0.3 고개가 하늘로 · 1초 본다(꼭대기에서 어깨 으쓱) · 0.4 내린다 · 나머지는 앞의 비. 팔짱
			var c := fmod(t, 3.0)
			var k := (c / 0.3) if c < 0.3 else (1.0 if c < 1.3 else ((1.0 - (c - 1.3) / 0.4) if c < 1.7 else 0.0))
			var sg := maxf(0.0, 1.0 - absf(c - 0.8) / 0.5)
			hip = Vector2(-1, -16); shoulder = Vector2(-2, -34 - sg * 1.5); head = Vector2(-2 + 3 * k, -42 - 3 * k - sg * 1.5)
			_ln(hip, shoulder); _ln(hip, Vector2(-4, -8), Vector2(-5, 0)); _ln(hip, Vector2(4, -8), Vector2(5, 0))
			_ln(shoulder, Vector2(7 + sg, -27 - sg * 1.5), Vector2(-4, -24 - sg * 1.5)); _ln(shoulder, Vector2(-8 - sg, -27 - sg * 1.5), Vector2(3, -24 - sg * 1.5))
			_head(head)
		"umbr":
			# 우산(run 76, 카페 옆 우산꽂이) — stickman.ts 'umbr' 과 같은 수: 0.3초에 걸쳐 오른팔이 머리 위로 오르고 캐노피가 펴진다(예비) · 든 채(유지, 살짝 흔들림) · 접힘은 거꾸로(회수). 3D 는 stick3d_poses.gd umbr
			var k := minf(1.0, t / 0.3); var sw := sin(t * 1.3) * 1.5 * k
			_ln(hip, shoulder); _legs_stand(hip)
			_ln(shoulder, Vector2(-5, -26), Vector2(-6, -18))
			var hd := Vector2(4 + 4 * k, -18 - 30 * k)
			_ln(shoulder, Vector2(6 + 2 * k, -26 - 12 * k), hd)
			var c := Vector2(hd.x + sw * 0.3, hd.y - 14 * k); var r := 2 + 14 * k
			draw_line(hd, c, color, 1.6, true)
			var pts := PackedVector2Array()
			for i in 13: pts.append(c + Vector2(cos(PI + i * PI / 12.0), sin(PI + i * PI / 12.0)) * r)
			draw_colored_polygon(pts, Color("ad7096")); draw_polyline(pts, color, LW, true)
			_head(head)
		"sweep":
			var p := sin(t * 5.0) * 6.0
			shoulder = Vector2(6, -31); head = Vector2(9, -39)
			_ln(hip, shoulder)
			_ln(hip, Vector2(-5, -8), Vector2(-7, 0)); _ln(hip, Vector2(5, -8), Vector2(6, 0))
			_ln(shoulder, Vector2(11 + p * 0.5, -26), Vector2(13 + p, -22)); _ln(shoulder, Vector2(9 + p * 0.5, -22), Vector2(16 + p, -16))
			draw_line(Vector2(9 + p, -28), Vector2(24 + p, 4), color, 1.6, true)
			draw_colored_polygon(PackedVector2Array([Vector2(20 + p, 2), Vector2(30 + p, 0), Vector2(27 + p, 6), Vector2(19 + p, 7)]), color)
			_head(head)
		"shake":
			var sw := sin(t * 9.0) * 4.0
			hip = Vector2(sw * 0.3, -16); shoulder = Vector2(sw * 0.6, -34); head = Vector2(sw * 0.7, -42)
			_ln(hip, shoulder); _legs_stand(hip)
			_ln(shoulder, Vector2(10 + sw, -44), Vector2(15 + sw, -53)); _ln(shoulder, Vector2(-9 + sw, -44), Vector2(-14 + sw, -53))
			for k in 3:
				var p := fmod(t * 2.2 + float(k) / 3.0, 1.0)
				draw_circle(Vector2(6 - k * 6, -50 + p * 42), 1.6, Color("7a9b4e"))
			_head(head)
		"brace":
			var br := sin(t * 3.0) * 0.6
			hip = Vector2(-2, -14); shoulder = Vector2(-5, -31); head = Vector2(-6, -39)
			_ln(hip, shoulder)
			_ln(hip, Vector2(9, -5), Vector2(15, 2)); _ln(hip, Vector2(-10, -6), Vector2(-15, 0))
			_ln(shoulder, Vector2(4, -24 + br), Vector2(9, -19 + br)); _ln(shoulder, Vector2(-1, -23 + br), Vector2(4, -18 + br))
			_head(head)
		"catch":
			hip = Vector2(0, -14); shoulder = Vector2(0, -31); head = Vector2(0, -39)
			_ln(hip, shoulder)
			_ln(hip, Vector2(-6, -7), Vector2(-8, 0)); _ln(hip, Vector2(6, -7), Vector2(8, 0))
			_ln(shoulder, Vector2(8, -42), Vector2(11, -52)); _ln(shoulder, Vector2(-8, -42), Vector2(-11, -52))
			_head(head)
		"lwave":
			# 왼손 인사(run 77, 우산 가족의 두 번째 자세) — stickman.ts 'lwave' 와 같은 수: 오른손은 편 우산을 든 채(umbr k=1), 왼팔이 0.2초에 오르고(예비) · 흔들고(유지) · 마지막 0.3초 내린다(회수). 3D 는 stick3d_poses.gd lwave
			var k := 0.0 if t >= 1.4 else (t / 0.2 if t < 0.2 else (1.0 - (t - 1.1) / 0.3 if t > 1.1 else 1.0))
			var p := sin(t * 9.0) * 7.0 * k; var sw := sin(t * 1.3) * 1.5
			_ln(hip, shoulder); _legs_stand(hip)
			_ln(shoulder, Vector2(-5 - k, -26 - 14 * k), Vector2(-6 - 2 * k - p, -18 - 32 * k))
			var hd := Vector2(8, -48)
			_ln(shoulder, Vector2(8, -38), hd)
			var c := Vector2(hd.x + sw * 0.3, -62.0); var r := 16.0
			draw_line(hd, c, color, 1.6, true)
			var pts := PackedVector2Array()
			for i in 13: pts.append(c + Vector2(cos(PI + i * PI / 12.0), sin(PI + i * PI / 12.0)) * r)
			draw_colored_polygon(pts, Color("ad7096")); draw_polyline(pts, color, LW, true)
			_head(head)
		"row":
			# 노 젓기(run 78, 거룻배) — stickman.ts 'row' 와 같은 수: 한 번 1.2초(0.5 젓기 · 0.7 회수), 캐치(k 0: 팔 앞으로 쭉·몸 앞)에서 피니시(k 1: 손 가슴·몸 뒤)로. 노는 손에서 물로. 3D 는 stick3d_poses.gd row
			var c := fmod(t, 1.2)
			var k := smoothstep(0.0, 1.0, c / 0.5) if c < 0.5 else 1.0 - smoothstep(0.0, 1.0, (c - 0.5) / 0.7)
			var lean := 0.35 - 0.65 * k
			hip = Vector2(0, -13); shoulder = seg(hip, 18.0, -D + lean); head = seg(shoulder, 8.0, -D + lean)
			_ln(hip, shoulder)
			for side: float in [1.0, -1.0]:
				var knee := seg(hip + Vector2(0, side), THIGH, D - (1.2 - 0.2 * k))
				_ln(hip + Vector2(0, side), knee, seg(knee, SHIN, D - (0.54 + 0.3 * k)))
			var el := seg(shoulder, UPPER, D - (1.4 - 1.05 * k)); var hd := seg(el, FORE, D - (1.55 + 0.7 * k))
			_ln(shoulder, el, hd)
			draw_line(hd, Vector2(hd.x - 14.0 + 20.0 * k, 3.0), color, 1.6, true)   # 노: 캐치엔 뱃머리(뒤) 쪽, 피니시엔 고물(앞) 쪽
			_head(head)
		"wave":
			var p := sin(t * 9.0) * 7.0
			_ln(hip, shoulder); _legs_stand(hip)
			_ln(shoulder, Vector2(6, -40), Vector2(8 + p, -50)); _ln(shoulder, Vector2(-5, -26), Vector2(-6, -18))
			_head(head)
		"laugh":
			var p := sin(t * 16.0) * 1.5
			shoulder = Vector2(p, -33); head = Vector2(-4, -45)
			_ln(hip, shoulder); _legs_stand(hip)
			_ln(shoulder, Vector2(8, -29), Vector2(12, -23)); _ln(shoulder, Vector2(-8, -29), Vector2(-12, -23))
			_head(head)
		"shrug":
			var p := (sin(t * 3.0) + 1.0) / 2.0
			shoulder = Vector2(0, -34 - p * 2); head = Vector2(0, -42 - p * 2)
			_ln(hip, shoulder); _legs_stand(hip)
			_ln(shoulder, Vector2(7, -30 - p * 4), Vector2(10, -24 - p * 2)); _ln(shoulder, Vector2(-7, -30 - p * 4), Vector2(-10, -24 - p * 2))
			_head(head)
		"yawn":
			head = Vector2(3, -45)
			_ln(hip, shoulder); _legs_stand(hip)
			_ln(shoulder, Vector2(7, -32), Vector2(12, -41)); _ln(shoulder, Vector2(-5, -26), Vector2(-6, -18))
			_head(head)
		"stretch":
			var p := sin(t * 2.0) * 1.5
			hip = Vector2(1, -16); shoulder = Vector2(2, -33 + p); head = Vector2(3, -42 + p)
			_ln(hip, shoulder); _legs_stand(hip)
			_ln(shoulder, Vector2(9, -44 + p), Vector2(12, -53 + p)); _ln(shoulder, Vector2(-5, -44 + p), Vector2(-8, -53 + p))
			_head(head)
		"look":
			var g := sin(t * 2.2) * 4.0
			head = Vector2(g, -42)
			_ln(hip, shoulder); _legs_stand(hip)
			_ln(shoulder, Vector2(-5, -26), Vector2(-6, -18)); _ln(shoulder, Vector2(5, -26), Vector2(6, -18))
			_head(head)
		"dance":
			var step := sin(t * 3.0) * 5.0
			var spin := sin(t * 1.5) * 4.0
			hip = Vector2(step * 0.3, -16); shoulder = Vector2(step * 0.4 + spin, -34); head = Vector2(step * 0.4 + spin, -42)
			_ln(hip, shoulder)
			_ln(hip, Vector2(7 + step, -8), Vector2(9 + step, 0)); _ln(hip, Vector2(-7 + step, -8), Vector2(-9 + step, 0))
			_ln(shoulder, Vector2(13, -30), Vector2(17, -25)); _ln(shoulder, Vector2(-13, -30), Vector2(-17, -25))
			_head(head)
		"yoga":
			var b := sin(t * 1.2) * 1.5
			hip = Vector2(0, -18 + b * 0.2); shoulder = Vector2(10, -10 + b); head = Vector2(16, -4 + b)
			_ln(hip, shoulder); _legs_stand(hip)
			_ln(shoulder, Vector2(16, -2 + b), Vector2(22, 6 + b)); _ln(shoulder, Vector2(16, -2 + b), Vector2(10, 8 + b))
			_head(head)
		_:
			# 서 있음: 숨 쉬듯 미세하게, 팔짱(arms) 이면 앞으로
			var br := sin(t * 2.0) * 0.6
			shoulder = Vector2(0, -34 - br); head = Vector2(0, -42 - br)
			_ln(hip, shoulder); _legs_stand(hip)
			if arms:
				_ln(shoulder, Vector2(7, -28), Vector2(-3, -25)); _ln(shoulder, Vector2(-6, -28), Vector2(4, -26))
			else:
				_ln(shoulder, Vector2(-5, -26), Vector2(-6, -18)); _ln(shoulder, Vector2(5, -26), Vector2(6, -18))
			_head(head)
