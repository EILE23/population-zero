extends SceneTree
## Climb 점검(헤드리스): 문 장면으로 들어가나, 층 30개의 모든 발판이 이전 발판에서 닿나(웹 물리를 그대로 시뮬레이션), 모아 뛰기 높이,
## 쉼터 문으로 나가면 다음 입장이 그 층에서 시작하나, 나오는 문 장면 뒤 조작이 풀리나
var town: Node3D
const C = preload("res://scripts/games/climb.gd")

func _lands(a: Dictionary, b: Dictionary) -> bool:
	# a 위의 세 자리(왼끝·가운데·오른끝)에서 모으기 0.05..0.7, 방향 ±1 로 뛰어 b 에 닿는가 — 공중엔 같은 방향을 누른다
	for sx in [a["x"] + 12.0, a["x"] + a["w"] / 2.0, a["x"] + a["w"] - 12.0]:
		for d in [-1.0, 1.0]:
			for ci in range(1, 15):
				var ch := ci * 0.05
				var x: float = sx; var y: float = a["y"]; var vy := C.JUMP_MIN + (C.JUMP_V - C.JUMP_MIN) * (ch / C.CHARGE); var vx: float = d * C.RUN
				var zz: float = C.PLAYER_Z; var bz: float = float(b.get("z", 0.0)); var dzs := 0.0; var vz := 0.0   # 사람은 늘 절벽 앞
				for f in 240:
					var dt := 1.0 / 60.0
					vy -= C.G * dt; vx = clampf(vx + d * C.AIR * dt, -C.RUN, C.RUN)
					if absf(bz - zz) < 4.0: dzs = 0.0; vz = 0.0
					vz = clampf(vz + dzs * C.AIR_Z * dt, -C.RUN_Z, C.RUN_Z); zz += vz * dt
					var ny := y + vy * dt; x = clampf(x + vx * dt, C.HW, C.WORLD_W - C.HW)
					if vy <= 0.0 and x + C.HW > b["x"] and x - C.HW < b["x"] + b["w"] and y >= b["y"] and ny <= b["y"] and absf(zz - bz) < float(b.get("d", 999.0)) / 2.0 + C.HZ: return true
					y = ny
					if y < a["y"] - 400.0: break
	return false

func _init() -> void:
	town = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	print("GATING during walk-in=", town.gating)
	for i in 90: await physics_frame
	var g: Node3D = town.game_node
	print("ENTER game=", g != null, " town_mode=", town.process_mode)
	# 닿기: 층 0..30 의 발판을 생성 순서대로(지름길 short 는 빼고) — 앞 발판에서 다음 발판
	var seq: Array = []
	for n in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 60, 61, 62, 63]:
		for p in g.band(n):
			if p["kind"] != "short" and not (p["kind"] == "rest" and n == 0): seq.append(p)
	var bad := 0
	for i in range(1, seq.size()):
		if seq[i]["kind"] in ["rest", "ledge"]: continue   # 쉼터는 층 바닥(떨어져 닿는다), 바위 턱은 등반으로만
		if not _lands(seq[i - 1], seq[i]): bad += 1; if bad <= 3: print("UNREACH ", seq[i - 1]["id"], " -> ", seq[i]["id"])
	print("REACH pairs=", seq.size() - 1, " unreachable=", bad)
	# 등반: 60층 바위벽 — 손도끼 없이 뛰어들면 못 매달리고, 있으면 매달려 올라 턱에 선다
	g.band(60)
	var wl: Dictionary = g._walls[60][0]
	for with_gear in [false, true]:
		g.gear = "axe-test" if with_gear else ""; g.hanging = {}; g.stamina = 1.0
		var left: bool = true
		g.x = float(wl["x0"]) - 30.0; g.y = float(wl["y0"]) + 120.0; g.z = 0.0; g.vy = 0.0; g.vx = 0.0; g.on = {}
		Input.action_press("move_right")
		for i in 20: await physics_frame
		Input.action_release("move_right")
		var hung: bool = not g.hanging.is_empty()
		Input.action_press("move_up")
		for i in 600:
			await physics_frame
			if g.hanging.is_empty(): break
		Input.action_release("move_up")
		print("CLIMB gear=", with_gear, " grabbed=", hung, " on_ledge=", (not g.on.is_empty() and g.on.get("kind", "") == "ledge"), " y=%.0f wall_top=%.0f stamina=%.2f" % [g.y, float(wl["y1"]), g.stamina])
	# 모아 뛰기: 꽉 모아 뛰면 몇 m 오르나
	for i in 60: await physics_frame
	var y0: float = g.y
	Input.action_press("jump")
	for i in 50:
		await physics_frame
		if i % 10 == 0: print("HOLD i=", i, " x=", g.x, " y=", g.y, " vy=", g.vy, " charge=", g.charge, " on=", not g.on.is_empty(), " pressed=", Input.is_action_pressed("jump"), " locked=", Time.get_ticks_msec() / 1000.0 < g._scene_until)
	Input.action_release("jump")
	var hi := 0.0
	for i in 60: await physics_frame; hi = maxf(hi, g.y - y0)
	print("CHARGE full jump rise=%.0f px (%.2f m, web 154px)" % [hi, hi * C.K])
	# 쉼터 5 에서 나가기
	var rest: Dictionary = g.band(5)[0]
	g.x = rest["x"] + 120.0; g.y = rest["y"]; g.on = rest; g.vy = 0.0
	for i in 5: await physics_frame
	Input.action_press("act"); await physics_frame; Input.action_release("act")
	for i in 120: await physics_frame
	print("EXIT game_gone=", town.game_node == null, " camp=", town.records.get("climb_camp", -1), " gating=", town.gating)
	for i in 120: await physics_frame
	print("WALKOUT gating=", town.gating, " town_mode=", town.process_mode)
	town.enter_game("climb")
	for i in 100: await physics_frame
	var g2: Node3D = town.game_node
	print("RESUME start_camp=", g2.start_camp if g2 else -1, " y_floor=", floori(g2.y / C.BAND_H) if g2 else -1)
	quit()
