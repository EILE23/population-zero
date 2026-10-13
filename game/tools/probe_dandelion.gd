extends SceneTree
## 민들레 홀씨 팩 점검(헤드리스): 자료가 읽히나, 바람 절벽 층의 잇단 발판 짝(70..240 px 틈, 위 발판이 0..160 px 높이; 위 발판은 crumble·spring 도 된다) 중 바람 아래쪽의 가장 넓은 틈에만 민들레가 서나(바람이 없으면 어느 쪽이든, 있으면 그쪽만; 연이 든 틈·지름길 판이 가르는 틈은 비켜 가나, 거울상, 층 19/20/24/25/56),
## 줄기 앞(아래 발판 가장자리 44 안)에서만 C 가 민들레의 것인가, 불면 홀씨가 0.5 뒤 0.2 마다 떠나 돌풍 120 과 20 px/s 로 오르다 3초에 터지나, 빈 머리는 bare 로 아무 일이 없고 마지막 홀씨 뒤 12초에 다시 차나,
## 꼭대기·떨어지는 몸의 손만 홀씨를 잡나(오르는 몸·멀리·앞·잡힌 홀씨는 아니다), 탄 몸이 홀씨와 같이 가다 1.5초에 30 px 높이에서 done 이 되나, 놓으면 홀씨의 속도를 주나, 모르는 민들레는 done 인가,
## 뿌리 잎·줄기·꽃받침·머리의 홀씨 여덟·날아가는 홀씨 여덟·소리 셋이 그려지고 떠난 홀씨가 머리에서 사라졌다 다시 자라나, puff 자세가 들숨에 가슴을 열고 팔을 올리며 날숨에 고개를 밀고 팔을 떨어뜨리고 회수에 바로 서나, 진짜 탑의 1..65층에서 plan 이 바람 절벽 층에만 민들레를 찾나
const C = preload("res://scripts/games/climb.gd")

func _init() -> void:
	var cd := ClimbDandelion.new(); root.add_child(cd)
	var ck := ClimbKite.new(); root.add_child(ck)
	var cv := ClimbVane.new(); root.add_child(cv)
	await process_frame
	print("PACK id=", cd.pack.get("id"), " kind=", cd.kind.size() > 0, " pose=", cd.pack.get("pose"), " themes=", cd.pack.get("themes"), " stalk_off=%.0f head_up=%.0f head_r=%.0f seeds=%d root_d=%.0f reach=%.0f blow_at=%.1f stagger=%.1f rise=%.0f life=%.1f hang=%.0f catch_r=%.0f catch_vy=%.0f carry=%.1f regrow=%.0f deck_d=%.0f v(0)=%.0f v(80)=%.0f v(400)=%.0f (want dandelion true puff [Wind cliffs] 20 24 22 8 30 44 0.5 0.2 20 3.0 58 26 60 1.5 12 28 120 80 240)" % [cd.stalk_off(), cd.head_up(), cd.head_r(), cd.seeds(), cd.root_d(), cd.reach(), cd.blow_at(), cd.stagger(), cd.rise_v(), cd.life_s(), cd.hang(), cd.catch_r(), cd.catch_vy(), cd.carry_s(), cd.regrow_s(), cd.deck_d(), cd.speed_for(0.0), cd.speed_for(80.0), cd.speed_for(-400.0)])
	var plats: Array = [
		{ "id": "21.0", "x": 100.0, "y": 12700.0, "w": 180.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "21.1", "x": 400.0, "y": 12800.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "21.2", "x": 110.0, "y": 12920.0, "w": 160.0, "kind": "ice", "z": -29.0, "d": 82.0 },
		{ "id": "21.3", "x": 390.0, "y": 13090.0, "w": 120.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "21.4", "x": 560.0, "y": 13200.0, "w": 110.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "21.5", "x": 400.0, "y": 13310.0, "w": 90.0, "kind": "crumble", "z": -29.0, "d": 82.0 },
		{ "id": "21s", "x": 640.0, "y": 12848.0, "w": 60.0, "kind": "short", "z": -29.0, "d": 60.0 },
	]
	var gust := cd.plan(21, plats, 0.0)
	var east := cd.plan(21, plats, 80.0); var west := cd.plan(21, plats, -80.0)
	var kited := cd.plan(21, plats, 0.0, [{ "id": "21.K0", "kind": "kite", "x": 270.0, "w": 130.0, "y": 12940.0 }])   # 연이 21.1↔21.2 의 틈에 — 21.0→21.1 (120) 으로 물러선다
	var cut := plats.duplicate(true); cut.append({ "id": "21c", "x": 300.0, "y": 12980.0, "w": 60.0, "kind": "short", "z": -29.0, "d": 60.0 })   # 21.1↔21.2 의 상자(260..410, 12770..13030)를 가른다
	var cutp := cd.plan(21, cut, 0.0)
	var mirror: Array = plats.map(func(p: Dictionary) -> Dictionary: var q := p.duplicate(); q["x"] = C.WORLD_W - float(p["x"]) - float(p["w"]); return q)
	var right := cd.plan(21, mirror, 0.0)
	var f19 := cd.plan(19, plats); var f20 := cd.plan(20, plats); var f24 := cd.plan(24, plats); var f25 := cd.plan(25, plats); var f56 := cd.plan(56, plats, -90.0)
	var band_root := Node3D.new(); root.add_child(band_root)
	cd.build(band_root, gust)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " dir %.0f gap %.0f dy %.0f %s→%s a_edge %.0f b_edge %.0f stalk %.0f head_y %.0f v %.0f x %.0f w %.0f y %.0f y_top %.0f z %.0f d %.0f" % [float(v["dir"]), float(v["gap"]), float(v["dy"]), String(v["a_id"]), String(v["b_id"]), float(v["a_edge"]), float(v["b_edge"]), float(v["stalk_x"]), float(v["head_y"]), float(v["v"]), float(v["x"]), float(v["w"]), float(v["y"]), float(v["y_top"]), float(v["z"]), float(v["d"])]
	print("PLAN gust=", gust.map(show), " (want 1: 21.D0 dir −1 gap 130 dy 120 21.1→21.2 wins over 21.0→21.1 gap 120 and 21.4→21.5 gap 70; 21.2→21.3 dy 170 out, 21.3→21.4 gap 50 out: a_edge 400 b_edge 270 stalk 380 head_y 12824 v 120 x 358 w 44 y 12800 y_top 12846 z −48 d 28)")
	var brief := func(v: Dictionary) -> String: return String(v["id"]) + " %s→%s dir %.0f gap %.0f stalk %.0f v %.0f" % [String(v["a_id"]), String(v["b_id"]), float(v["dir"]), float(v["gap"]), float(v["stalk_x"]), float(v["v"])]
	print("PLAN east=", east.map(brief), " (want 21.D0 21.0→21.1 dir 1 gap 120 stalk 300 v 80) west=", west.map(brief), " (want 21.D0 21.1→21.2 dir −1 gap 130 stalk 380 v 80) kited=", kited.map(brief), " (want 21.0→21.1 gap 120 stalk 300 v 120) cut=", cutp.map(brief), " (want the same) mirror=", right.map(brief), " (want 21.D0 21.1→21.2 dir 1 gap 130 stalk 580 v 120)")
	print("FLOORS 19=%d 20=%d 24=%d 25=%d 56=%d (want 0 1 1 0 1 — Clockwork 19 and Cloud sea 25 get none; 56 with a west wind finds 21.1→21.2)" % [f19.size(), f20.size(), f24.size(), f25.size(), f56.size()])
	var s: Dictionary = cd.heads[0]
	var z := C.PLAYER_Z
	var fig := Stick3D.new(); root.add_child(fig)
	var puff: AudioStreamPlayer3D = s["puff"]; var pop: AudioStreamPlayer3D = s["pop"]; var snap: AudioStreamPlayer3D = s["snap"]
	# 줄기 앞(dir −1: 가장자리 400 에서 발판 안쪽 44 까지): x 410 은 poised, 450 은 너무 멀고 395 는 가장자리 밖, 다른 발판 위는 아니다; 거기선 blow 가 took 거짓. x 410 의 blow: took, 8, puff; 0.1 뒤 다시 불면 bare
	cd.sync(0.0)
	var p_on := cd.poised(plats[1], 410.0); var p_far := cd.poised(plats[1], 450.0); var p_off := cd.poised(plats[1], 395.0); var p_other := cd.poised(plats[0], 410.0)
	var no := cd.blow(plats[1], 450.0, fig)
	var bl := cd.blow(plats[1], 410.0, fig); var pf := puff.playing
	cd.sync(0.1); var again := cd.blow(plats[1], 410.0, fig)
	print("BLOW poised on=%s far=%s off=%s other=%s (want true false false false) | refused took=%s (want false) | took=%s seeds=%d bare=%s puff=%s count=%d (want true 8 false true 1) | again took=%s bare=%s (want false true) full=%s (want false)" % [p_on, p_far, p_off, p_other, no["took"], bl["took"], int(bl["seeds"]), bl["bare"], pf, int(s["count"]), again["took"], again["bare"], cd.full(s)])
	# 홀씨의 시계: 0 번은 0.5 에 떠나 3.5 에 터진다, 7 번은 1.9 에; 1.5 에 0 번 (260, 12844) k 1.0, 3 번 (332, 12832) k 0.4, 7 번은 아직; 3.6 에 0 번은 터졌다; 머리는 1.9 부터 12초 — 7.9 에 0.5, 13.9 에 full
	var l0 := cd.launch_at(s, 0); var l7 := cd.launch_at(s, 7); var pp0 := cd.pop_at(s, 0)
	cd.sync(1.5); var s0 := cd.seed_at(s, 0, 1.5); var s3 := cd.seed_at(s, 3, 1.5); var s7 := cd.seed_at(s, 7, 1.5); var g15 := cd.grow_k(s)
	pop.stop(); cd.sync(3.6); var s0g := cd.seed_at(s, 0, 3.6); var popped := pop.playing
	cd.sync(7.9); var g79 := cd.grow_k(s); var full79 := cd.full(s)
	cd.sync(13.9); var full139 := cd.full(s)
	print("SEEDS launch0=%.1f launch7=%.1f pop0=%.1f (want 0.5 1.9 3.5) | 1.5: s0=%.0f %.0f k %.1f (want 260 12844 1.0) s3=%.0f %.0f k %.1f (want 332 12832 0.4) s7 empty=%s (want true) grow=%.2f (want 0.00) | 3.6: s0 empty=%s pop=%s (want true true) | 7.9: grow=%.2f full=%s (want 0.50 false) | 13.9: full=%s (want true)" % [l0, l7, pp0, float(s0.get("x", 0.0)), float(s0.get("y", 0.0)), float(s0.get("k", 0.0)), float(s3.get("x", 0.0)), float(s3.get("y", 0.0)), float(s3.get("k", 0.0)), s7.is_empty(), g15, s0g.is_empty(), popped, g79, full79, full139])
	# 잡기(새로 불어 20.0 에; 1.5 뒤 = 21.5: 0 번 (260, 12844) — 손은 발 + 58; 1..4 번이 그 뒤로 24 px 씩 줄지어 있다): 발 12786 x 260 vy 0 → 잡힌다(snap); 오르는 몸(vy 100)·x 160(줄의 앞쪽 100 밖)·발 12700(손이 86 밑)·앞(z −20)은 아니다; 같은 자리에서 다시 잡으면 0 번은 잡힌 채라 줄의 다음 1 번
	cd.sync(20.0); cd.blow(plats[1], 410.0, fig)
	cd.sync(21.5)
	var rising := cd.catch(260.0, 12786.0, z, 100.0); var far := cd.catch(160.0, 12786.0, z, 0.0); var low := cd.catch(260.0, 12700.0, z, 0.0); var front := cd.catch(260.0, 12786.0, -20.0, 0.0)
	var g := cd.catch(260.0, 12786.0, z, 0.0); var sn := snap.playing
	var twice := cd.catch(260.0, 12786.0, z, 0.0)
	print("CATCH rising=%s far=%s low=%s front=%s (want empty ×4) | caught=%s kind=%s seed=%d x=%.0f y=%.0f t0=%.1f dir=%.0f snap=%s (want 21.D0 dandelion 0 260 12786 21.5 −1 true) | twice seed=%d (want 1 — seed 0 stays taken, the next tuft in the line is caught instead)" % [rising.is_empty(), far.is_empty(), low.is_empty(), front.is_empty(), String(g.get("id", "-")), String(g.get("kind", "-")), int(g.get("seed", 9)), float(g.get("x", 0.0)), float(g.get("y", 0.0)), float(g.get("t0", 0.0)), float(g.get("dir", 0.0)), sn, int(twice.get("seed", -1))])
	# 타기: 22.0 → x 200 발 12796 (k 1.5) done 거짓, 메타 kite_v −1 kite_set 0; 23.0 → 잡힌 뒤 1.5 = 터진다: x 80 발 12816 done 참 (잡힌 12786 보다 30 위); 23.2 도 같은 자리 done; 놓으면 vx −120 vy 20; 모르는 민들레는 그 자리 done
	cd.sync(22.0); var r1 := cd.ride(g, fig); var kv := float(fig.get_meta("kite_v", 9.0)); var ks := float(fig.get_meta("kite_set", 9.0))
	cd.sync(23.0); var r2 := cd.ride(g, fig)
	cd.sync(23.2); var r3 := cd.ride(g, fig)
	var v := cd.let_go(g); var lost := cd.ride({ "id": "nope", "x": 5.0, "y": 7.0 }, fig); var vnone := cd.let_go({ "id": "nope" })
	print("RIDE 22.0: x=%.0f y=%.0f done=%s kite_v=%.0f kite_set=%.1f (want 200 12796 false −1 0.0) | 23.0: x=%.0f y=%.0f done=%s (want 80 12816 true) | 23.2: x=%.0f y=%.0f done=%s (want 80 12816 true) | let_go vx=%.0f vy=%.0f (want −120 20) | unknown x=%.0f y=%.0f done=%s vx=%.0f (want 5 7 true 0)" % [float(r1["x"]), float(r1["y"]), r1["done"], kv, ks, float(r2["x"]), float(r2["y"]), r2["done"], float(r3["x"]), float(r3["y"]), r3["done"], float(v["vx"]), float(v["vy"]), float(lost["x"]), float(lost["y"]), lost["done"], float(vnone["vx"])])
	# 그림: 노드 아이 10(잎 셋·줄기·꽃받침·머리·날아가는 홀씨들·소리 셋), 머리 8, 홀씨 하나에 2, 날아가는 것 8 (하나에 3); 노드 자리 −2.7778 355.5555 −1.3333 (to3 는 x 를 가운데 480 에서 잰다)
	# 21.5(0..4 떠남): 머리 홀씨 0 은 숨고 7 은 크기 1, 날아가는 0 은 보이고 자리 (−3.33, 1.22)±0.05, 7 은 숨는다; 27.9 (떠난 21.9 + 6): 홀씨 0 크기 0.5; 34.0: 1
	var node: Node3D = s["node"]; var head: Node3D = s["head"]; var tufts: Array = s["tufts"]; var fl: Array = s["flights"]; var flights: Node3D = (fl[0] as Node3D).get_parent()
	cd.sync(21.5); cd._place(s)
	var t0v: bool = (tufts[0] as Node3D).visible; var t7s: float = (tufts[7] as Node3D).scale.y; var f0v: bool = (fl[0] as Node3D).visible; var f0p: Vector3 = (fl[0] as Node3D).position; var f7v: bool = (fl[7] as Node3D).visible
	cd.sync(27.9); cd._place(s); var t0h: float = (tufts[0] as Node3D).scale.y
	cd.sync(34.0); cd._place(s); var t0f: float = (tufts[0] as Node3D).scale.y
	print("VISUAL node children=%d (want 10) head=%d (want 8) tuft=%d (want 2) flights=%d (want 8) flight=%d (want 3) node pos=%.4f %.4f %.4f (want −2.7778 355.5556 −1.3333) | 21.5: tuft0 visible=%s (want false) tuft7 scale=%.2f (want 1.00) flight0 visible=%s pos=%.2f %.2f (want true −3.33±0.05 1.22±0.05) flight7 visible=%s (want false) | 27.9: tuft0 scale=%.2f (want 0.50) | 34.0: %.2f (want 1.00)" % [node.get_child_count(), head.get_child_count(), (tufts[0] as Node3D).get_child_count(), flights.get_child_count(), (fl[0] as Node3D).get_child_count(), node.position.x, node.position.y, node.position.z, t0v, t7s, f0v, f0p.x, f0p.y, f7v, t0h, t0f])
	# 자세(meta puff_t 로 멈춰 세운다): 들숨 0.5: 골반 0.43..0.435 엉덩이 −0.08 무릎 0.08..0.12 어깨 −0.55 어깨 z ∓0.42 팔꿈치 −0.55 몸통 0.09±0.006 가슴 −0.14±0.006 고개 0.11±0.01(기본 고개는 가슴에 더하기 전의 lean 으로 잰다);
	# 날숨 0.9: 골반 0.385..0.39 엉덩이 −0.20 무릎 0.28..0.32 어깨 −0.05 어깨 z ∓0.12 팔꿈치 −0.15 몸통 0.18±0.006 가슴 0.37±0.006 고개 0.17±0.01; 선 2.0: 골반 0.415..0.42 엉덩이 −0.08 무릎 0.08..0.12 어깨 −0.20 팔꿈치 −0.35 몸통 0.0225±0.006 가슴 0.0275±0.006 고개 −0.035±0.01 done
	fig.pose_request = "puff"
	fig.set_meta("puff_t", 0.5)
	await process_frame; await process_frame; await process_frame
	var early_sh: float = (fig.shoulders[1.0] as Node3D).rotation.x
	while fig.pose_t < 1.2: await process_frame   # 헤드리스는 프레임이 빠르다 — 시간으로 기다린다
	var pel_i := fig.pelvis.position.y; var hip_i: float = (fig.hips[1.0] as Node3D).rotation.x; var knee_i: float = (fig.knees[1.0] as Node3D).rotation.x; var sh_i: float = (fig.shoulders[1.0] as Node3D).rotation.x
	var shz_i: float = (fig.shoulders[1.0] as Node3D).rotation.z; var shz_ib: float = (fig.shoulders[-1.0] as Node3D).rotation.z; var el_i: float = (fig.elbows[1.0] as Node3D).rotation.x; var tor_i := fig.torso.rotation.x; var ch_i := fig.chest.rotation.x; var nk_i := fig.neck.rotation.x; var done_i := PuffPoses.done(fig)
	fig.set_meta("puff_t", 0.9)
	var t1 := fig.pose_t
	while fig.pose_t < t1 + 0.8: await process_frame   # 블렌딩이 새 순간에 닿을 시간
	var pel_o := fig.pelvis.position.y; var hip_o: float = (fig.hips[1.0] as Node3D).rotation.x; var knee_o: float = (fig.knees[1.0] as Node3D).rotation.x; var sh_o: float = (fig.shoulders[1.0] as Node3D).rotation.x
	var shz_o: float = (fig.shoulders[1.0] as Node3D).rotation.z; var el_o: float = (fig.elbows[1.0] as Node3D).rotation.x; var tor_o := fig.torso.rotation.x; var ch_o := fig.chest.rotation.x; var nk_o := fig.neck.rotation.x
	fig.set_meta("puff_t", 2.0)
	t1 = fig.pose_t
	while fig.pose_t < t1 + 0.8: await process_frame
	var pel_r := fig.pelvis.position.y; var hip_r: float = (fig.hips[1.0] as Node3D).rotation.x; var knee_r: float = (fig.knees[1.0] as Node3D).rotation.x; var sh_r: float = (fig.shoulders[1.0] as Node3D).rotation.x
	var el_r: float = (fig.elbows[1.0] as Node3D).rotation.x; var tor_r := fig.torso.rotation.x; var ch_r := fig.chest.rotation.x; var nk_r := fig.neck.rotation.x; var done_r := PuffPoses.done(fig)
	print("POSE early shoulder=%.2f (want > −0.45: the arms have only begun to lift) in: pelvis=%.3f (want 0.430..0.435) hip=%.3f (want −0.080) knee=%.3f (want 0.08..0.12) shoulder=%.3f (want −0.550) z=%.3f %.3f (want −0.420 0.420) elbow=%.3f (want −0.550) torso=%.4f (want 0.090±0.006) chest=%.4f (want −0.140±0.006) neck=%.4f (want 0.110±0.01: −(0.09 + 0.11) × 0.7 from the lean plus 0.25) done=%s (want false) | out: pelvis=%.3f (want 0.385..0.390) hip=%.3f (want −0.200) knee=%.3f (want 0.28..0.32) shoulder=%.3f (want −0.050) z=%.3f (want −0.120) elbow=%.3f (want −0.150) torso=%.4f (want 0.180±0.006) chest=%.4f (want 0.370±0.006) neck=%.4f (want 0.170±0.01: −(0.18 + 0.22) × 0.7 plus 0.45) | rest: pelvis=%.3f (want 0.415..0.420) hip=%.3f (want −0.080) knee=%.3f (want 0.08..0.12) shoulder=%.3f (want −0.200) elbow=%.3f (want −0.350) torso=%.4f (want 0.0225±0.006) chest=%.4f (want 0.0275±0.006) neck=%.4f (want −0.035±0.01) done=%s (want true)" % [early_sh, pel_i, hip_i, knee_i, sh_i, shz_i, shz_ib, el_i, tor_i, ch_i, nk_i, done_i, pel_o, hip_o, knee_o, sh_o, shz_o, el_o, tor_o, ch_o, nk_o, pel_r, hip_r, knee_r, sh_r, el_r, tor_r, ch_r, nk_r, done_r])
	# 진짜 탑: 1..65층에 plan 이 찾는 민들레 — 바람 절벽 층 20..24 (돌풍) 와 55..59 (그 층의 바람과 같은 쪽 짝이 있을 때만), 연·풍향계가 든 틈은 비켜서
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var count := 0; var bands: Array = []
	for n in range(1, 66):
		var pl: Array = gm.band(n); var wind: float = gm.wind_of(n)
		var kp: Array = ck.plan(n, pl, wind)
		var out2 := cd.plan(n, pl, wind, kp + cv.plan(n, pl, wind, kp))
		if out2.size() > 0: bands.append("%d:%s" % [n, out2.map(func(v: Dictionary) -> String: return "%s→%s dir %.0f gap %.0f dy %.0f wind %.0f v %.0f" % [String(v["a_id"]), String(v["b_id"]), float(v["dir"]), float(v["gap"]), float(v["dy"]), float(v["wind"]), float(v["v"])])])
		count += out2.size()
	print("TOWER floors=", bands, " dandelions=", count, " (want a subset of 20..24 and 55..59, one each, never another theme, dir matching the wind's sign where wind ≠ 0, v 120 without wind and |wind| with it, never the gap the kite or the vane took)")
	quit()
