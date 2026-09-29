extends SceneTree
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	await process_frame
	var ss: Seesaw3D = town.seesaws[0]; var r = town.residents[5]
	r.spot = { "kind": "seesaw", "ss": ss }; r.state = "busy"; r.busy_until = 1e9
	ss.riders = [null, null]; ss.sit(r, 1); r.riding_seesaw = ss; r.fig.seated = true
	ss.angle = -Seesaw3D.LIMIT; ss.omega = 0.0
	town.body.global_position = ss.global_position + Vector3(-Seesaw3D.L * 0.9, 2.6, 0); town.body.velocity = Vector3.ZERO
	for i in 90:
		await physics_frame
		if i % 6 == 0: print("PROBE f", i, " angle=%.2f omega=%.2f riders=%s rvel=%s ry=%.2f py=%.2f pvy=%.2f floor=%s" % [ss.angle, ss.omega, str(ss.riders), str(r.velocity), r.global_position.y, town.body.global_position.y, town.body.velocity.y, town.body.is_on_floor()])
	quit()
