class_name ClimbTelescope
extends Node3D
## Climb 콘텐츠 팩 '망원경'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 별밤(Starlit) 층의 잇단 두 still 발판 사이 틈(90..220 px) — 아래 발판의 틈 쪽 가장자리 inset 안쪽, 걷는 선 뒤(절벽 쪽)에 선 세발 받침의 놋쇠 망원경이 틈 너머 위를 겨눈다.
## 받침 곁(HW + reach 안)에서 C: 눈을 댄다(peer — 골반에서 꺾여 접안렌즈로 숙인 몸, 한 손은 통을 쥐고 다른 손은 감은 눈을 오목하게 덮는다; 자리 잡기, 틈을 따라 천천히 훑기, 하늘을 보며 바로 서기): show_s 동안 바로 위 층(n+1)의 발판들이 틈 위 절벽 면에 별 윤곽으로 그려진다 — 발판마다 가는 테와 네 귀의 별, 층 전체를 scale 로 줄여 틈 가운데에 맞추고, 틈 폭 안에 든 것만 보인다; ← → 는 보는 자리를 pan_v 로 ±pan_max 까지 옮긴다 — 오르기 전에 위 배치를 읽는다. 보는 동안의 두 번째 C 는 아무것도 아니다.
## 단단한 것이 없고 값도 없다: 받침은 걷는 선 뒤에 서고, 그 곁을 지나 틈을 건너는 맨 점프는 그대로다(100%).
## 유령 판·렌즈(발판을 켜 준다)와 다르다: 이건 발판을 하나도 더하지 않고 눈만 더 멀리 보내는 첫 조각 — 위를 미리 보는 것은 플레이어의 선택이고 몸은 4초를 쓴다. 자세는 peer(stick3d_peer.gd — 운영자 보드의 '지도 읽기·둘러보기' 가족).
## 로더가 할 일(climb.gd, 운영자 세션): `var ts := ClimbTelescope.new(); add_child(ts)`; 층을 지을 때 `var ic := ci.plan(n, plats); var cnp := cn.plan(n, plats, ic); ts.build(root, ts.plan(n, plats, ic + cnp + ct.plan(n, plats, ic + cnp) + cc.plan(n, plats, cnp + ic)), band(n + 1))` (고드름·등롱·그네·초 계단의 계획을 taken 으로 — 한 틈을 둘이 안 나눈다; 셋째 인자는 위 층의 발판 — 윤곽의 원본); 매 틱 `ts.sync(_t)`;
## 발판에 선 가지에서 act 가 막 눌렸으면(`Input.is_action_just_pressed("act")`) `var r := ts.peer(on, x, z, true, fig); if r["peered"]: fig.pose_request = "peer"; _scene_until = now + PeerPoses.PEER_T` (보는 동안 몸은 선 자리에 — 걷기는 잠기고), `PeerPoses.done(fig)` 면 자세를 비운다 (받침 밖에선 C 는 로더의 것 — 판 읽기·쉼터 문);
## `ts.peering()` 인 틱마다 `ts.pan(Input.get_axis("left", "right"), dt, fig)` — 화살표가 걷기 대신 윤곽을 옮긴다.
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_telescope.gd

const PACK := "res://data/climb/telescope.json"
const C = preload("res://scripts/games/climb.gd")
const BAND_IN := 20.0      # taken 조각이 이 틈의 것인가: y 가 아래 발판 윗면 − BAND_IN 부터 위 발판 윗면 − BAND_IN 앞까지(run 152 의 띠 규칙 — 탑은 지그재그라 모든 틈이 한 x 열에 쌓인다)
const BODY_UP := 50.0      # 선 몸의 키(px) — 상자 위쪽 여유
const TRIPOD_Z := -62.0    # 받침의 깊이(px) — 걷는 선(PLAYER_Z −48)과 절벽(WALL_Z −70) 사이, 몸 뒤
const VIEW_Z := -64.0      # 윤곽의 깊이(px) — 절벽 면 바로 앞, 몸 뒤
const HOP_H := 12.0        # 윤곽 한 칸의 두께(px, 줄이기 전)
const ALPHA_LINE := 0.85   # 켜진 윤곽의 농도
const ALPHA_STAR := 1.0

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.telescope
var scopes: Array = []          # 지은 망원경 {id, kind "telescope", n, x, w, y, dir, gap, hinge_x, mid_x, tri_x, a_id, b_id, a_y, b_y, peer_t0, pan, node, tube, view, hops [{node, cx}], line_mat, star_mat, click, twinkle, shown}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("telescope", {})

func sync(now: float) -> void:
	t = now

func inset() -> float:
	return maxf(C.HW, float(kind.get("inset", 22.0)))

func tripod_h() -> float:
	return maxf(10.0, float(kind.get("tripod_h", 34.0)))

func tube_len() -> float:
	return maxf(10.0, float(kind.get("tube_len", 40.0)))

func reach() -> float:
	return maxf(0.0, float(kind.get("reach", 18.0)))

func show_s() -> float:
	return maxf(0.5, float(kind.get("show_s", 4.0)))

func settle_s() -> float:
	return clampf(float(kind.get("settle_s", 0.5)), 0.0, show_s() / 2.0)

func fade_s() -> float:
	return clampf(float(kind.get("fade_s", 0.6)), 0.01, show_s() / 2.0)

func view_scale() -> float:
	return clampf(float(kind.get("scale", 0.25)), 0.05, 1.0)

func view_up() -> float:
	return maxf(0.0, float(kind.get("view_up", 30.0)))

func pan_v() -> float:
	return maxf(0.0, float(kind.get("pan_v", 240.0)))

func pan_max() -> float:
	return maxf(0.0, float(kind.get("pan_max", 240.0)))

## 보고 있나(peer 뒤 show_s 안)
func peering_at(c: Dictionary, at: float) -> bool:
	var p0 := float(c["peer_t0"])
	return p0 >= 0.0 and at >= p0 and at < p0 + show_s()

## 어느 망원경이든 보는 중인가 — 로더가 화살표를 pan 으로 돌리는 조건
func peering() -> bool:
	for cv in scopes:
		if peering_at(cv, t): return true
	return false

## 윤곽의 농도 0..1: settle_s 뒤 0.3초에 1 로, 끝 fade_s 동안 0 으로, 안 볼 땐 0
func solidity(c: Dictionary, at: float) -> float:
	if not peering_at(c, at): return 0.0
	var since := at - float(c["peer_t0"]) - settle_s()
	var left := float(c["peer_t0"]) + show_s() - at
	return minf(clampf(since / 0.3, 0.0, 1.0), clampf(left / fade_s(), 0.0, 1.0))

## 층 n(테마 층·조각의 only 층만)의 잇단 두 still 발판(조각의 on; 아래 a·위 b) 중 틈이 min_gap..max_gap 이고 b 가 min_dy..max_dy 높으며 틈의 상자를 다른 발판이 가르지 않고 taken 조각이 닿지 않는 짝들 중 가장 넓은 틈 하나. 같은 층·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	var min_gap := float(kind.get("min_gap", 90.0)); var max_gap := float(kind.get("max_gap", 220.0))
	var min_dy := float(kind.get("min_dy", 40.0)); var max_dy := float(kind.get("max_dy", 150.0))
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var only: Dictionary = piece.get("only", {})
		if not only.is_empty() and not _on(n, only): continue
		var kinds: Array = piece.get("on", ["std", "ice"])
		var hops: Array = plats.filter(func(p: Dictionary) -> bool: return not (String(p["kind"]) in ["rest", "short", "ledge"]))
		var found: Array = []
		for i in range(1, hops.size()):
			var a: Dictionary = hops[i - 1]; var b: Dictionary = hops[i]   # a 가 아래 발판(band() 는 오르는 순서로 쌓는다)
			if not (String(a["kind"]) in kinds and String(b["kind"]) in kinds): continue
			var dy := float(b["y"]) - float(a["y"])
			if dy < min_dy or dy > max_dy: continue
			var ax0 := float(a["x"]); var ax1 := ax0 + float(a["w"]); var bx0 := float(b["x"]); var bx1 := bx0 + float(b["w"])
			if bx0 < ax1 and bx1 > ax0: continue   # 겹친 발판 — 틈이 없다
			var dir := 1.0 if bx0 >= ax1 else -1.0   # 아래 발판에서 위 발판 쪽
			var gap := bx0 - ax1 if dir > 0.0 else ax0 - bx1
			if gap < min_gap or gap > max_gap: continue
			if float(a["w"]) < inset() * 2.0 + 2.0 * C.HW: continue   # 받침과 그 곁의 몸이 설 자리
			var hinge := ax1 if dir > 0.0 else ax0
			var tri := hinge - dir * inset()
			var x0 := minf(tri, hinge + dir * gap) - 8.0; var x1 := maxf(tri, hinge + dir * gap) + 8.0
			if not _clear(plats, a, b, x0, x1, float(a["y"]) + 1.0, float(a["y"]) + BODY_UP): continue
			if not _free(taken, x0, x1, float(a["y"]) - BAND_IN, float(b["y"]) - BAND_IN): continue
			found.append({ "gap": gap, "dir": dir, "hinge_x": hinge, "tri_x": tri, "mid_x": hinge + dir * gap / 2.0,
				"a_id": String(a["id"]), "b_id": String(b["id"]), "a_y": float(a["y"]), "b_y": float(b["y"]), "z": float(a.get("z", 0.0)), "d": float(a.get("d", C.DEPTH_HALF * 2.0)) })
		found.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["gap"]) > float(q["gap"]) if float(p["gap"]) != float(q["gap"]) else float(p["a_y"]) < float(q["a_y"]))
		for i in range(0, mini(int(piece.get("max", 1)), found.size())):
			var g: Dictionary = found[i]
			var s: Dictionary = g.duplicate()
			s["id"] = "%d.S%d" % [n, i]; s["kind"] = "telescope"; s["n"] = n
			s["x"] = minf(float(g["tri_x"]), float(g["hinge_x"]) + float(g["dir"]) * float(g["gap"])); s["w"] = float(g["gap"]) + inset(); s["y"] = float(g["a_y"])
			s["y_top"] = float(g["a_y"]) + tripod_h() + tube_len() * 0.5   # 통 끝 — 다른 팩의 _free 가 읽는 키
			out.append(s)
	return out

## 층 n 이 {from, every} 에 드나
static func _on(n: int, rule: Dictionary) -> bool:
	var from := int(rule.get("from", 0))
	return n >= from and (n - from) % maxi(1, int(rule.get("every", 1))) == 0

## 틈의 상자(받침에서 위 발판 가장자리 너머 손 하나까지, 아래 발판 윗면..선 몸)에 두 발판 말고 다른 발판이 걸리지 않나 — 움직이는 발판은 진폭째
static func _clear(plats: Array, a: Dictionary, b: Dictionary, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for pv in plats:
		var p: Dictionary = pv
		if p["id"] == a["id"] or p["id"] == b["id"]: continue
		var py := float(p["y"])
		if py < ylo or py > yhi: continue
		var amp := float(p.get("amp", 0.0))
		var px0 := float(p["x"]) - amp - 10.0; var px1 := float(p["x"]) + float(p["w"]) + amp + 10.0
		if x1 > px0 and x0 < px1: return false
	return true

## 다른 팩의 조각(taken: x·w·y, 있으면 rail_y·beam_y·y_top 까지의 키)이 이 틈에 들지 않나 — 틈의 x 와 겹치고 조각의 높이 띠가 [ylo, yhi) 와 겹치면 그 틈은 그 팩의 것(등롱 장대·초는 아래 발판 높이, 그네는 틈 안에 매달린다; 위 발판 높이의 조각은 위 틈의 것)
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qx0 := float(q["x"]) - 10.0; var qx1 := float(q["x"]) + float(q.get("w", 0.0)) + 10.0
		var qy := float(q.get("y", 0.0)); var qtop := qy
		for key in ["rail_y", "beam_y", "y_top"]:
			if q.has(key): qtop = maxf(qtop, float(q[key]))
		if x1 > qx0 and x0 < qx1 and qtop >= ylo and qy < yhi: return false
	return true

## C 를 누른 틱 — 아래 발판 위, 받침 HW + reach 안이면 눈을 댄다: {peered, until, busy}. 이미 보는 동안(busy)은 아무것도 아니다. 걷는 깊이여야 한다
func peer(on: Dictionary, x: float, z: float, pressed: bool, fig: Stick3D = null) -> Dictionary:
	var none := { "peered": false, "until": -1.0, "busy": false }
	if not pressed: return none
	var oid := String(on.get("id", ""))
	for cv in scopes:
		var c: Dictionary = cv
		if oid != String(c["a_id"]): continue
		if absf(z - C.PLAYER_Z) >= C.HZ + 4.0: continue
		if absf(x - float(c["tri_x"])) > C.HW + reach(): continue
		if peering_at(c, t): return { "peered": false, "until": float(c["peer_t0"]) + show_s(), "busy": true }
		c["peer_t0"] = t; c["pan"] = 0.0; c["shown"] = false
		_play(c["click"])
		if fig: fig.set_meta("peer_pan", 0.0)
		return { "peered": true, "until": t + show_s(), "busy": false }
	return none

## 보는 동안 화살표 — 윤곽의 가운데를 dir 쪽으로 pan_v 만큼 옮긴다(±pan_max). 돌려주는 값은 지금 pan(px). 자세의 고개도 같이(meta peer_pan −1..1)
func pan(dir: float, dt: float, fig: Stick3D = null) -> float:
	for cv in scopes:
		var c: Dictionary = cv
		if not peering_at(c, t): continue
		c["pan"] = clampf(float(c["pan"]) + clampf(dir, -1.0, 1.0) * pan_v() * dt, -pan_max(), pan_max())
		if fig and pan_max() > 0.0: fig.set_meta("peer_pan", float(c["pan"]) / pan_max() * float(c["dir"]))
		return float(c["pan"])
	return 0.0

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 노드를 지금 자리로
func _process(delta: float) -> void:
	t += delta
	scopes = scopes.filter(func(c: Dictionary) -> bool: return is_instance_valid(c["node"]))   # 지운 층의 것은 뺀다(climb_lens 와 같은 식)
	for cv in scopes:
		_place(cv)

## 망원경을 짓는다 — root 는 그 층의 노드, above 는 위 층(n+1)의 발판(윤곽의 원본). 노드 원점은 (받침 가운데, 아래 발판 윗면, 받침의 깊이); 세 다리·머리판·놋쇠 통(틈 너머 위를 겨눈다, 자주 테)·접안렌즈·윤곽(틈 가운데 위, 절벽 면 앞)·소리 둘
func build(root: Node3D, planned: Array, above: Array = []) -> void:
	var th := tripod_h() * C.K; var tl := tube_len() * C.K
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate(true)
		var dir := float(s["dir"])
		var node := Node3D.new(); node.position = C.to3(float(s["tri_x"]), float(s["a_y"]), TRIPOD_Z * C.K); root.add_child(node)
		var wood := _mat(Color("6b4a35")); var brass := _mat(Color("b08d57")); var band := _mat(Color("ad7096")); var dark := _mat(Color("2f2a4e"))
		for i in 3:   # 세 다리 — 머리판에서 바깥으로 벌어진다
			var ang := TAU * float(i) / 3.0 + PI / 6.0
			var leg := _box(node, Vector3(1.6 * C.K, th, 1.6 * C.K), wood)
			leg.position = Vector3(cos(ang) * 5.0 * C.K, th / 2.0, sin(ang) * 5.0 * C.K)
			leg.rotation = Vector3(sin(ang) * 0.28, 0.0, -cos(ang) * 0.28)
		_box(node, Vector3(8.0 * C.K, 2.0 * C.K, 8.0 * C.K), dark).position = Vector3(0.0, th, 0.0)   # 머리판
		var tube := Node3D.new(); tube.position = Vector3(0.0, th + 2.0 * C.K, 0.0); node.add_child(tube)
		tube.rotation.z = dir * 0.42   # 틈 너머 위를 겨눈다 — pivot 의 +x 가 통의 방향(dir 쪽), 위로 0.42 rad
		var tm := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 2.2 * C.K; cm.bottom_radius = 3.0 * C.K; cm.height = tl; cm.radial_segments = 10
		tm.mesh = cm; tm.material_override = brass; tm.rotation.z = -dir * PI / 2.0; tm.position = Vector3(dir * tl * 0.3, 0.0, 0.0); tm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; tube.add_child(tm)   # 통 — 접안렌즈 쪽이 짧다
		_box(tube, Vector3(1.5 * C.K, 7.0 * C.K, 7.0 * C.K), band).position = Vector3(dir * tl * 0.55, 0.0, 0.0)   # 통의 테 — 강조색만
		_box(tube, Vector3(3.0 * C.K, 3.0 * C.K, 3.0 * C.K), dark).position = Vector3(-dir * tl * 0.22, 0.0, 0.0)   # 접안렌즈
		var view := Node3D.new(); view.position = Vector3((float(s["mid_x"]) - float(s["tri_x"])) * C.K, view_up() * C.K, (VIEW_Z - TRIPOD_Z) * C.K); node.add_child(view)
		var line_mat := _mat(Color("f2c84b"), true); line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var star_mat := _mat(Color("f7f4ef"), true); star_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var hops: Array = []
		for pv in above:
			var p: Dictionary = pv
			if String(p["kind"]) in ["ledge"]: continue
			hops.append(_build_hop(view, p, int(s["n"]) + 1, line_mat, star_mat))
		s["peer_t0"] = -99.0; s["pan"] = 0.0; s["shown"] = false
		s["node"] = node; s["tube"] = tube; s["view"] = view; s["hops"] = hops; s["line_mat"] = line_mat; s["star_mat"] = star_mat
		s["click"] = _snd(node, float(kind.get("click_hz", 1320)), 0.08, -16.0); s["twinkle"] = _snd(node, float(kind.get("twinkle_hz", 1760)), 0.3, -12.0)
		scopes.append(s)
		_place(s)

## 위 층의 발판 하나를 별 윤곽으로 — 테 네 변(line 두께)·네 귀의 별; 자리는 위 층 안의 자리(x 는 탑 가운데 기준, y 는 그 층 바닥 기준)를 scale 로 줄인 것. {node, cx: 줄인 x 가운데(px)}
func _build_hop(view: Node3D, p: Dictionary, n_above: int, line_mat: StandardMaterial3D, star_mat: StandardMaterial3D) -> Dictionary:
	var sc := view_scale(); var ln := maxf(0.5, float(kind.get("line", 1.5))) * C.K; var st := maxf(1.0, float(kind.get("star", 3.0))) * C.K
	var w := float(p["w"]) * sc * C.K; var h := HOP_H * sc * C.K
	var cx := (float(p["x"]) + float(p["w"]) / 2.0 - C.WORLD_W / 2.0) * sc
	var hn := Node3D.new(); hn.position = Vector3(cx * C.K, (float(p["y"]) - float(n_above) * C.BAND_H) * sc * C.K, 0.0); view.add_child(hn)
	_box(hn, Vector3(w, ln, ln), line_mat).position = Vector3(0.0, 0.0, 0.0)
	_box(hn, Vector3(w, ln, ln), line_mat).position = Vector3(0.0, -h, 0.0)
	_box(hn, Vector3(ln, h, ln), line_mat).position = Vector3(-w / 2.0, -h / 2.0, 0.0)
	_box(hn, Vector3(ln, h, ln), line_mat).position = Vector3(w / 2.0, -h / 2.0, 0.0)
	for sx in [-1.0, 1.0]:
		for sy in [0.0, -1.0]:
			_box(hn, Vector3(st, st, ln), star_mat).position = Vector3(sx * w / 2.0, sy * h, 0.0)
	return { "node": hn, "cx": cx }

## 윤곽은 농도대로 켜지고(pan 만큼 옮겨, 틈 폭 안의 칸만), 통은 pan 쪽으로 조금 돈다; 처음 켜질 때 반짝 소리
func _place(c: Dictionary) -> void:
	var a := solidity(c, t); var pan := float(c["pan"]) * view_scale()
	var lm: StandardMaterial3D = c["line_mat"]; var sm: StandardMaterial3D = c["star_mat"]
	lm.albedo_color = Color(lm.albedo_color, ALPHA_LINE * a); sm.albedo_color = Color(sm.albedo_color, ALPHA_STAR * a)
	var view: Node3D = c["view"]; view.position.x = (float(c["mid_x"]) - float(c["tri_x"]) - pan) * C.K
	var half := float(c["gap"]) / 2.0
	for hv in (c["hops"] as Array):
		var h: Dictionary = hv
		(h["node"] as Node3D).visible = a > 0.0 and absf(float(h["cx"]) - pan) <= half
	(c["tube"] as Node3D).rotation.y = -float(c["pan"]) / maxf(1.0, pan_max()) * 0.25
	if a > 0.0 and not bool(c["shown"]): _play(c["twinkle"])
	c["shown"] = a > 0.0

func _mat(c: Color, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	if unshaded: m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else: m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

func _snd(parent: Node3D, hz: float, secs: float, db: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new(); p.stream = _tick_wav(hz, secs); p.volume_db = db; p.unit_size = 6.0; p.max_distance = 30.0
	parent.add_child(p); return p

## 소리 — 짧은 기음이 잦아든다: click(0.08초, 접안렌즈에 눈이 닿는다)·twinkle(0.3초, 윤곽이 켜진다 — 기음 위에 느린 떨림). 한 번 재생, 반복 없음
static func _tick_wav(hz: float, secs: float) -> AudioStreamWAV:
	var rate := 22050; var count := int(rate * secs)
	var data := PackedByteArray(); data.resize(count * 2)
	for i in count:
		var k := float(i) / count
		var ph := float(i) * hz * TAU / rate
		var v := (sin(ph) * 0.5 + sin(ph * 2.0) * 0.2) * exp(-k * 5.0) * (0.7 + 0.3 * sin(k * secs * 30.0))
		data.encode_s16(i * 2, int(v * 22000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w
