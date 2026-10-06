extends SceneTree
## 차 안(창 모드) — user://shots/cabin-*.png: 3/4·뒤따라가기·운전석, 경적·전조등·라디오
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 40: await process_frame
	var want := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	var car: Car3D = null; var bd := 1e9
	for c in town.find_children("*", "Car3D", true, false):
		if (c as Car3D).ai: continue
		if want != "" and (c as Car3D).kind != want: continue
		var d: float = (c as Car3D).global_position.distance_to(town.body.global_position)
		if d < bd: bd = d; car = c
	town._enter_car(car, Time.get_ticks_msec() / 1000.0)
	Input.action_press("move_up")
	for i in 60: await physics_frame
	Input.action_release("move_up")
	for v in 3:
		town.car_view = v
		for i in 40: await process_frame
		root.get_texture().get_image().save_png("user://shots/cabin-%s-%d.png" % [want, v])
	town._honk(car); town._set_lights(car, true); town._tune(1)
	for i in 60: await process_frame
	print("CABIN double=%s view=%d lights=%s station=%d speed=%.1f hud=%s" % [town._double != null, town.car_view, town._lights_on, town._station, car.v, town._car_hud.text if town._car_hud else "-"])
	town._exit_car(Time.get_ticks_msec() / 1000.0)
	for i in 10: await process_frame
	print("OUT double=%s station=%d view=%d" % [town._double != null, town._station, town.car_view])
	quit()
