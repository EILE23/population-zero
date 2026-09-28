class_name Stage
extends Node2D
## 2.5D 무대 — 웹 엔진(site/src/features/games/engine/scene.ts)과 같은 셈법.
## 깊이 d(0=뒤, 1=앞)를 화면 y 와 크기로 바꾼다. 숫자를 바꾸면 웹과 게임이 서로 다른 세계가 되니 바꾸지 않는다.

const W := 960.0
const H := 470.0
const GROUND := 330.0
const DEPTH := 130.0

## 깊이 → 발끝 y
static func dy(d: float) -> float:
	return GROUND - DEPTH + d * DEPTH

## 깊이 → 크기 배율(뒤 0.7 ~ 앞 1.0)
static func ds(d: float) -> float:
	return 0.7 + 0.3 * d

## 무대 거리 — 깊이 차이는 400px 로 친다
static func dist(ax: float, ad: float, bx: float, bd: float) -> float:
	return Vector2(ax - bx, (ad - bd) * 400.0).length()

## 카메라를 목표에 부드럽게, 지도 폭 안에서
static func follow(cam: float, target_x: float, world_w: float, dt: float) -> float:
	var want := clampf(target_x - W / 2.0, 0.0, maxf(0.0, world_w - W))
	return cam + (want - cam) * minf(1.0, dt * 6.0)

@export var floor_back: Color = Color("cfc7c2")
@export var floor_front: Color = Color("e6e0da")
@export var world_w: float = 3200.0

func _draw() -> void:
	# 바닥 띠 — 뒤에서 앞으로 밝아진다(웹 광장의 floor 두 색)
	var top := GROUND - DEPTH
	var steps := 8
	for i in steps:
		var t0 := float(i) / steps
		var t1 := float(i + 1) / steps
		var c := floor_back.lerp(floor_front, t0)
		draw_rect(Rect2(0.0, top + t0 * DEPTH, W, (t1 - t0) * DEPTH + 1.0), c)
	# 뒤쪽 벽 선
	draw_line(Vector2(0.0, top), Vector2(W, top), Color("bfb6b0"), 1.0, true)
