extends SceneTree
## 팩 모델 줄 세워 보기(창 모드) — user://shots/kit-<이름>.png. 인자: 폴더 이름 앞부분들(쉼표)
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else "roads"
	var filt: Array = (args[1] if args.size() > 1 else "").split(",", false)
	var w := Node3D.new(); root.add_child(w)
	var env := WorldEnvironment.new(); env.environment = Environment.new(); env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color("cfe3c0"); env.environment.ambient_light_color = Color.WHITE; env.environment.ambient_light_energy = 0.6; w.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation = Vector3(-0.9, 0.6, 0); sun.shadow_enabled = true; w.add_child(sun)
	var d := DirAccess.open("res://assets/models/kenney/" + dir)
	var i := 0
	var names: Array = []
	for f in d.get_files():
		if not f.ends_with(".glb"): continue
		if not filt.is_empty() and not filt.any(func(p): return f.begins_with(p)): continue
		var n: Node3D = (load("res://assets/models/kenney/%s/%s" % [dir, f]) as PackedScene).instantiate()
		n.position = Vector3((i % 6) * 1.6, 0, (i / 6) * 1.6); w.add_child(n)
		var lb := Label3D.new(); lb.text = f.get_basename(); lb.font_size = 24; lb.pixel_size = 0.004; lb.position = n.position + Vector3(0, 0.05, 0.75); lb.rotation.x = -PI / 2; lb.modulate = Color.BLACK; w.add_child(lb)
		var ax := MeshInstance3D.new(); var am := BoxMesh.new(); am.size = Vector3(0.5, 0.05, 0.05); ax.mesh = am; ax.position = n.position + Vector3(0.25, 0.1, 0); var mr := StandardMaterial3D.new(); mr.albedo_color = Color.RED; ax.material_override = mr; w.add_child(ax)   # +x 빨강
		var az := MeshInstance3D.new(); var zm := BoxMesh.new(); zm.size = Vector3(0.05, 0.05, 0.5); az.mesh = zm; az.position = n.position + Vector3(0, 0.1, 0.25); var mb := StandardMaterial3D.new(); mb.albedo_color = Color.BLUE; az.material_override = mb; w.add_child(az)   # +z 파랑
		i += 1
	var cam := Camera3D.new(); var rows := ceili(i / 6.0)
	w.add_child(cam); cam.fov = 50; cam.current = true
	await process_frame
	cam.look_at_from_position(Vector3(4.0, 3.0 + rows * 1.2, rows * 1.6 + 2.5), Vector3(4.0, 0, rows * 0.8 - 0.4))
	print("KIT placed %d cam %s" % [i, str(cam.global_position)])
	for k in 20: await process_frame
	root.get_texture().get_image().save_png("user://shots/kit-%s.png" % (args[2] if args.size() > 2 else dir))
	quit()
