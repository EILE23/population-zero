class_name ClimbGhost
extends Node3D
## Climb 콘텐츠 팩 '유령 발판'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 한 층의 가장 긴 틈 한가운데, 두 발판 사이 높이에 보통 발판 모양의 판 하나 — 박자(beat, 통풍구 팩과 같은 시계)의 앞 반은 단단하고 뒤 반은 점선 윤곽만 남는다.
## 단단한 반이 끝나기 fade 초 전부터 판이 녹기 시작해 서 있는 몸이 경고를 받는다(teeter): 그 안에 뛰지 않으면 발밑이 사라지고 몸은 lurch 로 떨어진다. 유령인 동안 떨어지는 몸은 윤곽을 그냥 지나간다.
## 돌아올 땐 appear 초에 굳으며 짧은 종소리(chime)가 울린다 — 박자를 귀로도 잰다. 같은 층은 누구에게나 같은 자리(plan 은 결정적).
## 로더가 할 일(climb.gd, 운영자 세션): `var gh := ClimbGhost.new(); add_child(gh)`; 층을 지을 때 `gh.build(root, gh.plan(n, plats))`; 매 틱 `gh.sync(_t)`;
## 착지 판정에서 landed 가 비었고 vy <= 0 이면 `landed = gh.land(x, y, ny, z)`; 서 있을 때 `on["kind"] == "ghost" and not gh.holds(on)` 이면 `on = {}; apex = y; fig.pose_request = "lurch"`
## (착지 뒤 `LurchPoses.done(fig)` 면 비운다); 서 있는 판이 `gh.fading(on)` 이면 `fig.pose_request = "teeter"`, 아니면 비운다.
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 자세는 stick3d_lurch.gd(+ 기존 teeter), 점검은 tools/probe_ghost.gd

const PACK := "res://data/climb/ghost.json"
const C = preload("res://scripts/games/climb.gd")

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.slab
var slabs: Array = []           # 지은 판 {id, x, y, w, kind "ghost", z, d, phase, node, mats, dot_mat, chime, was}
var t := 0.0                    # 박자 시계 — 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("slab", {})

func sync(now: float) -> void:
	t = now

## 농도를 그림에 — 몸통은 solidity 만큼, 점선 윤곽은 그 반대; 굳는 순간 종이 울린다
func _process(delta: float) -> void:
	t += delta
	slabs = slabs.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_updraft 와 같은 식)
	for sv in slabs:
		var s: Dictionary = sv
		var k := solidity(s)
		for mv in (s["mats"] as Array):
			var m: StandardMaterial3D = mv
			m.albedo_color = Color(m.albedo_color, k)
		var dm: StandardMaterial3D = s["dot_mat"]
		dm.albedo_color = Color(dm.albedo_color, 1.0 - k)
		var on := active(s)
		if on and not bool(s["was"]):
			var ch: AudioStreamPlayer3D = s["chime"]
			if ch.playing: ch.stop()
			ch.play()
		s["was"] = on

## 층 n 의 잇단 두 발판(종류 on) 사이 틈 중 가장 긴 것(모서리끼리 min_gap 이상)에 판 하나 — 틈 한가운데, 두 발판 높이의 중간, 양쪽에 margin 을 남긴 너비(w_max 까지). 같은 층은 늘 같은 답
func plan(n: int, plats: Array) -> Array:
	var out: Array = []
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var from := int(piece.get("from", 0)); var every := maxi(1, int(piece.get("every", 1)))
		if n < from or (n - from) % every != 0: continue
		var kinds: Array = piece.get("on", ["std"]); var min_gap := float(piece.get("min_gap", 60.0))
		var margin := float(kind.get("margin", 20.0)); var w_min := float(kind.get("w_min", 44.0)); var w_max := float(kind.get("w_max", 120.0))
		var hops := plats.filter(func(p: Dictionary) -> bool: return not (String(p["kind"]) in ["rest", "short", "ledge"]))   # 잇단 '뜀 발판'끼리만 — 얼음·이동 발판을 건너뛴 틈은 그 발판 위에 판을 놓게 된다
		var gaps: Array = []
		for i in range(1, hops.size()):
			var a: Dictionary = hops[i - 1]; var b: Dictionary = hops[i]   # a 가 아래 발판(band() 는 오르는 순서로 쌓는다)
			if not (String(a["kind"]) in kinds and String(b["kind"]) in kinds): continue
			var ax0 := float(a["x"]); var ax1 := ax0 + float(a["w"]); var bx0 := float(b["x"]); var bx1 := bx0 + float(b["w"])
			var gap := bx0 - ax1 if bx0 >= ax1 else ax0 - bx1
			if gap < min_gap: continue
			var mid := (ax1 + bx0) / 2.0 if bx0 >= ax1 else (bx1 + ax0) / 2.0
			var w := clampf(gap - 2.0 * margin, w_min, w_max)
			w = minf(w, gap - 16.0)   # 좁은 틈에선 양쪽 8px 은 남긴다
			var y := (float(a["y"]) + float(b["y"])) / 2.0
			if not _clear(plats, mid - w / 2.0, w, y): continue   # 지름길 판 따위와 겹치면 그 틈은 버린다
			gaps.append({ "gap": gap, "x": mid - w / 2.0, "y": y, "w": w, "z": float(a.get("z", 0.0)), "d": float(a.get("d", C.DEPTH_HALF * 2.0)) })
		gaps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["gap"]) > float(b["gap"]))
		for i in mini(int(piece.get("max", 1)), gaps.size()):
			var g: Dictionary = gaps[i]
			out.append({ "id": "%d.g%d" % [n, i], "x": float(g["x"]), "y": float(g["y"]), "w": float(g["w"]), "kind": "ghost", "z": float(g["z"]), "d": float(g["d"]), "phase": float(piece.get("phase", 0.0)) })
	return out

## 이 자리(x..x+w, 높이 y)가 다른 발판과 10px 안으로 겹치지 않나 — 지름길 판·얼음 발판 위에 유령 판이 포개지면 둘 다 못 읽는다
static func _clear(plats: Array, x: float, w: float, y: float) -> bool:
	for pv in plats:
		var p: Dictionary = pv
		var px0 := float(p["x"]) - 10.0; var px1 := float(p["x"]) + float(p["w"]) + 10.0
		if x + w > px0 and x < px1 and absf(y - float(p["y"])) < 40.0: return false
	return true

## 판을 짓는다 — root 는 그 층의 노드(층이 지워지면 같이 지워진다). 연보라 종이 판에 포도빛 윗테·앞테(보통 발판과 같은 세 상자, 투명 재질), 앞 윗모서리를 따라 점선 윤곽(유령일 때만), 종소리
func build(root: Node3D, planned: Array) -> void:
	var th := float(kind.get("thick", 18)) * C.K
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate()
		var w: float = float(s["w"]) * C.K; var dep: float = float(s["d"]) * C.K
		var node := Node3D.new(); node.position = C.to3(float(s["x"]) + float(s["w"]) / 2.0, float(s["y"]), float(s["z"]) * C.K); root.add_child(node)
		var mats: Array = []
		mats.append(_box(node, Vector3(w, th, dep), Vector3(0, -th / 2.0, 0), Color("ded4e2")))
		mats.append(_box(node, Vector3(w, 0.06, dep), Vector3(0, -0.03, 0), Color("ad7096")))   # 윗면 테두리
		mats.append(_box(node, Vector3(w, th, 0.06), Vector3(0, -th / 2.0, dep / 2.0), Color("7b526c")))   # 앞면 테두리 — 턱 끝이 또렷하게
		var dm := _mat(Color("7b526c"), true)
		var dots := maxi(2, int(kind.get("dots", 7)))
		for i in dots:
			_dot(node, dm, Vector3((float(i) / (dots - 1) - 0.5) * w, 0.0, dep / 2.0))
		for sx in [-0.5, 0.5]: _dot(node, dm, Vector3(sx * w, 0.0, -dep / 2.0))   # 뒤 두 귀
		var chime := AudioStreamPlayer3D.new(); chime.stream = _chime_wav(float(kind.get("chime_hz", 660))); chime.volume_db = -10.0; chime.unit_size = 6.0; chime.max_distance = 30.0; node.add_child(chime)
		s["node"] = node; s["mats"] = mats; s["dot_mat"] = dm; s["chime"] = chime; s["was"] = active(s)
		slabs.append(s)

## 박자 안의 자리 0..1 — 앞 solid 만큼이 단단하다(통풍구 팩의 active 와 같은 식)
func phase_of(s: Dictionary) -> float:
	return fposmod(t / float(kind.get("beat", 4.0)) + float(s["phase"]), 1.0)

func active(s: Dictionary) -> bool:
	return phase_of(s) < float(kind.get("solid", 0.5))

## 단단한 부분이 끝나기까지 남은 초(유령이면 0)
func left(s: Dictionary) -> float:
	return maxf(0.0, (float(kind.get("solid", 0.5)) - phase_of(s)) * float(kind.get("beat", 4.0)))

## 서 있는 몸이 경고를 받는 때 — 단단하지만 fade 초 안에 사라진다
func fading(s: Dictionary) -> bool:
	return active(s) and left(s) < float(kind.get("fade", 0.4))

## 그림 농도 0..1: 굳을 때 appear 초에 1 로, 끝 fade 초 동안 0 으로, 유령이면 0
func solidity(s: Dictionary) -> float:
	if not active(s): return 0.0
	var since := phase_of(s) * float(kind.get("beat", 4.0))
	return minf(clampf(since / float(kind.get("appear", 0.15)), 0.0, 1.0), clampf(left(s) / float(kind.get("fade", 0.4)), 0.0, 1.0))

## 로더의 착지 판정과 같은 규칙(HW·HZ) — 이 틱에 단단한 판의 윗면을 지나 떨어지는 몸만 받고 그 판(발판 모양 사전)을 돌려준다; 유령 판은 그냥 지나간다
func land(x: float, y: float, ny: float, z: float) -> Dictionary:
	var hw := C.HW
	for sv in slabs:
		var s: Dictionary = sv
		if not active(s): continue
		var sx := float(s["x"]); var sy := float(s["y"])
		if x + hw > sx and x - hw < sx + float(s["w"]) and y >= sy and ny <= sy and absf(z - float(s["z"])) < float(s["d"]) / 2.0 + C.HZ: return s
	return {}

## 서 있는 판이 아직 받쳐 주나 — 아니면 로더가 on 을 비우고 lurch 를 고른다
func holds(s: Dictionary) -> bool:
	return active(s)

func _mat(c: Color, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA   # 농도가 박자를 따라 오간다 — 호환 렌더러에서도 되는 알파
	if unshaded: m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else: m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, at: Vector3, c: Color) -> StandardMaterial3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = _mat(c); mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi.material_override

func _dot(parent: Node3D, m: StandardMaterial3D, at: Vector3) -> void:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.07, 0.07, 0.07); mi.mesh = bm; mi.material_override = m; mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

## 종소리 — 기음에 옅은 3배음, 0.25초 안에 잦아든다(한 번 재생, 반복 없음)
static func _chime_wav(hz: float) -> AudioStreamWAV:
	var rate := 22050; var count := int(rate * 0.25)
	var data := PackedByteArray(); data.resize(count * 2)
	for i in count:
		var k := float(i) / count
		var ph := float(i) * hz * TAU / rate
		var v := (sin(ph) * 0.6 + sin(ph * 3.0) * 0.1) * (1.0 - k) * (1.0 - k)
		data.encode_s16(i * 2, int(v * 24000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w
