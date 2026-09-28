extends Node2D
## 에셋 갤러리 — assets/manifest.json 의 모든 것을 종류별로 한 줄씩 늘어놓는다. 새 에셋이 다른 것들 옆에서 어떻게 보이는지 확인하는 씬.
## ← → 로 가로 스크롤, ↑ ↓ 로 줄 이동. 사람 크기 비교용으로 각 줄 맨 앞에 서 있는 졸라맨을 둔다.

const ROW_H := 300.0
const PAD := 40.0
var cam := Vector2.ZERO
var rows: Array[String] = []

func _ready() -> void:
	var f := FileAccess.open("res://assets/manifest.json", FileAccess.READ)
	if f == null:
		push_error("gallery: assets/manifest.json missing — run `node game/tools/assets.mjs`")
		return
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var by_cat := {}
	for a in data.get("assets", []):
		var cat: String = a["cat"]
		if not by_cat.has(cat):
			by_cat[cat] = []
			rows.append(cat)
		by_cat[cat].append(a)
	var world := $World
	var y := 0.0
	for cat in rows:
		var label := Label.new()
		label.text = cat
		label.position = Vector2(PAD, y + 12)
		label.add_theme_color_override("font_color", Color("5b4f56"))
		label.add_theme_font_size_override("font_size", 12)
		world.add_child(label)
		var ref := Figure.new()
		ref.position = Vector2(PAD + 30, y + ROW_H - PAD)
		ref.arms = true
		world.add_child(ref)
		var x := PAD + 90.0
		for a in by_cat[cat]:
			var p := Prop.new()
			p.asset = a["id"]
			p.position = Vector2(x + float(a["w"]) / 2.0, y + ROW_H - PAD)
			world.add_child(p)
			var name_lbl := Label.new()
			name_lbl.text = a["name"]
			name_lbl.position = Vector2(x, y + ROW_H - PAD + 6)
			name_lbl.add_theme_color_override("font_color", Color("8a7f86"))
			name_lbl.add_theme_font_size_override("font_size", 10)
			world.add_child(name_lbl)
			x += float(a["w"]) + PAD
		y += ROW_H

func _process(delta: float) -> void:
	var v := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down")) * 600.0 * delta
	cam = Vector2(maxf(0.0, cam.x + v.x), clampf(cam.y + v.y, 0.0, maxf(0.0, rows.size() * ROW_H - 470.0)))
	$World.position = -cam
