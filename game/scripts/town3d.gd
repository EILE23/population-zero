extends TownPlayer
## 3D 마을 — 루트. 세계를 짓고(_ready) 프레임마다 카메라·범례를 돌린다(_process). 나머지는 상속 계층에 있다:
##   town_base.gd(상태·도우미) → town_build.gd(건설) → town_places.gd(골목·강·풀밭) → town_boat.gd(부두·거룻배) → town_trades.gd(거리의 장인) → town_critters.gd(동물) → town_systems.gd(시스템) → town_player.gd(조작) → 여기.

func _ready() -> void:
	_light()
	_ground()
	_solid_floor()
	water = Water3D.new(); add_child(water)   # 물 애셋 — 공원(연못)과 강이 여기에 붓는다
	_path(Vector3(-WORLD_X, 0, 2), Vector3(WORLD_X, 0, 2), 2.4)  # 큰길: 공원 ↔ 마을 ↔ 시장
	_district("park", Vector3(-31, 0, -2), _park)
	_district("market", Vector3(31, 0, -2), _market)
	_district("east", Vector3(59, 0, -1), _east)   # 동쪽 마을(2026-09-30)
	_district("shops", Vector3(31, 0, -2), _shops)   # 화덕(run 72)과 우산꽂이(run 76) — 시장과 같은 중심이라 같이 켜고 꺼진다
	_district("trades", Vector3(59, 0, -1), func(c: Vector3) -> void: _cobbler(c + Vector3(-5.2, 0, -3.0)))   # 구두장이 작업대(run 80) — 동쪽 광장 서쪽 끝, 동쪽 마을과 같이 켜고 꺼진다
	_sun = get_node_or_null("Sun")
	_path(Vector3(0, 0, 0.8), Vector3(0, 0, -3.6), 2.0)    # 큰길 가장자리에서 가운데 집 현관까지(도로와 겹치면 이음새; 전엔 집 밑을 지나 -10 까지 갔다)
	_path(Vector3(3.35, 0, 0.8), Vector3(3.35, 0, -13), 2.0)  # 가운데 집과 계단집 사이 틈(x 2.2..4.5)으로 북쪽 골목까지
	_district("lane", Vector3(0, 0, -15), _lane)
	_river()   # 남쪽 강·돌다리·초원(비전 2단계)
	_jetty()   # 부두와 거룻배(CI run 78) — 다리 동쪽 북쪽 둑, 강 위를 다닌다
	_district("meadow", Vector3(0, 0, 18), _meadow)          # 텃밭·벤치(CI run 70) — 나무·풀밭 자리·물가는 _river 가 만든다
	_district("terrace", TERR_AT, _terrace)                  # 전망 언덕(CI run 73) — 풀밭 동쪽 끝의 풀 선반, 돌계단으로 오른다
	_hill(Vector3(31, 0, 18.5), 6.5, 2.6); _hill(Vector3(-27, 0, 18.5), 6.5, 2.0); _hill(Vector3(40.5, 0, 21), 4.5, 1.6)   # 언덕 — 차로 넘으면 뜬다(강·텃밭·전망 언덕과 안 겹치게)   # 언덕 — 차로 넘으면 뜬다
	_car("sedan", Vector3(19.5, 0, 4.6), PI / 2.0)      # 시장 앞 큰길가에 세단(운영자 2026-09-29: 차·운전)
	_car("hatchback", Vector3(-19.5, 0, 4.6), -PI / 2.0)   # 공원 앞에 해치백
	_car("race", Vector3(12.5, 0, 4.6), PI / 2.0); _car("suv", Vector3(-12.5, 0, 4.6), PI / 2.0); _car("truck", Vector3(26, 0, -9.5), 0.0); _car("tractor", Vector3(-6, 0, 18.5), 0.0)
	# 교통: 주민이 모는 차 둘이 큰길을 오간다(동쪽 차선 z 2.6, 서쪽 차선 z 1.4, 끝에서 유턴)
	for k in [["taxi", -30.0], ["delivery", 20.0]]:
		var tc := _car(k[0], Vector3(k[1], 0, 2.6), -PI / 2.0)
		tc.ai = true; tc.driver = tc
		tc.route = [Vector3(62, 0, 2.6), Vector3(67, 0, 4.2), Vector3(66, 0, 7.0), Vector3(61, 0, 5.2), Vector3(58, 0, 1.4), Vector3(-38, 0, 1.4), Vector3(-43, 0, -0.3), Vector3(-44, 0, 4.0), Vector3(-39, 0, 5.2), Vector3(-36, 0, 2.6)]   # 동쪽 마을까지, 끝에선 남쪽 풀밭으로 크게 돌아 유턴
	_house(Vector3(-7, 0, -4), Vector3(4.0, 2.6, 3.4), Color("dfe6ea"), "iron", false, 1)
	_house(Vector3(0.5, 0, -6), Vector3(3.4, 3.1, 3.2), Color("f7f4ef"), "brick", false, 2)
	_house(Vector3(7, 0, -4), Vector3(5.0, 2.4, 3.8), Color("e6d3a5"), "iron", true, 3)  # 계단집 — 옥상까지 걸어 올라간다
	_house(Vector3(-12, 0, -8), Vector3(3.6, 2.8, 3.2), Color("b56a5a"), "wood", false, 4)
	for p in [Vector3(-11, 0, -1), Vector3(-3.5, 0, -1.5), Vector3(5.6, 0, -0.8), Vector3(11, 0, -1.5), Vector3(-9, 0, 5), Vector3(9, 0, 5.5), Vector3(13, 0, -7)]:   # (4,-1) 나무는 골목길 틈에서 비켜 났다
		_tree(p, 1.0 + fmod(absf(p.x) * 0.37, 0.5))
	_bench(Vector3(-4, 0, 4.2)); _bench(Vector3(4, 0, 4.2))
	_lamp(Vector3(-1.6, 0, 3.6)); _lamp(Vector3(1.6, 0, 3.6)); _lamp(Vector3(-8, 0, 0.6)); _lamp(Vector3(8, 0, 0.6))
	_fence(Vector3(-13, 0, 7), 6.0); _fence(Vector3(9, 0, 7.5), 5.0)
	_item("apple", Vector3(-2.2, 0, 3.0)); _item("cup", Vector3(3.2, 0, 2.6)); _item("paper", Vector3(-5.5, 0, 1.2)); _item("apple", Vector3(6.4, 0, 3.4))
	# 플레이어 = 충돌체(캡슐) + 그 안의 입체 졸라맨
	body = CharacterBody3D.new()
	body.position = Vector3(0, 0.02, 4)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 0.18; cap.height = 0.95
	col.shape = cap; col.position.y = 0.5
	body.add_child(col)
	body.collision_layer = 4; body.collision_mask = 7
	player = Stick3D.new()
	body.add_child(player)
	add_child(body)
	cam = $Camera3D
	_residents(32)   # 동쪽 마을 집 넷이 생겨 여덟 명 더(2026-09-30)
	_hire_drivers()
	if "--sheet" in OS.get_cmdline_user_args():
		add_child(load("res://tools/motion_sheet.gd").new())   # 개발용 동작 시트(연속 프레임) — `-- --sheet` 로만 켜진다

## 시장 가게 앞의 것들 — places 층의 빌더라 _market(build 층)에선 못 부른다: 빵집 화덕은 문 오른쪽 바깥(창구·문·화덕이 한 줄), 우산꽂이는 카페 창구 오른쪽
func _shops(c: Vector3) -> void:
	var bc: Dictionary = spots.filter(func(sp): return sp["kind"] == "counter" and sp.has("stock"))[0]   # 빵집 창구 — 재고가 있는 유일한 창구
	_oven(c + Vector3(-4.3, 0, -5.9), bc)
	_rack(c + Vector3(8.3, 0, -6.0))

func _process(delta: float) -> void:
	_hud(Time.get_ticks_msec() / 1000.0)
	if Input.is_key_pressed(KEY_V) and not _v_down:
		view_25d = not view_25d
	_v_down = Input.is_key_pressed(KEY_V)
	var fp := focus_pos()
	var px := clampf(fp.x, -WORLD_X + 6.0, WORLD_X - 6.0)
	if view_25d:
		# 2.5D: 앞에서 살짝 위(약 13°)에서 보는 낮은 옆시점, 직교 투영이라 원근 왜곡이 없다 — 깊이(앞뒤)는 화면 위아래로만 읽힌다
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = lerpf(cam.size, 9.5, minf(1.0, delta * 4.0))
		var want := Vector3(px, 3.4, clampf(fp.z, -WORLD_Z + 2.0, WORLD_Z) + 11.0)
		cam.position = cam.position.lerp(want, minf(1.0, delta * 4.0))
		if cam_kick > 0.0:
			cam.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * cam_kick; cam_kick = maxf(0.0, cam_kick - delta * 0.3)
		cam.look_at(Vector3(cam.position.x, 0.9, cam.position.z - 11.0), Vector3.UP)
	else:
		# 3/4 시점: 플레이어 뒤·위에서 내려다본다
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		var want := Vector3(px, 0, clampf(fp.z, -WORLD_Z + 6.0, WORLD_Z - 4.0)) + Vector3(0, 8.5, 7.5)
		cam.position = cam.position.lerp(want, minf(1.0, delta * 4.0))
		if cam_kick > 0.0:
			cam.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * cam_kick; cam_kick = maxf(0.0, cam_kick - delta * 0.3)
		cam.look_at(Vector3(cam.position.x, 0.6, cam.position.z - 7.5), Vector3.UP)
