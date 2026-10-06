class_name TownPlots
extends TownCity
## 내가 짓는 집(운영자 2026-10-06: "집 짓는 것도 구현 안 돼 있고 집 자체도 네가 지은 것 같은데, 플레이어나 주민들이 다 직접 만들 수 있게") —
##   빈 필지 앞 "PLOT FOR SALE" 표지판(지은 마을 가장자리의 다음 필지 몇 개) → C: 집 모양을 고른다(오두막·타운하우스·방갈로·차고·날개채·탑·옥상 정원) → 값을 치르면 내 공사장
##   공사장 앞 C = 망치질 한 번 = 일 한 단위(건축가 주민과 같은 단위, 건축가도 와서 돕는다 — 같은 공사장 목록). 다 쌓이면 내 집(문패에 내 이름, 주민은 안 들어온다)
##   records["my_plots"]: {순번: {style, done}} — 계정 저장에 같이 간다(poz_net). records["done_extra"]: 순서를 건너 먼저 지어진 필지(다시 켜도 그 자리에)
## 건축가가 지을 필지는 순서대로, 산 필지는 건너뛴다(town_growth._open_sites)

const PLOT_PRICE := 30
const FOR_SALE := 6            # 한 번에 내놓는 필지 수
const STYLE_NAMES := { "cottage": "Cottage — fence and flowers", "townhouse": "Townhouse — narrow, two floors", "bungalow": "Bungalow — wide, low, a veranda",
	"garage": "House with a garage", "wing": "House with a back wing", "turret": "House with a corner turret", "terrace": "Flat roof with a roof garden" }

var _sale_nodes := {}          # 순번 -> 표지판 노드
var _pending_extra: Array = []
var _menu: CanvasLayer = null
var _menu_lot := -1

func _mine() -> Dictionary:
	if not records.has("my_plots"): records["my_plots"] = {}
	return records["my_plots"]

func _claimed(k: int) -> bool:
	return _mine().has(str(k)) or k in _pending_extra

func _is_mine(k: int) -> bool:
	return _mine().has(str(k))

func _style_for(l: Dictionary) -> String:
	var e: Variant = _mine().get(str(int(l["order"])))
	return String(e["style"]) if e is Dictionary else ""

## 성장 시작 — 건너 지은 필지·내 필지를 먼저 표시해 두고(그 자리에 공사장을 다시 열지 않게), 성장 엔진이 돈 뒤에 짓는다
func _growth_init() -> void:
	_pending_extra = (records.get("done_extra", []) as Array).map(func(v: Variant) -> int: return int(v))
	super()
	var lots := TownPlan.lots()
	for k in _pending_extra:
		if k < lots.size(): _finish_lot(lots[k], false)
	_pending_extra.clear()
	for key in _mine():
		var k := int(key); var e: Dictionary = _mine()[key]
		if k >= lots.size(): continue
		if e.get("done", false): _finish_lot(lots[k], false)
		else: _open_my_site(k)
	_refresh_sale()

## 순서를 건너 지어진 필지는 기록해 둔다
func _finish_lot(l: Dictionary, live: bool) -> void:
	var k := int(l["order"])
	var was := _done.has(k)
	super(l, live)
	if was: return
	spots = spots.filter(func(sp: Dictionary) -> bool: return not (sp["kind"] == "build" and int(sp.get("lot", -1)) == k))   # 다 지은 공사장 자리
	if _is_mine(k):
		(_mine()[str(k)] as Dictionary)["done"] = true
		var dr: Dictionary = doors[doors.size() - 1]
		var net: Variant = get_tree().root.get_node_or_null("PozNet")
		dr["owner"] = String(net.handle) if net and not net.guest else "you"; dr["mine"] = true
		if live: say_toast("Your house is finished. The door is yours.")
	if k >= built:
		var ex: Array = records.get("done_extra", [])
		if not k in ex: ex.append(k); records["done_extra"] = ex
	if live: _save_records(); _refresh_sale()

# ── 팔 필지 ──
func _refresh_sale() -> void:
	var lots := TownPlan.lots()
	var want: Array = []
	var k := built
	while want.size() < FOR_SALE and k < lots.size():
		if not _done.has(k) and not _claimed(k) and not _site_nodes.has(k) and CityMap.lot_kind(lots[k]) == "house": want.append(k)
		k += 1
	for old in _sale_nodes.keys():
		if not old in want:
			(_sale_nodes[old] as Node3D).queue_free(); _sale_nodes.erase(old)
			spots = spots.filter(func(sp: Dictionary) -> bool: return not (sp["kind"] == "sale" and int(sp["lot"]) == old))
	for nk in want:
		if _sale_nodes.has(nk): continue
		var l: Dictionary = lots[nk]
		var at := Vector3(l["c"].x + 1.6, 0, float(l["street_z"]) - TownPlan.PATH_W / 2.0 - 0.6)
		var keep := _build_parent; var n := Node3D.new(); _root_for(at).add_child(n); _build_parent = n
		_box(Vector3(0.08, 1.2, 0.08), at, _mat(Color("6b4a35")), false)
		_box(Vector3(0.9, 0.5, 0.05), at + Vector3(0, 0.95, 0), _mat(Color("f7f4ef")), false)
		var lb := Label3D.new(); lb.text = "PLOT FOR SALE\n%d coins" % PLOT_PRICE; lb.font_size = 40; lb.pixel_size = 0.004; lb.modulate = Color("ad7096"); lb.outline_size = 0
		lb.position = at + Vector3(0, 1.2, 0.04); _add(lb)
		_build_parent = keep
		_sale_nodes[nk] = n
		spots.append({ "pos": at + Vector3(0, 0, 0.7), "kind": "sale", "yaw": PI, "lot": nk })

func sale_use(sp: Dictionary, now: float) -> void:
	player.face(float(sp["yaw"])); action_until = now + 0.3
	_open_menu(int(sp["lot"]))

## 모양 고르기 — 단추 일곱, 값, 닫기. 메뉴가 열린 동안 몸은 멈춘다(typing)
func _open_menu(k: int) -> void:
	_menu_lot = k
	if _menu: _menu.queue_free()
	_menu = CanvasLayer.new(); _menu.layer = 35; add_child(_menu)
	var center := CenterContainer.new(); center.set_anchors_preset(Control.PRESET_FULL_RECT); _menu.add_child(center)
	var p := PanelContainer.new(); var sb := StyleBoxFlat.new(); sb.bg_color = Color("f7f4ef"); sb.border_color = Color("7b526c"); sb.set_border_width_all(2); sb.set_corner_radius_all(10); sb.set_content_margin_all(18)
	p.add_theme_stylebox_override("panel", sb); center.add_child(p)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 6); p.add_child(v)
	var t := Label.new(); t.text = "Build a house here — %d coins (you have %d)" % [PLOT_PRICE, coins]; t.add_theme_font_size_override("font_size", 20); t.add_theme_color_override("font_color", Color("1b0c15")); v.add_child(t)
	var hint := Label.new(); hint.text = "You build it yourself: hammer at the site with %s. Builders come and help." % GameMenu.key_of("act"); hint.add_theme_font_size_override("font_size", 13); hint.add_theme_color_override("font_color", Color("7b526c")); v.add_child(hint)
	for st in STYLE_NAMES:
		var b := Button.new(); b.text = STYLE_NAMES[st]; b.custom_minimum_size = Vector2(360, 34); b.disabled = coins < PLOT_PRICE
		b.pressed.connect(func() -> void: _buy(k, String(st))); v.add_child(b)
	var close := Button.new(); close.text = "Not now"; close.pressed.connect(_close_menu); v.add_child(close)
	set_meta("menu_open", true)

func _close_menu() -> void:
	if _menu: _menu.queue_free(); _menu = null
	set_meta("menu_open", false)

func _buy(k: int, style: String) -> void:
	_close_menu()
	if coins < PLOT_PRICE: say_toast("That's %d coins. Sell things, or win in a game." % PLOT_PRICE); return
	_set_coins(coins - PLOT_PRICE)
	_mine()[str(k)] = { "style": style, "done": false }
	_save_records()
	_open_my_site(k)
	_refresh_sale()
	say_toast("Bought. Now build it — hammer at the site.")

## 내 공사장 — 건축가 공사장과 같은 목록(_site_nodes)이라 건축가가 와서 돕는다. 이름표만 다르다
func _open_my_site(k: int) -> void:
	if _site_nodes.has(k): return
	var l: Dictionary = TownPlan.lots()[k]
	if gen.flat_limit < k + 1: gen.flat_limit = k + 1; gen.reflat(l["c"])
	_pave(l)
	_site_nodes[k] = Node3D.new(); _built_root.add_child(_site_nodes[k])
	_draw_site(k)

func _draw_site(k: int) -> void:
	super(k)
	if not _site_nodes.has(k): return
	if _is_mine(k):
		for ch in (_site_nodes[k] as Node3D).get_children():
			if ch is Label3D: (ch as Label3D).text = "Your house — %d%%" % int(100.0 * float(site_work.get(k, 0.0)) / (STAGE_WORK * 5.0)); (ch as Label3D).modulate = Color("ad7096")
	var sp: Dictionary = build_spot_of(k)   # 어느 공사장이든 사람도 거들 수 있다
	if not spots.has(sp): spots.append(sp)

func _open_sites() -> void:
	super()
	if is_inside_tree() and not _sale_nodes.is_empty(): _refresh_sale()   # 새 공사장 자리의 "팝니다" 판은 거둔다

# ── 목재소 — 건축가가 판자를 지고 간다(resident_build) ──
var _yard: Array = []
func lumber_spot(r: Node) -> Dictionary:
	if _yard.is_empty():
		var at := Vector3(-30, 0, -31)
		var keep := _build_parent; _build_parent = _root_for(at)
		for i in 4: _box(Vector3(2.4, 0.18, 0.5), at + Vector3(0, i * 0.18, (i % 2) * 0.2), _mat(Color("c9a27a")))
		for i in 3: _box(Vector3(2.4, 0.18, 0.5), at + Vector3(0, i * 0.18, 1.3), _mat(Color("b48a5a")))
		_signpost(at + Vector3(-2.0, 0, 0.6), "LUMBER YARD")
		_build_parent = keep
		for i in 3: _yard.append({ "pos": at + Vector3(-0.8 + i * 0.8, 0, 2.3), "kind": "lumber", "yaw": PI })
	for y in _yard:
		if r.call("_free_slot", y) >= 0: return y
	return {}

## 공사장 자리(build_spot 과 같은 것) — 사람도 C 로 쓴다
func build_spot_of(k: int) -> Dictionary:
	var n: Node3D = _site_nodes[k]
	var sp: Dictionary = n.get_meta("spot", {})
	if sp.is_empty():
		var l: Dictionary = TownPlan.lots()[k]
		var s: Vector3 = TownPlan.house_spec(l)["size"]
		sp = { "pos": TownPlan.spot_of(l) + Vector3(0, 0, s.z / 2.0 + 0.9), "kind": "build", "yaw": PI, "lot": k }
		n.set_meta("spot", sp)
	return sp

## 망치질 — 2.5초 hammer 자세, 끝나면 일 한 단위(건축가와 같은 build_work). 누구 공사장이든 도울 수 있다; 남의 집이면 품삯(money 1, town_wages), 제 집이면 없다
func site_use(sp: Dictionary, now: float) -> void:
	if not _site_nodes.has(int(sp["lot"])): return
	player.face(float(sp["yaw"])); player.pose_request = "hammer"; use_until = now + 2.5; action_until = now + 2.5
	var by: Variant = null if _is_mine(int(sp["lot"])) else "player"
	get_tree().create_timer(2.4).timeout.connect(func() -> void:
		if player.pose_request == "hammer": build_work(sp, by))
