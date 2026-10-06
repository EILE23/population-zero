class_name PozUpdate
extends Node
## 클라이언트 자동 업데이트(운영자 2026-10-06: "다운로드 받은 뒤 자동 업데이트는?", "버전 관리는?") — 내보낸 Windows 판에서만 돈다.
## 버전: CI 가 빌드마다 res://version.txt 에 0.1.<빌드번호> 를 쓰고 GitHub Releases(client-v0.1.N)에 POZ-windows.zip·POZ.pck·version.json 을 올린다. 옛 버전도 Releases 에 남는다(되돌리기 = 그 릴리스를 latest 로).
## 켜면 releases/latest 의 version.json 을 보고, 빌드 번호가 크면 게임 데이터(POZ.pck)만 받아 exe 옆에 POZ.pck.new 로 둔다.
## 끌 때(또는 F9 지금 다시 켜기) PowerShell 이 게임이 닫히길 기다렸다가 새 pck 로 바꿔 끼운다(실행 중엔 pck 가 잠겨 있다).
## 엔진(exe)이 바뀐 릴리스면 pck 만으로는 안 된다 — 새로 받으라고 안내(U: 다운로드 페이지)

const LATEST := "https://github.com/EILE23/population-zero/releases/latest/download/version.json"
const PAGE := "https://population.town/"
const ENGINE := "4.3"

var status := ""          # "" | checking | downloading | ready | full | error
var latest := ""
var _http: HTTPRequest
var _new_pck := ""
var _kind := ""

static func version() -> String:
	return FileAccess.get_file_as_string("res://version.txt").strip_edges() if FileAccess.file_exists("res://version.txt") else "0.0.0-dev"

static func build_of(v: String) -> int:
	var p := v.split(".")
	return int(p[2]) if p.size() >= 3 and p[2].is_valid_int() else 0

static func enabled() -> bool:
	return OS.has_feature("template") and OS.get_name() == "Windows"

func _ready() -> void:
	get_tree().set_auto_accept_quit(false)   # 끌 때 바꿔 끼우기를 먼저
	_http = HTTPRequest.new(); _http.timeout = 600.0; add_child(_http)
	_http.request_completed.connect(_on_done)
	_new_pck = OS.get_executable_path().get_basename() + ".pck.new"
	status = "checking"; _kind = "check"
	_http.request(LATEST)

func _on_done(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		status = "error" if _kind == "pck" else ""; return
	if _kind == "check":
		var d: Variant = JSON.parse_string(body.get_string_from_utf8())
		if not (d is Dictionary): status = ""; return
		latest = String(d.get("version", ""))
		if build_of(latest) <= build_of(version()): status = ""; return
		if String(d.get("engine", ENGINE)) != ENGINE: status = "full"; return
		status = "downloading"; _kind = "pck"
		_http.download_file = _new_pck
		_http.request(String(d.get("pck_url", "")))
	elif _kind == "pck":
		status = "ready"
		_http.download_file = ""

## 한 줄 안내(마을 위 오른쪽) — 비면 안 보인다
func line() -> String:
	match status:
		"downloading": return "Downloading update %s…" % latest
		"ready": return "Update %s ready — F9 restart now, or it applies when you quit" % latest
		"full": return "A new POZ (%s) needs a fresh download — press U" % latest
		"error": return "Update download failed — it will try again next launch"
	return ""

func open_download() -> void:
	OS.shell_open(PAGE)

## 받아 둔 pck 로 바꿔 끼운다 — 게임이 닫힌 뒤에. relaunch 면 다시 켠다
func apply(relaunch: bool) -> void:
	if status != "ready" or not FileAccess.file_exists(_new_pck):
		get_tree().quit(); return
	var exe := OS.get_executable_path()
	var pck := exe.get_basename() + ".pck"
	var ps := "$p=%d; while (Get-Process -Id $p -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 300 }; Move-Item -Force -LiteralPath '%s' -Destination '%s'" % [OS.get_process_id(), _new_pck, pck]
	if relaunch: ps += "; Start-Process -FilePath '%s'" % exe
	OS.create_process("powershell.exe", ["-NoProfile", "-WindowStyle", "Hidden", "-Command", ps])
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		apply(false)
