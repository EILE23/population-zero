extends SceneTree
## 물리 틱 하나의 값 — 물리만 따로 재기(_physics_process 가 맨 앞·맨 뒤인 두 노드), 그리고 vsync 켠 채 fps
var t0 := 0
var acc := 0.0
var n := 0
class Head extends Node:
	var o
	func _physics_process(_d: float) -> void: o.t0 = Time.get_ticks_usec()
class Tail extends Node:
	var o
	func _physics_process(_d: float) -> void: o.acc += Time.get_ticks_usec() - o.t0; o.n += 1
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 60: await process_frame
	while not town._due.is_empty(): await process_frame
	for i in 120: await process_frame
	var h := Head.new(); h.o = self; h.process_physics_priority = -1000; root.add_child(h)
	var t := Tail.new(); t.o = self; t.process_physics_priority = 1000; root.add_child(t)
	var a := Time.get_ticks_usec()
	for i in 240: await process_frame
	print("PP scripts per physics tick %.2f ms, ticks/frame %.2f, frame %.1f ms fps=%d" % [acc / n / 1000.0, n / 240.0, (Time.get_ticks_usec() - a) / 240000.0, Engine.get_frames_per_second()])
	var cnt := {}
	var stack: Array = [town]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		if nd.is_physics_processing() and nd.get_script():
			var k: String = (nd.get_script() as Script).resource_path.get_file()
			cnt[k] = int(cnt.get(k, 0)) + 1
		stack.append_array(nd.get_children())
	print("PP physics nodes ", cnt)
	for k in ["car3d.gd"]:
		var cars: Array = town.cars
		var a3 := Time.get_ticks_usec()
		for c in cars: c._physics_process(1.0 / 60.0)
		print("PP cars %d one tick %.2f ms" % [cars.size(), (Time.get_ticks_usec() - a3) / 1000.0])
	for step in ["residents", "cars", "town"]:
		if step == "residents":
			for r in town.residents: r.set_physics_process(false)
		elif step == "cars":
			for c in town.cars: c.set_physics_process(false)
		else: town.set_physics_process(false)
		acc = 0.0; n = 0
		for i in 120: await process_frame
		print("PP without %s: %.2f ms per tick" % [step, acc / maxi(n, 1) / 1000.0])
	var a2 := Time.get_ticks_usec(); var f0 := Engine.get_physics_frames()
	for i in 240: await physics_frame
	print("PP physics frame wall %.1f ms" % ((Time.get_ticks_usec() - a2) / 240000.0))
	quit()
