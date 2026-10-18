extends SceneTree
## 별가루 더미 팩 점검(헤드리스): 자료가 읽히나, 별밤 층의 still std 발판 중 min_w 100 보다 넓고 기둥이 비고 taken 이 없는 가장 넓은 것에만 더미가 놓이나(등롱 장대가 선 발판은 비켜 가고, 기둥에 지름길 판이 든 발판도 비켜 가고, 좁은 발판뿐이면 없고, 다른 테마 층은 아니다; 31층은 5삽, 34층 8삽, 65층 4삽),
## 삽 곁의 C 가 파기에 들고(busy, shovel_t, digging, crunch) 삽에서 떠나면 그 삽은 버리고 몸이 바로 풀리나, 쥐고 있으면 0.2 s 찌르기·0.4 s 지렛대·0.7 s 헤이브·0.91 s 에 한 삽(dug 1, k 0.2, 다음 바퀴 shovel_t 0)이고, 놓으면 그 바퀴를 마치고(1.82 s 에 dug 2, stop) 0.3 s 뒤 풀리나(판 것은 남는다),
## 남이 파는 동안 플레이어의 C 는 기다리나, C 없는 몸·먼 z·다른 발판은 아무것도 아니나(평이 100%), 세 삽 더 파면(42.73) 별이 뜨고(dug, gaze, star, chime, day 0, deep 5, me_t) 0.4 s 에 별이 20 에 있고 0.67 s 에 몸이 풀리나, 1 s 뒤 별이 40 에 걸려 도나, 별이 뜬 더미 곁 C 는 아무것도 아니나,
## 쉼터 판의 줄(note)이 위 다섯 층 → 아래 다섯 층 순으로 세나, 90 s 뒤(132.74 — 실수 끝자리를 피해 0.01 늦게) 되메워지나(refill, hush, 0.5 s 에 별 20, 2 s 에 더미 반, 3.07 s 에 heaped·dug 0·별 없음), 다음 날 다른 몸(count 거짓)이 판 별은 세지 않나(0/1, 1 up),
## 더미·무더기·삽(손잡이·T 자루·날·띠)·별(세 조각)·내리는 별가루·소리 셋이 그려지나, 노드 자리, 꽂힌 삽의 자리(−6.6 px, −0.25),
## shovel 자세가 찌르기 끝(0.25)에 골반 0.34·상체 0.225·팔 −0.9·팔꿈치 −0.2·리드 엉덩이 −0.25·무릎 0.3·트레일 무릎 0.15·고개 > 0 이고, 찌르기 가운데(0.125)에 리드 엉덩이 −1.025·무릎 1.5 이고, 지렛대(0.55)에 골반 0.30·팔 −0.5·팔꿈치 −1.3·엉덩이 −0.1·무릎 0.4 이고,
## 헤이브 끝(0.9)에 골반 0.42·상체 −0.045·팔 −1.5·어깨 z −0.45 둘 다·팔꿈치 −0.3·무릎 0.1·고개 < 0 이고, 바라봄 0.3 s 에 리드 팔 −0.6/−0.5·트레일 팔 0.2/z 0.5/−1.3·리드 무릎 0.05·트레일 엉덩이 0.1·고개 −0.62±0.06 이고, 멈춤 0.15 s 에 트레일 팔 −2.75/−2.35 이고 0.3 s 에 서나(done),
## 진짜 탑의 1..70층에서 plan 이 별밤 층(30..34, 65..69)에만 더미를 찾나
const C = preload("res://scripts/games/climb.gd")
const DT := 1.0 / 60.0

func _init() -> void:
	var cd := ClimbDrift.new(); root.add_child(cd)
	var ci := ClimbIcicle.new(); root.add_child(ci)
	var cn := ClimbLantern.new(); root.add_child(cn)
	var ct := ClimbTrapeze.new(); root.add_child(ct)
	var cc := ClimbCandle.new(); root.add_child(cc)
	var ts := ClimbTelescope.new(); root.add_child(ts)
	var tr := ClimbTightrope.new(); root.add_child(tr)
	await process_frame
	print("PACK id=", cd.pack.get("id"), " kind=", cd.kind.size() > 0, " pose=", cd.pack.get("pose"), " themes=", cd.pack.get("themes"), " min_w=%.0f reach=%.0f d=%.0f w=%.0f h=%.0f heap=%.0f handle=%.0f col=%.0f scoops(31)=%d thrust=%.2f lever=%.2f heave=%.2f cycle=%.2f stop=%.2f star=%.0f rise=%.2f gaze=%.2f hang=%.0f sink=%.2f refill=%.2f day=%.0f (want drift true shovel [Starlit] 100 14 24 44 18 30 46 30 5 0.25 0.30 0.35 0.90 0.30 40 0.80 0.60 90 1.00 2.00 600)" % [cd.min_w(), cd.reach(), cd.drift_d(), cd.drift_w(), cd.drift_h(), cd.heap_dx(), cd.handle_h(), cd.col_w(), cd.scoops_of(31), cd.thrust_s(), cd.lever_s(), cd.heave_s(), cd.cycle_s(), cd.stop_s(), cd.star_h(), cd.rise_s(), cd.gaze_s(), cd.hang_s(), cd.sink_s(), cd.refill_s(), cd.day_s()])
	var plats: Array = [
		{ "id": "31.0", "x": 60.0, "y": 18700.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "31.1", "x": 320.0, "y": 18810.0, "w": 140.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "31.2", "x": 100.0, "y": 18920.0, "w": 130.0, "kind": "ice", "z": -29.0, "d": 82.0 },
		{ "id": "31.3", "x": 380.0, "y": 19030.0, "w": 120.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "31.4", "x": 150.0, "y": 19140.0, "w": 160.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "31.5", "x": 450.0, "y": 19250.0, "w": 130.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "31s", "x": 700.0, "y": 19190.0, "w": 40.0, "kind": "short", "z": -29.0, "d": 60.0 },
	]
	var free := cd.plan(31, plats)
	var pole := { "id": "31.L0", "kind": "lantern", "x": 225.0, "w": 10.0, "y": 19140.0, "len": 90.0 }   # 등롱 장대가 31.4 에 섰다 — 31.0 으로
	var poled := cd.plan(31, plats, [pole])
	var cut := plats.duplicate(true); cut.append({ "id": "31c", "x": 215.0, "y": 19180.0, "w": 40.0, "kind": "short", "z": -29.0, "d": 60.0 })   # 31.4 의 기둥에 지름길 판 — 31.0 으로
	var cutp := cd.plan(31, cut)
	var thin := plats.duplicate(true)
	for pv in thin:   # 전부 좁다 — 없다
		var q: Dictionary = pv; q["w"] = 90.0
	var thinp := cd.plan(31, thin)
	var f29 := cd.plan(29, plats); var f30 := cd.plan(30, plats); var f34 := cd.plan(34, plats); var f35 := cd.plan(35, plats); var f65 := cd.plan(65, plats)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " on %s w %.0f wx %.0f x %.0f w %.1f y %.0f y_top %.0f z %.0f d %.0f scoops %d" % [String(v["hop_id"]), float(v["hop_w"]), float(v["wx"]), float(v["x"]), float(v["w"]), float(v["y"]), float(v["y_top"]), float(v["z"]), float(v["d"]), int(v["scoops"])]
	var brief := func(v: Dictionary) -> String: return "%s wx %.0f scoops %d" % [String(v["hop_id"]), float(v["wx"]), int(v["scoops"])]
	print("PLAN free=", free.map(show), " (want 1: 31.D0 on 31.4 w 160 wx 230 x 208 w 69.6 y 19140 y_top 19190 z −58 d 24 scoops 5)")
	print("PLAN poled=", poled.map(brief), " (want [31.0 wx 135 scoops 5]) cut=", cutp.map(brief), " (want [31.0 wx 135 scoops 5]) thin=", thinp.size(), " (want 0) floors 29/30/34/35/65=", [f29.size(), f30.size(), f34.size(), f35.size(), f65.size()], " (want 0 1 1 0 1) scoops 30/34/65=", [int((f30[0] as Dictionary)["scoops"]) if f30.size() > 0 else -1, int((f34[0] as Dictionary)["scoops"]) if f34.size() > 0 else -1, int((f65[0] as Dictionary)["scoops"]) if f65.size() > 0 else -1], " (want 4 8 4)")
	var band_root := Node3D.new(); root.add_child(band_root)
	cd.build(band_root, free)
	var s: Dictionary = cd.drifts[0]
	var fig := Stick3D.new(); root.add_child(fig)
	var fig2 := Stick3D.new(); root.add_child(fig2)
	var on: Dictionary = plats[4]; var z := C.PLAYER_Z
	var crunch: AudioStreamPlayer3D = s["crunch"]; var chime: AudioStreamPlayer3D = s["chime"]; var hush: AudioStreamPlayer3D = s["hush"]
	# 파기(t 10, 몸 236 — 삽 230 곁): busy, shovel_t 0, digging, crunch; 삽에서 떠나면(150) 그 삽은 버리고 몸은 바로 풀린다(dug 0)
	cd.sync(10.0)
	var a := cd.dig(236.0, z, on, true, fig); var a_state := "%s/%s/%.0f/%s/%d/%s" % [String(s["st"]), String(s["ph"]), float(fig.get_meta("shovel_t", 9.0)), cd.digging(fig), int(s["digs"]), crunch.playing]
	var gone := cd.dig(150.0, z, on, true, fig); var gone_state := "%s '%s' %s %s %d" % [String(s["st"]), String(s["ph"]), cd.digging(fig), fig.has_meta("shovel_t"), int(s["dug"])]
	var far_z := cd.dig(236.0, z + 40.0, on, true, fig); var other_hop := cd.dig(236.0, z, plats[3], true, fig); var plain := cd.dig(236.0, z, on, false, fig)
	print("DIG start: busy=%s k=%.2f id=%s st/ph/meta/digging/digs/crunch=%s (want true 0.00 31.D0 heaped/thrust/0/true/1/true) | away: busy=%s → %s (want false 'heaped '' false false 0') | far z: %s other hop: %s plain (no C): %s st=%s (want false false false heaped)" % [a["busy"], float(a["k"]), String(a["id"]), a_state, gone["busy"], gone_state, far_z["busy"], other_hop["busy"], plain["busy"], String(s["st"])])
	# 쥐고 판다(t 20): 0.2 찌르기, 0.4 지렛대, 0.7 헤이브, 0.91 한 삽(dug 1, k 0.2, 다음 바퀴 shovel_t 0); 놓으면(21.5) 그 바퀴를 마치고 1.82 에 dug 2·stop, 1.97 아직 busy, 2.13 에 풀린다(판 것은 남는다)
	cd.sync(20.0); cd.dig(236.0, z, on, true, fig)
	cd.sync(20.2); var r1 := cd.dig(236.0, z, on, true, fig); var p1 := "%s t=%.2f" % [String(s["ph"]), float(fig.get_meta("shovel_t", 9.0))]
	cd.sync(20.4); cd.dig(236.0, z, on, true, fig); var p2 := String(s["ph"])
	cd.sync(20.7); cd.dig(236.0, z, on, true, fig); var p3 := String(s["ph"])
	cd.sync(20.91); var r4 := cd.dig(236.0, z, on, true, fig); var p4 := "%s dug=%d k=%.2f t=%.2f" % [String(s["ph"]), int(s["dug"]), float(r4["k"]), float(fig.get_meta("shovel_t", 9.0))]
	cd.sync(21.5); var r5 := cd.dig(236.0, z, on, false, fig); var p5 := "%s held=%s busy=%s" % [String(s["ph"]), s["held"], r5["busy"]]
	cd.sync(21.82); var r6 := cd.dig(236.0, z, on, false, fig); var p6 := "%s dug=%d k=%.2f end=%s busy=%s" % [String(s["ph"]), int(s["dug"]), float(r6["k"]), String(fig.get_meta("shovel_end", "?")), r6["busy"]]
	cd.sync(21.97); cd._process(0.0); var r7 := cd.dig(236.0, z, on, false, fig); var p7 := "%s u=%.2f busy=%s" % [String(s["ph"]), float(fig.get_meta("shovel_u", 9.0)), r7["busy"]]
	cd.sync(22.13); cd._process(0.0); var r8 := cd.dig(236.0, z, on, false, fig); var p8 := "%s '%s' busy=%s digging=%s meta=%s/%s/%s dug=%d" % [String(s["st"]), String(s["ph"]), r8["busy"], cd.digging(fig), fig.has_meta("shovel_t"), fig.has_meta("shovel_end"), fig.has_meta("shovel_u"), int(s["dug"])]
	print("HELD 0.2 s: busy=%s %s (want true thrust t=0.20) | 0.4 s: %s (want lever) | 0.7 s: %s (want heave) | 0.91 s: %s (want thrust dug=1 k=0.20 t=0.00) | let go at 0.59: %s (want heave held=false busy=true) | 0.91: %s (want stop dug=2 k=0.40 end=stop busy=true) | +0.15: %s (want stop u=0.15 busy=true) | +0.31: %s (want heaped '' busy=false digging=false meta=false/false/false dug=2)" % [r1["busy"], p1, p2, p3, p4, p5, p6, p7, p8])
	# 남이 판다(t 30, fig2): 플레이어의 C 는 기다린다(busy 거짓); fig2 가 떠나면 그 삽은 버린다
	cd.sync(30.0); cd.dig(236.0, z, on, true, fig2, false)
	var wait := cd.dig(236.0, z, on, true, fig); var wait_state := "%s" % [(s["fig"] as Stick3D) == fig2]
	cd.dig(150.0, z, on, true, fig2); var left := "'%s' %d" % [String(s["ph"]), int(s["dug"])]
	print("OTHER waits: busy=%s fig2=%s (want false true) | fig2 away: %s (want '' 2)" % [wait["busy"], wait_state, left])
	# 세 삽 더(t 40): 40.91 dug 3, 41.82 dug 4, 42.73 dug 5 → 별(dug, gaze, star, chime, day 0, deep 5, me_t 42.73, stars 1); 0.4 s 에 별 20·아직 busy; 0.67 s 에 풀림; 1 s 에 별 40; 별 곁 C 는 아무것도 아니다
	cd.sync(40.0); cd.dig(236.0, z, on, true, fig)
	cd.sync(40.91); cd.dig(236.0, z, on, true, fig); var d3 := int(s["dug"])
	cd.sync(41.82); cd.dig(236.0, z, on, true, fig); var d4 := int(s["dug"])
	cd.sync(42.73); var r9 := cd.dig(236.0, z, on, true, fig); var star_state := "%s/%s dug=%d k=%.1f busy=%s end=%s chime=%s day=%d deep=%d me_t=%.2f stars=%d" % [String(s["st"]), String(s["ph"]), int(s["dug"]), float(r9["k"]), r9["busy"], String(fig.get_meta("shovel_end", "?")), chime.playing, int(s["day"]), int(s["deep"]), float(s["me_t"]), int(s["stars"])]
	cd.sync(43.13); cd._process(0.0); var r10 := cd.dig(236.0, z, on, true, fig); var star: Node3D = s["star"]; var mid := "%s h=%.1f busy=%s visible=%s u=%.2f" % [String(s["ph"]), cd.star_h_now(s), r10["busy"], star.visible, float(fig.get_meta("shovel_u", 9.0))]
	cd.sync(43.4); cd._process(0.0); var r11 := cd.dig(236.0, z, on, true, fig); var freed := "'%s' busy=%s digging=%s meta=%s" % [String(s["ph"]), r11["busy"], cd.digging(fig), fig.has_meta("shovel_t")]
	cd.sync(43.73); cd._process(0.0); var hung := "h=%.1f yaw=%.2f" % [cd.star_h_now(s), wrapf(star.rotation.y, 0.0, TAU)]
	print("STAR 0.91/1.82: dug=%d/%d (want 3/4) | 2.73: %s (want dug/gaze dug=5 k=1.0 busy=true end=star chime=true day=0 deep=5 me_t=42.73 stars=1) | +0.4: %s (want gaze h=20.0 busy=true visible=true u=0.40) | +0.67: %s (want '' busy=false digging=false meta=false) | +1.0: %s (want h=40.0 yaw=%.2f)" % [d3, d4, star_state, mid, freed, hung, fmod(43.73 * TAU * 0.3, TAU)])
	print("NOTE 30=\"%s\" (want Stardust drifts, floors 30–34: 1 of 1 dug out today, the deepest 5 scoops, 1 star up.) 35=\"%s\" (want the same: nothing on 35..39, so the floors below) 40=\"%s\" (want empty)" % [cd.note(30), cd.note(35), cd.note(40)])
	# 되메움: 90 s 뒤(132.73) refill·hush; 0.5 s 에 별 20; 2 s 에 더미 반(mound_k 0.5); 3.07 s 에 heaped·dug 0·별 없음·더미 1
	var mound: Node3D = s["mound"]; var heap: Node3D = s["heap"]
	cd.sync(132.74); cd._process(0.0); var rf := "%s hush=%s" % [String(s["st"]), hush.playing]
	cd.sync(133.24); cd._process(0.0); var rf1 := "h=%.1f mound=%.2f heap=%.2f" % [cd.star_h_now(s), cd.mound_k(s), heap.scale.y]
	cd.sync(134.74); cd._process(0.0); var rf2 := "mound=%.2f scale=%.2f" % [cd.mound_k(s), mound.scale.y]
	cd.sync(135.81); cd._process(0.0); var rf3 := "%s dug=%d h=%.0f visible=%s mound=%.2f" % [String(s["st"]), int(s["dug"]), cd.star_h_now(s), star.visible, cd.mound_k(s)]
	print("REFILL 90 s: %s (want refill hush=true) | +0.5: %s (want h=20.0 mound=0.00 heap=0.90) | +2.0: %s (want mound=0.50 scale=0.50) | +3.07: %s (want heaped dug=0 h=−1 visible=false mound=1.00) note 30=\"%s\" (want … 1 of 1 dug out today, the deepest 5 scoops. — no longer up)" % [rf, rf1, rf2, rf3, cd.note(30)])
	# 다음 날(620): 다른 몸(count 거짓)이 다섯 삽 → 별은 뜨지만 세지 않는다(0/1, 1 up); 뜬 별 곁 플레이어의 C 는 아무것도 아니다
	cd.sync(620.0); cd.dig(236.0, z, on, true, fig2, false)
	for i in 5:
		cd.sync(620.0 + 0.91 * (i + 1)); cd.dig(236.0, z, on, true, fig2, false)
	var other := "%s/%s dug=%d day=%d stars=%d" % [String(s["st"]), String(s["ph"]), int(s["dug"]), int(s["day"]), int(s["stars"])]
	cd.sync(626.0); cd._process(0.0); var up_c := cd.dig(236.0, z, on, true, fig)
	print("DAY other body: %s (want dug/gaze dug=5 day=0 stars=2) note 30=\"%s\" (want … 0 of 1 dug out today, 1 star up.) C beside the star: busy=%s (want false)" % [other, cd.note(30), up_c["busy"]])
	# 그림: 노드 자리, 더미·무더기·삽(4)·별(3)·별가루·소리 셋, 꽂힌 삽의 자리
	var node: Node3D = s["node"]; var shovel: Node3D = s["shovel"]
	cd.sync(700.0); cd._process(0.0)
	print("VISUAL node=%s (want %s) children=%d (want 8: mound heap shovel star fall + 3 sounds) shovel parts=%d (want 4) star parts=%d (want 3) planted: x=%.4f y=%.2f z=%.4f tilt=%.2f (want −0.1833 0.00 0.3333 −0.25) heap x=%.4f (want 0.8333)" % [node.position, C.to3(230.0, 19140.0, C.WALL_Z * C.K), node.get_child_count(), shovel.get_child_count(), star.get_child_count(), shovel.position.x, shovel.position.y, shovel.position.z, shovel.rotation.z, heap.position.x])
	await _pose(fig)
	# 진짜 탑: 1..70층에 plan 이 찾는 더미 — 별밤 층 30..34, 65..69 중 고드름·등롱·그네·초 계단·망원경·외줄이 안 쓴 넓은 발판이 있는 층만
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var bands: Array = []
	for n in range(1, 71):
		var pl: Array = gm.band(n)
		var ic: Array = ci.plan(n, pl); var lp: Array = cn.plan(n, pl, ic); var tp: Array = ct.plan(n, pl, ic + lp); var cp: Array = cc.plan(n, pl, lp + ic); var tsp: Array = ts.plan(n, pl, ic + lp + tp + cp)
		var out2 := cd.plan(n, pl, ic + lp + tp + cp + tsp + tr.plan(n, pl, ic + lp + tp + tsp))
		if out2.size() > 0: bands.append("%d:%s" % [n, out2.map(func(v: Dictionary) -> String: return "%s w %.0f %d scoops" % [String(v["hop_id"]), float(v["hop_w"]), int(v["scoops"])])])
	print("TOWER floors=", bands, " (want a subset of 30..34, 65..69 — one drift each on the widest std hop no other Starlit pack took, 4..8 scoops by floor mod 5, never another theme)")
	quit()

## shovel 자세 — 찌르기 끝·가운데, 지렛대, 헤이브 끝, 바라봄, 멈춤 가운데·끝의 관절(torso 는 lean × 0.45, 골반은 0.42 − dip; 무릎은 숨 ±0.03)
func _pose(fig: Stick3D) -> void:
	fig.pose_request = "shovel"; fig.set_meta("shovel_t", 0.25)
	for i in 45: await process_frame   # 관절은 섞여 따라온다(Stick3D 의 블렌딩) — 자리를 잡을 때까지
	var a_pel := fig.pelvis.position.y; var a_tx := fig.torso.rotation.x; var a_shx: float = (fig.shoulders[1.0] as Node3D).rotation.x; var a_el: float = (fig.elbows[1.0] as Node3D).rotation.x
	var a_hip: float = (fig.hips[1.0] as Node3D).rotation.x; var a_knee: float = (fig.knees[1.0] as Node3D).rotation.x; var a_knee2: float = (fig.knees[-1.0] as Node3D).rotation.x; var a_hip2: float = (fig.hips[-1.0] as Node3D).rotation.x; var a_neck := fig.neck.rotation.x
	fig.set_meta("shovel_t", 0.125)
	for i in 45: await process_frame
	var m_hip: float = (fig.hips[1.0] as Node3D).rotation.x; var m_knee: float = (fig.knees[1.0] as Node3D).rotation.x
	fig.set_meta("shovel_t", 0.55)
	for i in 45: await process_frame
	var b_pel := fig.pelvis.position.y; var b_shx: float = (fig.shoulders[1.0] as Node3D).rotation.x; var b_el: float = (fig.elbows[1.0] as Node3D).rotation.x; var b_hip: float = (fig.hips[-1.0] as Node3D).rotation.x; var b_knee: float = (fig.knees[1.0] as Node3D).rotation.x
	fig.set_meta("shovel_t", 0.9)
	for i in 45: await process_frame
	var c_pel := fig.pelvis.position.y; var c_tx := fig.torso.rotation.x; var c_shx: float = (fig.shoulders[1.0] as Node3D).rotation.x; var c_shz := wrapf((fig.shoulders[1.0] as Node3D).rotation.z, -PI, PI); var c_shz2 := wrapf((fig.shoulders[-1.0] as Node3D).rotation.z, -PI, PI)
	var c_el: float = (fig.elbows[1.0] as Node3D).rotation.x; var c_knee: float = (fig.knees[1.0] as Node3D).rotation.x; var c_hip: float = (fig.hips[1.0] as Node3D).rotation.x; var c_neck := fig.neck.rotation.x
	fig.set_meta("shovel_end", "star"); fig.set_meta("shovel_u", 0.3)
	for i in 45: await process_frame
	var g_shx: float = (fig.shoulders[1.0] as Node3D).rotation.x; var g_el: float = (fig.elbows[1.0] as Node3D).rotation.x; var g_shx2: float = (fig.shoulders[-1.0] as Node3D).rotation.x; var g_shz2 := wrapf((fig.shoulders[-1.0] as Node3D).rotation.z, -PI, PI); var g_el2: float = (fig.elbows[-1.0] as Node3D).rotation.x
	var g_knee: float = (fig.knees[1.0] as Node3D).rotation.x; var g_hip2: float = (fig.hips[-1.0] as Node3D).rotation.x; var g_neck := fig.neck.rotation.x; var g_tx := fig.torso.rotation.x
	fig.set_meta("shovel_end", "stop"); fig.set_meta("shovel_u", 0.15)
	for i in 45: await process_frame
	var s_shx2: float = (fig.shoulders[-1.0] as Node3D).rotation.x; var s_el2: float = (fig.elbows[-1.0] as Node3D).rotation.x; var s_shx: float = (fig.shoulders[1.0] as Node3D).rotation.x
	fig.set_meta("shovel_u", 0.3)
	for i in 45: await process_frame
	var e_shx: float = (fig.shoulders[1.0] as Node3D).rotation.x; var e_pel := fig.pelvis.position.y; var e_tx := fig.torso.rotation.x; var e_hip: float = (fig.hips[1.0] as Node3D).rotation.x
	fig.remove_meta("shovel_t"); fig.remove_meta("shovel_end"); fig.remove_meta("shovel_u")
	print("POSE thrust end: pelvis=%.2f torso=%.3f arm=%.2f elbow=%.2f lead hip=%.2f lead knee=%.2f trail hip=%.2f trail knee=%.2f neck>0=%s (want 0.34 0.225 −0.90 −0.20 −0.25 0.30±0.03 0.00 0.15±0.03 true) | thrust mid: lead hip=%.3f knee=%.2f (want −1.025 1.50±0.03) | lever: pelvis=%.2f arm=%.2f elbow=%.2f hip=%.2f knee=%.2f (want 0.30 −0.50 −1.30 −0.10 0.40±0.03)" % [a_pel, a_tx, a_shx, a_el, a_hip, a_knee, a_hip2, a_knee2, a_neck > 0.0, m_hip, m_knee, b_pel, b_shx, b_el, b_hip, b_knee])
	print("POSE heave end: pelvis=%.2f torso=%.3f arm=%.2f shoulder z=%.2f/%.2f elbow=%.2f hip=%.2f knee=%.2f neck<0=%s (want 0.42 −0.045 −1.50 −0.45/−0.45 −0.30 0.00 0.10±0.03 true) | gaze 0.3 s: lead arm=%.2f/%.2f trail arm=%.2f z=%.2f/%.2f lead knee=%.2f trail hip=%.2f torso=%.3f neck=%.2f (want −0.60/−0.50 0.20 0.50/−1.30 0.05±0.03 0.10 0.045 −0.62±0.06) | stop 0.15 s: trail arm=%.2f/%.2f lead arm=%.2f (want −2.75 −2.35 −0.75) | stop 0.3 s: arm=%.2f pelvis=%.2f torso=%.2f hip=%.2f (want 0.00 0.42 0.00 0.00) done(no meta, 3.0 → just past)=%s" % [c_pel, c_tx, c_shx, c_shz, c_shz2, c_el, c_hip, c_knee, c_neck < 0.0, g_shx, g_el, g_shx2, g_shz2, g_el2, g_knee, g_hip2, g_tx, g_neck, s_shx2, s_el2, s_shx, e_shx, e_pel, e_tx, e_hip, _demo_done(fig)])
	fig.pose_request = ""

## 메타 없이 pose_t 로 도는 시연 — 세 바퀴 뒤 0.3 s 에 done
func _demo_done(fig: Stick3D) -> bool:
	var e := ShovelPoses.CYCLE_T * ShovelPoses.DEMO_SCOOPS + ShovelPoses.STOP_T
	fig.pose_t = e - 0.01; var before := ShovelPoses.done(fig)
	fig.pose_t = e + 0.001; var after := ShovelPoses.done(fig)   # 3.0 − 2.7 은 실수로 0.3 에 한 끗 못 미친다 — 한 틱 뒤를 본다
	return (not before) and after
