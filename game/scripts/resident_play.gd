class_name ResidentPlay
extends ResidentFurnish
## 놀이터에서 남을 거드는 주민 — 그네 밀어 주기·시소 반대쪽 앉기·시소에서 튀어 오르기. town_systems 의 _swings/_seesaws 가 부른다.
## resident.gd 가 500줄을 넘어 주제별로 떼어 낸 층(run 117 점검 때): … → ResidentPawn → ResidentFurnish → **ResidentPlay** → Resident → ResidentKid

## 그네 뒤로 가서 밀어 주기(사람이 타는데 안 밀 때 town 이 부르거나, 주민이 그네 자리에 왔는데 차 있을 때)
func go_push(sw: Dictionary) -> void:
	_release()   # 걸어가던(또는 방금 잡은 그네) 자리를 비운다 — 안 비우면 그 칸이 영영 '찬 자리'
	pushing_swing = sw; sw["pusher"] = self
	spot = { "kind": "push", "swing": sw }
	route = town.crossings(global_position, sw["at"]) + [{ "pos": sw["at"] + Vector3(0, 0, -1.1), "act": "" }]
	target = route[0]["pos"]; state = "walk"
	say(["Hold on.", "Here.", "Higher?"][uid % 3], 1.5)


## 시소 반대쪽으로 — 사람이 혼자 타고 있으면 와서 앉는다(town_systems _seesaws). 도착하면 _arrive 의 "seesaw" 가 가까운 쪽(= 빈 쪽)에 앉힌다
func go_seesaw(sp: Dictionary, side: int) -> void:
	_release()
	var ss: Seesaw3D = sp["ss"]
	var seat := ss.seat_pos(side); seat.y = 0.0
	spot = sp; slot = 0; set_meta("ss_coming", true)
	route = town.crossings(global_position, seat) + [{ "pos": seat + (seat - ss.global_position).normalized() * 0.35, "act": "" }]
	target = route[0]["pos"]; state = "walk"
	say(["I'll take the other end.", "Room for one?", "Hold still."][uid % 3], 1.6)
	get_tree().create_timer(20.0).timeout.connect(func() -> void: if is_instance_valid(self): remove_meta("ss_coming"))

## 시소에서 튀어 오름 — 날아올랐다 발로 착지하고, 한마디
func seesaw_launch(vy: float) -> void:
	riding_seesaw = null; fig.seated = false; _release()
	collision_layer = 4; collision_mask = 7
	velocity = Vector3(randf_range(-0.4, 0.4), vy, randf_range(0.3, 0.8)); fig.squash = 1.0
	state = "busy"; busy_until = Time.get_ticks_msec() / 1000.0 + 1.2; spot = { "kind": "greet" }
	say(["Whoa.", "That was high.", "Again."][uid % 3], 1.4)
