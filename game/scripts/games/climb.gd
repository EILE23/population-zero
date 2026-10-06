extends Node3D
## Climb — 탑 안의 세상(운영자 2026-10-06: "탑을 오른다는 느낌보다는 탑 내부 세상에서 끝없는 정상을 향해 간다", "웹 Climb 처럼 점프를 잘 할 수 있어야").
## 마을의 Climb 탑 문으로 들어오면 탑 안: 끝이 없는 세로 세상. 옆에서 보는 2.5D(웹 Climb 과 같은 좌우·위) — 점프 거리를 눈으로 잴 수 있다.
## 물리·층 생성은 웹 Climb(site/src/lib/tower.ts)의 숫자 그대로(px 단위로 계산, 화면엔 K 배로): 점프킹 규칙(누르면 그 자리에서 힘을 모으고 놓으면 뛴다),
## 한쪽만 막힌 발판(아래에서 뚫고 올라가 위에 선다), 착지하면 멈춘다, 공중 조작, 벽 튕김, 높이서 떨어지면 찌부, 스프링·얼음·움직임·무너짐, 40층부터 바람.
## 같은 SEED 면 누구에게나 같은 탑(웹과 같은 영구 탑 규칙). 층은 가까운 것만 짓고 먼 층은 지운다 — 끝이 없다.
## 5층마다 쉼터(넓은 발판·등불·벤치·문): 쉼터 문(C)으로 나가면 다음엔 그 쉼터에서 이어 시작한다. 시작할 땐 문을 열고 걸어 나온다.
## 테마는 다섯 층마다 바뀐다 — 옛 홀 → 공중 정원 → 서고 → 태엽 → 바람 절벽 → 구름 바다 → 별밤 → (다시 처음, 색을 조금씩 바꿔 끝없이)

signal finished(result: Dictionary)

var best := 0.0
var start_camp := 0          # 마을이 넣어 준다(records.climb_camp) — 이 쉼터 층에서 시작
const K := 1.0 / 36.0        # px → m (졸라맨 44px ≈ 1.2m)
const WORLD_W := 960.0
const BAND_H := 600.0
const G := 2400.0
const WALK := 260.0
const RUN := 300.0
const AIR := 1500.0
const JUMP_V := 860.0
const JUMP_MIN := 430.0
const CHARGE := 0.7
const SPLAT := 330.0
const REST_EVERY := 5
const HOPS := 6
const SEED := 0x505a
const HW := 10.0
const DEPTH := 2.6           # 발판 깊이(m) — 옆에서 보이는 두께감
const THEMES := [
	["Old hall", Color("b8aea6"), Color("8a7f86"), Color("e3c46a")],
	["Hanging garden", Color("9cc86a"), Color("5f8a3e"), Color("f2b632")],
	["Library", Color("c9a07a"), Color("6b4a35"), Color("efe9e2")],
	["Clockwork", Color("c9c2bb"), Color("8a6a4a"), Color("e08a2a")],
	["Wind cliffs", Color("9a8f86"), Color("6e7a86"), Color("8fb8cc")],
	["Cloud sea", Color("f7f4ef"), Color("c9dde6"), Color("ad7096")],
	["Starlit", Color("7b6fa8"), Color("2f2a4e"), Color("f2c84b")],
]

var fig: Stick3D
var cam: Camera3D
var hud: Label
var banner: Label
var fade: ColorRect
var _banner_until := 0.0
var _bands := {}              # n -> {plats: Array, node: Node3D}
var _crumbled := {}           # id -> 무너진 시각
var _stand_since := {}        # id -> 밟기 시작한 시각(무너짐)
var _env: Environment
# 몸(웹 Body 와 같은 칸)
var x := WORLD_W / 2.0
var y := 0.0
var vx := 0.0
var vy := 0.0
var on: Dictionary = {}
var face := 1.0
var hurt := 0.0
var charge := 0.0
var apex := 0.0
var top := 0.0
var t0 := 0.0
var _t := 0.0
var _scene_until := 0.0      # 문 장면 동안 조작 잠금
var _scene_dx := 0.0
var _leaving := false
var _floor_shown := -1
var _door_of: Node3D = null

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

static func rng(seed: int) -> Callable:
	var st := [seed & 0xffffffff]
	return func() -> float:
		st[0] = (st[0] + 0x6d2b79f5) & 0xffffffff
		var t: int = st[0]
		t = _imul(t ^ (t >> 15), t | 1)
		t ^= (t + _imul(t ^ (t >> 7), t | 61)) & 0xffffffff
		return float((t ^ (t >> 14)) & 0xffffffff) / 4294967296.0

static func _imul(a: int, b: int) -> int:
	return (a * b) & 0xffffffff

func _mat(c: Color, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	if unshaded: m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else: m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, at: Vector3, c: Color, unshaded := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = _mat(c, unshaded); mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 그림자는 사람만 — 발판 그림자가 뒷벽을 덮어 어지러웠다
	parent.add_child(mi); return mi

static func to3(px: float, py: float, z := 0.0) -> Vector3:
	return Vector3((px - WORLD_W / 2.0) * K, py * K, z)

static func theme(n: int) -> Array:
	return THEMES[(n / REST_EVERY) % THEMES.size()]

# ── 층(웹 band() 그대로) ──
func band(n: int) -> Array:
	if _bands.has(n): return _bands[n]["plats"]
	var r := rng(SEED ^ _imul(n + 1, 2654435761))
	var out: Array = []
	var base := n * BAND_H
	if n == 0: out.append({ "id": "ground", "x": 0.0, "y": 0.0, "w": WORLD_W, "kind": "rest" })
	elif n % REST_EVERY == 0: out.append({ "id": "%dr" % n, "x": 180.0 + r.call() * 200.0, "y": base, "w": 400.0, "kind": "rest" })
	var prev_last: Dictionary = {}
	if n > 0:
		for p in band(n - 1):
			if p["kind"] != "rest" and p["kind"] != "short": prev_last = p
	var cx: float = prev_last["x"] + prev_last["w"] / 2.0 if not prev_last.is_empty() else WORLD_W / 2.0
	var side := -1.0 if cx > WORLD_W / 2.0 else 1.0
	var py: float = (prev_last["y"] if not prev_last.is_empty() else base) + 96.0 + r.call() * 28.0
	if n % REST_EVERY == 0 and n > 0: py = base + 96.0 + r.call() * 28.0
	var stretch := minf(1.0, n / 60.0)
	var spice := 0.0 if n < 2 else minf(0.45, 0.12 + n * 0.006)
	for i in HOPS:
		var w: float = 200.0 - stretch * 70.0 - r.call() * 40.0
		var dy: float = 92.0 + stretch * 20.0 + r.call() * 26.0
		var reach := RUN * ((JUMP_V + sqrt(JUMP_V * JUMP_V - 2.0 * G * dy)) / G) - 40.0
		var gap: float = minf(reach, 60.0 + stretch * 70.0 + r.call() * (reach - 60.0 - stretch * 70.0))
		var prev_half: float = (prev_last["w"] / 2.0 if not prev_last.is_empty() else 0.0) if i == 0 else out[out.size() - 1]["w"] / 2.0
		var nx: float = cx + side * (prev_half + gap + w / 2.0)
		if nx - w / 2.0 < 0.0 or nx + w / 2.0 > WORLD_W: side = -side; nx = cx + side * (prev_half + gap + w / 2.0)
		nx = clampf(nx, w / 2.0, WORLD_W - w / 2.0)
		cx = nx; side = -side if r.call() < 0.7 else side
		var kind := "std"
		if r.call() < spice:
			var k: float = r.call()
			kind = "spring" if k < 0.3 else ("ice" if k < 0.55 else ("move" if k < 0.8 else "crumble"))
		var p := { "id": "%d.%d" % [n, i], "x": nx - w / 2.0, "y": py, "w": w, "kind": kind }
		if kind == "move": p["amp"] = 60.0 + r.call() * 80.0; p["freq"] = 0.25 + r.call() * 0.3; p["phase"] = r.call() * 6.28
		out.append(p)
		py += dy
	if r.call() < 0.6:   # 지름길: 3번째에서 한 번에 5번째 높이로 — 작고 높고 멀다
		var p3: Dictionary = out[out.size() - 4]; var p5: Dictionary = out[out.size() - 2]
		var sx: float = p3["x"] + p3["w"] / 2.0 + (150.0 if p5["x"] + p5["w"] / 2.0 > p3["x"] + p3["w"] / 2.0 else -150.0)
		out.append({ "id": "%ds" % n, "x": clampf(sx - 30.0, 0.0, WORLD_W - 60.0), "y": p3["y"] + 148.0, "w": 60.0, "kind": "short" })
	_bands[n] = { "plats": out, "node": null }
	return out

func plat_x(p: Dictionary, t: float) -> float:
	return p["x"] + float(p.get("amp", 0.0)) * sin(float(p.get("freq", 0.3)) * t * 6.2832 + float(p.get("phase", 0.0))) if p["kind"] == "move" else p["x"]

func wind_of(n: int) -> float:
	if n < 40: return 0.0
	var r := rng(SEED ^ _imul(n + 555, 1597334677))
	var v: float = r.call()
	return 0.0 if v < 0.45 else (-1.0 if r.call() < 0.5 else 1.0) * (60.0 + minf(120.0, (n - 40) * 1.5) * r.call())

func around(py: float) -> Array:
	var n := maxi(0, floori(py / BAND_H))
	var out: Array = []
	for k in [n - 1, n, n + 1, n + 2]:
		if k >= 0: out.append_array(band(k))
	return out

# ── 장면 ──
func _ready() -> void:
	t0 = _now()
	var we := WorldEnvironment.new(); _env = Environment.new()
	_env.background_mode = Environment.BG_COLOR; _env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; _env.ambient_light_color = Color(0.95, 0.93, 0.9); _env.ambient_light_energy = 0.35
	_env.fog_enabled = false   # 안개가 색을 다 씻어 냈다
	we.environment = _env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, 25, 0); sun.light_energy = 0.75; sun.shadow_enabled = true; add_child(sun)
	fig = Stick3D.new(); add_child(fig)
	cam = Camera3D.new(); cam.fov = 50.0; add_child(cam); cam.current = true
	var ui := CanvasLayer.new(); add_child(ui)
	hud = Label.new(); hud.position = Vector2(14, 10); hud.add_theme_color_override("font_color", Color("1b0c15")); hud.add_theme_color_override("font_outline_color", Color("f7f4ef")); hud.add_theme_constant_override("outline_size", 6); ui.add_child(hud)
	banner = Label.new(); banner.position = Vector2(14, 64); banner.add_theme_font_size_override("font_size", 28); banner.add_theme_color_override("font_color", Color("7b526c")); banner.add_theme_color_override("font_outline_color", Color("f7f4ef")); banner.add_theme_constant_override("outline_size", 8); ui.add_child(banner)
	fade = ColorRect.new(); fade.color = Color(0, 0, 0, 1); fade.set_anchors_preset(Control.PRESET_FULL_RECT); fade.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.add_child(fade)
	# 시작: 그 쉼터(없으면 바닥)의 문 앞에서 문을 열고 걸어 나온다
	var n := start_camp if start_camp > 0 and start_camp % REST_EVERY == 0 else 0
	var rest: Dictionary = band(n)[0]
	x = rest["x"] + 70.0; y = rest["y"]; on = rest; apex = y; top = y
	_stream()
	_door_of = _bands[n]["door"]
	_door_scene(true)
	create_tween().tween_property(fade, "color:a", 0.0, 0.45)
	_say(("Floor %d" % n) if n > 0 else "The tower", 2.0)

## 문 장면 — 나올 땐 문이 열리고 오른쪽으로 걸어 나온다, 들어갈 땐 문으로 걸어가 열고 사라진다(화면이 어두워진다)
func _door_scene(out: bool) -> void:
	_scene_until = _now() + (0.9 if out else 0.8)
	_scene_dx = 120.0 if out else -90.0
	if _door_of:
		var leaf: Node3D = _door_of.get_node("leaf")
		var tw := create_tween(); tw.tween_property(leaf, "rotation:y", -1.6, 0.3)
		if out: tw.tween_interval(0.6); tw.tween_property(leaf, "rotation:y", 0.0, 0.35)

## 가까운 층만 짓고 먼 층은 지운다
func _stream() -> void:
	var n := maxi(0, floori(y / BAND_H))
	for k in range(n - 1, n + 3):
		if k < 0: continue
		band(k)
		if _bands[k]["node"] == null: _build_band(k)
	for k in _bands.keys():
		if (k < n - 2 or k > n + 4) and _bands[k]["node"] != null:
			(_bands[k]["node"] as Node3D).queue_free(); _bands[k]["node"] = null

## 한 층의 3D — 뒤 벽(탑 안쪽 벽: 아치·빛 드는 창·덩굴), 양옆 기둥, 발판(종류마다 모양), 쉼터(등불·벤치·문·층 표지)
func _build_band(n: int) -> void:
	var th := theme(n); var wall: Color = th[1]; var deep: Color = th[2]; var acc: Color = th[3]
	var tint := float((n / (REST_EVERY * THEMES.size())) % 4) * 0.06   # 한 바퀴 돌 때마다 조금 다른 색 — 끝없이 같은 테마로 안 보이게
	wall = wall.lerp(Color("ad7096"), tint); deep = deep.lerp(Color("2f2a4e"), tint)
	var root := Node3D.new(); root.name = "Band%d" % n; add_child(root); _bands[n]["node"] = root
	var y0 := n * BAND_H * K; var hgt := BAND_H * K; var halfw := WORLD_W * K / 2.0
	_box(root, Vector3(WORLD_W * K + 6.0, hgt, 0.6), Vector3(0, y0 + hgt / 2.0, -9.0), deep)   # 뒤 벽
	var r := rng(SEED ^ _imul(n + 77, 40503))
	for i in 3:   # 빛 드는 창 셋(아치) — 탑 바깥의 하늘이 비친다
		var wx: float = -halfw + 4.0 + i * (halfw - 4.0) + (r.call() - 0.5) * 3.0
		var wy: float = y0 + 4.0 + r.call() * (hgt - 8.0)
		_box(root, Vector3(1.6, 3.2, 0.1), Vector3(wx, wy, -8.65), Color("fff4d6"), true)
		_box(root, Vector3(1.9, 0.25, 0.3), Vector3(wx, wy + 1.7, -8.6), wall)   # 아치 머리
	if (n / REST_EVERY) % THEMES.size() == 6:   # 별밤: 뒷벽에 별
		for i in 24: _box(root, Vector3(0.08, 0.08, 0.02), Vector3(-halfw + r.call() * WORLD_W * K, y0 + r.call() * hgt, -8.65), Color("f7f4ef"), true)
	for i in 4:   # 덩굴·현수막(테마 색)
		var vx0: float = -halfw + r.call() * WORLD_W * K
		_box(root, Vector3(0.12, 2.5 + r.call() * 4.0, 0.1), Vector3(vx0, y0 + hgt - 2.0 - r.call() * 3.0, -8.6), acc.darkened(0.2))
	for s in [-1.0, 1.0]:   # 양옆 기둥(벽 튕김이 보인다)
		_box(root, Vector3(1.0, hgt, DEPTH + 2.0), Vector3(s * (halfw + 0.5), y0 + hgt / 2.0, -1.0), wall.darkened(0.1))
	for p in _bands[n]["plats"]: _build_plat(root, n, p, wall, acc)

func _build_plat(root: Node3D, n: int, p: Dictionary, wall: Color, acc: Color) -> void:
	var w: float = p["w"] * K
	var kind: String = p["kind"]
	var node := Node3D.new(); node.position = to3(p["x"] + p["w"] / 2.0, p["y"]); root.add_child(node); p["node"] = node
	var col := wall
	match kind:
		"ice": col = Color("cfe8f2")
		"crumble": col = Color("c9a07a")
		"move": col = Color("b48a5a")
		"spring": col = wall.darkened(0.15)
		"short": col = acc
	var th := 0.5 if kind != "rest" else 0.8
	_box(node, Vector3(w, th, DEPTH), Vector3(0, -th / 2.0, 0), col)
	_box(node, Vector3(w, 0.06, DEPTH), Vector3(0, -0.03, 0), col.lightened(0.25))   # 윗면 테두리
	if kind in ["std", "move", "ice"]: _decor(node, n, w)
	match kind:
		"crumble":
			for s in [-0.3, 0.25]: _box(node, Vector3(0.05, 0.02, DEPTH * 0.8), Vector3(s * w, 0.0, 0), Color("5a3d2b")).rotation.y = 0.4 * s
		"spring":
			var coil := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.28; cm.bottom_radius = 0.28; cm.height = 0.35; coil.mesh = cm; coil.material_override = _mat(Color("8a8a92")); coil.position = Vector3(0, 0.17, 0); node.add_child(coil)
			_box(node, Vector3(0.9, 0.1, 0.9), Vector3(0, 0.38, 0), Color("e8473c"))
		"rest":
			var lamp := OmniLight3D.new(); lamp.light_color = Color(1.0, 0.8, 0.5); lamp.light_energy = 1.0; lamp.omni_range = 6.0; lamp.position = Vector3(-w * 0.3, 1.6, 0.6); node.add_child(lamp)
			_box(node, Vector3(0.08, 1.4, 0.08), Vector3(-w * 0.3, 0.7, 0.6), Color("4a4a52"))
			_box(node, Vector3(0.25, 0.3, 0.25), Vector3(-w * 0.3, 1.5, 0.6), Color("f2c84b"), true)
			_box(node, Vector3(1.6, 0.12, 0.45), Vector3(w * 0.25, 0.45, -0.6), Color("8a6a4a"))   # 벤치
			for s in [-0.65, 0.65]: _box(node, Vector3(0.1, 0.45, 0.4), Vector3(w * 0.25 + s, 0.22, -0.6), Color("6b4a35"))
			# 문(나가는 곳) — 쉼터 왼쪽 안쪽, 경첩 문짝
			var door := Node3D.new(); door.position = Vector3(-w / 2.0 + 1.6, 0, -DEPTH / 2.0 + 0.1); node.add_child(door)
			_box(door, Vector3(1.4, 2.2, 0.2), Vector3(0, 1.1, -0.05), Color("3a2f36"))
			var hinge := Node3D.new(); hinge.name = "leaf"; hinge.position = Vector3(-0.55, 0, 0.08); door.add_child(hinge)
			_box(hinge, Vector3(1.1, 2.0, 0.08), Vector3(0.55, 1.0, 0), Color("8a6a4a"))
			_bands[n]["door"] = door
			var lb := Label3D.new(); lb.text = ("FLOOR %d\nC: leave here" % n) if n > 0 else "THE TOWER\nC: leave"
			lb.font_size = 64; lb.pixel_size = 0.005; lb.modulate = Color("1b0c15"); lb.outline_size = 10; lb.outline_modulate = Color("f7f4ef"); lb.position = Vector3(-w / 2.0 + 1.6, 2.8, -DEPTH / 2.0 + 0.2); node.add_child(lb)

# ── 한 틱(웹 step() 그대로, px) ──
func _physics_process(delta: float) -> void:
	var now := _now(); _t += delta
	var dt := minf(delta, 1.0 / 30.0)
	var locked := now < _scene_until or _leaving
	var dir := 0.0 if locked else Input.get_axis("move_left", "move_right")
	dir = signf(dir) if absf(dir) > 0.3 else 0.0
	var jump_held := not locked and Input.is_action_pressed("jump")
	if locked and now < _scene_until: dir = signf(_scene_dx)
	var was_air := on.is_empty()
	hurt = maxf(0.0, hurt - dt)
	if not on.is_empty():
		if hurt > 0.0: vx = 0.0
		elif jump_held:   # 한 줄 if 뒤에 elif 를 두면 안쪽 if 에 붙는다 — 그래서 누르는 동안 바로 뛰었다
			charge = minf(CHARGE, charge + dt); vx = 0.0
			if dir != 0.0: face = dir
		elif charge > 0.0:
			vy = JUMP_MIN + (JUMP_V - JUMP_MIN) * (charge / CHARGE)
			vx = dir * RUN; if dir != 0.0: face = dir
			on = {}; charge = 0.0; apex = y
		else:
			var target := dir * WALK * (0.55 if locked else 1.0)
			vx = vx + (target - vx) * minf(1.0, dt * 1.6) if on["kind"] == "ice" else target
			if dir != 0.0: face = dir
	if not on.is_empty() and on["kind"] == "move": x += plat_x(on, _t) - plat_x(on, _t - dt)
	if on.is_empty():
		vy -= G * dt; x += wind_of(floori(y / BAND_H)) * dt; apex = maxf(apex, y)
		if dir != 0.0 and hurt <= 0.0: vx = clampf(vx + dir * AIR * dt, -RUN, RUN); face = dir
	var ny := y + vy * dt
	x += vx * dt
	if x < HW:
		x = HW
		if on.is_empty(): vx = absf(vx) * 0.55
	elif x > WORLD_W - HW:
		x = WORLD_W - HW
		if on.is_empty(): vx = -absf(vx) * 0.55
	var landed: Dictionary = {}
	if vy <= 0.0:
		for p in around(y):
			if _crumbled.has(p["id"]): continue
			var px := plat_x(p, _t)
			if x + HW > px and x - HW < px + p["w"] and y >= p["y"] and ny <= p["y"]: landed = p; break
	if not landed.is_empty():
		y = landed["y"]; on = landed
		if landed["kind"] == "spring": vy = JUMP_V * 1.5; on = {}; apex = y; fig.squash = 1.0
		else:
			vy = 0.0
			if was_air:
				vx = 0.0; fig.squash = -0.6
				if apex - y > SPLAT: hurt = 1.1; _say("Splat.", 1.0)
				Jump3D.dust(self, to3(x, y), clampf((apex - y) / SPLAT, 0.2, 1.0))
			apex = y
	else:
		y = ny
		if not on.is_empty():
			var px := plat_x(on, _t)
			if x + HW <= px or x - HW >= px + on["w"] or _crumbled.has(on["id"]): on = {}; apex = y
	_crumble(now)
	top = maxf(top, y)
	_stream()
	_figure()
	_camera(delta)
	_hud(now)
	if not locked and Input.is_action_just_pressed("act") and not on.is_empty() and on["kind"] == "rest" and on.has("node"): _exit_here(on)
	if not _leaving and Input.is_action_just_pressed("ui_cancel"): _leave({})

## 무너지는 발판: 밟고 0.6초 흔들리다 사라지고 3초 뒤 돌아온다
func _crumble(now: float) -> void:
	if not on.is_empty() and on["kind"] == "crumble" and not _stand_since.has(on["id"]): _stand_since[on["id"]] = now
	for id in _stand_since.keys():
		var since: float = _stand_since[id]
		if now - since > 0.6 and not _crumbled.has(id): _crumbled[id] = now
	for id in _crumbled.keys():
		if now - float(_crumbled[id]) > 3.0: _crumbled.erase(id); _stand_since.erase(id)
	for p in around(y):
		if p["kind"] != "crumble" or not p.has("node") or not is_instance_valid(p["node"]): continue
		var nd: Node3D = p["node"]
		var base := to3(p["x"] + p["w"] / 2.0, p["y"])
		if _crumbled.has(p["id"]):
			var k := now - float(_crumbled[p["id"]])
			nd.position = base - Vector3(0, minf(k * 9.0, 12.0), 0); nd.visible = k < 1.2
		elif _stand_since.has(p["id"]): nd.position = base + Vector3(sin(now * 60.0) * 0.04, 0, 0); nd.visible = true
		else: nd.position = base; nd.visible = true
	for p in around(y):   # 움직이는 발판
		if p["kind"] == "move" and p.has("node") and is_instance_valid(p["node"]): (p["node"] as Node3D).position = to3(plat_x(p, _t) + p["w"] / 2.0, p["y"])

## 몸 — 웹 포즈(서기·달리기·모으기·뜀·떨어짐·찌부)를 Stick3D 로
func _figure() -> void:
	fig.position = to3(x, y)
	fig.face(PI / 2.0 if face > 0.0 else -PI / 2.0)
	fig.move_dir = Vector3(signf(vx), 0, 0) if absf(vx) > 20.0 and not on.is_empty() else Vector3.ZERO
	fig.speed = absf(vx) * K if not on.is_empty() else 0.0
	fig.airborne = on.is_empty(); fig.vertical = vy * K
	fig.crouch = charge / CHARGE * 0.9 if charge > 0.0 else 0.0
	fig.lying = hurt > 0.5

## 카메라 — 옆에서(웹처럼), 사람보다 조금 위를 보고 따라간다. 테마가 바뀌면 배경색도 천천히
func _camera(delta: float) -> void:
	var p := to3(x, y)
	var want := Vector3(clampf(p.x * 0.6, -6.0, 6.0), p.y + 2.6, 13.5)   # 가까이 — 사람이 작아 보였다
	cam.global_position = cam.global_position.lerp(want, minf(1.0, delta * 4.0)) if cam.global_position.length() > 0.1 else want
	cam.look_at(Vector3(cam.global_position.x * 0.7, cam.global_position.y - 1.2, 0), Vector3.UP)
	var n := floori(y / BAND_H)
	var th := theme(n)
	_env.background_color = _env.background_color.lerp((th[2] as Color).darkened(0.25), minf(1.0, delta * 1.5))   # 배경은 테마의 짙은 색
	_env.fog_light_color = _env.background_color

func _say(t: String, secs := 1.6) -> void:
	banner.text = t; _banner_until = _now() + secs

func _hud(now: float) -> void:
	var n := floori(y / BAND_H)
	var fl := n / REST_EVERY * REST_EVERY
	if fl != _floor_shown and n % REST_EVERY == 0 and n > 0: _floor_shown = fl; _say("Floor %d · %s" % [n, theme(n)[0]], 2.2)
	var m := y * K
	hud.text = "CLIMB   %d m   best %d m   floor %d   %s\n← → walk · hold SPACE to charge, release to jump · C at a door: leave here · Esc: leave" % [int(m), int(maxf(best, top * K)), n, _clock(now - t0)]
	if now > _banner_until and not _leaving: banner.text = ""

static func _clock(s: float) -> String:
	return "%d:%04.1f" % [int(s) / 60, fmod(s, 60.0)]

## 쉼터 문으로 나가기 — 문으로 걸어가 열고 들어가며 화면이 어두워진다. 다음엔 이 쉼터에서 시작
func _exit_here(rest: Dictionary) -> void:
	var n := floori(float(rest["y"]) / BAND_H)
	_door_of = _bands[n].get("door")
	_door_scene(false)
	_scene_dx = signf(float(rest["x"]) + 1.6 / K - x) * 90.0   # 문 쪽으로 걷는다(문은 쉼터 왼쪽 안)
	if absf(float(rest["x"]) + 1.6 / K - x) < 20.0: _scene_dx = 0.0
	_leaving = true
	_say("Leaving at floor %d." % n, 1.2)
	var tw := create_tween(); tw.tween_interval(0.5); tw.tween_property(fade, "color:a", 1.0, 0.4)
	tw.tween_callback(func() -> void: _leave({ "camp": n }))

func _leave(extra: Dictionary) -> void:
	set_physics_process(false)
	var res := { "score": top * K, "time": _now() - t0, "top": false }
	res.merge(extra)
	finished.emit(res)

## 테마 장식(발판마다 조금씩, 같은 시드로 늘 같게) — 정원: 풀·꽃, 서고: 책 줄, 태엽: 톱니, 바람: 깃발, 구름: 뭉게, 별밤: 등불. 옛 홀은 이끼 띠
func _decor(node: Node3D, n: int, w: float) -> void:
	var r := rng(SEED ^ _imul(int(node.position.x * 100.0) + n * 7919, 2246822519))
	var t := (n / REST_EVERY) % THEMES.size()
	var acc: Color = THEMES[t][3]
	match t:
		0:
			_box(node, Vector3(w * 0.9, 0.04, 0.3), Vector3(0, 0.0, DEPTH / 2.0 - 0.15), Color("7f9a5a"))
		1:
			for i in 5:
				var gx: float = (r.call() - 0.5) * w * 0.9
				_box(node, Vector3(0.08, 0.25 + r.call() * 0.2, 0.08), Vector3(gx, 0.12, (r.call() - 0.5) * DEPTH * 0.8), Color("6aa04c"))
				if r.call() < 0.5: _box(node, Vector3(0.14, 0.1, 0.14), Vector3(gx, 0.32, (r.call() - 0.5) * DEPTH * 0.6), [Color("ff6b8a"), acc, Color("f7f4ef")][i % 3], true)
		2:
			var bx: float = -w * 0.4
			while bx < w * 0.1:
				var bw: float = 0.08 + r.call() * 0.08; var bh: float = 0.25 + r.call() * 0.2
				_box(node, Vector3(bw, bh, 0.3), Vector3(bx, bh / 2.0, -DEPTH / 2.0 + 0.25), [Color("8a3b3b"), Color("3b5a8a"), Color("6b8a3b"), Color("c9a07a")][int(r.call() * 4.0)])
				bx += bw + 0.01
		3:
			var gear := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.45; cm.bottom_radius = 0.45; cm.height = 0.12; cm.radial_segments = 10
			gear.mesh = cm; gear.material_override = _mat(acc); gear.rotation.x = PI / 2.0; gear.position = Vector3((r.call() - 0.5) * w * 0.6, -0.55, DEPTH / 2.0 + 0.08); node.add_child(gear)
			gear.set_meta("spin", 0.8 + r.call())
		4:
			_box(node, Vector3(0.05, 1.2, 0.05), Vector3(w * 0.4, 0.6, -DEPTH / 2.0 + 0.2), Color("4a4a52"))
			_box(node, Vector3(0.5, 0.3, 0.02), Vector3(w * 0.4 + 0.27, 1.05, -DEPTH / 2.0 + 0.2), acc)
		5:
			for i in 3:
				var cl := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.5 + r.call() * 0.4; sm.height = sm.radius * 1.1; cl.mesh = sm; cl.material_override = _mat(Color("ffffff"), true)
				cl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				cl.position = Vector3((r.call() - 0.5) * w, -0.55, (r.call() - 0.5) * DEPTH); node.add_child(cl)
		6:
			_box(node, Vector3(0.05, 0.9, 0.05), Vector3(-w * 0.4, 0.45, 0.3), Color("4a4a52"))
			_box(node, Vector3(0.2, 0.22, 0.2), Vector3(-w * 0.4, 0.95, 0.3), acc, true)

func _process(delta: float) -> void:
	for b in _bands.values():   # 태엽 테마의 톱니가 돈다
		if b["node"] == null: continue
		for g in (b["node"] as Node3D).find_children("*", "MeshInstance3D", true, false):
			if g.has_meta("spin"): g.rotation.y += delta * float(g.get_meta("spin"))
