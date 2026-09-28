class_name Prop
extends Node2D
## 소품 하나 — assets/svg/<category>/<name>.svg 를 발끝(원점) 기준으로 그린다. 무대 좌표(x, d)에서 화면 위치·크기는 Stage 가 정한다.
## 에셋이 없으면 이름표가 붙은 상자를 그려서 빠진 게 눈에 띄게 한다(조용히 사라지지 않는다).

@export var asset: String = "props/bench":
	set(v):
		asset = v
		_load()
@export var d: float = 0.5
@export var x: float = 0.0
@export var flip: bool = false

var _tex: Texture2D
var _missing := false

func _ready() -> void:
	_load()
	place()

func _load() -> void:
	var p := "res://assets/svg/%s.svg" % asset
	_tex = load(p) if ResourceLoader.exists(p) else null
	_missing = _tex == null
	queue_redraw()

## 무대 좌표 → 화면. 뒤에 있는 것이 먼저 그려지도록 z_index 는 깊이
func place() -> void:
	var s := Stage.ds(d)
	scale = Vector2(-s if flip else s, s)
	position = Vector2(x, Stage.dy(d))
	z_index = int(d * 100.0) - 1

func _draw() -> void:
	if _tex:
		var sz := _tex.get_size()
		draw_texture(_tex, Vector2(-sz.x / 2.0, -sz.y))
	else:
		draw_rect(Rect2(-20, -40, 40, 40), Color("efe9e2"))
		draw_rect(Rect2(-20, -40, 40, 40), Color("ad7096"), false, 1.6)
		draw_line(Vector2(-20, -40), Vector2(20, 0), Color("ad7096"), 1.6)
		draw_line(Vector2(-20, 0), Vector2(20, -40), Color("ad7096"), 1.6)
