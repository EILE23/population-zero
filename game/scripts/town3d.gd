extends TownPlayer
## 3D 마을 — 루트. 세계를 짓고(_ready) 프레임마다 카메라·범례를 돌린다(_process). 나머지는 상속 계층에 있다:
##   town_base.gd(상태·도우미) → town_build.gd(건설) → town_places.gd(골목·강·풀밭) → town_boat.gd(부두·거룻배) → town_trades.gd(거리의 장인) → town_critters.gd(동물) → town_systems.gd(시스템) → … → town_sites.gd(열린 세계 장소) → town_swap.gd(하나 두고 하나 가져가기) → town_letters.gd(편지방) → town_sunroom.gd(이야기방) → town_nap.gd(낮잠방) → town_coins.gd(동전) → town_busk.gd(악사) → town_ledger.gd(외상 장부) → … → town_social.gd(채팅) → town_wages.gd(품삯) → town_store.gd(잡화점) → town_jobs.gd(심부름판) → town_pawn.gd(전당포) → town_furnish.gd(내 집 가구) → town_player.gd(조작) → 여기.

func _ready() -> void:
	_light()
	_ground()
	_solid_floor()
	water = Water3D.new(); add_child(water)   # 물 애셋 — 공원(연못)과 강이 여기에 붓는다
	# 옛 마을(허브: 공원·시장·동쪽 마을·골목·초원·전망 언덕·옛 집 넷)은 폐기했다(운영자 2026-10-14) — 산골 도시(valley)가 가운데까지 채운다.
	# 남긴 것: 가운데 광장(Valley.SQUARE)의 게시판·심부름판·전당포·악사 무대, 편지방·이야기방, 강·돌다리·디딤돌·부두
	_sun = get_node_or_null("Sun")
	_district("letters", ROOM_AT, _letter_room)   # 편지방(run 99, town_letters)
	_district("sunroom", SUN_AT, _sunroom)   # 이야기방(run 103, town_sunroom)
	_noticeboard(NOTICE_AT)   # 광장 게시판(run 100, town_letters)
	_jobsboard(JOBS_AT)   # 심부름판(run 115, town_jobs)
	_pawn_post(PAWN_AT)   # 전당포 부스(run 116, town_pawn)
	_busk_stage(NOTICE_AT + Vector3(4.0, 0, -1.2))   # 악사의 상자 무대와 모자(run 111, town_busk)
	_path(Vector3(-24, 0, -11.5), Vector3(24, 0, -11.5), 16.0)   # 광장 돌바닥
	_river()   # 강·돌다리
	_stones()   # 디딤돌(CI run 84)
	_jetty()   # 부두와 거룻배(CI run 78)
	for p in [Vector3(-22, 0, -4.5), Vector3(22, 0, -4.5), Vector3(-22, 0, -18.5), Vector3(22, 0, -18.5)]: _tree(p, 1.15)
	for x in [-14.0, -2.0, 12.0]: _bench(Vector3(x, 0, -4.8))
	_lamp(Vector3(-12, 0, -4.2)); _lamp(Vector3(12, 0, -4.2))
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
	_hire_broker()   # 전당포 주인 — uid % 24 == 5 인 어른(운전사보다 먼저, town_pawn)
	_hire_busker()   # 악사 — 남은 어른 중 어울림이 가장 높은 이, 등에 상자 기타(운전사보다 먼저, town_busk)
	_hire_drivers()
	_growth_init()   # 마을이 자란다 — 지은 집을 다시 세우고, 건축가를 정하고, 공사장을 연다(town_growth)
	_city_init()   # 지도대로(data/map/town.json) — 관공서·공원 블록, 장소 길의 가로등·나무, 이정표, 가게 주인(town_city)
	_traffic_init()   # 자기 차로 볼일 보러 다니는 주민(town_traffic)
	_store_init()   # 잡화점에서 사 쓴 것을 다시 쓴다(records["worn"], town_store)
	_social_init()   # 채팅·조작법 창·감정 표현(town_social)
	call_deferred("_net_town")   # 웹 계정·멀티(poz_net.gd) — 루트에 하나, 마을 방에 들어간다
	ResidentKid.settle(self)   # 아이 둘 — 서로 가장 좋아하는 어른 둘의 집에(run 102, resident_kid)
	if "--sheet" in OS.get_cmdline_user_args():
		add_child(load("res://tools/motion_sheet.gd").new())   # 개발용 동작 시트(연속 프레임) — `-- --sheet` 로만 켜진다

func _process(delta: float) -> void:
	_hud(Time.get_ticks_msec() / 1000.0)
	Signals.tick()   # 신호등 불빛(재질 셋 — 바뀔 때만 쓴다)
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
		gen.radius = clampi(int(3.0 + zoom * 0.4), 3, 7)   # 멀리 볼수록 넓게 짓는다 — 11(23×23칸)이면 칸마다 나무·바위 그리기로 수천 번이라 멀리서 렉이 났다(운영자 2026-10-08)
		var env: Environment = ($WorldEnvironment as WorldEnvironment).environment
		env.fog_density = 0.011 / zoom   # 멀리 볼수록 옅게 — sqrt 면 도시가 하얗게 바랬다
		cam.position = cam.position.lerp(want, minf(1.0, delta * 4.0))
		if cam_kick > 0.0:
			cam.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * cam_kick; cam_kick = maxf(0.0, cam_kick - delta * 0.3)
		cam.look_at(Vector3(cam.position.x, cam.position.y - 7.9 * zoom, cam.position.z - 7.5 * zoom), Vector3.UP)
	_board_cam(delta)   # 게시판을 보는 중이면 판 앞으로(town_social)
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
