extends TownPlayer
## 3D 마을 — 루트. 세계를 짓고(_ready) 프레임마다 카메라·범례를 돌린다(_process). 나머지는 상속 계층에 있다:
##   town_base.gd(상태·도우미) → town_build.gd(건설) → town_systems.gd(시스템) → town_player.gd(조작) → 여기.

func _ready() -> void:
	_light()
	_ground()
	_solid_floor()
	_path(Vector3(-WORLD_X, 0, 2), Vector3(WORLD_X, 0, 2), 2.4)  # 큰길: 공원 ↔ 마을 ↔ 시장
	_district("park", Vector3(-31, 0, -2), _park)
	_district("market", Vector3(31, 0, -2), _market)
	_sun = get_node_or_null("Sun")
	_path(Vector3(0, 0, 0.8), Vector3(0, 0, -3.6), 2.0)    # 큰길 가장자리에서 가운데 집 현관까지(도로와 겹치면 이음새; 전엔 집 밑을 지나 -10 까지 갔다)
	_path(Vector3(3.35, 0, 0.8), Vector3(3.35, 0, -13), 2.0)  # 가운데 집과 계단집 사이 틈(x 2.2..4.5)으로 북쪽 골목까지
	_district("lane", Vector3(0, 0, -15), _lane)
	_river()   # 남쪽 강·돌다리·초원(비전 2단계)
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
	player = Stick3D.new()
	body.add_child(player)
	add_child(body)
	cam = $Camera3D
	_residents(24)

## 북쪽 골목(2026-09-28 월요일 비전 런의 첫 조각 — 마을은 매달 눈에 띄게 넓어져야 한다): x=0 길이 북으로 이어져 동서 골목(z≈-13)과 만나고,
## 남향 집 세 채가 골목을 본다. 집 생성기가 문·침대·의자·선반을 등록하니 주민 명부의 집 배정(home_door = doors[i % n])에 저절로 들어가
## 밤에 여기서 자는 주민이 생긴다 — 새 집은 주인이 있어야 한다는 규칙. 골목 뒤는 담(세계 끝이 안 보이게)
func _lane(at: Vector3) -> void:
	_path(at + Vector3(-14, 0, 2), at + Vector3(14, 0, 2), 2.0)
	_house(at + Vector3(-8, 0, -1.5), Vector3(4.2, 2.7, 3.4), Color("8fb8cc"), "wood", false, 5)
	_house(at + Vector3(0, 0, -2), Vector3(3.8, 2.9, 3.2), Color("efe9e2"), "brick", false, 6)
	_house(at + Vector3(8, 0, -1.5), Vector3(4.6, 2.5, 3.6), Color("e6d3a5"), "wood", false, 7)
	_bench(at + Vector3(4, 0, 3.6)); _lamp(at + Vector3(-3.5, 0, 3.4))
	_tree(at + Vector3(-12.5, 0, -1), 1.2); _tree(at + Vector3(12.5, 0, -1), 1.05)
	_fence(at + Vector3(-13, 0, -4), 26.0)

func _process(delta: float) -> void:
	_hud(Time.get_ticks_msec() / 1000.0)
	if Input.is_key_pressed(KEY_V) and not _v_down:
		view_25d = not view_25d
	_v_down = Input.is_key_pressed(KEY_V)
	var px := clampf(body.position.x, -WORLD_X + 6.0, WORLD_X - 6.0)
	if view_25d:
		# 2.5D: 앞에서 살짝 위(약 13°)에서 보는 낮은 옆시점, 직교 투영이라 원근 왜곡이 없다 — 깊이(앞뒤)는 화면 위아래로만 읽힌다
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = lerpf(cam.size, 9.5, minf(1.0, delta * 4.0))
		var want := Vector3(px, 3.4, clampf(body.position.z, -WORLD_Z + 2.0, WORLD_Z) + 11.0)
		cam.position = cam.position.lerp(want, minf(1.0, delta * 4.0))
		if cam_kick > 0.0:
			cam.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * cam_kick; cam_kick = maxf(0.0, cam_kick - delta * 0.3)
		cam.look_at(Vector3(cam.position.x, 0.9, cam.position.z - 11.0), Vector3.UP)
	else:
		# 3/4 시점: 플레이어 뒤·위에서 내려다본다
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		var want := Vector3(px, 0, clampf(body.position.z, -WORLD_Z + 6.0, WORLD_Z - 4.0)) + Vector3(0, 8.5, 7.5)
		cam.position = cam.position.lerp(want, minf(1.0, delta * 4.0))
		if cam_kick > 0.0:
			cam.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * cam_kick; cam_kick = maxf(0.0, cam_kick - delta * 0.3)
		cam.look_at(Vector3(cam.position.x, 0.6, cam.position.z - 7.5), Vector3.UP)
