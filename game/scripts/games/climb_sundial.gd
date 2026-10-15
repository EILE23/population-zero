class_name ClimbSundial
extends Node3D
## Climb 콘텐츠 팩 '해시계'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 공중 정원(Hanging garden) 층의 가장 넓은 still 발판 하나 — 가운데 x, 절벽에서 inset 안쪽에 둥근 돌판(size px)이 발판에 박혀 있다: 열두 시각 눈금, 가운데 그노몬(gnomon_h), 그리고 탑의 하루(day_s — 허들 줄이 세는 그 하루)에 한 바퀴 도는 그림자. 앞길은 비어 있다.
## 돌판 곁(반지름 + reach 안)에서 C: 읽는다(squint — 한 손은 빛을 가려 이마 위에 납작하게, 다른 손은 그림자를 가리키며 아래로, 몸은 골반에서 뒤로 젖혀지고 무게가 발에서 발로 옮겨 가며 고개가 그림자를 따라 판으로 내려가고 해로 올라간다, 끄덕, 바로 서기): settle_s 뒤 show_s 동안 돌판 위에 탑의 시각이 쓰이고,
## 바로 위 통풍구 층(vent_floor_above — 상승기류 팩의 from/every 를 그 자료에서 읽는다)의 통풍구들이 절벽 면에 올라가는 화살표로 그려진다 — 층 전체를 scale 로 줄여 돌판 가운데에 맞춘 참 x; 지금 부는 통풍구의 화살표는 밝고 떠오르며 다른 것은 흐리고 멎어 있다 — 오르기 전에 피할 발판 위를 안다. 읽는 동안의 두 번째 C 는 아무것도 아니다.
## 단단한 것이 없고 값도 없다: 돌판은 3 px 두께로 발판에 박혀 있고 그 위를 지나는 맨 달리기는 그대로다(100%).
## 망원경(peer — 위 층의 발판을 보여 준다)과 다르다: 이건 탑에 시각을 처음 주는 조각 — 같은 하루를 허들 판과 나누고, 통풍구의 박자를 멀리서 읽게 한다. 자세는 squint(stick3d_squint.gd — 운영자 보드의 '지도 읽기·둘러보기' 가족).
## 로더가 할 일(climb.gd, 운영자 세션): `var sd := ClimbSundial.new(); add_child(sd)`; 층을 지을 때 `var vn := sd.vent_floor_above(n); sd.build(root, sd.plan(n, plats, cu.plan(n, plats) + cpl.plan(n, plats) + ctu.plan(n, plats) + cv.plan(n, plats) + chm.plan(n, plats, wind_of(n)) + cz.plan(n, plats)), cu.plan(vn, band(vn)), vn)`
## (통풍구·시소 화분·튤립·덩굴·해먹·집라인의 계획을 taken 으로 — 한 발판을 둘이 안 나눈다; 셋째·넷째 인자는 위 통풍구 층의 계획과 층 번호 — 화살표의 원본); 매 틱 `sd.sync(_t)`;
## 발판에 선 가지에서 act 가 막 눌렸으면(`Input.is_action_just_pressed("act")`) `var r := sd.read(on, x, z, true, fig); if r["read"]: fig.pose_request = "squint"; _scene_until = now + SquintPoses.SQUINT_T` (읽는 동안 몸은 선 자리에 — 걷기는 잠기고), `SquintPoses.done(fig)` 면 자세를 비운다 (돌판 밖에선 C 는 로더의 것 — 판 읽기·쉼터 문).
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_sundial.gd

const PACK := "res://data/climb/sundial.json"
const VENTS := "res://data/climb/updraft.json"   # 통풍구 층의 규칙(from/every)과 박자(beat)는 그 팩의 자료에서 — 둘이 어긋나지 않게
const C = preload("res://scripts/games/climb.gd")
const BAND_LO := 20.0      # taken 조각이 이 발판의 것인가: y 가 발판 윗면 − BAND_LO 부터 윗면 + BAND_HI 앞까지(run 152 의 띠 규칙)
const BAND_HI := 60.0
const BODY_UP := 50.0      # 선 몸의 키(px) — 상자 위쪽 여유
const VIEW_Z := -64.0      # 화살표의 깊이(px) — 절벽 면 바로 앞, 몸 뒤
const SLAB_H := 3.0        # 돌판 두께(px)
const ALPHA_LIT := 0.9     # 지금 부는 통풍구의 화살표
const ALPHA_DIM := 0.3     # 멎은 통풍구의 화살표

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.dial
var vent_rule: Dictionary = {}  # 상승기류 팩의 첫 조각 {from, every}
var vent_beat := 4.0
var dials: Array = []           # 지은 해시계 {id, kind "dial", n, hop_id, cx, x, w, y, y_top, z, d, vent_n, read_t0, node, shadow, label, view, arrows [{node, shaft, head, phase}], chime, tick, shown}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("dial", {})
	var g := FileAccess.open(VENTS, FileAccess.READ)
	if g:
		var up := JSON.parse_string(g.get_as_text()) as Dictionary
		var pieces: Array = up.get("pieces", [])
		if pieces.size() > 0: vent_rule = pieces[0]
		var vk: Dictionary = (up.get("kinds", {}) as Dictionary).get("vent", {})
		vent_beat = maxf(0.1, float(vk.get("beat", 4.0)))

func sync(now: float) -> void:
	t = now

func size() -> float:
	return maxf(12.0, float(kind.get("size", 36.0)))

func inset() -> float:
	return maxf(size() / 2.0, float(kind.get("inset", 30.0)))

func margin() -> float:
	return maxf(C.HW, float(kind.get("margin", 24.0)))

func min_w() -> float:
	return maxf(size() + margin() * 2.0, float(kind.get("min_w", 100.0)))

func gnomon_h() -> float:
	return maxf(4.0, float(kind.get("gnomon_h", 14.0)))

func day_s() -> float:
	return maxf(1.0, float(kind.get("day_s", 600.0)))

func reach() -> float:
	return maxf(0.0, float(kind.get("reach", 18.0)))

func read_s() -> float:
	return maxf(0.5, float(kind.get("read_s", 3.2)))

func show_s() -> float:
	return maxf(read_s(), float(kind.get("show_s", 6.0)))

func settle_s() -> float:
	return clampf(float(kind.get("settle_s", 0.5)), 0.0, read_s() / 2.0)

func fade_s() -> float:
	return clampf(float(kind.get("fade_s", 0.6)), 0.01, show_s() / 2.0)

func view_scale() -> float:
	return clampf(float(kind.get("scale", 0.25)), 0.05, 1.0)

func view_up() -> float:
	return maxf(0.0, float(kind.get("view_up", 40.0)))

## 탑의 오늘 중 지난 몫 0..1 — 그림자가 한 바퀴
func day_frac(at: float) -> float:
	return fposmod(at / day_s(), 1.0)

## 탑의 시각 "hh:mm" — 하루를 24시간으로 읽는다
func time_text(at: float) -> String:
	var m := int(day_frac(at) * 1440.0) % 1440
	return "%02d:%02d" % [m / 60, m % 60]

## n 층 위의 첫 통풍구 층 — 상승기류 팩의 {from, every}
func vent_floor_above(n: int) -> int:
	var from := int(vent_rule.get("from", 3)); var every := maxi(1, int(vent_rule.get("every", 4)))
	var v := maxi(n + 1, from)
	while (v - from) % every != 0: v += 1
	return v

## 그 통풍구가 지금 부나 — climb_updraft.active 와 같은 식(박자 한 바퀴의 앞 반은 phase 0, 뒤 반은 phase 0.5)
func lit(phase: float, at: float) -> bool:
	return fposmod(at / vent_beat + phase, 1.0) < 0.5

## 읽는 중인가(read 뒤 read_s 안 — 몸이 잠긴 동안)
func reading_at(c: Dictionary, at: float) -> bool:
	var r0 := float(c["read_t0"])
	return r0 >= 0.0 and at >= r0 and at < r0 + read_s()

## 어느 해시계든 읽는 중인가 — 로더가 걷기를 잠그는 조건
func squinting() -> bool:
	for cv in dials:
		if reading_at(cv, t): return true
	return false

## 시각·화살표의 농도 0..1: settle_s 뒤 0.3초에 1 로, show_s 끝 fade_s 동안 0 으로, 읽지 않았으면 0
func solidity(c: Dictionary, at: float) -> float:
	var r0 := float(c["read_t0"])
	if r0 < 0.0 or at < r0 or at >= r0 + show_s(): return 0.0
	var since := at - r0 - settle_s()
	var left := r0 + show_s() - at
	return minf(clampf(since / 0.3, 0.0, 1.0), clampf(left / fade_s(), 0.0, 1.0))

## 층 n(테마 층)의 still 발판(조각의 on) 중 min_w 넓이에, 돌판 상자(돌판 ± 몸 하나, 윗면..선 몸)를 다른 발판이 가르지 않고, taken 조각이 띠 안에 없는 것들 중 가장 넓은 것 하나. 같은 층·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var kinds: Array = piece.get("on", ["std", "ice"])
		var hops: Array = plats.filter(func(p: Dictionary) -> bool: return String(p["kind"]) in kinds and not (String(p["kind"]) in ["rest", "short", "ledge"]) and float(p["w"]) >= min_w())
		var found: Array = []
		for hv in hops:
			var p: Dictionary = hv
			var cx := float(p["x"]) + float(p["w"]) / 2.0
			var x0 := cx - size() / 2.0 - margin(); var x1 := cx + size() / 2.0 + margin()
			if not _clear(plats, p, x0, x1, float(p["y"]) + 1.0, float(p["y"]) + BODY_UP): continue
			if not _free(taken, x0, x1, float(p["y"]) - BAND_LO, float(p["y"]) + BAND_HI): continue
			found.append({ "w": float(p["w"]), "hop_id": String(p["id"]), "y": float(p["y"]), "cx": cx })
		found.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["w"]) > float(q["w"]) if float(p["w"]) != float(q["w"]) else float(p["y"]) < float(q["y"]))
		for i in range(0, mini(int(piece.get("max", 1)), found.size())):
			var g: Dictionary = found[i]
			var s: Dictionary = g.duplicate()
			s["id"] = "%d.D%d" % [n, i]; s["kind"] = "dial"; s["n"] = n
			s["x"] = float(g["cx"]) - size() / 2.0; s["w"] = size()
			s["y_top"] = float(g["y"]) + gnomon_h()   # 그노몬 끝 — 다른 팩의 _free 가 읽는 키
			s["z"] = C.WALL_Z + inset(); s["d"] = size()   # 돌판의 깊이 — 절벽에서 inset 가운데
			out.append(s)
	return out

## 돌판의 상자에 그 발판 말고 다른 발판이 걸리지 않나 — 움직이는 발판은 진폭째
static func _clear(plats: Array, a: Dictionary, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for pv in plats:
		var p: Dictionary = pv
		if p["id"] == a["id"]: continue
		var py := float(p["y"])
		if py < ylo or py > yhi: continue
		var amp := float(p.get("amp", 0.0))
		var px0 := float(p["x"]) - amp - 10.0; var px1 := float(p["x"]) + float(p["w"]) + amp + 10.0
		if x1 > px0 and x0 < px1: return false
	return true

## 다른 팩의 조각(taken: x, 있으면 w·rail_y·beam_y·y_top)이 돌판의 x 와 겹치고 높이 띠 [ylo, yhi) 에 들면 그 발판은 그 팩의 것 — 통풍구는 발판 가운데(w 없음), 화분·튤립은 틈 가장자리, 덩굴·해먹·집라인은 틈
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qx0 := float(q.get("x", 0.0)) - 10.0; var qx1 := float(q.get("x", 0.0)) + float(q.get("w", 0.0)) + 10.0
		var qy := float(q.get("y", 0.0)); var qtop := qy
		for key in ["rail_y", "beam_y", "y_top"]:
			if q.has(key): qtop = maxf(qtop, float(q[key]))
		if x1 > qx0 and x0 < qx1 and qtop >= ylo and qy < yhi: return false
	return true

## C 를 누른 틱 — 그 발판 위, 돌판 반지름 + reach 안, 걷는 깊이면 읽는다: {read, until, busy, text}. 이미 읽는 동안(busy)은 아무것도 아니다. text 는 로더가 원하면 띄우는 한 줄(돌판 위의 글자가 이미 같은 시각을 보인다)
func read(on: Dictionary, x: float, z: float, pressed: bool, fig: Stick3D = null) -> Dictionary:
	var none := { "read": false, "until": -1.0, "busy": false, "text": "" }
	if not pressed: return none
	var oid := String(on.get("id", ""))
	for cv in dials:
		var c: Dictionary = cv
		if oid != String(c["hop_id"]): continue
		if absf(z - C.PLAYER_Z) >= C.HZ + 4.0: continue
		if absf(x - float(c["cx"])) > size() / 2.0 + reach(): continue
		if reading_at(c, t): return { "read": false, "until": float(c["read_t0"]) + read_s(), "busy": true, "text": "" }
		c["read_t0"] = t; c["shown"] = false
		_play(c["chime"])
		if fig: fig.set_meta("squint_dir", cos(day_frac(t) * TAU))   # 고개가 그림자 끝 쪽을 본다 — 그림자는 그노몬에서 +x 로 뻗어 하루에 한 바퀴
		return { "read": true, "until": t + read_s(), "busy": false, "text": _text(c) }
	return none

## 읽은 줄 — 탑의 시각과 위 통풍구 층
func _text(c: Dictionary) -> String:
	var vn := int(c["vent_n"]); var n := int(c["n"])
	if (c["arrows"] as Array).is_empty(): return "Tower time %s." % time_text(t)
	return "Tower time %s. Vents: floor %d, %d up. The bright arrow is blowing." % [time_text(t), vn, vn - n]

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 노드를 지금 자리로
func _process(delta: float) -> void:
	t += delta
	dials = dials.filter(func(c: Dictionary) -> bool: return is_instance_valid(c["node"]))   # 지운 층의 것은 뺀다(climb_telescope 와 같은 식)
	for cv in dials:
		_place(cv)

## 해시계를 짓는다 — root 는 그 층의 노드, vents 는 위 통풍구 층(vent_n)의 계획(화살표의 원본). 노드 원점은 (돌판 가운데, 발판 윗면, 돌판의 깊이); 돌판·열두 눈금·그노몬·그림자·시각 글자·화살표(절벽 면 앞)·소리 둘
func build(root: Node3D, planned: Array, vents: Array = [], vent_n: int = -1) -> void:
	var r := size() / 2.0 * C.K; var gh := gnomon_h() * C.K
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate(true)
		var node := Node3D.new(); node.position = C.to3(float(s["cx"]), float(s["y"]), float(s["z"]) * C.K); root.add_child(node)
		var stone := _mat(Color("b9b2a6")); var ink := _mat(Color("2f2a4e")); var brass := _mat(Color("b08d57")); var band := _mat(Color("ad7096"))
		var slab := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = r; cm.bottom_radius = r; cm.height = SLAB_H * C.K; cm.radial_segments = 18
		slab.mesh = cm; slab.material_override = stone; slab.position = Vector3(0.0, SLAB_H * C.K / 2.0, 0.0); slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; node.add_child(slab)
		for i in 12:   # 열두 시각 눈금 — 테 안쪽, 6시(앞)와 12시(절벽)는 강조색
			var ang := TAU * float(i) / 12.0
			var mk := _box(node, Vector3(1.2 * C.K, 0.6 * C.K, 3.0 * C.K), band if i % 6 == 0 else ink)
			mk.position = Vector3(sin(ang) * (r - 3.0 * C.K), SLAB_H * C.K + 0.3 * C.K, cos(ang) * (r - 3.0 * C.K)); mk.rotation.y = -ang
		var gn := _box(node, Vector3(1.5 * C.K, gh, 4.0 * C.K), brass); gn.position = Vector3(0.0, SLAB_H * C.K + gh / 2.0, -1.0 * C.K); gn.rotation.x = 0.35   # 그노몬 — 절벽 쪽으로 기운 놋쇠 날
		var shadow := Node3D.new(); shadow.position = Vector3(0.0, SLAB_H * C.K + 0.4 * C.K, 0.0); node.add_child(shadow)   # 그림자의 축 — y 로 돈다
		var sl := (size() / 2.0 - 4.0) * C.K
		_box(shadow, Vector3(sl, 0.5 * C.K, 2.0 * C.K), _mat(Color("4a4a52"))).position = Vector3(sl / 2.0, 0.0, 0.0)
		var label := Label3D.new(); label.text = ""; label.font_size = 40; label.pixel_size = 0.004; label.modulate = Color("1b0c15"); label.outline_size = 8; label.outline_modulate = Color("f7f4ef")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; label.no_depth_test = true; label.position = Vector3(0.0, view_up() * 0.5 * C.K, 0.0); label.visible = false; node.add_child(label)
		var view := Node3D.new(); view.position = Vector3(0.0, view_up() * C.K, (VIEW_Z - float(s["z"])) * C.K); node.add_child(view)
		var arrows: Array = []
		for vv in vents:
			arrows.append(_build_arrow(view, vv))
		s["vent_n"] = vent_n; s["read_t0"] = -99.0; s["shown"] = false
		s["node"] = node; s["shadow"] = shadow; s["label"] = label; s["view"] = view; s["arrows"] = arrows
		s["chime"] = _snd(node, float(kind.get("chime_hz", 1046)), 0.25, -14.0); s["tick"] = _snd(node, float(kind.get("tick_hz", 660)), 0.08, -16.0)
		dials.append(s)
		_place(s)

## 통풍구 하나를 올라가는 화살표로 — 자루(line × arrow)와 꺾인 머리 둘; 자리는 층 안의 x(탑 가운데 기준)를 scale 로 줄인 것. {node, shaft, head, phase}
func _build_arrow(view: Node3D, v: Dictionary) -> Dictionary:
	var sc := view_scale(); var ln := maxf(0.5, float(kind.get("line", 1.5))) * C.K; var al := maxf(4.0, float(kind.get("arrow", 14.0))) * C.K
	var cx := (float(v["x"]) - C.WORLD_W / 2.0) * sc
	var an := Node3D.new(); an.position = Vector3(cx * C.K, 0.0, 0.0); view.add_child(an)
	var shaft := _mat(Color("f2b632"), true); shaft.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var head := _mat(Color("f7f4ef"), true); head.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_box(an, Vector3(ln, al, ln), shaft).position = Vector3(0.0, al / 2.0, 0.0)
	for sx in [-1.0, 1.0]:
		var hb := _box(an, Vector3(ln, al * 0.45, ln), head)
		hb.position = Vector3(sx * al * 0.16, al - al * 0.16, 0.0); hb.rotation.z = sx * 0.75
	return { "node": an, "shaft": shaft, "head": head, "phase": float(v.get("phase", 0.0)) }

## 그림자는 하루에 한 바퀴, 시각 글자와 화살표는 농도대로 — 부는 통풍구의 화살표는 밝고 떠오르며(rise 안에서 감긴다) 멎은 것은 흐리고 멎어 있다; 처음 켜질 때 그노몬 소리
func _place(c: Dictionary) -> void:
	var a := solidity(c, t)
	(c["shadow"] as Node3D).rotation.y = -day_frac(t) * TAU
	var label: Label3D = c["label"]
	label.visible = a > 0.0
	if a > 0.0: label.text = time_text(t); label.modulate = Color(Color("1b0c15"), a); label.outline_modulate = Color(Color("f7f4ef"), a)
	var rise := maxf(1.0, float(kind.get("rise", 12.0))) * C.K; var rv := maxf(0.0, float(kind.get("rise_v", 18.0))) * C.K
	for av in (c["arrows"] as Array):
		var ar: Dictionary = av
		var on := lit(float(ar["phase"]), t)
		var k := (ALPHA_LIT if on else ALPHA_DIM) * a
		var sm: StandardMaterial3D = ar["shaft"]; var hm: StandardMaterial3D = ar["head"]
		sm.albedo_color = Color(sm.albedo_color, k); hm.albedo_color = Color(hm.albedo_color, k)
		var an: Node3D = ar["node"]
		an.visible = a > 0.0
		an.position.y = fposmod(t * rv, rise) if on else 0.0
	if a > 0.0 and not bool(c["shown"]): _play(c["tick"])
	c["shown"] = a > 0.0

func _mat(c: Color, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	if unshaded: m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else: m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size_v: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size_v; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만(돌판의 그림자는 그려 둔 판)
	parent.add_child(mi); return mi

func _snd(parent: Node3D, hz: float, secs: float, db: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new(); p.stream = _tick_wav(hz, secs); p.volume_db = db; p.unit_size = 6.0; p.max_distance = 30.0
	parent.add_child(p); return p

## 소리 — 짧은 기음이 잦아든다: chime(0.25초, 읽기 시작)·tick(0.08초, 시각이 켜진다). 한 번 재생, 반복 없음
static func _tick_wav(hz: float, secs: float) -> AudioStreamWAV:
	var rate := 22050; var count := int(rate * secs)
	var data := PackedByteArray(); data.resize(count * 2)
	for i in count:
		var k := float(i) / count
		var ph := float(i) * hz * TAU / rate
		var v := (sin(ph) * 0.5 + sin(ph * 2.0) * 0.2) * exp(-k * 5.0)
		data.encode_s16(i * 2, int(v * 22000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w
