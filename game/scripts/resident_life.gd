class_name ResidentLife
extends ResidentBase
## 주민의 하루 — 일과표(시간대·직업이 고르는 자리), 수다, 운전. resident.gd 가 500줄에 닿아 뗐다(2026-09-30). 사슬: base → life → resident

var car_seat: Car3D = null

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

## 수다 — 자리에 닿았을 때 2m 안에 쉬는 주민이 있으면 서로 마주 보고 번갈아 말한다(8~14초). 사람이 끼어들면(인사) 그만
func _chat(now: float) -> bool:
	if spot.get("kind", "") in ["bed", "chair", "shelf", "swing", "seesaw", "plot", "oven", "repair", "grass"] or randf() > 0.35: return false
	return _chat_force(now)

## 수다를 곧장(시트 도구·이벤트용)
func _chat_force(now := Time.get_ticks_msec() / 1000.0) -> bool:
	for o in town.residents:
		if o == self or o.state != "busy" or o.fig.pose_request != "" or o.fig.seated: continue
		if o.global_position.distance_to(global_position) > 2.0: continue
		var lines: Array = [["Lovely weather.", "Is it."], ["Did you hear about the bakery?", "I did not."], ["The river is high today.", "It usually is."], ["Busy day?", "Somewhat."], ["That car again.", "Every morning."]]
		var pair: Array = lines[(uid + o.uid) % lines.size()]
		var until := now + randf_range(8.0, 14.0)
		for pr in [[self, o, pair[0]], [o, self, pair[1]]]:
			var a: Resident = pr[0]; var b: Resident = pr[1]
			a.fig.pose_request = "talk"; a.fig.face(atan2(b.global_position.x - a.global_position.x, b.global_position.z - a.global_position.z))
			a.busy_until = until; a.state = "busy"
		say(pair[0], 2.4)
		o.get_tree().create_timer(1.8).timeout.connect(func() -> void: if o.fig.pose_request == "talk": o.say(pair[1], 2.4))
		return true
	return false

## 운전 맡기 — 이 주민이 이 차의 운전사가 된다. 충돌을 끄고(차 안), 일과를 멈춘다
func drive(c: Car3D) -> void:
	_release(); car_seat = c; c.driver = self; job = "driver"
	state = "drive"; collision_layer = 0; collision_mask = 0
	say(["Morning route.", "Mind the road.", "On schedule."][uid % 3], 2.0)
