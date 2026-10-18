extends SceneTree
## 시계추 팩 점검(헤드리스): 자료가 읽히나, 태엽 층의 still std 발판 중 min_w 110 보다 넓고 기둥이 비고 taken 이 없는 가장 넓은 것에만 추가 서나(띠가 깔린 발판은 비켜 가고, 기둥에 지름길 판이 든 발판도 비켜 가고, 좁은 발판뿐이면 없고, 다른 테마 층은 아니다; 16층은 10 kg·1.1 s, 19층 16 kg, 50층 8 kg),
## 추 곁의 C 가 들기에 들고(busy, press_t, lifting) 추에서 떠나면 추가 떨어지고 몸이 바로 풀리나(drop → thud 0.25 s → down 0.4 s), 쥐고 있으면 0.5 s 에 클린(h 22.2)·0.8 s 에 프레스(42.1)·1.0 s 에 버티기(k 0.045, h 50.7)·2.04 s 에 아직 버티고(0.991)·2.06 s 에 거나(hook, press_end, k 1), 0.3 s 뒤 시계가 도나(wound, h 52, 오늘 1, me_t, 메타가 사라진다),
## 30 s 에 추가 26 에 바늘이 −π 북이 −3.25 째깍 30 번이고 60 s 에 바닥(down, clank, 바늘 0)이나, 쉼터 판의 줄(note)이 위 다섯 층 → 아래 다섯 층 순으로 세나, 다음 날 1.2 s 에 놓으면 추가 51.06 에서 떨어져(0.125 s 에 38.3) thud 하고 0.4 s 에 몸이 풀리나(세지 않는다),
## 다른 몸(count 거짓)이 감은 시계는 세지 않나(0/1, 1 running), 남이 드는 동안 플레이어의 C 는 기다리나, 돌고 있는 추 곁의 C 와 C 없는 몸은 아무것도 아니나(평이 100%), 추·사슬·받침·북·다이얼·바늘·소리 셋이 그려지나(사슬 1.5 길이), 노드 자리,
## press 자세가 쪼그림에 골반 0.22·상체 0.55·엉덩이 −1.1·무릎 1.6·팔 −0.2·고개 숙임이고, 머리 위에 골반 0.37·상체 −0.12·팔 −2.95±0.05·리드 엉덩이 −0.45·트레일 0.35·고개 −0.4·가슴 −0.12 이고, 버티기 0.5 s 에 다리가 모이고 흔들리나, 걸고 0.3 s 에 서나, 놓치고 0.15 s 에 팔이 떨어지고 움츠리나,
## 감는 이(run 175)가 집(추 + 40)에 서서 차례에 추로 걸어가(0.17 s) 초크를 치고(chalk 1.37 s, 가루 둘) 같은 lift(count 거짓)·press 로 2.35 s 들어 거나(날·me_t 는 그대로), 제 시계가 다 풀린 뒤 1분을 두고 다시 가나, 플레이어가 감으면 다 풀린 뒤 1 s 에 가나, 플레이어가 먼저 잡으면 돌아와 기다리나, 플레이어가 놓치면 thud 에 20 px 물러나 1.5 s 뒤 돌아와 떨어진 시계를 감나,
## chalk 자세가 박수의 모임에 어깨 −1.0·z −0.05·팔꿈치 −1.4·무릎 0.15 이고 벌림에 z −0.4 이고 비빔에 팔꿈치가 어긋나고 털기 가운데 팔이 반 내려와 바깥으로 흔들리고 끝에 서나(done),
## 진짜 탑의 1..65층에서 plan 이 태엽 층(15..19, 50..54)에만 추를 찾나
const C = preload("res://scripts/games/climb.gd")
const DT := 1.0 / 60.0

func _init() -> void:
	var cw := ClimbWeight.new(); root.add_child(cw)
	var cg := ClimbGears.new(); root.add_child(cg)
	var cpn := ClimbPendulum.new(); root.add_child(cpn)
	var pk := ClimbPerch.new(); root.add_child(pk)
	var cl := ClimbBellows.new(); root.add_child(cl)
	var ew := ClimbEscape.new(); root.add_child(ew)
	await process_frame
	print("PACK id=", cw.pack.get("id"), " kind=", cw.kind.size() > 0, " pose=", cw.pack.get("pose"), " themes=", cw.pack.get("themes"), " min_w=%.0f reach=%.0f d=%.0f r=%.0f h=%.0f col=%.0f kg=%d/%d grip=%.2f clean=%.2f press=%.2f rise=%.2f chest=%.0f head=%.0f hold(10)=%.2f hook=%.2f drop=%.2f recover=%.2f hook_h=%.0f drum=%.0f/%.0f dial=%.0f run=%.0f tick=%.1f day=%.0f (want weight true press [Clockwork] 110 14 24 9 14 40 8/2 0.30 0.30 0.35 0.95 30 50 1.10 0.30 0.25 0.40 52 76/8 12 60 1.0 600)" % [cw.min_w(), cw.reach(), cw.weight_d(), cw.weight_r(), cw.weight_h(), cw.col_w(), cw.kg_of(15), cw.kg_of(16) - cw.kg_of(15), cw.grip_s(), cw.clean_s(), cw.press_s(), cw.rise_s(), cw.chest_h(), cw.head_h(), cw.hold_of(10), cw.hook_s(), cw.drop_s(), cw.recover_s(), cw.hook_h(), cw.drum_h(), cw.drum_r(), cw.dial_r(), cw.run_s(), cw.tick_s(), cw.day_s()])
	var plats: Array = [
		{ "id": "16.0", "x": 60.0, "y": 9700.0, "w": 160.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "16.1", "x": 320.0, "y": 9810.0, "w": 150.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "16.2", "x": 100.0, "y": 9920.0, "w": 140.0, "kind": "ice", "z": -29.0, "d": 82.0 },
		{ "id": "16.3", "x": 380.0, "y": 10030.0, "w": 130.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "16.4", "x": 150.0, "y": 10140.0, "w": 170.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "16.5", "x": 450.0, "y": 10250.0, "w": 140.0, "kind": "std", "z": -29.0, "d": 82.0 },
		{ "id": "16s", "x": 700.0, "y": 10190.0, "w": 40.0, "kind": "short", "z": -29.0, "d": 60.0 },
	]
	var free := cw.plan(16, plats)
	var belt := { "id": "16.B0", "kind": "belt", "x": 150.0, "w": 170.0, "y": 10140.0, "y_top": 10146.0 }   # 톱니 띠가 16.4 를 가졌다 — 16.0 으로
	var belted := cw.plan(16, plats, [belt])
	var cut := plats.duplicate(true); cut.append({ "id": "16c", "x": 200.0, "y": 10200.0, "w": 40.0, "kind": "short", "z": -29.0, "d": 60.0 })   # 16.4 의 기둥에 지름길 판 — 16.0 으로
	var cutp := cw.plan(16, cut)
	var thin := plats.duplicate(true)
	for pv in thin:   # 전부 좁다 — 없다
		var q: Dictionary = pv; q["w"] = 100.0
	var thinp := cw.plan(16, thin)
	var f14 := cw.plan(14, plats); var f15 := cw.plan(15, plats); var f19 := cw.plan(19, plats); var f20 := cw.plan(20, plats); var f50 := cw.plan(50, plats)
	var show := func(v: Dictionary) -> String: return String(v["id"]) + " on %s w %.0f wx %.0f x %.0f w %.0f y %.0f y_top %.0f z %.0f d %.0f kg %d hold %.2f" % [String(v["hop_id"]), float(v["hop_w"]), float(v["wx"]), float(v["x"]), float(v["w"]), float(v["y"]), float(v["y_top"]), float(v["z"]), float(v["d"]), int(v["kg"]), float(v["hold_s"])]
	var brief := func(v: Dictionary) -> String: return "%s wx %.0f kg %d" % [String(v["hop_id"]), float(v["wx"]), int(v["kg"])]
	print("PLAN free=", free.map(show), " (want 1: 16.W0 on 16.4 w 170 wx 235 x 226 w 18 y 10140 y_top 10228 z −58 d 24 kg 10 hold 1.10)")
	print("PLAN belted=", belted.map(brief), " (want [16.0 wx 140 kg 10]) cut=", cutp.map(brief), " (want [16.0 wx 140 kg 10]) thin=", thinp.size(), " (want 0) floors 14/15/19/20/50=", [f14.size(), f15.size(), f19.size(), f20.size(), f50.size()], " (want 0 1 1 0 1) kg 19/50=", [int((f19[0] as Dictionary)["kg"]) if f19.size() > 0 else -1, int((f50[0] as Dictionary)["kg"]) if f50.size() > 0 else -1], " (want 16 8)")
	var band_root := Node3D.new(); root.add_child(band_root)
	cw.build(band_root, free)
	var s: Dictionary = cw.weights[0]
	var wd: ClimbWinder = s["winder"]; wd.phase = "gone"; wd.next_at = 1e9   # 감는 이는 뒤에(WINDER) — 그때까지 층을 떠나 있다(차례가 오면 위 want 가 어긋난다)
	var fig := Stick3D.new(); root.add_child(fig)
	var on: Dictionary = plats[4]; var z := C.PLAYER_Z
	var thud: AudioStreamPlayer3D = s["thud"]; var clank: AudioStreamPlayer3D = s["clank"]
	# 들기(t 10, 몸 240 — 추 235 곁): busy, press_t 0, lifting; 추에서 떠나면(150) 추가 떨어지고 몸은 바로 풀린다 — 0.25 s 에 thud, 0.4 s 에 down
	cw.sync(10.0)
	var a := cw.lift(240.0, z, on, true, fig); var a_state := "%s/%s/%.0f/%s/%d" % [String(s["st"]), String(s["ph"]), float(fig.get_meta("press_t", 9.0)), cw.lifting(fig), int(s["lifts"])]
	var gone := cw.lift(150.0, z, on, true, fig); var gone_state := "%s %s %s %s %d" % [String(s["st"]), String(s["ph"]), cw.lifting(fig), fig.has_meta("press_t"), int(s["drops"])]
	cw.sync(10.25); cw._process(0.0); var thud_state := "%s %s thud=%s h=%.1f" % [String(s["st"]), String(s["ph"]), thud.playing, float(s["h"])]
	cw.sync(10.4); cw._process(0.0); var down_state := "%s '%s' fig=%s" % [String(s["st"]), String(s["ph"]), s["fig"] == null]
	var far_z := cw.lift(240.0, z + 40.0, on, true, fig); var other_hop := cw.lift(240.0, z, plats[3], true, fig); var plain := cw.lift(240.0, z, on, false, fig)
	print("LIFT start: busy=%s k=%.2f id=%s st/ph/meta/lifting/lifts=%s (want true 0.00 16.W0 lift/grip/0/true/1) | away: busy=%s → %s (want false 'lift drop false false 1') | 0.25 s: %s (want lift drop thud=true h=0.0) | 0.4 s: %s (want down '' fig=true) | far z: %s other hop: %s plain (no C): %s st=%s (want false false false down)" % [a["busy"], float(a["k"]), String(a["id"]), a_state, gone["busy"], gone_state, thud_state, down_state, far_z["busy"], other_hop["busy"], plain["busy"], String(s["st"])])
	# 쥐고 든다(t 20): 0.5 s 클린 h 22.2, 0.8 s 프레스 42.1, 1.0 s 버티기 k 0.045 h 50.7, 2.04 s 아직 0.991, 2.06 s 걸기(hook, press_end hook, k 1), 22.4 에 시계가 돈다(wound, h 52, 오늘 1, me_t 22.4, 메타 없음, lifting 거짓, C 는 아무것도 아니다)
	cw.sync(20.0); cw.lift(240.0, z, on, true, fig)
	cw.sync(20.5); var r1 := cw.lift(240.0, z, on, true, fig); var p1 := "%s h=%.1f t=%.2f" % [String(s["ph"]), float(s["h"]), float(fig.get_meta("press_t", 9.0))]
	cw.sync(20.8); cw.lift(240.0, z, on, true, fig); var p2 := "%s h=%.1f" % [String(s["ph"]), float(s["h"])]
	cw.sync(21.0); var r3 := cw.lift(240.0, z, on, true, fig); var p3 := "%s k=%.3f h=%.1f" % [String(s["ph"]), float(r3["k"]), float(s["h"])]
	cw.sync(22.04); var r4 := cw.lift(240.0, z, on, true, fig); var p4 := "%s k=%.3f" % [String(s["ph"]), float(r4["k"])]
	cw.sync(22.06); var r5 := cw.lift(240.0, z, on, true, fig); var p5 := "%s busy=%s k=%.1f end=%s u=%.1f" % [String(s["ph"]), r5["busy"], float(r5["k"]), String(fig.get_meta("press_end", "?")), float(fig.get_meta("press_u", 9.0))]
	cw.sync(22.2); cw._process(0.0); var mid_hook := "%s rising=%s u=%.2f" % [String(s["ph"]), float(s["h"]) > float(s["h0"]) and float(s["h"]) < 52.0, float(fig.get_meta("press_u", 9.0))]
	cw.sync(22.4); cw._process(0.0); var r6 := cw.lift(240.0, z, on, true, fig)
	var wound := "%s '%s' h=%.0f day=%d me_t=%.1f meta=%s/%s/%s lifting=%s busy=%s" % [String(s["st"]), String(s["ph"]), float(s["h"]), int(s["day"]), float(s["me_t"]), fig.has_meta("press_t"), fig.has_meta("press_end"), fig.has_meta("press_u"), cw.lifting(fig), r6["busy"]]
	var today := cw.wound_today(16, 16)
	print("HOLD 0.5 s: busy=%s %s (want true clean h=22.2 t=0.50) | 0.8 s: %s (want press h=42.1) | 1.0 s: %s (want hold k=0.045 h=50.7) | 2.04 s: %s (want hold k=0.991) | 2.06 s: %s (want hook busy=true k=1.0 end=hook u=0.0) | 0.14 s into the hook: %s (want hook rising=true — between h0 and 52 — u=0.14) | 22.4: %s (want wound '' h=52 day=0 me_t=22.4 meta=false/false/false lifting=false busy=false) today=%d/%d heaviest %d running %d (want 1/1 10 1)" % [r1["busy"], p1, p2, p3, p4, p5, mid_hook, wound, int(today["wound"]), int(today["total"]), int(today["heaviest"]), int(today["running"])])
	print("NOTE 15=\"%s\" (want Clock weights, floors 15–19: 1 of 1 clock wound today, the heaviest 10 kg, 1 running.) 20=\"%s\" (want the same: nothing on 20..24, so the floors below) 25=\"%s\" (want empty)" % [cw.note(15), cw.note(20), cw.note(25)])
	# 도는 시계: 30 s 에 추 26, 바늘 −π, 북 −3.25, 째깍 30; 60 s 에 바닥(down, clank, 바늘 0, 사슬 1.5)
	var hand: Node3D = s["hand"]; var drum: Node3D = s["drum"]; var chain: Node3D = s["chain"]
	cw.sync(52.4); cw._process(0.0); var half := "%s h=%.0f hand=%.4f drum=%.2f ticks=%d" % [String(s["st"]), float(s["h"]), hand.rotation.z, drum.rotation.z, int(s["tick_i"])]
	cw.sync(82.5); cw._process(0.0); var run_down := "%s h=%.0f hand=%.1f clank=%s chain=%.4f/%.4f" % [String(s["st"]), float(s["h"]), hand.rotation.z, clank.playing, chain.scale.y, chain.position.y]
	print("RUN 30 s: ", half, " (want wound h=26 hand=−3.1416 drum=−3.25 ticks=30 — 29 if the float lands a hair short) | 60 s: ", run_down, " (want down h=0 hand=0.0 clank=true chain=1.5000/1.1389) note 15=\"%s\" (want … 1 of 1 clock wound today, the heaviest 10 kg. — no longer running)" % cw.note(15))
	# 다음 날(620): 1.2 s 에 놓는다 — 추가 51.06 에서 떨어져 0.125 s 에 38.3, 0.25 s 에 thud·0, 0.41 s 에 down·몸 풀림; 오늘은 0/1
	cw.sync(620.0); cw.lift(240.0, z, on, true, fig)
	cw.sync(621.2); cw.lift(240.0, z, on, true, fig); var h0 := float(s["h"])
	var d1 := cw.lift(240.0, z, on, false, fig); var d1s := "%s busy=%s k=%.1f end=%s h0=%.2f" % [String(s["ph"]), d1["busy"], float(d1["k"]), String(fig.get_meta("press_end", "?")), float(s["h0"])]
	cw.sync(621.325); cw._process(0.0); var d2s := "h=%.1f u=%.3f thudded=%s" % [float(s["h"]), float(fig.get_meta("press_u", 9.0)), s["thudded"]]
	cw.sync(621.45); cw._process(0.0); var d3s := "h=%.1f thudded=%s %s" % [float(s["h"]), s["thudded"], String(s["ph"])]
	cw.sync(621.61); cw._process(0.0); var d4s := "%s '%s' meta=%s lifting=%s drops=%d lifts=%d" % [String(s["st"]), String(s["ph"]), fig.has_meta("press_t") or fig.has_meta("press_end"), cw.lifting(fig), int(s["drops"]), int(s["lifts"])]
	var dday := cw.wound_today(16, 16)
	print("DROP at 1.2 s: h=%.2f %s (want 51.06 drop busy=true k=0.0 end=drop h0=51.06) | 0.125 s: %s (want h=38.3 u=0.125 thudded=false) | 0.25 s: %s (want h=0.0 thudded=true drop) | 0.41 s: %s (want down '' meta=false lifting=false drops=2 lifts=3) today=%d/%d (want 0/1: a dropped weight is never counted)" % [h0, d1s, d2s, d3s, d4s, int(dday["wound"]), int(dday["total"])])
	# 다른 몸(count 거짓, 셋째 날 1230): 감아도 오늘은 0/1(1 running); 그 몸이 드는 동안 플레이어의 C 는 기다린다(busy 거짓); me_t 는 그대로
	var fig2 := Stick3D.new(); root.add_child(fig2)
	cw.sync(1230.0); cw.lift(240.0, z, on, true, fig2, false)
	var wait_me := cw.lift(240.0, z, on, true, fig)
	cw.sync(1232.1); cw.lift(240.0, z, on, true, fig2, false)
	cw.sync(1232.5); cw._process(0.0); var o := cw.wound_today(16, 16)
	var other := "%s today=%d/%d running=%d me_t=%.1f fig2 meta=%s" % [String(s["st"]), int(o["wound"]), int(o["total"]), int(o["running"]), float(s["me_t"]), fig2.has_meta("press_t")]
	cw.sync(1300.0); cw._process(0.0)
	print("OTHER body: waits=%s (want false) %s (want wound today=0/1 running=1 me_t=22.4 fig2 meta=false: a resident's clock is never counted) | 1300: %s (want down)" % [wait_me["busy"], other, String(s["st"])])
	# 그림: 노드 아이 8(추·사슬·받침·북·다이얼·소리 셋), 추 아이 3, 북 2, 다이얼 2; 노드 자리 (235 − 480)/36 = −6.8056, 10140/36 = 281.6667, −70/36 = −1.9444
	var node: Node3D = s["node"]; var w_node: Node3D = s["w_node"]; var dial := hand.get_parent() as Node3D
	print("VISUAL children=%d (want 9: 8 + the winder) weight=%d drum=%d dial=%d (want 3 2 2) node pos=%.4f %.4f %.4f (want −6.8056 281.6667 −1.9444) weight pos=%.4f %.4f %.4f (want 0.0000 0.1944 0.3333) dial x=%.4f (want 0.6667)" % [node.get_child_count(), w_node.get_child_count(), drum.get_child_count(), dial.get_child_count(), node.position.x, node.position.y, node.position.z, w_node.position.x, w_node.position.y, w_node.position.z, dial.position.x])
	# 자세(메타로 세운다): 쪼그림(press_t 0.3) 골반 0.22, 상체 0.55, 엉덩이 −1.1, 무릎 1.6, 팔 −0.2, 팔꿈치 0, 리드 어깨 z −0.12, 고개 > 0;
	# 머리 위(0.95): 골반 0.37, 상체 −0.12, 팔 −2.95 ± 0.05, 팔꿈치 0 ± 0.03, 리드 엉덩이 −0.45, 트레일 0.35, 리드 무릎 0.58 ± 0.03, 트레일 0.33 ± 0.03, 고개 −0.4, 가슴 −0.12, 리드 어깨 z −0.12;
	# 버티기 0.5 s(1.45): 엉덩이 0 둘 다, 무릎 0.08 ± 0.03, 어깨 z 가 −0.12 에서 ±0.08 흔들린다; 걸고 0.3 s: 골반 0.42, 상체 0, 팔 0, 엉덩이 0, 고개 0; 놓치고 0.15 s: 골반 0.3174, 상체 0.1230, 팔 0.1709, 엉덩이 −0.3418, 무릎 0.533 ± 0.02, 고개 > 0
	fig.pose_request = "press"; fig.set_meta("press_t", 0.3)
	for i in 45: await process_frame   # 관절은 섞여 따라온다(Stick3D 의 블렌딩) — 자리를 잡을 때까지
	var g_pel := fig.pelvis.position.y; var g_tx := fig.torso.rotation.x; var g_hip: float = (fig.hips[1.0] as Node3D).rotation.x; var g_knee: float = (fig.knees[1.0] as Node3D).rotation.x
	var g_shx: float = (fig.shoulders[1.0] as Node3D).rotation.x; var g_el: float = (fig.elbows[1.0] as Node3D).rotation.x; var g_shz := wrapf((fig.shoulders[1.0] as Node3D).rotation.z, -PI, PI); var g_neck := fig.neck.rotation.x
	fig.set_meta("press_t", 0.95)
	for i in 45: await process_frame
	var t_pel := fig.pelvis.position.y; var t_tx := fig.torso.rotation.x; var t_shx: float = (fig.shoulders[1.0] as Node3D).rotation.x; var t_el: float = (fig.elbows[1.0] as Node3D).rotation.x
	var t_hip: float = (fig.hips[1.0] as Node3D).rotation.x; var t_hip2: float = (fig.hips[-1.0] as Node3D).rotation.x; var t_knee: float = (fig.knees[1.0] as Node3D).rotation.x; var t_knee2: float = (fig.knees[-1.0] as Node3D).rotation.x
	var t_neck := fig.neck.rotation.x; var t_chest := fig.chest.rotation.x; var t_shz := wrapf((fig.shoulders[1.0] as Node3D).rotation.z, -PI, PI)
	fig.set_meta("press_t", 1.45)
	for i in 45: await process_frame
	var h_hip: float = (fig.hips[1.0] as Node3D).rotation.x; var h_hip2: float = (fig.hips[-1.0] as Node3D).rotation.x; var h_knee: float = (fig.knees[1.0] as Node3D).rotation.x; var h_shz := wrapf((fig.shoulders[1.0] as Node3D).rotation.z, -PI, PI)
	fig.set_meta("press_end", "hook"); fig.set_meta("press_u", 0.3)
	for i in 45: await process_frame
	var k_pel := fig.pelvis.position.y; var k_tx := fig.torso.rotation.x; var k_shx: float = (fig.shoulders[1.0] as Node3D).rotation.x; var k_hip: float = (fig.hips[1.0] as Node3D).rotation.x; var k_neck := fig.neck.rotation.x
	fig.set_meta("press_end", "drop"); fig.set_meta("press_u", 0.15)
	for i in 45: await process_frame
	var d_pel := fig.pelvis.position.y; var d_tx := fig.torso.rotation.x; var d_shx: float = (fig.shoulders[1.0] as Node3D).rotation.x; var d_hip: float = (fig.hips[1.0] as Node3D).rotation.x; var d_knee: float = (fig.knees[1.0] as Node3D).rotation.x; var d_neck := fig.neck.rotation.x
	fig.remove_meta("press_t"); fig.remove_meta("press_end"); fig.remove_meta("press_u")
	print("POSE grip: pelvis=%.2f torso=%.2f hip=%.2f knee=%.2f arm=%.2f elbow=%.2f shoulder z=%.2f neck>0=%s (want 0.22 0.55 −1.10 1.60 −0.20 0.00 −0.12 true) | top: pelvis=%.2f torso=%.2f arm=%.2f elbow=%.2f lead hip=%.2f trail hip=%.2f lead knee=%.2f trail knee=%.2f neck=%.2f chest=%.2f shoulder z=%.2f (want 0.37 −0.12 −2.95±0.05 0.00±0.03 −0.45 0.35 0.58±0.03 0.33±0.03 −0.40 −0.12 −0.12)" % [g_pel, g_tx, g_hip, g_knee, g_shx, g_el, g_shz, g_neck > 0.0, t_pel, t_tx, t_shx, t_el, t_hip, t_hip2, t_knee, t_knee2, t_neck, t_chest, t_shz])
	print("POSE hold 0.5 s: hips=%.2f/%.2f knee=%.2f shoulder z=%.2f (want 0.00/0.00 0.08±0.03 −0.12±0.08) | hooked 0.3 s: pelvis=%.2f torso=%.2f arm=%.2f hip=%.2f neck=%.2f (want 0.42 0.00 0.00 0.00 0.00) | dropped 0.15 s: pelvis=%.4f torso=%.4f arm=%.4f hip=%.4f knee=%.3f neck>0=%s (want 0.3175 0.1230 0.1709 −0.3418 0.533±0.03 true) done(no meta)=%s at pose_t %.2f (want true once past 2.25 s)" % [h_hip, h_hip2, h_knee, h_shz, k_pel, absf(k_tx), absf(k_shx), absf(k_hip), absf(k_neck), d_pel, d_tx, d_shx, d_hip, d_knee, d_neck > 0.0, PressPoses.done(fig), fig.pose_t])
	fig.pose_request = ""
	await _winder(cw, s, wd, fig, on, z)
	await _chalk_pose()
	# 진짜 탑: 1..65층에 plan 이 찾는 추 — 태엽 층 15..19, 50..54 중 띠·추·뻐꾸기 집·풀무·핀 바퀴가 안 쓴 넓은 발판이 있는 층만
	var town := (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 20: await physics_frame
	town.enter_game("climb")
	for i in 90: await physics_frame
	var gm: Node3D = town.game_node
	var bands: Array = []
	for n in range(1, 66):
		var pl: Array = gm.band(n)
		var ck: Array = cg.plan(n, pl) + cpn.plan(n, pl) + pk.plan(n, pl); var bl: Array = cl.plan(n, pl, ck)
		var out2 := cw.plan(n, pl, ck + bl + ew.plan(n, pl, ck + bl))
		if out2.size() > 0: bands.append("%d:%s" % [n, out2.map(func(v: Dictionary) -> String: return "%s w %.0f %d kg" % [String(v["hop_id"]), float(v["hop_w"]), int(v["kg"])])])
	print("TOWER floors=", bands, " (want a subset of 15..19, 50..54 — one weight each on the widest std hop no other Clockwork pack took, 8..16 kg by floor mod 5, never another theme)")
	quit()

## 감는 이(run 175): 집·차례·초크·들기·귀가, 제 시계 뒤의 1분, 플레이어를 따라가기, 플레이어가 먼저, 플레이어의 놓침
func _winder(cw: ClimbWeight, s: Dictionary, wd: ClimbWinder, fig: Stick3D, on: Dictionary, z: float) -> void:
	# t 1300(셋째 날, fig2 의 시계는 1292.4 에 다 풀렸다): 집 275(추 235 + 40)·z −48·카메라; 차례가 오면 추로 걸어가(돌아서는 틱 하나 + 40 px / 260 → 11 틱 0.18 s) 초크(chalk, 메타 0) → 1.37 s 뒤 들기(press, grip, count 거짓, 가루 둘) → 0.95 + 1.1 + 0.3 = 2.35 s 뒤 걸고 집으로(wound, 날·me_t 그대로) → 다음은 다 풀린 뒤 1분
	cw.sync(1300.0); cw._process(0.0); wd._home(); var me0 := float(s["me_t"]); var day0 := int(s["day"])
	var g0 := "%s x=%.0f home=%.0f z=%.0f visible=%s pose='%s' next=%.1f" % [wd.phase, wd.x, wd.home_x, wd.z, wd.fig.visible, wd.fig.pose_request, maxf(0.0, wd.next_at - cw.t)]
	_until(cw, wd, "chalk", 60)
	var ch := "%s x=%.0f pose=%s meta=%.2f at=%.2f s" % [wd.phase, wd.x, wd.fig.pose_request, float(wd.fig.get_meta("chalk_t", 9.0)), cw.t - 1300.0]
	_until(cw, wd, "lift", 120)
	var lf := "%s x=%.0f pose=%s ph=%s mine=%s count=%s puffs=%d meta=%s at=%.2f s" % [wd.phase, wd.x, wd.fig.pose_request, String(s["ph"]), (s["fig"] as Stick3D) == wd.fig, s["count"], wd.puffs, wd.fig.has_meta("chalk_t"), cw.t - 1300.0]
	_until(cw, wd, "back", 300)
	var tw := cw.wound_today(16, 16)
	var bk := "%s st=%s pose='%s' winds=%d day same=%s me_t same=%s today=%d/%d running=%d at=%.2f s" % [wd.phase, String(s["st"]), wd.fig.pose_request, wd.winds, int(s["day"]) == day0, float(s["me_t"]) == me0, int(tw["wound"]), int(tw["total"]), int(tw["running"]), cw.t - 1300.0]
	_until(cw, wd, "idle", 60)
	var hm := "%s x=%.0f next=%.1f" % [wd.phase, wd.x, wd.next_at - cw.t]
	print("WINDER start: ", g0, " (want idle 275 275 −48 true '' 0.0) | chalk: ", ch, " (want chalk 235 chalk 0.00 0.18: a tick to turn, 40 px at WALK) | lift: ", lf, " (want lift 235 press grip true false 2 false 1.55: 1.37 s of chalk, two puffs) | hooked: ", bk, " (want back wound '' 1 true true 0/1 1 3.90..3.95: 0.95 + 1.1 + 0.3 s of press, a winder's clock is never counted) | home: ", hm, " (want idle 275 ≈119.8: the run plus a minute) trail=", wd.trail)
	# 제 시계 뒤의 1분: 61 s 뒤 시계는 다 풀렸는데(down) 0.5 s 동안 집(idle); next_at 에 걸어간다
	cw.sync(cw.t + 61.0); cw._process(0.0); var down_st := String(s["st"])
	for i in 30: cw._process(DT)
	var waited := wd.phase
	cw.sync(wd.next_at - 0.5 * DT); _until(cw, wd, "walk", 30)
	print("WINDER a minute: st=%s (want down) 0.5 s later=%s (want idle) walks at %.3f s past next_at (want 0.000..0.034)" % [down_st, waited, cw.t - wd.next_at])
	# 플레이어를 따라가기: 플레이어가 2.5 s 들어 걸면(me_t) 감는 이는 집(idle), 차례는 me_t + 61; 60.9 s 엔 집, 61.0 s 에 걸어가 감는다(winds 2)
	wd._home(); wd.next_at = cw.t + 1e4
	for i in 150: cw.lift(240.0, z, on, true, fig); cw._process(DT)
	var me1 := float(s["me_t"]); var day1 := int(s["day"]); var fw := "%s st=%s me_t set=%s next−me_t=%.1f" % [wd.phase, String(s["st"]), me1 > me0, wd.next_at - me1]
	cw.sync(me1 + 60.5); cw._process(0.0)
	for i in 24: cw._process(DT)
	var early := "%s st=%s" % [wd.phase, String(s["st"])]
	_until(cw, wd, "walk", 30); var when := cw.t - me1
	_until(cw, wd, "lift", 200); _until(cw, wd, "idle", 600)
	print("WINDER follows you: while you hold and after your hook=", fw, " (want idle wound true 61.0) | 60.9 s after=", early, " (want idle down) | walks at %.2f s after your hook (want 61.00..61.02: the run out, a clank, a second) | then winds=%d st=%s day same=%s (want 2 wound true: your hook set the day, the winder's leaves it)" % [when, wd.winds, String(s["st"]), int(s["day"]) == day1])
	# 플레이어가 먼저: 감는 이가 걸어가는 중(3 틱 — 첫 틱에 돌아서고 둘 걷는다, x 266)에 플레이어가 잡으면 돌아와 집에서 기다린다; 플레이어가 1.2 s 들다 놓으면 thud(0.25 s)에 물러나(step → 295) 1.5 s 서 있다(linger) 집으로 → 차례가 지났으니 떨어진 시계를 감는다(winds 3)
	cw.sync(cw.t + 61.0); cw._process(0.0); wd._home()
	for i in 3: cw._process(DT)
	var mid_x := wd.x
	cw.lift(240.0, z, on, true, fig); cw._process(DT)
	var yield_ph := wd.phase
	_until(cw, wd, "idle", 60); var yielded := "%s x=%.0f" % [wd.phase, wd.x]
	for i in 72: cw.lift(240.0, z, on, true, fig); cw._process(DT)
	cw.lift(240.0, z, on, false, fig); var rel := cw.t
	_until(cw, wd, "step", 60); var stepped := "%s at=%.2f s thudded=%s" % [wd.phase, cw.t - rel, s["thudded"]]
	_until(cw, wd, "linger", 60); var lingered := "%s x=%.0f" % [wd.phase, wd.x]
	_until(cw, wd, "back", 120); var back_at := cw.t - rel
	_until(cw, wd, "idle", 60); var home2 := "%s x=%.0f" % [wd.phase, wd.x]
	_until(cw, wd, "lift", 200); _until(cw, wd, "idle", 600)
	print("WINDER the player first: walking x=%.0f (want 266: the first tick turns, two walk) | you grip: %s (want back) → %s (want idle 275) | you drop: %s (want step 0.25..0.27 true: the thud is the cue) → %s (want linger 295) → back at %.2f s (want 1.83..1.87) → %s (want idle 275) | then winds=%d st=%s day same=%s me_t same=%s (want 3 wound true true: the keeper winds what you dropped)" % [mid_x, yield_ph, yielded, stepped, lingered, back_at, home2, wd.winds, String(s["st"]), int(s["day"]) == day1, float(s["me_t"]) == me1])

## chalk 자세(메타로 세운다): 모임(1/6) 어깨 −1.00 z −0.05 팔꿈치 −1.40 무릎 0.15 엉덩이 −0.05 몸통 0.054 고개 > 0; 벌림(1/3) z −0.40 무릎 0.10; 비빔(0.8667) z −0.05 팔꿈치 −1.42/−1.38(어긋난다); 털기 가운데(1.2167) 어깨 −0.55 z −0.40 팔꿈치 −0.875 몸통 0.027; 끝(1.4) 어깨 −0.10 z 0.00 팔꿈치 −0.35 몸통 0 done
func _chalk_pose() -> void:
	var f3 := Stick3D.new(); root.add_child(f3)
	f3.pose_request = "chalk"; f3.set_meta("chalk_t", 1.0 / 6.0)
	for i in 60: await process_frame
	var m_shx: float = (f3.shoulders[1.0] as Node3D).rotation.x; var m_shz := wrapf((f3.shoulders[1.0] as Node3D).rotation.z, -PI, PI); var m_el: float = (f3.elbows[1.0] as Node3D).rotation.x
	var m_knee: float = (f3.knees[1.0] as Node3D).rotation.x; var m_hip: float = (f3.hips[1.0] as Node3D).rotation.x; var m_tx := f3.torso.rotation.x; var m_neck := f3.neck.rotation.x
	f3.set_meta("chalk_t", 1.0 / 3.0)
	for i in 45: await process_frame
	var a_shz := wrapf((f3.shoulders[1.0] as Node3D).rotation.z, -PI, PI); var a_knee: float = (f3.knees[1.0] as Node3D).rotation.x
	f3.set_meta("chalk_t", 2.0 / 3.0 + 0.2)
	for i in 45: await process_frame
	var r_shz := wrapf((f3.shoulders[1.0] as Node3D).rotation.z, -PI, PI); var r_el: float = (f3.elbows[1.0] as Node3D).rotation.x; var r_el2: float = (f3.elbows[-1.0] as Node3D).rotation.x
	f3.set_meta("chalk_t", 2.0 / 3.0 + 0.4 + 0.15)
	for i in 45: await process_frame
	var s_shx: float = (f3.shoulders[1.0] as Node3D).rotation.x; var s_shz := wrapf((f3.shoulders[1.0] as Node3D).rotation.z, -PI, PI); var s_el: float = (f3.elbows[1.0] as Node3D).rotation.x; var s_tx := f3.torso.rotation.x
	f3.set_meta("chalk_t", 1.4)
	for i in 45: await process_frame
	var e_shx: float = (f3.shoulders[1.0] as Node3D).rotation.x; var e_shz := wrapf((f3.shoulders[1.0] as Node3D).rotation.z, -PI, PI); var e_el: float = (f3.elbows[1.0] as Node3D).rotation.x; var e_tx := f3.torso.rotation.x; var e_done := ChalkPoses.done(f3)
	f3.remove_meta("chalk_t"); f3.pose_request = ""
	print("CHALK pose meet: arm=%.2f z=%.2f elbow=%.2f knee=%.2f hip=%.2f torso=%.3f neck>0=%s (want −1.00 −0.05 −1.40 0.15 −0.05 0.054 true) | apart: z=%.2f knee=%.2f (want −0.40 0.10) | rub: z=%.2f elbows=%.2f/%.2f (want −0.05 −1.42/−1.38: out of step) | shake mid: arm=%.2f z=%.2f elbow=%.3f torso=%.3f (want −0.55 −0.40 −0.875 0.027) | end: arm=%.2f z=%.2f elbow=%.2f torso=%.3f done=%s (want −0.10 0.00 −0.35 0.000 true) | claps between (0.16,0.17] (0.17,0.49] (0.49,0.51] (0.51,1.4]=%s %s %s %s (want true false true false) total=%.3f (want 1.367)" % [m_shx, m_shz, m_el, m_knee, m_hip, m_tx, m_neck > 0.0, a_shz, a_knee, r_shz, r_el, r_el2, s_shx, s_shz, s_el, s_tx, e_shx, e_shz, e_el, e_tx, e_done, ChalkPoses.clap_between(0.16, 0.17), ChalkPoses.clap_between(0.17, 0.49), ChalkPoses.clap_between(0.49, 0.51), ChalkPoses.clap_between(0.51, 1.4), ChalkPoses.TOTAL])

## 감는 이의 phase 가 p 가 될 때까지 팩의 _process 를 돌린다(cap_ticks × 5 틱까지 — 안 오면 그냥 돌아온다, 출력의 want 가 어긋난다)
func _until(cw: ClimbWeight, wd: ClimbWinder, p: String, cap_ticks: int) -> void:
	var n := 0
	while wd.phase != p and n < cap_ticks * 5:
		cw._process(DT); n += 1
