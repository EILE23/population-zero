class_name ResidentLife
extends ResidentBase
## 주민의 하루 — 일과표(시간대·직업이 고르는 자리), 수다, 운전. resident.gd 가 500줄에 닿아 뗐다(2026-09-30). 사슬: base → life → pair(resident_pair.gd) → shelf → letters → resident → kid(resident_kid.gd, 아이 — run 102)

var car_seat: Car3D = null
var own_car: Car3D = null     # 내 차 — 끌려 내려도 일이 끝나면 돌아가 다시 탄다

var walked := 0.0   # 걸은 거리(m) — 밑창이 닳는다. town.SOLE_M 을 넘으면 구두장이가 일할 때 걸상에 들른다(run 80, town_trades)
var dull := 0       # 가게지기가 마친 창구·노점 교대 수 — 가위가 무뎌진다. town.DULL_N 이면 칼갈이가 갈 때 손님 자리에 들른다(run 81, town_trades)

## 직업 — 문에 적힌 것이 먼저(빵집 주인·구두장이·칼갈이·운전사), 없으면 uid 로(정원사·가게지기·산책꾼)
func _role() -> String:
	return ["gardener", "keeper", "walker", "walker", "keeper", "walker"][uid % 6] if job == "" else job

## 지금 시각(0..24) — town 의 해와 같은 시계
func _hour() -> float:
	return fmod(town.clock * 24.0 + 6.0, 24.0)

## 일과표 — 이 시각에 이 사람이 가고 싶은 자리 종류. 직업은 uid 로(정원사·가게지기·산책꾼), 빵집 주인·수리공·운전사는 따로 돈다
func _schedule_kinds() -> Array:
	var h := _hour()
	var role := _role()
	if h < 9.0: return ["counter", "door", "bank"]                            # 아침: 빵 사러, 집 앞, 물가
	if h >= 12.0 and h < 13.5: return ["counter", "bench", "chair"]           # 점심: 창구·벤치
	if h >= 17.0: return ["bench", "lamp", "swing", "seesaw", "grass", "lookout", "bank"]   # 저녁: 놀고 쉰다
	match role:                                                               # 낮 일
		"gardener": return ["plot", "tree", "grass"]
		"keeper": return ["door", "counter", "hatstand"]                        # 노점 손님 자리(door)·창구에 서 있는다
		_: return ["bench", "tree", "bank", "lookout", "lamp"]

## 수다 — 자리에 닿았을 때 2m 안에 쉬는 주민이 있으면 서로 마주 보고 번갈아 말한다(8~14초). 말 많은 사람일수록 자주. 사람이 끼어들면(인사) 그만
func _chat(now: float) -> bool:
	if spot.get("kind", "") in ["bed", "chair", "shelf", "swing", "seesaw", "plot", "oven", "repair", "grass", "cobbler", "stool", "wheel", "whet", "stitch", "fitting", "swap", "letters", "notice"] or randf() > 0.15 + 0.4 * mind.social: return false
	return _chat_force(now)

## 수다를 곧장(시트 도구·이벤트용). 상대는 친한 사람부터. 화제는 제 관심사(minds.json topics), 답은 사이가 정한다 — 친구는 맞장구, 앙숙은 반박하고 한 번 더 받아친다.
## 사람을 두고 호불호가 크면 소문을 낸다: 내 생각이 듣는 사람에게 조금 옮는다(맞고 다니는 사람은 마을 전체에 평판이 깎인다)
func _chat_force(now := Time.get_ticks_msec() / 1000.0) -> bool:
	var o: ResidentLife = null; var best := -9.0
	for x in town.residents:
		if x == self or x.state != "busy" or x.fig.pose_request != "" or x.fig.seated: continue
		if x.global_position.distance_to(global_position) > 2.0: continue
		var k: float = mind.relation_k(x) + randf() * 0.3
		if k > best: best = k; o = x
	if o == null: return false
	var rk := mind.relation_k(o)
	var opener: String; var reply: String; var back := ""
	if absf(mind.fond) > 0.3 and randf() < 0.45:
		opener = mind.line("gossip_bad" if mind.fond < 0.0 else "gossip_good")
		var trust := 0.1 + 0.2 * maxf(rk, 0.0)   # 친한 사람 말일수록 믿는다
		o.mind.fond = clampf(o.mind.fond + mind.fond * trust, -1.0, 1.0)
		reply = o.mind.line("agree" if o.mind.fond * mind.fond > 0.05 else "neutral")
	else:
		opener = mind.topic()
		if rk < -0.2: reply = o.mind.line("disagree"); back = mind.line("disagree")
		elif rk > 0.3 or o.mind.mood > 0.4: reply = o.mind.line("agree")
		else: reply = o.mind.line("neutral")
	mind.befriend(o, -0.02 if rk < -0.2 else 0.08); o.mind.befriend(self, -0.02 if rk < -0.2 else 0.08)
	var until := now + randf_range(8.0, 14.0)
	for pr in [[self, o], [o, self]]:
		var a: ResidentLife = pr[0]; var b: ResidentLife = pr[1]
		a.fig.pose_request = "talk"; a.fig.face(atan2(b.global_position.x - a.global_position.x, b.global_position.z - a.global_position.z))
		a.busy_until = until; a.state = "busy"
	say(opener, 2.4)
	get_tree().create_timer(1.9).timeout.connect(func() -> void: if o.fig.pose_request == "talk": o.say(reply, 2.4))
	if back != "": get_tree().create_timer(3.9).timeout.connect(func() -> void: if fig.pose_request == "talk": say(back, 2.2))
	return true

## 자아가 도는 곳: 욕구·기분(mind.tick), 사람을 알아보기(_notice), 기억 저장(맨 앞 사람이 30초마다 모두를)
func _process(delta: float) -> void:
	super(delta)
	if state == "drive": return
	if fig.action == "fight" and state != "chase":   # 쫓는 중이 아닐 때의 막기·피하기 진행(쫓는 중엔 _chase 가)
		var nw := Time.get_ticks_msec() / 1000.0
		fig.action_t = 1.0 - (act_until - nw) / maxf(act_dur, 0.01)
		if nw >= act_until: fig.action = ""; fig.action_t = 0.0; fig.move = ""
	if state == "walk": walked += fig.speed * delta   # 실제 속도로 — 벽에 막혀 제자리걸음이면 안 닳는다
	mind.tick(delta)
	_notice(Time.get_ticks_msec() / 1000.0)
	if town.residents.size() > 0 and town.residents[0] == self: ResidentMind.save_all(town.residents)

func _exit_tree() -> void:
	if town and town.residents.size() > 0 and town.residents[0] == self: ResidentMind.save_all(town.residents, true)

## 사람을 알아본다(4m, 1초에 한 번쯤): 좋아하면 먼저 손을 흔들고, 처음 보면 말 많은 사람은 인사하고, 미우면 — 성미 급한 사람은 쫓아오고, 겁 많은 사람은 피하고, 나머지는 한마디 쏘아붙인다
func _notice(now: float) -> void:
	if now < mind.notice_at: return
	mind.notice_at = now + randf_range(0.6, 1.2)
	var free_body := (state == "routine" or state == "walk") and not in_boat or (state == "busy" and not fig.seated and riding_swing.is_empty() and riding_seesaw == null and not in_boat and fig.pose_request in ["", "umbr"] and bites == 0)
	if not free_body or town.driving != null: return
	var pp: Vector3 = town.body.global_position
	var d := global_position.distance_to(pp)
	if d > 4.0 or now - mind.spoke_at < 25.0: return
	var m := mind
	if m.fond < -0.3:
		m.spoke_at = now
		if now - m.last_hurt < 90.0 and m.temper > 0.6 and m.brave > 0.4 and d < 3.0:
			_release(); quarry = town.body; state = "chase"; chase_until = now + 4.0; say(m.line("grudge"), 1.6)
		elif m.brave < 0.5 or m.fond < -0.6: _flee(pp)
		else: say(m.line("greet_cold"), 1.6)
	elif (m.fond > 0.3 and m.social > 0.3 and d < 3.5) or (m.met == 0 and m.social > 0.75 and d < 2.5):
		m.spoke_at = now
		say(m.greet_line(), 1.8)
		if state == "routine":
			fig.pose_request = "lwave" if has_umb else "wave"; fig.face(atan2(pp.x - global_position.x, pp.z - global_position.z))
			state = "busy"; spot = { "kind": "greet" }; busy_until = now + 1.4

## 피하기 — 하던 걸 접고 사람 반대쪽으로 6m 서둘러 걸어가(빠른 걸음) 거기서 잠깐 선다. 다리·계단은 같은 길찾기(via_bridge)
func _flee(from: Vector3) -> void:
	if state == "busy": call("_leave")
	else: _release()
	var away := global_position - from; away.y = 0.0
	if away.length() < 0.1: away = Vector3(1, 0, 0)
	var to := global_position + away.normalized() * 6.0
	to.x = clampf(to.x, -town.WORLD_X + 3.0, town.WORLD_X - 3.0); to.z = clampf(to.z, -town.WORLD_Z + 3.0, town.WORLD_Z - 3.0); to.y = 0.0
	if town.in_water(to): to = global_position - (to - global_position) * 0.5
	spot = { "kind": "flee", "pos": to }; route = town.via_bridge(global_position, [{ "pos": to, "act": "" }])
	target = route[0]["pos"]; state = "walk"; fig.pose_request = ""
	say(mind.line("flee"), 1.4)

## 운전 맡기 — 이 주민이 이 차의 운전사가 된다. 충돌을 끄고(차 안), 일과를 멈춘다
func drive(c: Car3D) -> void:
	_release(); car_seat = c; own_car = c; c.driver = self; job = "driver"; fig.base_scale = Vector3.ONE * 0.8
	state = "drive"; collision_layer = 0; collision_mask = 0
	say(["Morning route.", "Mind the road.", "On schedule."][uid % 3], 2.0)

## 차에서 내림(끌려 나감) — 운전석 옆에 서고 몸·충돌을 되돌린다. 일자리(운전사)와 내 차는 그대로
func leave_car() -> void:
	if car_seat == null: return
	var c := car_seat
	if c.driver == self: c.driver = null
	global_position = c.exit_pos() + Vector3(0, 0.02, 0); car_seat = null
	fig.base_scale = Vector3.ONE; fig.seated = false; fig.pose_request = ""; collision_layer = 4; collision_mask = 7   # scale 은 매 프레임 base_scale 로 다시 쓰인다(리뷰: 끌려 내린 운전사가 0.8 로 남았다)
	state = "routine"; busy_until = 0.0

## 내 차로 돌아가기 — 차가 비어 있으면(아무도 안 몰고 내가 타고 있지도 않으면) 걸어가 운전석에 탄다. 내가 몰고 가 버렸으면 가끔 투덜댄다
func _back_to_car() -> bool:
	if own_car == null or car_seat != null: return false
	if own_car.driver != null or town.driving == own_car:
		if randf() < 0.3: say(["That is my car.", "Bring it back.", "I need that."][randi() % 3], 1.8)
		return false
	spot = { "kind": "car" }
	route = town.via_bridge(global_position, [{ "pos": own_car.exit_pos(), "act": "" }]); target = route[0]["pos"]; state = "walk"
	say(["Back to work.", "Right. The car.", "Where was I."][randi() % 3], 1.6)
	return true

## 장인들(run 80 구두장이, run 81 칼갈이 — "Trades on the street"): 장인(집 문에 "cobbler"/"cutler")은 낮(09–17)에 넷 중 셋은 제 작업대로. 밑창이 닳은(walked > SOLE_M) 사람은
## 구두장이가 일하는 중이면 다섯 중 셋은 걸상으로, 가위가 무딘(dull >= DULL_N) 가게지기는 칼갈이가 가는 중이면 다섯 중 셋은 손님 자리로. 나머지는 여느 때처럼 고른다 — 평범한 결과(지나쳐 걷기)가 남는다. 못 가면 false
func _trade_pick(now: float) -> bool:
	if job == "woodcutter" and _wood_pick(now): return true   # 나무꾼(오두막): 장작 나르기·패기
	if town.is_night() or weather == "rain" or fig.carrying: return false
	var tc: Dictionary = town.cobbler; var tw: Dictionary = town.wheel; var tt: Dictionary = town.tailor
	var h := _hour()
	var sp: Dictionary = {}
	if job == "cobbler" and not tc.is_empty() and h >= 9.0 and h < 17.0 and randf() < 0.75: sp = tc["work"]
	elif job == "cutler" and not tw.is_empty() and h >= 9.0 and h < 17.0 and randf() < 0.75: sp = tw["work"]
	elif job == "tailor" and not tt.is_empty() and h >= 9.0 and h < 17.0 and randf() < 0.75: sp = tt["work"]
	elif not tt.is_empty() and Wear.torn(fig.worn.get("back")) and town.tailor_at_work() != null and global_position.distance_to(tt["fitting"]["pos"]) < 45.0 and randf() < 0.6: sp = tt["fitting"]   # 찢어진 것부터(run 82) — 넘어진 뒤라 급하다
	elif not tc.is_empty() and walked > town.SOLE_M and town.cobbler_at_work() != null and global_position.distance_to(tc["stool"]["pos"]) < 45.0 and randf() < 0.6: sp = tc["stool"]
	elif not tw.is_empty() and dull >= town.DULL_N and town.cutler_at_work() != null and global_position.distance_to(tw["whet"]["pos"]) < 45.0 and randf() < 0.6: sp = tw["whet"]
	if sp.is_empty() or _free_slot(sp) < 0: return false
	spot = sp; slot = 0; _claim(sp, 0)
	route = town.via_bridge(global_position, [{ "pos": sp["pos"], "act": "" }])
	target = route[0]["pos"]; state = "walk"; busy_until = now
	return true

## 작업대에 닿음 — 장인은 제 손일(hammer/grind, 25~45초), 손님은 걸상에 앉아(구두) 또는 건너편에 팔짱 끼고 서서(가위) 두 바퀴 받는다. 오는 사이 장인이 떠났으면 한마디 하고 간다
func _trade_arrive(now: float) -> void:
	fig.face(spot.get("yaw", 0.0))
	var w: ResidentBase = null
	match spot["kind"]:
		"cobbler":
			fig.pose_request = "hammer"; busy_until = now + randf_range(25.0, 45.0)
			say(mind.line("cobbler_open"), 1.6)
		"wheel":
			fig.pose_request = "grind"; busy_until = now + randf_range(25.0, 45.0)
			say(mind.line("cutler_open"), 1.6)
		"stitch":
			fig.seated = true; collision_layer = 0; collision_mask = 0
			global_position = spot["pos"] + Vector3(0, 0.05, 0)
			fig.pose_request = "sew"; busy_until = now + randf_range(25.0, 45.0)
			say(mind.line("tailor_open"), 1.6)
		"fitting":
			w = town.tailor_at_work()
			if w == null: _trade_closed(now); return
			fig.seated = true; collision_layer = 0; collision_mask = 0
			global_position = spot["pos"] + Vector3(0, 0.05, 0)
			busy_until = now + StickPoses.SEW_T + 0.3
			w.say(w.mind.line("tailor_serve"), 1.6)
			get_tree().create_timer(StickPoses.SEW_T).timeout.connect(_mended)
		"stool":
			w = town.cobbler_at_work()
			if w == null: _trade_closed(now); return
			fig.seated = true; collision_layer = 0; collision_mask = 0
			global_position = spot["pos"] + Vector3(0, 0.05, 0)
			busy_until = now + StickPoses.HAMMER_T * 2.0 + 0.3
			w.say(w.mind.line("cobbler_serve"), 1.6)
			get_tree().create_timer(StickPoses.HAMMER_T * 2.0).timeout.connect(_resoled)
		"chop":
			fig.pose_request = "chop"; busy_until = now + StickPoses.CHOP_T * randi_range(5, 9) + 0.2
			say(mind.line("chop"), 1.6)
		"pile":
			fig.action = "grab"; fig.action_t = 0.0; busy_until = now + 0.5
			if fig.carrying and String(fig.carrying.get_meta("kind", "")) == "log":
				if town.pile_put(): fig.release(town, Vector3.ZERO).queue_free()
				else: town.items.append(fig.release(town, global_position + Vector3(0.4, 0.06, 0)))   # 꽉 찼다 — 옆에 둔다
				carrying_kind = ""
			elif not fig.carrying:
				var top: Node3D = town.pile_take()   # 저녁 — 난로에 넣을 하나를 내린다(_wood_pick)
				if top != null and fig.hold(top): carrying_kind = "log"
		"stove":
			# 오두막 난로(run 92): 들고 온 장작을 사람과 같은 stoke 자세로 화실에 넣는다. 그새 사람이 채워 꽉 찼으면 서서 보고 장작은 다음 _wood_pick 이 더미로
			if fig.carrying and String(fig.carrying.get_meta("kind", "")) == "log" and town.stoke(fig, self):
				busy_until = now + HearthPoses.STOKE_T + 0.2; say(mind.line("stoke"), 1.6)
			else: fig.face(PI); busy_until = now + 1.0
		"logs":
			var lg: Variant = spot.get("log")   # 그새 사람이 주워 갔을 수 있다 — 타입을 박으면 지워진 노드를 넣을 때 멈춘다
			fig.action = "grab"; fig.action_t = 0.0; busy_until = now + 0.4
			if is_instance_valid(lg) and lg in town.items and global_position.distance_to(lg.global_position) < 1.2 and fig.hold(lg):
				town.items.erase(lg); carrying_kind = "log"
		"whet":
			w = town.cutler_at_work()
			if w == null: _trade_closed(now); return
			fig.pose_request = "wait"; busy_until = now + StickPoses.GRIND_T * 2.0 + 0.3
			w.say(w.mind.line("cutler_serve"), 1.6)
			get_tree().create_timer(StickPoses.GRIND_T * 2.0).timeout.connect(_sharpened)

## 나무꾼(오두막 문의 주민): 장작을 들었으면 더미로, 낮(08–17)엔 그루터기 둘레에 흩어진 게 있으면 다섯 중 넷은 하나 주우러, 아니면 넷 중 셋은 그루터기로(더미가 꽉 찼으면 안 팬다).
## 사람이 하는 것과 같은 자리·같은 자세(town_woods) — 패고, 줍고, 쌓는다. 비·밤엔 쉰다. 16:30 부터 어둡기 전, 화실이 비었으면 더미에서 하나를 내려 난로로(run 92 — 밤에 들고 있어도 난로부터)
## 오두막 안 난로는 문으로 들어간다(침대·의자와 같은 길, 나올 땐 _leave 가 문으로)
func _wood_pick(now: float) -> bool:
	var wc: Dictionary = town.woodcut
	if wc.is_empty(): return false
	var sp: Dictionary = {}
	var eve: bool = _hour() >= 16.5 or town.is_night()
	if fig.carrying and String(fig.carrying.get_meta("kind", "")) == "log": sp = wc["stove"] if eve and int(wc["fire"]) < town.FIRE_MAX else wc["pile"]
	elif not fig.carrying and eve and not town.is_night() and int(wc["fire"]) == 0 and not (wc["stack"] as Array).is_empty(): sp = wc["pile"]   # 내리러
	elif fig.carrying or town.is_night() or weather == "rain" or _hour() < 8.0 or _hour() >= 17.0: return false
	else:
		var full: bool = (wc["stack"] as Array).size() >= town.STACK_MAX   # 꽉 찼으면 줍지도 패지도 않는다 — 주워다 옆에 내려놓기를 끝없이 되풀이했다
		var loose: Array = town.loose_logs()
		if not loose.is_empty() and not full and randf() < 0.8:
			var lg: Node3D = loose[randi() % loose.size()]
			spot = { "kind": "logs", "pos": lg.global_position, "log": lg }
			route = town.via_bridge(global_position, [{ "pos": lg.global_position + Vector3(-0.35, 0, 0), "act": "" }])
			target = route[0]["pos"]; state = "walk"; busy_until = now
			return true
		if not full and randf() < 0.75: sp = wc["work"]
	if sp.is_empty() or _free_slot(sp) < 0: return false
	spot = sp; slot = 0; _claim(sp, 0)
	if sp.has("door"):
		door_ref = sp["door"]; var dp: Vector3 = door_ref["pos"]
		route = town.via_bridge(global_position, call("_approach", door_ref) + [{ "pos": dp + Vector3(0, 0, 0.8), "act": "open" }, { "pos": dp + Vector3(0, 0, -1.3), "act": "close" }, { "pos": sp["pos"], "act": "" }])
	else: route = town.via_bridge(global_position, [{ "pos": sp["pos"], "act": "" }])
	target = route[0]["pos"]; state = "walk"; busy_until = now
	return true

## 부두 끝에 닿음(run 91) — 빈손이고 비가 안 오고 아무도 그 자리에서 낚고 있지 않으면 셋에 하나는 걸터앉아 던진다(사람이 C 로 하는 것과 같은 cast_line).
## 입질이 오면 town 이 같은 창 안에서 챈다(_fish) — 낚으면 _fish_caught. 60초 안에 안 물면 일어나 다른 데로(자세가 풀리면 대도 거둔다)
func _fish_arrive(now: float) -> bool:
	if fig.carrying or weather == "rain" or randf() >= 1.0 / 3.0: return false
	for e in town.fishers:
		if e["spot"] == spot: return false
	var yaw: float = spot["yaw"]
	global_position = spot["pos"] + Vector3(sin(yaw), 0.05, cos(yaw)) * 0.3
	fig.face(yaw); town.cast_line(fig, self, spot, now)
	busy_until = now + 60.0
	say(mind.line("fish"), 1.6)
	return true

## 낚았다 — 손에 든 물고기를 그 자리에서 세 입에(_bite: eat 자세, 한입마다 작아진다). 다 먹으면 떠난다
func _fish_caught(now: float) -> void:
	carrying_kind = "fish"; bites = 3; bite_at = now + 1.0; busy_until = now + 0.9 * 3 + 1.6
	say(mind.line("fish_catch"), 1.8)

## 손님으로 왔는데 장인이 없다 — 한마디 하고 곧 다른 자리로
func _trade_closed(now: float) -> void:
	busy_until = now + 1.0; say(mind.line("trade_closed"), 1.4)

## 두 바퀴가 끝났을 때 아직 손님 자리면 가위가 새것 — 맞아 넘어졌거나 비로 떠났으면 없던 일
func _sharpened() -> void:
	if state != "busy" or spot.get("kind", "") != "whet" or town.cutler_at_work() == null: return   # 칼갈이가 도중에 떠났으면 없던 일
	dull = 0; say(mind.line("sharpened"), 1.6)

## 한 바퀴가 끝났을 때 아직 손님 걸상이면 찢어진 곳이 없어진다 — 맞아 넘어졌거나 비로 떠났으면 없던 일(그럼 또 찢어진 채로 다시 온다)
func _mended() -> void:
	if state != "busy" or spot.get("kind", "") != "fitting" or town.tailor_at_work() == null: return
	Wear.mend(fig.worn.get("back"))
	var w: ResidentBase = town.tailor_at_work()
	if w != null: w.say("There.", 1.4)
	get_tree().create_timer(1.2).timeout.connect(func() -> void: say(mind.line("mended"), 1.6))

## 두 바퀴가 끝났을 때 아직 걸상이면 밑창이 새것 — 맞아 넘어졌거나 비로 떠났으면 없던 일
func _resoled() -> void:
	if state != "busy" or spot.get("kind", "") != "stool" or town.cobbler_at_work() == null: return
	walked = 0.0; say(mind.line("resoled"), 1.6)

# ── 싸움(2026-10-01) — 사람과 같은 기술표(FightMoves). 실력은 성미·배짱에서: 높을수록 연계를 길게 잇고 센 기술을 섞고, 덜 쉬고, 막거나 피한다 ──
var act_until := 0.0
var act_dur := 0.0
var last_move := ""
var chain_until := -1.0

func fight_skill() -> float:
	return clampf(0.15 + 0.5 * mind.temper + 0.35 * mind.brave, 0.0, 1.0)

## 쫓기(state chase) 한 프레임 — 수평 속도를 돌려준다. 기술 중엔 제자리(기술의 lunge 만큼 살짝 나간다), 사거리 밖이면 달려가고, 안이면 다음 기술
func _chase(now: float) -> Vector2:
	if quarry == null or now >= chase_until:
		say(mind.line("giveup")); quarry = null; fig.action = ""; fig.action_t = 0.0; fig.move = ""
		state = "routine"; busy_until = now + 1.0
		return Vector2.ZERO
	var to := quarry.global_position - global_position; to.y = 0.0
	var d := to.length(); var dir := to.normalized()
	if now < act_until:
		fig.action_t = 1.0 - (act_until - now) / act_dur; fig.move_dir = Vector3.ZERO; fig.speed = 0.0
		var lg := float(FightMoves.get_move(fig.move)["lunge"]) if fig.move in FightMoves.MOVES else 0.0
		return Vector2(dir.x, dir.z) * lg * 0.6
	if fig.action == "fight": fig.action = ""; fig.action_t = 0.0
	if d > 0.85:
		fig.move_dir = dir; fig.speed = RUN
		return Vector2(dir.x, dir.z) * RUN
	fig.move_dir = Vector3.ZERO; fig.speed = 0.0; fig.face(atan2(dir.x, dir.z))
	if now >= next_punch:
		var sk := fight_skill()
		var m := FightMoves.resident_pick(last_move, sk, now < chain_until)
		var mv := FightMoves.get_move(m)
		fig.action = "fight"; fig.move = m; fig.action_t = 0.0
		act_dur = float(mv["dur"]); act_until = now + act_dur; last_move = m; chain_until = act_until + 0.3
		next_punch = act_until + lerpf(0.7, 0.08, sk) + randf() * 0.2   # 서툰 사람은 한 대 치고 숨을 고른다
		get_tree().create_timer(act_dur * float(mv["hit"])).timeout.connect(func() -> void:
			if state == "chase" and fig.move == m and quarry: town.resident_hits_player(self, dir, m))
	return Vector2.ZERO

## 사람이 내 앞에서 기술을 시작함(town_combat start_move) — 싸우는 중이거나 방금 맞은 사람만 반응한다. 실력만큼: 막기(가드) 아니면 피하기(뒤로 반 발짝)
func sense_attack(now: float, _m: String) -> void:
	if state in ["down", "getup", "drive"] or in_boat or fig.seated: return
	if not (state == "chase" or now - last_hit < 4.0): return
	var sk := fight_skill()
	if randf() > sk * 0.55: return
	var away: Vector3 = global_position - town.body.global_position; away.y = 0.0
	if randf() < 0.6:
		guard_until = now + FightMoves.BLOCK_T
		fig.action = "fight"; fig.move = "block"; act_dur = FightMoves.BLOCK_T; act_until = guard_until
		fig.face(atan2(-away.x, -away.z))
	else:
		fig.action = "fight"; fig.move = "dodge"; act_dur = FightMoves.DODGE_T; act_until = now + act_dur
		velocity += away.normalized() * 3.2

## 나눠 먹기("Sharing food" 1조각, run 85): 먹을 걸 들고 벤치에 앉았는데 같은 벤치에 빈손으로 앉은 이가 있으면 — 주민이든 사람이든 — 반을 쪼개 건넨다(share 자세).
## 친할수록 잘 주고 사이가 나쁘면(relation_k < 0) 거의 안 준다; 사람에겐 호감(fond)만큼. 안 주면(평범한 결과) 그냥 앉아 있다. 준 쪽도 받은 쪽도 남은 두 입을 앉은 채 먹는다
func _share(now: float) -> void:
	if carrying_kind == "cup": _pass_along(now, null, 0.3, 0.15); return   # 컵은 쪼갤 수 없다 — 꽉 찬 벤치면 줄을 따라 넘긴다(run 86); 0.7 은 그냥 들고 앉아 있다
	if not (carrying_kind in town.FOOD) or fig.carrying == null or int(fig.carrying.get_meta("bites", 0)) >= 2: return
	var at: Vector3 = spot["pos"]
	var mate: Node3D = null
	for o in town.residents:
		if o == self or o.state != "busy" or not o.fig.seated or o.fig.carrying != null or o.bites > 0 or String(o.spot.get("kind", "")) != "bench": continue
		if (o.spot["pos"] as Vector3).distance_to(at) < 0.1 and randf() < 0.35 + 0.4 * mind.relation_k(o): mate = o; break
	if mate == null and town.player.seated and town.player.carrying == null and town.seat_at(at) and randf() < 0.35 + 0.4 * mind.fond:
		mate = town.body
	if mate == null: return
	if randf() < 0.4 and _pass_along(now, null, 1.0, 0.15): return   # 나누려던 차에 벤치가 꽉 찼으면 반 대신 통째로 줄을 따라 — 나누는 확률을 갈라 쓰니 혼자 먹기(평범한 결과)는 run 85 그대로
	fig.set_meta("share_side", TownMeals.share_side(spot.get("yaw", 0.0), global_position, mate.global_position))
	fig.pose_request = "share"; busy_until = now + StickPoses.SHARE_T + 0.9 * 2 + 2.0
	say(mind.line("share_offer"), 1.4)
	get_tree().create_timer(StickPoses.SHARE_HAND).timeout.connect(func() -> void: _hand_half(mate))

func _hand_half(mate: Node3D) -> void:
	if state != "busy" or fig.pose_request != "share" or fig.carrying == null or not is_instance_valid(mate): return   # 그새 맞았거나 떠났다 — 없던 일
	var now := Time.get_ticks_msec() / 1000.0
	var to_player: bool = mate == town.body
	if to_player and (not town.player.seated or town.player.carrying != null): return   # 사람이 일어났다
	if not to_player and (not (mate as ResidentBase).fig.seated or (mate as ResidentBase).fig.carrying != null): return
	var half: Node3D = town.split_food(fig.carrying)
	if half == null: return
	if to_player: town.take_share(half, self)
	else: (mate as ResidentBase).take_half(half, self)
	bites = 3 - int(fig.carrying.get_meta("bites", 1)); bite_at = now + (StickPoses.SHARE_T - StickPoses.SHARE_HAND) + 0.1

## 줄을 따라 넘기기("Sharing food" 2조각, run 86): 세 칸 벤치가 꽉 찼을 때(나 + 둘) 든 컵·먹을 거를 옆 칸 빈손에게 통째로(pass 자세). 받은 쪽은 온 반대쪽으로 또 넘길 수 있다 — 확률은 한 번마다 반(onward)
func _pass_along(now: float, from: Node3D, chance: float, onward: float) -> bool:
	if fig.carrying == null or not TownMeals.passable(carrying_kind) or randf() >= chance: return false
	var row: Array[Node3D] = town.bench_row(spot["pos"])
	if row.size() < 3: return false   # 둘뿐이면 줄이 아니다 — 반 쪼개기(_share)가 맡는다
	var yaw: float = spot.get("yaw", 0.0)
	for o in row:
		if o == self or o == from or o.global_position.distance_to(global_position) > 0.6: continue
		if from != null and TownMeals.share_side(yaw, global_position, o.global_position) == TownMeals.share_side(yaw, global_position, from.global_position): continue   # 온 쪽으로 되돌리지 않는다
		var empty: bool = town.player.carrying == null if o == town.body else ((o as ResidentBase).fig.carrying == null and (o as ResidentBase).bites == 0)
		if not empty: continue   # 이미 든 이에게는 안 넘긴다
		fig.set_meta("share_side", TownMeals.share_side(yaw, global_position, o.global_position))
		fig.pose_request = "pass"; busy_until = maxf(busy_until, now + StickPoses.PASS_T + 0.5)
		say(mind.line("pass_on"), 1.2)
		get_tree().create_timer(StickPoses.PASS_HAND).timeout.connect(func() -> void: _hand_pass(o, onward))
		return true
	return false

func _hand_pass(mate: Node3D, onward: float) -> void:
	if state != "busy" or fig.pose_request != "pass" or fig.carrying == null or not is_instance_valid(mate): return   # 그새 맞았거나 떠났다 — 없던 일
	if mate == town.body:
		if not town.seat_at(spot.get("pos", Vector3.INF)) or town.player.carrying != null: return   # 같은 벤치에 앉아 있어야(시소·의자도 seated 다)
		town.take_passed(_let_go(), self)
		return
	var r := mate as ResidentLife
	if r.state != "busy" or not r.fig.seated or r.fig.carrying != null: return
	r.take_passed(_let_go(), self, onward)

func _let_go() -> Node3D:
	var it := fig.release(town, Vector3.ZERO); bites = 0
	carrying_kind = String(fig.carrying.get_meta("kind", "")) if fig.carrying else ""
	return it

## 넘겨받기 — 손에 들고 고맙다 하고, 잠깐 뒤 줄 반대쪽으로 또 넘기거나(onward) 앉은 채 남은 입을 먹는다. 컵이면 든 채 앉아 있다
func take_passed(it: Node3D, from: Node3D, onward: float) -> void:
	fig.hold(it); carrying_kind = String(it.get_meta("kind", ""))
	busy_until = maxf(busy_until, Time.get_ticks_msec() / 1000.0 + 2.0)
	if from == town.body: mind.gifted()
	elif from is ResidentBase: mind.befriend(from as ResidentBase, 0.05); (from as ResidentBase).mind.befriend(self, 0.05)   # 정은 양쪽으로
	mind.company = minf(1.0, mind.company + 0.15)   # 같은 벤치에서 나눠 먹으면 덜 외롭다
	say(mind.line("pass_thanks"), 1.2)
	get_tree().create_timer(0.6).timeout.connect(func() -> void: _after_pass(from, onward))

func _after_pass(from: Node3D, onward: float) -> void:
	if state != "busy" or fig.carrying == null or not fig.seated: return
	var now := Time.get_ticks_msec() / 1000.0
	if is_instance_valid(from) and _pass_along(now, from, onward, onward * 0.5): return
	if carrying_kind in town.FOOD:
		bites = 3 - int(fig.carrying.get_meta("bites", 0)); bite_at = now + 0.3; busy_until = maxf(busy_until, now + 0.9 * bites + 1.5)

## 나루(run 94) 걷던 길의 "board" — 배가 제 쪽 부두에 비어 있으면 탄다(건너편 부두에서 town_boat 가 내려 주고 길을 잇는다).
## 그새 떠났으면(사람이 탔다) 내릴 부두("land")를 버리고 여기서 다리·디딤돌로 다시 짠다 — 부두에 서서 배를 기다리진 않는다
func _ferry_board() -> void:
	if town.board(self, true): say(mind.line("ferry"), 1.6); return
	var rest: Array = route.slice(1)
	if rest.is_empty(): rest = [{ "pos": route[0]["pos"] if not route.is_empty() else global_position, "act": "" }]
	route = town.crossings(global_position, rest[0]["pos"]) + rest
