class_name PozNet
extends Node
## 웹 계정·멀티(운영자 2026-10-06: "웹에서 로그인하고 게임실행 버튼 누르면 접속하고 멀티도 되야하고") — 마을이 멈춰도(미니게임 안) 살아 있게 루트에 둔다.
## 1) 입장권: /play/poz 가 postMessage 로 건넨 세션 토큰을 웹 셸(export head_include)의 window.__poz 에서 읽는다(JavaScriptBridge). 토큰이 없으면 구경꾼.
## 2) 저장: /api/game/save(Bearer) — 처음에 받아 마을 기록(records·동전)에 덮고, 그 뒤 10초마다 바뀐 게 있으면 올린다. 서버에 아무것도 없으면 이 기기의 것을 올린다.
## 3) 방: wss://population.town/ws/poz/<town|climb|race>?t=토큰 — 사이트의 방 코드(위치·자세·채팅·hitp 중계)를 그대로 쓴다. 비로그인은 보기만.
##    방마다 좌표를 방 칸에 싣는 법은 보내는 쪽(마을·게임)이 정한다 — 여기선 받은 값을 넘겨주고(ghost_place), 이름표 달린 졸라맨(Stick3D)을 세운다.
## 위치는 10Hz, 끊기면 3초 뒤 다시 붙는다. 네트워크가 없거나 막혀도 게임은 혼자 계속 된다

const API := "https://population.town"
const WS := "wss://population.town/ws/poz/"
const SEND_EVERY := 0.1
const SAVE_EVERY := 10.0

signal message(m: Dictionary)        # 방에서 온 모든 메시지(ev·chat 등) — 게임이 골라 쓴다

var token := ""
var handle := ""
var me := 0
var guest := true
var town: Node = null                 # TownBase — 저장할 기록·동전
var room := ""
var ws: WebSocketPeer = null
var others := {}                      # uid -> {handle, x, y, z, pose, face, s, m, node}
var ghost_parent: Node3D = null       # 지금 방의 졸라맨을 세울 곳(마을 또는 게임)
var ghost_place: Callable             # func(o: Dictionary) -> Transform3D — 방 좌표를 3D 로
var pos_source: Callable              # func() -> Dictionary {x,y,z,pose,face,s,m} — 보낼 내 자리
var _t := 0.0
var _send_at := 0.0
var _save_at := 0.0
var _last_saved := ""
var _loaded := false
var _retry_at := -1.0
var _http: HTTPRequest

func _ready() -> void:
	name = "PozNet"
	_http = HTTPRequest.new(); add_child(_http)

func _process(delta: float) -> void:
	_t += delta
	if token == "" and guest: _read_ticket()
	if ws != null:
		ws.poll()
		var st := ws.get_ready_state()
		if st == WebSocketPeer.STATE_OPEN:
			while ws.get_available_packet_count() > 0: _on_packet(ws.get_packet().get_string_from_utf8())
			if not guest and pos_source.is_valid() and _t >= _send_at:
				_send_at = _t + SEND_EVERY
				var p: Dictionary = pos_source.call(); p["t"] = "pos"
				ws.send_text(JSON.stringify(p))
		elif st == WebSocketPeer.STATE_CLOSED:
			ws = null; _retry_at = _t + 3.0
	elif room != "" and _retry_at > 0.0 and _t >= _retry_at:
		_retry_at = -1.0; _open()
	_ghosts(delta)
	if _loaded and not guest and _t >= _save_at:
		_save_at = _t + SAVE_EVERY; _upload_if_changed()

## 입장권 읽기(웹만) — /play/poz 가 건넨 토큰, 또는 구경꾼 표시
func _read_ticket() -> void:
	if not OS.has_feature("web") or fmod(_t, 0.5) > 0.05: return
	var raw: Variant = JavaScriptBridge.eval("JSON.stringify(window.__poz || {})", true)
	if not (raw is String): return
	var d: Variant = JSON.parse_string(raw)
	if not (d is Dictionary): return
	if String(d.get("token", "")) != "":
		token = String(d["token"]); handle = String(d.get("handle", "")); guest = false
		_load_save()
		if room != "": join(room)   # 이미 구경꾼으로 들어가 있던 방에 내 이름으로 다시
	elif d.get("guest", false):
		guest = true; token = ""

## 방 바꾸기 — 마을(town)·Climb(climb)·레이싱(race). 졸라맨은 그 방 것으로 새로
func join(r: String) -> void:
	if ws != null: ws.close(); ws = null
	for k in others.keys(): _drop(k)
	room = r
	_open()

func leave() -> void:
	if ws != null: ws.close(); ws = null
	for k in others.keys(): _drop(k)
	room = ""

func _open() -> void:
	if room == "": return
	ws = WebSocketPeer.new()
	var url := WS + room + ("?t=" + token.uri_encode() if token != "" else "")
	if ws.connect_to_url(url) != OK: ws = null; _retry_at = _t + 5.0

func send_ev(ev: Dictionary) -> void:
	if ws != null and ws.get_ready_state() == WebSocketPeer.STATE_OPEN and not guest: ws.send_text(JSON.stringify({ "t": "ev", "ev": ev }))

func send_chat(body: String) -> void:
	if ws != null and ws.get_ready_state() == WebSocketPeer.STATE_OPEN and not guest: ws.send_text(JSON.stringify({ "t": "chat", "body": body }))

func online() -> int:
	return others.size() + (0 if guest else 1)

func _on_packet(raw: String) -> void:
	var m: Variant = JSON.parse_string(raw)
	if not (m is Dictionary): return
	match String(m.get("t", "")):
		"init":
			me = int(m.get("me", 0))
			for u in m.get("users", []): if int(u.get("uid", 0)) != me and String(u.get("status", "")) == "active": _upsert(u)
		"user":
			var u: Dictionary = m.get("u", {})
			if int(u.get("uid", 0)) != me: _upsert(u)
		"pos":
			if int(m.get("uid", 0)) != me: _upsert(m)
		"leave": _drop(int(m.get("uid", 0)))
	message.emit(m)

func _upsert(u: Dictionary) -> void:
	var id := int(u.get("uid", 0))
	if id == 0: return
	var o: Dictionary = others.get(id, { "handle": String(u.get("handle", "")), "node": null })
	for k in ["x", "y", "z", "pose", "face", "s", "m"]: if u.has(k): o[k] = u[k]
	if u.has("map"): o["m"] = u["map"]
	if u.has("stack"): o["s"] = u["stack"]
	if u.has("handle") and String(u["handle"]) != "": o["handle"] = String(u["handle"])
	others[id] = o

func _drop(id: int) -> void:
	if others.has(id):
		var n: Node = others[id].get("node")
		if n != null and is_instance_valid(n): n.queue_free()
		others.erase(id)

## 남의 졸라맨 — 받은 자리로 부드럽게 따라가고, 움직이면 걷는다. 이름표는 위에
func _ghosts(delta: float) -> void:
	if ghost_parent == null or not is_instance_valid(ghost_parent) or not ghost_place.is_valid(): return
	for id in others:
		var o: Dictionary = others[id]
		if String(o.get("m", room)) != "" and o.has("m") and String(o["m"]) != room and room != "": continue
		var g: Stick3D = o.get("node")
		if g == null or not is_instance_valid(g):
			g = Stick3D.new(); g.color = Color.from_hsv(fmod(id * 137.508, 360.0) / 360.0, 0.6, 0.55); g.head_color = g.color
			ghost_parent.add_child(g); o["node"] = g
			var lb := Label3D.new(); lb.text = String(o.get("handle", "")); lb.font_size = 44; lb.pixel_size = 0.002; lb.modulate = Color("7b526c"); lb.outline_size = 8; lb.outline_modulate = Color("f7f4ef")
			lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lb.no_depth_test = true; lb.position = Vector3(0, 1.4, 0); g.add_child(lb)
		var tf: Transform3D = ghost_place.call(o)
		var was := g.global_position
		g.global_position = was.lerp(tf.origin, minf(1.0, delta * 10.0))
		var mv := tf.origin - was; mv.y = 0.0
		g.move_dir = mv.normalized() if mv.length() > 0.02 else Vector3.ZERO; g.speed = mv.length() / maxf(delta, 0.001) if mv.length() > 0.02 else 0.0
		if g.move_dir == Vector3.ZERO: g.face(tf.basis.get_euler().y)
		var ps := String(o.get("pose", ""))
		g.airborne = ps in ["jump", "fall"]
		# 감정 표현(town_social) — 같은 자세로: 손 흔들기·눕기는 일과 자세, 환호·꾸벅·춤은 FightPoses 기술처럼 되풀이
		g.pose_request = ps if ps in ["wave", "sky"] else ""
		if ps in ["cheer", "bow", "dance"]: g.action = "fight"; g.move = ps; g.action_t = fmod(_t / (2.6 if ps == "bow" else 0.65), 1.0)
		elif g.action == "fight": g.action = ""; g.move = ""

# ── 저장 ──
func _load_save() -> void:
	if token == "": return
	_http.request_completed.connect(_on_loaded, CONNECT_ONE_SHOT)
	_http.request(API + "/api/game/save", ["Authorization: Bearer " + token])

func _on_loaded(_result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	_loaded = true
	if code != 200 or town == null: return
	var d: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (d is Dictionary): return
	var data: Variant = d.get("data")
	if data is Dictionary and (data as Dictionary).has("records"):
		town.records = data["records"]
		town.coins = int(town.records.get("coins", 0)); town.call("_set_coins", town.coins); town.call("_refresh_signs")
		_last_saved = JSON.stringify(_snapshot())
	else:
		_upload_if_changed()   # 서버가 비었다 — 이 기기의 것을 올린다
	if town.has_method("say_toast"): town.call("say_toast", "Signed in as %s." % handle)

func _snapshot() -> Dictionary:
	var r: Dictionary = (town.records as Dictionary).duplicate(true) if town else {}
	if town: r["coins"] = town.coins
	return { "records": r }

func _upload_if_changed() -> void:
	if token == "" or town == null or _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED: return
	var snap := JSON.stringify(_snapshot())
	if snap == _last_saved: return
	_last_saved = snap
	_http.request(API + "/api/game/save", ["Authorization: Bearer " + token, "Content-Type: application/json"], HTTPClient.METHOD_PUT, JSON.stringify({ "data": _snapshot() }))
