extends SceneTree
## 별가루 더미 팩 점검(헤드리스): 자료가 읽히나, 별밤 층의 still std 발판 중 min_w 100 보다 넓고 기둥이 비고 taken 이 없는 가장 넓은 것에만 더미가 놓이나(등롱 장대가 선 발판은 비켜 가고, 기둥에 지름길 판이 든 발판도 비켜 가고, 좁은 발판뿐이면 없고, 다른 테마 층은 아니다; 31층은 5삽, 34층 8삽, 65층 4삽),
## 삽 곁의 C 가 파기에 들고(busy, shovel_t, digging, crunch) 삽에서 떠나면 그 삽은 버리고 몸이 바로 풀리나, 쥐고 있으면 0.2 s 찌르기·0.4 s 지렛대·0.7 s 헤이브·0.91 s 에 한 삽(dug 1, k 0.2, 다음 바퀴 shovel_t 0)이고, 놓으면 그 바퀴를 마치고(1.82 s 에 dug 2, stop) 0.3 s 뒤 풀리나(판 것은 남는다),
## 남이 파는 동안 플레이어의 C 는 기다리나, C 없는 몸·먼 z·다른 발판은 아무것도 아니나(평이 100%), 세 삽 더 파면(42.73) 별이 뜨고(dug, gaze, star, chime, day 0, deep 5, me_t) 0.4 s 에 별이 20 에 있고 0.67 s 에 몸이 풀리나, 1 s 뒤 별이 40 에 걸려 도나, 별이 뜬 더미 곁 C 는 아무것도 아니나,
## 쉼터 판의 줄(note)이 위 다섯 층 → 아래 다섯 층 순으로 세나, 90 s 뒤(132.74 — 실수 끝자리를 피해 0.01 늦게) 되메워지나(refill, hush, 0.5 s 에 별 20, 2 s 에 더미 반, 3.07 s 에 heaped·dug 0·별 없음), 다음 날 다른 몸(count 거짓)이 판 별은 세지 않나(0/1, 1 up),
## 더미·무더기·삽(손잡이·T 자루·날·띠)·별(세 조각)·내리는 별가루·소리 셋이 그려지나, 노드 자리, 꽂힌 삽의 자리(−6.6 px, −0.25),
## shovel 자세가 찌르기 끝(0.25)에 골반 0.34·상체 0.225·팔 −0.9·팔꿈치 −0.2·리드 엉덩이 −0.25·무릎 0.3·트레일 무릎 0.15·고개 > 0 이고, 찌르기 가운데(0.125)에 리드 엉덩이 −1.025·무릎 1.5 이고, 지렛대(0.55)에 골반 0.30·팔 −0.5·팔꿈치 −1.3·엉덩이 −0.1·무릎 0.4 이고,
## 헤이브 끝(0.9)에 골반 0.42·상체 −0.045·팔 −1.5·어깨 z −0.45 둘 다·팔꿈치 −0.3·무릎 0.1·고개 < 0 이고, 바라봄 0.3 s 에 리드 팔 −0.6/−0.5·트레일 팔 0.2/z 0.5/−1.3·리드 무릎 0.05·트레일 엉덩이 0.1·고개 −0.62±0.06 이고, 멈춤 0.15 s 에 트레일 팔 −2.75/−2.35 이고 0.3 s 에 서나(done),
## 파는 이(run 177)가 집(무더기 + 40 = 300)에 카메라를 보고 서서 차례에 삽으로 걸어가(0.3 s) 소매를 걷고(sleeve 1.0 s) count 거짓으로 다섯 삽을 다 파 별을 드러내고(세지 않는다, 1 up) 집으로 오나, 되메워진 뒤 1분에 가나, 플레이어의 별 뒤엔 되메워진 뒤 1 s 에 따라 파나, 플레이어가 먼저 잡으면 돌아오나, 플레이어가 바퀴 중에 떠나면 바로 와서 남은 삽을 마치나(takeover), 놓은(stop) 더미엔 안 오나,
## sleeve 자세가 오른소매 가운데(0.2)에 미는 팔 −0.9/z 0.25/팔꿈치 −1.15·걷히는 팔 −0.9/z 0.1/−0.1·몸통 0.045·고개 > 0 이고, 왼소매(0.6)엔 거울이고, 깃의 첫 당김(0.85)엔 −1.7/z −0.15/−2.1·몸통 0 이고, 1.0 에 팔이 내려와 done 이나,
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
	var dg: ClimbDigger = s["digger"]; dg.phase = "gone"; dg.next_at = 1e9   # 파는 이는 뒤에(DIGGER) — 그때까지 층을 떠나 있다(차례가 오면 위 want 가 어긋난다)
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
	print("VISUAL node=%s (want %s) children=%d (want 9: mound heap shovel star fall + 3 sounds + the digger) shovel parts=%d (want 4) star parts=%d (want 3) planted: x=%.4f y=%.2f z=%.4f tilt=%.2f (want −0.1833 0.00 0.3333 −0.25) heap x=%.4f (want 0.8333)" % [node.position, C.to3(230.0, 19140.0, C.WALL_Z * C.K), node.get_child_count(), shovel.get_child_count(), star.get_child_count(), shovel.position.x, shovel.position.y, shovel.position.z, shovel.rotation.z, heap.position.x])
	await _pose(fig)
	await _sleeve_pose()
	_digger(cd, s, dg, fig, on, z)
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

## 파는 이(run 177): 집·차례·소매·파기·귀가, 되메워진 뒤의 1분, 플레이어를 따라가기, 플레이어가 먼저, 플레이어가 두고 간 더미, 놓은 더미
func _digger(cd: ClimbDrift, s: Dictionary, dg: ClimbDigger, fig: Stick3D, on: Dictionary, z: float) -> void:
	# fig2 의 별(624.55)이 되메워진 뒤(_settle — 팩의 되메움 시계는 _process 가 hang 의 끝을 본 틱에 선다, 시간을 건너뛰면 3 s 가 밀린다): 집 300(무더기 260 + 40, 발판 끝 안쪽 300 까지)·z −48·카메라; 차례가 오면 삽으로 걸어가(돌아서는 틱 하나 + 70 px / 260 → 17 틱 0.30 s) 소매(sleeve, 메타 0) → 1.0 s 뒤 파기(shovel, thrust, count 거짓) → 5 × 0.9 + 0.6 = 5.1 s 뒤 별을 보고 집으로(dug, 날·me_t 그대로, 0/1 1 up) → 다음은 되메워진 뒤 1분
	_settle(cd, s, 0.1); var t0 := cd.t; dg._home(); var me0 := float(s["me_t"]); var day0 := int(s["day"])
	var g0 := "%s st=%s x=%.0f home=%.0f z=%.0f visible=%s pose='%s' next=%.1f" % [dg.phase, String(s["st"]), dg.x, dg.home_x, dg.z, dg.fig.visible, dg.fig.pose_request, maxf(0.0, dg.next_at - cd.t)]
	_until(cd, dg, "sleeve", 60)
	var sl := "%s x=%.0f pose=%s meta=%.2f at=%.2f s" % [dg.phase, dg.x, dg.fig.pose_request, float(dg.fig.get_meta("sleeve_t", 9.0)), cd.t - t0]
	_until(cd, dg, "dig", 120)
	var dgs := "%s x=%.0f pose=%s ph=%s mine=%s count=%s meta=%s takeovers=%d at=%.2f s" % [dg.phase, dg.x, dg.fig.pose_request, String(s["ph"]), (s["fig"] as Stick3D) == dg.fig, s["count"], dg.fig.has_meta("sleeve_t"), dg.takeovers, cd.t - t0]
	_until(cd, dg, "back", 600)
	var td := cd.dug_today(31, 31)
	var bk := "%s st=%s pose='%s' stars=%d day same=%s me_t same=%s today=%d/%d up=%d at=%.2f s" % [dg.phase, String(s["st"]), dg.fig.pose_request, dg.stars, int(s["day"]) == day0, float(s["me_t"]) == me0, int(td["dug"]), int(td["total"]), int(td["up"]), cd.t - t0]
	_until(cd, dg, "idle", 60)
	var hm := "%s x=%.0f next=%.1f" % [dg.phase, dg.x, dg.next_at - cd.t]
	print("DIGGER start: ", g0, " (want idle heaped 300 300 −48 true '' 0.0) | sleeve: ", sl, " (want sleeve 230 sleeve 0.00 0.28..0.32: a tick to turn, 70 px at WALK) | dig: ", dgs, " (want dig 230 shovel thrust true false false 0 1.28..1.34: 1.0 s of sleeve) | star: ", bk, " (want back dug '' 1 true true 0/1 1 6.45..6.55: five scoops and the gaze, a digger's star is never counted) | home: ", hm, " (want idle 300 ≈152: the hang, the sink, the refill and a minute) trail=", dg.trail)
	# 되메워진 뒤의 1분: 93.5 s 뒤 더미는 쌓였는데(heaped) 0.5 s 동안 집(idle); next_at 에 걸어간다
	_settle(cd, s, 0.5); var heaped_st := String(s["st"])
	for i in 30: cd._process(DT)
	var waited := dg.phase
	cd.sync(dg.next_at - 0.5 * DT); _until(cd, dg, "walk", 30)
	print("DIGGER a minute: st=%s (want heaped) 0.5 s later=%s (want idle) walks at %.3f s past next_at (want 0.000..0.034)" % [heaped_st, waited, cd.t - dg.next_at])
	# 플레이어를 따라가기: 플레이어가 다섯 삽을 파 별을 내면(me_t) 파는 이는 집(idle), 차례는 me_t + 94; 93.9 s 엔 집, 94.0 s 에 걸어가 판다(stars 2)
	dg._home(); dg.next_at = cd.t + 1e4
	for i in 320: cd.dig(236.0, z, on, true, fig); cd._process(DT)
	var me1 := float(s["me_t"]); var day1 := int(s["day"]); var fw := "%s st=%s me_t set=%s next−me_t=%.1f" % [dg.phase, String(s["st"]), me1 > me0, dg.next_at - me1]
	_settle(cd, s, 0.5)
	for i in 24: cd._process(DT)
	var early := "%s st=%s" % [dg.phase, String(s["st"])]
	_until(cd, dg, "walk", 30); var when := cd.t - me1
	_until(cd, dg, "dig", 200); _until(cd, dg, "idle", 600)
	print("DIGGER follows you: while you dig and after your star=", fw, " (want idle dug true 94.0) | 93.9 s after=", early, " (want idle heaped) | walks at %.2f s after your star (want 94.00..94.02: the hang, the sink, the refill, a second) | then stars=%d st=%s day same=%s (want 2 dug true: your star set the day, the digger's leaves it)" % [when, dg.stars, String(s["st"]), int(s["day"]) == day1])
	# 플레이어가 먼저: 파는 이가 걸어가는 중(3 틱 — 첫 틱에 돌아서고 둘 걷는다, x 291)에 플레이어가 잡으면 돌아와 집에서 기다린다; 플레이어가 두 삽 파고 셋째 바퀴 중에 떠나면(left_t) 바로 와서(walk) 소매를 걷고 남은 세 삽을 마친다(takeover, 3 × 0.9 + 0.6 = 3.3 s) — 별은 세지 않는다
	_settle(cd, s, 1.0); dg._home()
	for i in 3: cd._process(DT)
	var mid_x := dg.x
	cd.dig(236.0, z, on, true, fig); cd._process(DT)
	var yield_ph := dg.phase
	_until(cd, dg, "idle", 60); var yielded := "%s x=%.0f" % [dg.phase, dg.x]
	for i in 120: cd.dig(236.0, z, on, true, fig); cd._process(DT)
	var mid := "dug=%d ph=%s" % [int(s["dug"]), String(s["ph"])]
	cd.dig(150.0, z, on, true, fig); var left := cd.t; cd._process(DT)
	var came := "%s at=%.2f s left_t set=%s dug=%d ph='%s'" % [dg.phase, cd.t - left, float(s["left_t"]) == left, int(s["dug"]), String(s["ph"])]
	_until(cd, dg, "dig", 200); var took := "%s takeovers=%d dug=%d at=%.2f s" % [dg.phase, dg.takeovers, int(s["dug"]), cd.t - left]
	_until(cd, dg, "back", 600); var fin := "%s st=%s dug=%d stars=%d day same=%s me_t same=%s at=%.2f s" % [dg.phase, String(s["st"]), int(s["dug"]), dg.stars, int(s["day"]) == day1, float(s["me_t"]) == me1, cd.t - left]
	_until(cd, dg, "idle", 60)
	print("DIGGER the player first: walking x=%.0f (want 291: the first tick turns, two walk) | you grip: %s (want back) → %s (want idle 300) | you dig two and leave mid-cycle: %s (want dug=2 ph=thrust) → %s (want walk 0.02 true 2 '': the leaving is the cue) → %s (want dig 1 2 1.30..1.40) → %s (want back dug dug=5 3 true true 4.60..4.75: the digger finishes what you left)" % [mid_x, yield_ph, yielded, mid, came, took, fin])
	# 놓은(stop) 더미는 떠난 게 아니다: 되메워진 뒤 플레이어가 한 삽 파고 놓으면(dug 2, stop → '') 파는 이는 집(idle), 차례는 1분 뒤
	_settle(cd, s, 1.0)
	for i in 55: cd.dig(236.0, z, on, true, fig); cd._process(DT)
	for i in 130: cd.dig(236.0, z, on, false, fig); cd._process(DT)
	print("DIGGER a stop is not a leaving: st=%s ph='%s' dug=%d digger=%s x=%.0f next in %.1f s (want heaped '' 2 idle 300 ≈56: the minute, not the leaving)" % [String(s["st"]), String(s["ph"]), int(s["dug"]), dg.phase, dg.x, dg.next_at - cd.t])

## sleeve 자세(메타로 세운다): 오른소매 가운데(0.2) 미는 팔(+) 어깨 −0.90 z 0.25 팔꿈치 −1.15·걷히는 팔(−) −0.90 z 0.10 −0.10·무릎 0.10·엉덩이 −0.05·몸통 0.045·고개 > 0; 왼소매(0.6) 거울; 깃의 첫 당김(0.85) 어깨 −1.70 z −0.15/0.15 팔꿈치 −2.10 몸통 0 고개 < 0; 끝(1.0) 어깨 0 팔꿈치 0 done
func _sleeve_pose() -> void:
	var f3 := Stick3D.new(); root.add_child(f3)
	f3.pose_request = "sleeve"; f3.set_meta("sleeve_t", 0.2)
	for i in 60: await process_frame
	var a_shx: float = (f3.shoulders[1.0] as Node3D).rotation.x; var a_shz := wrapf((f3.shoulders[1.0] as Node3D).rotation.z, -PI, PI); var a_el: float = (f3.elbows[1.0] as Node3D).rotation.x
	var a_shx2: float = (f3.shoulders[-1.0] as Node3D).rotation.x; var a_shz2 := wrapf((f3.shoulders[-1.0] as Node3D).rotation.z, -PI, PI); var a_el2: float = (f3.elbows[-1.0] as Node3D).rotation.x
	var a_knee: float = (f3.knees[1.0] as Node3D).rotation.x; var a_hip: float = (f3.hips[1.0] as Node3D).rotation.x; var a_tx := f3.torso.rotation.x; var a_neck := f3.neck.rotation.x
	f3.set_meta("sleeve_t", 0.6)
	for i in 45: await process_frame
	var b_shz := wrapf((f3.shoulders[1.0] as Node3D).rotation.z, -PI, PI); var b_el: float = (f3.elbows[1.0] as Node3D).rotation.x; var b_shz2 := wrapf((f3.shoulders[-1.0] as Node3D).rotation.z, -PI, PI); var b_el2: float = (f3.elbows[-1.0] as Node3D).rotation.x
	f3.set_meta("sleeve_t", 0.85)
	for i in 45: await process_frame
	var c_shx: float = (f3.shoulders[1.0] as Node3D).rotation.x; var c_shz := wrapf((f3.shoulders[1.0] as Node3D).rotation.z, -PI, PI); var c_shz2 := wrapf((f3.shoulders[-1.0] as Node3D).rotation.z, -PI, PI); var c_el: float = (f3.elbows[1.0] as Node3D).rotation.x; var c_tx := f3.torso.rotation.x; var c_neck := f3.neck.rotation.x
	f3.set_meta("sleeve_t", 1.0)
	for i in 45: await process_frame
	var e_shx: float = (f3.shoulders[1.0] as Node3D).rotation.x; var e_el: float = (f3.elbows[1.0] as Node3D).rotation.x; var e_done := SleevePoses.done(f3)
	f3.remove_meta("sleeve_t"); f3.pose_request = ""
	print("SLEEVE pose right sleeve mid: pushing arm=%.2f z=%.2f elbow=%.2f | rolled arm=%.2f z=%.2f elbow=%.2f | knee=%.2f hip=%.2f torso=%.3f neck>0=%s (want −0.90 0.25 −1.15 | −0.90 0.10 −0.10 | 0.10±0.03 −0.05 0.045 true) | left sleeve mid: z=%.2f/%.2f elbows=%.2f/%.2f (want −0.10/−0.25 −0.10/−1.15: the mirror) | collar, first tug: arm=%.2f z=%.2f/%.2f elbow=%.2f torso=%.3f neck<0=%s (want −1.70 −0.15/0.15 −2.10 0.000 true) | end: arm=%.2f elbow=%.2f done=%s (want 0.00 0.00 true) total=%.2f (want 1.00)" % [a_shx, a_shz, a_el, a_shx2, a_shz2, a_el2, a_knee, a_hip, a_tx, a_neck > 0.0, b_shz, b_shz2, b_el, b_el2, c_shx, c_shz, c_shz2, c_el, c_tx, c_neck < 0.0, e_shx, e_el, e_done, SleevePoses.TOTAL])

## 지금 뜬 별의 더미가 되메워진 뒤 extra s 로 — 두 틱에 걸쳐(hang 의 끝에 refill, sink + refill 뒤 heaped): 팩의 되메움 시계는 _process 가 hang 의 끝을 본 틱에 서니 한 번에 건너뛰면 3 s 가 밀린다
func _settle(cd: ClimbDrift, s: Dictionary, extra: float) -> void:
	var star_t0 := float(s["star_t0"])
	cd.sync(maxf(cd.t, star_t0 + cd.hang_s() + 0.001)); cd._process(0.0)
	cd.sync(maxf(cd.t, star_t0 + cd.hang_s() + cd.sink_s() + cd.refill_s() + extra)); cd._process(0.0)

## 파는 이의 phase 가 p 가 될 때까지 팩의 _process 를 돌린다(cap_ticks × 5 틱까지 — 안 오면 그냥 돌아온다, 출력의 want 가 어긋난다)
func _until(cd: ClimbDrift, dg: ClimbDigger, p: String, cap_ticks: int) -> void:
	var n := 0
	while dg.phase != p and n < cap_ticks * 5:
		cd._process(DT); n += 1
