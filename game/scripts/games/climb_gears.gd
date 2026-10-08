class_name ClimbGears
extends Node3D
## Climb 콘텐츠 팩 '톱니 컨베이어'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 태엽(Clockwork) 층의 std 발판 윗면에 깔린 띠 — 양 끝의 놋쇠 톱니가 돌며 강철 살이 흐른다. 띠 위에 선 몸은 speed 로 실려 간다(걷기 260 보다 느려 거슬러 걸으면 이긴다 — 발판이 덫이 되진 않는다):
## 힘을 모으는(점프 차지 0.7초) 동안 63px 끌려가고, 가만히 서면 1.2초 안에 턱 밖으로(탑이 원래 가진 평범한 추락, 새 부상은 없다). 띠는 run_s 동안 한쪽으로, stall_s 멈췄다가(톱니도 선다) 반대쪽으로 — 누구에게나 같은 시계(로더의 _t).
## 다시 돌기 시작할 때 쇠 clank — 뒤집혔다는 신호; 그 순간 선 몸은 jolt_s 동안 새 방향의 반대로 휘청(자세 tread 의 meta). 뜀을 띠가 가는 쪽으로 뛰면 boost 만큼 더 간다(로더가 원하면).
## 로더가 할 일(climb.gd, 운영자 세션): `var cg := ClimbGears.new(); add_child(cg)`; 층을 지을 때 `cg.build(root, cg.plan(n, plats))`; 매 틱 `cg.sync(_t)`;
## 'move' 발판의 드리프트를 더하는 자리에서 `elif cg.belt_of(on): x += cg.carry(on, dt, fig, dir); fig.pose_request = "tread"` (dir 은 좌우 입력 −1/0/1) — 턱 밖으로 나가면 로더의 기존 검사가 on 을 비운다(그때 자세도 비운다: `if on.is_empty() or cg.belt_of(on).is_empty(): 자세를 ""`);
## 뜀을 놓는 자리에서 원하면 `vx = dir * RUN + cg.boost(on)` (on 을 비우기 전에); 공중(on 이 빈 틱)이면 `var sh := cg.sweep(x, y, z); if not sh.is_empty(): vx = sh["vx"]; vy = sh["vy"]; hurt = 0.4; fig.squash = -0.4`. 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 자세는 stick3d_tread.gd, 점검은 tools/probe_gears.gd

const PACK := "res://data/climb/gears.json"
const C = preload("res://scripts/games/climb.gd")

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.belt
var belts: Array = []           # 지은 띠 {id, kind "gears", hop, x, y, w, z, d, phase, flip, len, node, gears, slats, clank, rode}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("belt", {})

func sync(now: float) -> void:
	t = now

func speed() -> float:
	return float(kind.get("speed", 90.0))

func run_s() -> float:
	return float(kind.get("run_s", 5.0))

func stall_s() -> float:
	return float(kind.get("stall_s", 0.6))

## 한 주기: 간다 → 선다 → 돌아온다 → 선다
func cycle() -> float:
	return 2.0 * (run_s() + stall_s())

## 띠의 방향 −1/0/+1 at 시각(+1 이면 +x 로 흐른다) — 주기 안의 자리로 읽는다, flip 이 시작 방향을 뒤집는다
func dir_at(s: Dictionary, at: float) -> float:
	var u := fposmod(at + float(s.get("phase", 0.0)), cycle())
	var d := 0.0
	if u < run_s(): d = 1.0
	elif u >= run_s() + stall_s() and u < 2.0 * run_s() + stall_s(): d = -1.0
	return d * float(s.get("flip", 1.0))

func dir(s: Dictionary) -> float:
	return dir_at(s, t)

## 지금 돌기 시작한 뒤 흐른 시간(초) — 멈춰 있으면 9 (자세의 휘청은 jolt_s 안에서만)
func started(s: Dictionary) -> float:
	var u := fposmod(t + float(s.get("phase", 0.0)), cycle())
	if u < run_s(): return u
	var back := u - (run_s() + stall_s())
	if back >= 0.0 and back < run_s(): return back
	return 9.0

## 띠가 흐른 거리(px, 부호 있음) at 시각 — 한 주기의 합은 0 이라 주기 안의 자리로만 센다(누구에게나 같은 그림, 누적 오차 없음)
func travel(s: Dictionary, at: float) -> float:
	var u := fposmod(at + float(s.get("phase", 0.0)), cycle())
	var fwd := minf(u, run_s())
	var back := clampf(u - (run_s() + stall_s()), 0.0, run_s())
	return float(s.get("flip", 1.0)) * speed() * (fwd - back)

## 층 n 의 테마 층(themes)에서 std 발판 윗면에 띠를 깐다 — 조각마다 'not' 층(상승기류 층)은 건너뛰고, 첫 std 발판은 평범하게 두고, min_w 이상인 것부터 max 개. 같은 층은 늘 같은 답
func plan(n: int, plats: Array) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var skip: Dictionary = piece.get("not", {})
		if not skip.is_empty() and n >= int(skip.get("from", 0)) and (n - int(skip.get("from", 0))) % maxi(1, int(skip.get("every", 1))) == 0: continue
		var kinds: Array = piece.get("on", ["std"]); var min_w := float(kind.get("min_w", 110.0))
		var hops := plats.filter(func(p: Dictionary) -> bool: return String(p["kind"]) in kinds)
		var k := 0; var cap := int(piece.get("max", 3))
		for i in range(1 if bool(piece.get("skip_first", true)) else 0, hops.size()):
			if k >= cap: break
			var p: Dictionary = hops[i]
			if float(p["w"]) < min_w: continue
			out.append({ "id": "%d.g%d" % [n, k], "kind": "gears", "hop": String(p["id"]), "x": float(p["x"]), "y": float(p["y"]), "w": float(p["w"]), "z": float(p.get("z", C.PLAYER_Z)), "d": float(p.get("d", C.DEPTH_HALF * 2.0)),
				"phase": k * float(piece.get("stagger", 0.31)) * cycle(), "flip": 1.0 if k % 2 == 0 else -1.0 })
			k += 1
	return out

## 이 발판(on)에 띠가 깔렸나 — 깔렸으면 그 띠, 아니면 빈 사전
func belt_of(on: Dictionary) -> Dictionary:
	var id := String(on.get("id", ""))
	for sv in belts:
		if String((sv as Dictionary)["hop"]) == id: return sv
	return {}

## 서 있는 매 틱 — 이 틱에 실려 가는 px. fig 가 있으면 자세의 메타를 적는다: tread_k 보는 쪽으로 실려 가는 정도(+ 앞), tread_w 걷기(−1 거슬러·0 서서·+1 같은 쪽), tread_j 돌기 시작한 뒤 흐른 초
func carry(on: Dictionary, dt: float, fig: Stick3D = null, walk := 0.0) -> float:
	var s := belt_of(on)
	if s.is_empty(): return 0.0
	var d := dir(s)
	if fig:
		var fw := 1.0 if sin(fig._yaw) >= 0.0 else -1.0   # +x 를 보면 sin 이 +
		fig.set_meta("tread_k", d * fw)
		fig.set_meta("tread_w", 0.0 if walk == 0.0 else (-1.0 if d != 0.0 and signf(walk) != d else 1.0))
		fig.set_meta("tread_j", started(s))
	s["rode"] = t
	return d * speed() * dt

## 띠에서 뛰면 띠가 가는 쪽으로 더 간다(px/s) — 띠가 없거나 서 있으면 0
func boost(on: Dictionary) -> float:
	var s := belt_of(on)
	return 0.0 if s.is_empty() else dir(s) * speed()

## 공중의 몸(x±HW, y..y+body_h)이 발판 옆에서 톱니(끝의 축 둘레 gear_r + bite)에 닿았나 — 닿았으면 띠가 가는 쪽(서 있으면 바깥쪽)·위로 미는 속도 {vx, vy}, 아니면 빈 사전.
## 발판 위 공간은 세지 않는다(x 가 턱 안이면 빈 사전) — 턱 끝에서 걸어 내려가거나 뛰는 몸, 아래서 뚫고 올라와 서는 몸의 평범한 결과가 그대로다; 옆에서 턱 끝을 스치는 몸만(끝 밖 bite + HW 안) 물린다
func sweep(x: float, y: float, z: float) -> Dictionary:
	var bh := float(kind.get("body_h", 40.0)); var r := float(kind.get("gear_r", 14.0)) + float(kind.get("bite", 4.0))
	for sv in belts:
		var s: Dictionary = sv
		if absf(z - float(s["z"])) >= float(s["d"]) / 2.0 + C.HZ: continue
		var x0 := float(s["x"]); var x1 := x0 + float(s["w"])
		if x >= x0 and x <= x1: continue
		var gx := x0 + float(kind.get("inset", 10.0)) if x < x0 else x1 - float(kind.get("inset", 10.0))
		var gy := float(s["y"]) - 3.0
		var cx := clampf(gx, x - C.HW, x + C.HW); var cy := clampf(gy, y, y + bh)   # 상자에서 축에 가장 가까운 점
		if (cx - gx) * (cx - gx) + (cy - gy) * (cy - gy) > r * r: continue
		var d := dir(s)
		var side := d if d != 0.0 else (-1.0 if x < x0 else 1.0)
		return { "vx": side * float(kind.get("shove_vx", 200.0)), "vy": float(kind.get("shove_vy", 220.0)) }
	return {}

## 톱니를 돌리고 살을 흘린다(빈 띠도 돈다 — 태엽이니까); 돌기 시작하는 틱에 clank
func _process(delta: float) -> void:
	t += delta
	belts = belts.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_windmill 과 같은 식)
	for sv in belts:
		var s: Dictionary = sv
		_roll(s)
		if dir_at(s, t) != 0.0 and dir_at(s, t - delta) == 0.0:
			var ck: AudioStreamPlayer3D = s["clank"]
			if ck.playing: ck.stop()
			ck.play()

## 띠를 짓는다 — root 는 그 층의 노드. 노드 원점은 발판 윗면 가운데(발판 노드와 같은 자리); 고무 띠 + 흐르는 강철 살 + 앞면의 놋쇠 톱니 둘 + clank
func build(root: Node3D, planned: Array) -> void:
	var th := float(kind.get("thick", 3.0)) * C.K; var pitch := float(kind.get("pitch", 16.0)) * C.K; var sw := float(kind.get("slat", 6.0)) * C.K
	var gr := float(kind.get("gear_r", 14.0)) * C.K
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate()
		var len := (float(s["w"]) - 2.0 * float(kind.get("inset", 10.0))) * C.K
		var dep := float(s["d"]) * C.K
		var node := Node3D.new(); node.position = C.to3(float(s["x"]) + float(s["w"]) / 2.0, float(s["y"]), float(s["z"]) * C.K); root.add_child(node)
		var rubber := _mat(Color("3a3330")); var steel := _mat(Color("a89f94")); var brass := _mat(Color("e08a2a")); var ink := _mat(Color("2f2a4e"))
		_box(node, Vector3(len, th, dep * 0.72), rubber).position = Vector3(0, th / 2.0, 0)
		var slats: Array = []
		for _i in int(len / pitch):
			slats.append(_box(node, Vector3(sw, th * 1.5, dep * 0.72), steel))
		var gears: Array = []
		for e in [-1.0, 1.0]:
			var ex: float = e
			var g := Node3D.new(); g.position = Vector3(ex * len / 2.0, -0.08, dep / 2.0 + 0.05); node.add_child(g)   # 축은 앞면 밖, 윗면보다 조금 아래 — 이가 띠 위로 솟는다
			var disc := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = gr; cm.bottom_radius = gr; cm.height = 0.06; cm.radial_segments = 12; disc.mesh = cm
			disc.material_override = brass; disc.rotation.x = PI / 2.0; disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; g.add_child(disc)
			for i in int(kind.get("teeth", 8)):
				var a := i * TAU / float(kind.get("teeth", 8))
				var tooth := _box(g, Vector3(0.1, 0.11, 0.06), brass)
				tooth.position = Vector3(cos(a) * (gr + 0.04), sin(a) * (gr + 0.04), 0); tooth.rotation.z = a
			_box(g, Vector3(0.06, 0.06, 0.07), ink)   # 축 머리
			gears.append(g)
		var clank := AudioStreamPlayer3D.new(); clank.stream = _clank_wav(float(kind.get("clank_hz", 140))); clank.volume_db = -8.0; clank.unit_size = 6.0; clank.max_distance = 30.0; node.add_child(clank)
		s["len"] = len; s["node"] = node; s["gears"] = gears; s["slats"] = slats; s["clank"] = clank; s["rode"] = -9.0
		belts.append(s)
		_roll(s)

## 살을 흐른 만큼 옮기고(띠 길이로 감는다) 톱니를 돌린다 — 윗면이 +x 로 가면 톱니는 시계 방향(−z)
func _roll(s: Dictionary) -> void:
	var len := float(s["len"]); var tr := travel(s, t) * C.K
	var pitch := float(kind.get("pitch", 16.0)) * C.K; var th := float(kind.get("thick", 3.0)) * C.K
	var slats: Array = s["slats"]
	for i in slats.size():
		(slats[i] as Node3D).position = Vector3(-len / 2.0 + fposmod(tr + i * pitch, len), th * 0.75, 0)
	for gv in (s["gears"] as Array):
		(gv as Node3D).rotation.z = -tr / (float(kind.get("gear_r", 14.0)) * C.K)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

## 쇠 clank — 0.16초, 낮은 기음에 쇳소리 배음 둘이 빠르게 잦아든다(한 번 재생, 반복 없음)
static func _clank_wav(hz: float) -> AudioStreamWAV:
	var rate := 22050; var count := int(rate * 0.16)
	var data := PackedByteArray(); data.resize(count * 2)
	for i in count:
		var k := float(i) / count
		var ph := float(i) * hz * TAU / rate
		var v := (sin(ph) * 0.45 + sin(ph * 3.1) * 0.3 + sin(ph * 5.7) * 0.15) * exp(-k * 6.0)
		data.encode_s16(i * 2, int(v * 22000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w
