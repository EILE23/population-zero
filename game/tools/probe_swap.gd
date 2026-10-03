extends SceneTree
## 책 상자 점검(헤드리스, run 98 — "Leave one, take one" 1조각): 상자가 있고 책등 넷이 보이나, 사람이 책을 꽂으면 재고 +1·손이 비나, 빈손 C 면 −1·손에 책이 오나,
## 주민이 빈손으로 닿으면 하나 꺼내 읽나(−1), 책을 들고 닿으면 꽂나(+1, 둘에 하나는 다시 꺼낸다), 관리인이 있나
## godot --headless --path game -s res://tools/probe_swap.gd
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	town.weather = "clear"
	var bx: Dictionary = town.bookbox
	var shown := (bx["shown"] as Array).filter(func(b): return (b as Node3D).visible).size()
	print("BOX stock=", bx["stock"], " shown=", shown, " librarians=", town.residents.filter(func(r): return r.job == "librarian").size(), " (want 4 4 >=1)")
	town.body.global_position = bx["pos"] + Vector3(0, 0.02, 0)
	town.player.hold(town.make_item("book", Vector3.ZERO))
	var s0: int = bx["stock"]
	var ok: bool = town.swap_use(Time.get_ticks_msec() / 1000.0)
	await create_timer(1.1).timeout
	print("PUT ok=", ok, " stock ", s0, "->", bx["stock"], " hand=", town.player.carrying, " pose='", town.player.pose_request, "' (want +1, null, '')")
	s0 = bx["stock"]
	ok = town.swap_use(Time.get_ticks_msec() / 1000.0)
	await create_timer(1.1).timeout
	var held: String = String(town.player.carrying.get_meta("kind", "")) if town.player.carrying else ""
	print("TAKE ok=", ok, " stock ", s0, "->", bx["stock"], " hand=", held, " (want -1, book)")
	town.player.release(town, Vector3.ZERO).queue_free()
	town.body.global_position = Vector3(0, 0.02, 4)
	var free: Array = town.residents.filter(func(x): return x.state in ["routine", "walk", "busy"] and x.fig.carrying == null and not x.fig.seated and x.riding_swing.is_empty() and x.riding_seesaw == null and not x.in_boat and not x.has_umb and x.job != "librarian")
	var r: ResidentShelf = free[0]
	r._leave(); r.weather = "clear"
	r.global_position = bx["pos"] + Vector3(0, 0.1, 0.05); r.spot = bx; r.slot = 1; r._claim(bx, 1); r.state = "busy"
	s0 = bx["stock"]
	r._swap_arrive(Time.get_ticks_msec() / 1000.0)
	await create_timer(1.2).timeout
	print("R TAKE stock ", s0, "->", bx["stock"], " kind=", r.carrying_kind, " pose=", r.fig.pose_request, " (want -1, book, read)")
	r.state = "busy"; r.spot = bx; r.fig.pose_request = ""
	s0 = bx["stock"]
	r._swap_arrive(Time.get_ticks_msec() / 1000.0)
	await create_timer(0.85).timeout
	print("R PUT stock ", s0, "->", bx["stock"], " kind='", r.carrying_kind, "' (want +1, '')")
	await create_timer(1.6).timeout
	print("R AFTER stock=", bx["stock"], " kind='", r.carrying_kind, "' pose=", r.fig.pose_request, " (either swapped: book/read, or returned: ''/'')")
	quit()
