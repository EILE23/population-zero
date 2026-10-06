class_name PozAccount
extends Node
## 데스크톱 클라이언트 로그인(운영자 2026-10-06: "유저가 클라이언트로 켰을 때 로그인 처리는?") — 게임엔 비밀번호를 치지 않는다(TV 앱식 기기 연결):
##   S → /api/game/link 에서 코드를 받아 브라우저로 population.town/link?code= 를 연다 → 웹에서 Connect → 3초마다 /api/game/link/poll → 세션 토큰
##   받은 토큰은 user://account.json 에 두고 다음부터는 켜자마자 그 계정(PozNet.signed_in). 저장 읽기가 401 이면 지우고 다시 S 안내(forget)
## 웹판은 이걸 쓰지 않는다 — /play 가 postMessage 로 토큰을 준다(PozNet._read_ticket)

const FILE := "user://account.json"
var net: PozNet
var status := ""            # "" | "linking"
var code := ""
var url := ""
var _device := ""
var _interval := 3.0
var _poll_at := -1.0
var _until := 0.0
var _kind := ""             # 지금 HTTP 가 무엇인지: start | poll
var _http: HTTPRequest

func _ready() -> void:
	_http = HTTPRequest.new(); _http.timeout = 15.0; add_child(_http)
	_http.request_completed.connect(_on_done)
	if FileAccess.file_exists(FILE):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE))
		if d is Dictionary and String(d.get("token", "")) != "": net.signed_in(String(d["token"]), String(d.get("handle", "")))

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## S — 연결 중이면 브라우저만 다시 연다
func sign_in() -> void:
	if not net.guest: return
	if status == "linking" and _now() < _until:
		OS.shell_open(url); return
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED: return
	_kind = "start"
	_http.request(PozNet.API + "/api/game/link", ["Content-Type: application/json"], HTTPClient.METHOD_POST, "{}")

func sign_out() -> void:
	forget()
	_say("Signed out on this computer.")

## 토큰을 버린다(로그아웃·만료) — 구경꾼으로
func forget() -> void:
	if FileAccess.file_exists(FILE): DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE))
	status = ""; code = ""
	net.signed_out()

func _process(_d: float) -> void:
	if status != "linking": return
	if _now() > _until:
		status = ""; code = ""; _say("The sign-in code expired. Press S for a new one."); return
	if _now() >= _poll_at and _http.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		_poll_at = _now() + _interval; _kind = "poll"
		_http.request(PozNet.API + "/api/game/link/poll", ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify({ "device": _device }))

func _on_done(_r: int, http_code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	var d: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (d is Dictionary): d = {}
	if _kind == "start":
		if http_code != 200:
			_say(String(d.get("message", "Could not reach population.town."))); return
		_device = String(d["device"]); code = String(d["code"]); url = String(d["url"])
		_interval = maxf(2.0, float(d.get("interval", 3))); _until = _now() + float(d.get("expires_in", 600)); _poll_at = _now() + _interval
		status = "linking"
		OS.shell_open(url)
		_say("Code %s — press Connect in your browser." % code)
	elif _kind == "poll" and status == "linking":
		if http_code == 410:
			status = ""; code = ""; _say("The sign-in code expired. Press S for a new one.")
		elif http_code == 200 and String(d.get("status", "")) == "ok":
			var u: Dictionary = d.get("user", {})
			var f := FileAccess.open(FILE, FileAccess.WRITE)
			if f: f.store_string(JSON.stringify({ "token": String(d["token"]), "handle": String(u.get("handle", "")) })); f.close()
			status = ""; code = ""
			net.signed_in(String(d["token"]), String(u.get("handle", "")))

func _say(t: String) -> void:
	if net.town and net.town.has_method("say_toast"): net.town.call("say_toast", t)
