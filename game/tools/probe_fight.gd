extends SceneTree
## 싸움 점검(헤드리스): 입력 연계(Z Z Z → 앞차기·밀어차기·돌려차기, Z X → 등주먹, X X X X → 잽·스트레이트·훅·어퍼컷, 공중 Z → 날아차기),
## 맞은 주민의 반응(넘어짐·밀림), 실력 높은 주민의 기술 다양성·막기
var town: Node3D
func _press(a: String) -> void:
	Input.action_press(a); await physics_frame; Input.action_release(a)

func _seq(keys: Array, gap_frames: int) -> Array:
	var got: Array = []
	for k in keys:
		await _press(k)
		for i in gap_frames: await physics_frame
		got.append(town.move_last)
	return got

func _init() -> void:
	town = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	var b: CharacterBody3D = town.body
	b.global_position = Vector3(-3.5, 0.02, 15.0); town.player.face(PI / 2.0); town.player.rotation.y = PI / 2.0
	for i in 10: await physics_frame
	print("CHAIN ZZZ ", await _seq(["kick", "kick", "kick"], 24))
	for i in 60: await physics_frame
	print("CHAIN XXXX ", await _seq(["hit", "hit", "hit", "hit"], 16))
	for i in 60: await physics_frame
	print("CHAIN ZX ", await _seq(["kick", "hit"], 20))
	for i in 60: await physics_frame
	b.velocity.y = 6.0; for i in 6: await physics_frame
	print("AIR ", await _seq(["kick"], 2), " ", await _seq(["hit"], 2) if false else "")
	for i in 90: await physics_frame
	# 맞기: 앞 0.8m 주민에게 밀어차기
	var r: Resident = town.residents.filter(func(x): return x.state != "drive")[2]
	r.global_position = b.global_position + Vector3(0.8, 0, 0); r.state = "routine"; r.guard_until = -1.0
	town.player.face(PI / 2.0); town.player.rotation.y = PI / 2.0
	town.move_last = "front"; town.chain_until = Time.get_ticks_msec() / 1000.0 + 1.0
	var p0: Vector3 = r.global_position
	await _press("kick")
	for i in 40: await physics_frame
	print("HITPUSH move=", town.move_last, " state=", r.state, " moved=%.2f" % r.global_position.distance_to(p0))
	# 실력 좋은 주민이 쫓아와 싸운다 — 쓴 기술 종류와 막기
	var hot: Resident = town.residents.filter(func(x): return x.state != "drive").reduce(func(a, x): return x if x.fight_skill() > a.fight_skill() else a)
	hot.global_position = b.global_position + Vector3(2.0, 0, 0); hot.quarry = b; hot.state = "chase"; hot.chase_until = Time.get_ticks_msec() / 1000.0 + 8.0
	var used := {}; var blocks := 0
	for i in 480:
		await physics_frame
		if hot.fig.action == "fight": used[hot.fig.move] = true
		if i % 40 == 0 and town.down_until < Time.get_ticks_msec() / 1000.0:
			town.player.face(atan2(hot.global_position.x - b.global_position.x, hot.global_position.z - b.global_position.z)); town.player.rotation.y = town.player._yaw_target
			await _press("hit")
		if hot.guard_until > Time.get_ticks_msec() / 1000.0: blocks += 1
	print("RESIDENT ", hot.handle, " skill=%.2f used=%s guard_frames=%d player_downs=%s last_hit_on_me=%.1f" % [hot.fight_skill(), used.keys(), blocks, town.down_until > 0.0, town.my_last_hit])
	quit()
