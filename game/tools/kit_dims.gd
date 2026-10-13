extends SceneTree
## 팩 모델 치수(AABB) — 이름 크기 원점
func _init() -> void:
	for dir in (OS.get_cmdline_user_args() if not OS.get_cmdline_user_args().is_empty() else ["roads", "suburban", "commercial"]):
		var d := DirAccess.open("res://assets/models/kenney/" + dir)
		for f in d.get_files():
			if not f.ends_with(".glb"): continue
			var n: Node3D = (load("res://assets/models/kenney/%s/%s" % [dir, f]) as PackedScene).instantiate()
			var ab := AABB(); var first := true
			for m in n.find_children("*", "MeshInstance3D", true, false):
				var a: AABB = (m as MeshInstance3D).get_aabb()
				var xf := Transform3D(); var p: Node = m
				while p != n and p != null: xf = (p as Node3D).transform * xf; p = p.get_parent()
				a = xf * a
				ab = a if first else ab.merge(a); first = false
			print("DIM %s/%s pos=%s size=%s" % [dir, f.get_basename(), str(ab.position.snapped(Vector3.ONE * 0.01)), str(ab.size.snapped(Vector3.ONE * 0.01))])
			n.free()
	quit()
