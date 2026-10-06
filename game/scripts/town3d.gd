extends TownPlayer
## 3D 마을 — 루트. 세계를 짓고(_ready) 프레임마다 카메라·범례를 돌린다(_process). 나머지는 상속 계층에 있다:
##   town_base.gd(상태·도우미) → town_build.gd(건설) → town_places.gd(골목·강·풀밭) → town_boat.gd(부두·거룻배) → town_trades.gd(거리의 장인) → town_critters.gd(동물) → town_systems.gd(시스템) → … → town_sites.gd(열린 세계 장소) → town_swap.gd(하나 두고 하나 가져가기) → town_letters.gd(편지방) → town_sunroom.gd(이야기방) → town_nap.gd(낮잠방) → town_coins.gd(동전) → town_busk.gd(악사) → town_ledger.gd(외상 장부) → … → town_social.gd(채팅) → town_wages.gd(품삯) → town_store.gd(잡화점) → town_jobs.gd(심부름판) → town_player.gd(조작) → 여기.

func _ready() -> void:
	_light()
	_ground()
	_solid_floor()
	water = Water3D.new(); add_child(water)   # 물 애셋 — 공원(연못)과 강이 여기에 붓는다
	_path(Vector3(-OPEN, 0, 2), Vector3(OPEN, 0, 2), 3.6)   # 두 차선(1.8m씩) — 2.4 일 땐 차 둘이 못 지나가 길가 소품을 쳤다  # 큰길: 공원 ↔ 마을 ↔ 시장, 그리고 세계 끝까지(열린 세계)
	_district("park", Vector3(-31, 0, -2), _park)
	_district("market", Vector3(31, 0, -2), _market)
	_district("east", Vector3(59, 0, -1), _east)   # 동쪽 마을(2026-09-30)
	_district("shops", Vector3(31, 0, -2), _shops)   # 화덕(run 72)과 우산꽂이(run 76) — 시장과 같은 중심이라 같이 켜고 꺼진다
	_district("trades", Vector3(59, 0, -1), func(c: Vector3) -> void: _cobbler(c + Vector3(-5.2, 0, -3.0)); _stitchhouse(c + Vector3(5.2, 0, -3.0)))   # 구두장이 작업대(run 80)는 동쪽 광장 서쪽 끝, 바느질 탁자(run 82)는 맞은편 동쪽 끝 — 동쪽 마을과 같이 켜고 꺼진다
	_sun = get_node_or_null("Sun")
	_path(Vector3(0, 0, 0.8), Vector3(0, 0, -3.6), 2.0)    # 큰길 가장자리에서 가운데 집 현관까지(도로와 겹치면 이음새; 전엔 집 밑을 지나 -10 까지 갔다)
	_path(Vector3(3.35, 0, 0.8), Vector3(3.35, 0, -13), 2.0)  # 가운데 집과 계단집 사이 틈(x 2.2..4.5)으로 북쪽 골목까지
	_district("lane", Vector3(0, 0, -15), _lane)
	_district("letters", ROOM_AT, _letter_room)   # 편지방(run 99, town_letters) — 골목 동쪽 끝의 새 집, 시장 쪽 오솔길
	_district("sunroom", SUN_AT, _sunroom)   # 이야기방(run 103, town_sunroom) — 골목 서쪽(공원) 끝의 새 집, 골목 길이 문 앞까지
	_noticeboard(NOTICE_AT)   # 광장 게시판(run 100, town_letters) — 가운데 집 뒤, 구역 밖이라 늘 서 있다(쪽지가 시간 따라 바뀐다)
	_jobsboard(JOBS_AT)   # 심부름판(run 115, town_jobs) — 게시판 서쪽 3m, 넷째 집 동쪽 벽에서 1m; 동전이 붙은 카드가 꽂히고 떼인다
	_busk_stage(NOTICE_AT + Vector3(4.0, 0, -1.2))   # 악사의 상자 무대와 모자(run 111, town_busk) — 게시판 동쪽 4m, 가운데 집 뒷벽(z −7.6)에서 1.6m, 골목 가로등(−3.5, −11.6)과 2.2m
	_river()   # 남쪽 강·돌다리·초원(비전 2단계)
	_stones()   # 디딤돌(CI run 84) — 시장 서쪽 끝 x 23 의 둘째 건널목
	_jetty()   # 부두와 거룻배(CI run 78) — 다리 동쪽 북쪽 둑, 강 위를 다닌다
	_district("meadow", Vector3(0, 0, 18), _meadow)          # 텃밭·벤치(CI run 70) — 나무·풀밭 자리·물가는 _river 가 만든다
	_district("terrace", TERR_AT, _terrace)                  # 전망 언덕(CI run 73) — 풀밭 동쪽 끝의 풀 선반, 돌계단으로 오른다
	_hill(Vector3(31, 0, 18.5), 6.5, 2.6); _hill(Vector3(-27, 0, 18.5), 6.5, 2.0); _hill(Vector3(40.5, 0, 21), 4.5, 1.6)   # 언덕 — 차로 넘으면 뜬다(강·텃밭·전망 언덕과 안 겹치게)   # 언덕 — 차로 넘으면 뜬다
	_car("sedan", Vector3(19.5, 0, 4.6), PI / 2.0)      # 시장 앞 큰길가에 세단(운영자 2026-09-29: 차·운전)
	_car("hatchback", Vector3(-19.5, 0, 4.6), -PI / 2.0)   # 공원 앞에 해치백
	_car("race", Vector3(12.5, 0, 4.6), PI / 2.0); _car("suv", Vector3(-12.5, 0, 4.6), PI / 2.0); _car("truck", Vector3(26, 0, -9.5), 0.0); _car("tractor", Vector3(-6, 0, 18.5), 0.0)
	# 교통: 주민이 모는 차 둘이 큰길을 오간다(동쪽 차선 z 2.6, 서쪽 차선 z 1.4, 끝에서 유턴)
	for k in [["taxi", -30.0], ["delivery", 20.0]]:
		var tc := _car(k[0], Vector3(k[1], 0, 2.9), -PI / 2.0)
		tc.ai = true; tc.driver = tc
		tc.route = [Vector3(84, 0, 2.9), Vector3(89, 0, 4.3), Vector3(89.5, 0, 6.4), Vector3(84, 0, 5.8), Vector3(80, 0, 1.1), Vector3(-80, 0, 1.1), Vector3(-85, 0, -0.5), Vector3(-89.5, 0, 1.6), Vector3(-88, 0, 4.8), Vector3(-83, 0, 5.4), Vector3(-78, 0, 2.9)]   # 유턴은 마을 밖 넓은 길에서(열린 세계) — 공원·동쪽 마을 소품 사이 S자에서 끼던 것   # 차선 간격 1.7m(차 폭 1.5) — 1.2m 일 땐 마주 오는 차끼리 서로 막았다   # 동쪽 마을까지, 끝에선 남쪽 풀밭으로 크게 돌아 유턴
	_house(Vector3(-7, 0, -4), Vector3(4.0, 2.6, 3.4), Color("dfe6ea"), "iron", false, 1)
	_house(Vector3(0.5, 0, -6), Vector3(3.4, 3.1, 3.2), Color("f7f4ef"), "brick", false, 2)
	_house(Vector3(7, 0, -4), Vector3(5.0, 2.4, 3.8), Color("e6d3a5"), "iron", true, 3)  # 계단집 — 옥상까지 걸어 올라간다
	_house(Vector3(-12, 0, -8), Vector3(3.6, 2.8, 3.2), Color("b56a5a"), "wood", false, 4)
	for p in [Vector3(-11, 0, -1), Vector3(-3.5, 0, -1.5), Vector3(5.6, 0, -0.8), Vector3(11, 0, -1.5), Vector3(-9, 0, 5), Vector3(9, 0, 5.5), Vector3(13, 0, -7)]:   # (4,-1) 나무는 골목길 틈에서 비켜 났다
		_tree(p, 1.0 + fmod(absf(p.x) * 0.37, 0.5))
	_bench(Vector3(-4, 0, 4.2)); _bench(Vector3(4, 0, 4.2))
	_lamp(Vector3(-1.6, 0, 4.0)); _lamp(Vector3(1.6, 0, 4.0)); _lamp(Vector3(-8, 0, -0.4)); _lamp(Vector3(8, 0, -0.4))   # 차선 밖으로(동쪽 차선 가장자리 3.6, 서쪽 0.4)
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
	_sites()   # 열린 세계의 장소들(숲 오두막·호숫가 마을·Climb 탑) — 주민 집이 생기니 주민보다 먼저(town_sites)
	_mountains()   # 마을 뒤 산 — 나선 돌계단·꼭대기 산스장·정자(town_mountain, 땅은 WorldGen.PEAKS)
	_residents(32)   # 동쪽 마을 집 넷이 생겨 여덟 명 더(2026-09-30)
	_hire_storysitter()   # 이야기방 주인 — 일 없는 어른 중 가장 '늙은 마음'(운전사보다 먼저 골라야 운전대에 앉지 않는다, town_sunroom)
	_hire_busker()   # 악사 — 남은 어른 중 어울림이 가장 높은 이, 등에 상자 기타(운전사보다 먼저, town_busk)
	_hire_drivers()
	_growth_init()   # 마을이 자란다 — 지은 집을 다시 세우고, 건축가를 정하고, 공사장을 연다(town_growth)
	_city_init()   # 지도대로(data/map/town.json) — 관공서·공원 블록, 장소 길의 가로등·나무, 이정표, 가게 주인(town_city)
	_store_init()   # 잡화점에서 사 쓴 것을 다시 쓴다(records["worn"], town_store)
	_social_init()   # 채팅·조작법 창·감정 표현(town_social)
	call_deferred("_net_town")   # 웹 계정·멀티(poz_net.gd) — 루트에 하나, 마을 방에 들어간다
	ResidentKid.settle(self)   # 아이 둘 — 서로 가장 좋아하는 어른 둘의 집에(run 102, resident_kid)
	if "--sheet" in OS.get_cmdline_user_args():
		add_child(load("res://tools/motion_sheet.gd").new())   # 개발용 동작 시트(연속 프레임) — `-- --sheet` 로만 켜진다

## 시장 가게 앞의 것들 — places·trades 층의 빌더라 _market(build 층)에선 못 부른다: 빵집 화덕은 문 오른쪽 바깥(창구·문·화덕이 한 줄), 우산꽂이는 카페 창구 오른쪽, 숫돌은 광장 동쪽 끝
func _shops(c: Vector3) -> void:
	var bc: Dictionary = spots.filter(func(sp): return sp["kind"] == "counter" and sp.has("stock"))[0]   # 빵집 창구 — 재고가 있는 유일한 창구
	_oven(c + Vector3(-4.3, 0, -5.9), bc)
	_rack(c + Vector3(8.3, 0, -6.0))
	_bookbox(c + Vector3(-9.5, 0, -6.0))   # 책 상자(run 98, swap 층) — 빵집 서쪽 옆, 큰길(z −0.1..4.1)에서 멀다
	_grindstone(c + Vector3(11.2, 0, -3.4))   # 칼갈이 숫돌(run 81, trades 층) — 넷째 노점 옆, 자갈 광장 동쪽 가장자리
	_ledger(c + Vector3(-9.7, 0, -8.6))   # 외상 장부 탁자(run 112, ledger 층) — 빵집 서쪽 벽(x 22.5) 옆, 책 상자(z −8) 뒤 1.9m, 편지방(z ≤ −14.6)과 큰길에서 멀다

func _process(delta: float) -> void:
	_hud(Time.get_ticks_msec() / 1000.0)
	var fp := focus_pos()
	var px := clampf(fp.x, -OPEN + 6.0, OPEN - 6.0)
	if view_25d:
		# 2.5D: 앞에서 살짝 위(약 13°)에서 보는 낮은 옆시점, 직교 투영이라 원근 왜곡이 없다 — 깊이(앞뒤)는 화면 위아래로만 읽힌다
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = lerpf(cam.size, 9.5, minf(1.0, delta * 4.0))
		var want := Vector3(px, 3.4 + fp.y, clampf(fp.z, -OPEN + 2.0, OPEN) + 11.0)   # 언덕에 오르면 카메라도 따라 오른다
		for k in [0.25, 0.5, 0.75, 1.0]:   # 나와 카메라 사이 언덕이 시야를 막으면 그만큼 올린다(열린 세계 — 앞 언덕이 화면을 덮었다)
			want.y = maxf(want.y, gen.height(px, fp.z + 11.0 * k) + 1.6 + (3.4 - 1.6) * (1.0 - k))
		cam.position = cam.position.lerp(want, minf(1.0, delta * 4.0))
		if cam_kick > 0.0:
			cam.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * cam_kick; cam_kick = maxf(0.0, cam_kick - delta * 0.3)
		cam.look_at(Vector3(cam.position.x, cam.position.y - 2.5, cam.position.z - 11.0), Vector3.UP)
	else:
		# 3/4 시점: 플레이어 뒤·위에서 내려다본다
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		zoom = lerpf(zoom, zoom_want, minf(1.0, delta * 6.0))
		var want := Vector3(px, fp.y, clampf(fp.z, -OPEN + 6.0, OPEN - 4.0)) + Vector3(0, 8.5, 7.5) * zoom   # 휠·-/= 로 멀리(운영자: 위에서 봤을 때 도시)
		for k in ([] if is_inside() else [0.3, 0.55, 0.8]):   # (방 안이면 안 본다 — town_interior) 카메라와 나 사이 언덕이 시선을 가리면 그 위로 올린다(열린 세계 남쪽 언덕)
			var hk: float = gen.height(px, fp.z + 7.5 * zoom * k) + 0.9
			want.y = maxf(want.y, fp.y + 0.6 + (hk - fp.y - 0.6) / k)
		cam.far = 400.0 + 120.0 * zoom
		gen.radius = clampi(int(3.0 + zoom * 0.55), 3, 11)   # 멀리 볼수록 넓게 짓는다
		var env: Environment = ($WorldEnvironment as WorldEnvironment).environment
		env.fog_density = 0.011 / zoom   # 멀리 볼수록 옅게 — sqrt 면 도시가 하얗게 바랬다
		cam.position = cam.position.lerp(want, minf(1.0, delta * 4.0))
		if cam_kick > 0.0:
			cam.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * cam_kick; cam_kick = maxf(0.0, cam_kick - delta * 0.3)
		cam.look_at(Vector3(cam.position.x, cam.position.y - 7.9 * zoom, cam.position.z - 7.5 * zoom), Vector3.UP)
	_cabin_cam(delta)   # 차 안 시점(V — 뒤따라가기·운전석 1인칭, town_cabin)이면 덮어쓴다

## 줌 — 마우스 휠 또는 -/= (1 = 기본, 30 = 도시를 내려다본다)
var zoom := 1.0
var zoom_want := 1.0
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP: zoom_want = maxf(1.0, zoom_want / 1.2)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN: zoom_want = minf(30.0, zoom_want * 1.2)
	elif e is InputEventKey and e.pressed:
		if e.is_action_pressed("zoom_in"): zoom_want = maxf(1.0, zoom_want / 1.25)   # 키는 Esc 메뉴에서 바꾼다(game_menu)
		elif e.is_action_pressed("zoom_out"): zoom_want = minf(30.0, zoom_want * 1.25)
