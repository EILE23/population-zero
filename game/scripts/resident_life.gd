class_name ResidentLife
extends ResidentBase
## 주민의 하루 — 일과표(시간대·직업이 고르는 자리), 수다, 운전. resident.gd 가 500줄에 닿아 뗐다(2026-09-30). 사슬: base → life → resident

var car_seat: Car3D = null
var own_car: Car3D = null     # 내 차 — 끌려 내려도 일이 끝나면 돌아가 다시 탄다

## 지금 시각(0..24) — town 의 해와 같은 시계
func _hour() -> float:
	return fmod(town.clock * 24.0 + 6.0, 24.0)

## 일과표 — 이 시각에 이 사람이 가고 싶은 자리 종류. 직업은 uid 로(정원사·가게지기·산책꾼), 빵집 주인·수리공·운전사는 따로 돈다
func _schedule_kinds() -> Array:
	var h := _hour()
	var role: String = ["gardener", "keeper", "walker", "walker", "keeper", "walker"][uid % 6] if job == "" else job
	if h < 9.0: return ["counter", "door", "bank"]                            # 아침: 빵 사러, 집 앞, 물가
	if h >= 12.0 and h < 13.5: return ["counter", "bench", "chair"]           # 점심: 창구·벤치
	if h >= 17.0: return ["bench", "lamp", "swing", "seesaw", "grass", "lookout", "bank"]   # 저녁: 놀고 쉰다
	match role:                                                               # 낮 일
		"gardener": return ["plot", "tree", "grass"]
		"keeper": return ["door", "counter", "hatstand"]                        # 노점 손님 자리(door)·창구에 서 있는다
		_: return ["bench", "tree", "bank", "lookout", "lamp"]

## 수다 — 자리에 닿았을 때 2m 안에 쉬는 주민이 있으면 서로 마주 보고 번갈아 말한다(8~14초). 말 많은 사람일수록 자주. 사람이 끼어들면(인사) 그만
func _chat(now: float) -> bool:
	if spot.get("kind", "") in ["bed", "chair", "shelf", "swing", "seesaw", "plot", "oven", "repair", "grass"] or randf() > 0.15 + 0.4 * mind.social: return false
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
	mind.tick(delta)
	_notice(Time.get_ticks_msec() / 1000.0)
	if town.residents.size() > 0 and town.residents[0] == self: ResidentMind.save_all(town.residents)

func _exit_tree() -> void:
	if town and town.residents.size() > 0 and town.residents[0] == self: ResidentMind.save_all(town.residents, true)

## 사람을 알아본다(4m, 1초에 한 번쯤): 좋아하면 먼저 손을 흔들고, 처음 보면 말 많은 사람은 인사하고, 미우면 — 성미 급한 사람은 쫓아오고, 겁 많은 사람은 피하고, 나머지는 한마디 쏘아붙인다
func _notice(now: float) -> void:
	if now < mind.notice_at: return
	mind.notice_at = now + randf_range(0.6, 1.2)
	var free_body := state == "routine" or state == "walk" or (state == "busy" and not fig.seated and riding_swing.is_empty() and riding_seesaw == null and not in_boat and fig.pose_request in ["", "umbr"] and bites == 0)
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
	_release(); car_seat = c; own_car = c; c.driver = self; job = "driver"; fig.scale = Vector3.ONE * 0.8
	state = "drive"; collision_layer = 0; collision_mask = 0
	say(["Morning route.", "Mind the road.", "On schedule."][uid % 3], 2.0)

## 차에서 내림(끌려 나감) — 운전석 옆에 서고 몸·충돌을 되돌린다. 일자리(운전사)와 내 차는 그대로
func leave_car() -> void:
	if car_seat == null: return
	var c := car_seat
	if c.driver == self: c.driver = null
	global_position = c.exit_pos() + Vector3(0, 0.02, 0); car_seat = null
	fig.scale = Vector3.ONE; fig.seated = false; fig.pose_request = ""; collision_layer = 4; collision_mask = 7
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
