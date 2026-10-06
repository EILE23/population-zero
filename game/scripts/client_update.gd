class_name PozUpdate
extends Node
## 클라이언트 자동 업데이트(운영자 2026-10-06: "다운로드 받은 뒤 자동 업데이트는?", "버전 관리는?") — 내보낸 Windows 판에서만 돈다.
## 버전: CI 가 빌드마다 res://version.txt 에 0.1.<빌드번호> 를 쓰고 GitHub Releases(client-v0.1.N)에 POZ-windows.zip·POZ.pck·version.json 을 올린다. 옛 버전도 Releases 에 남는다(되돌리기 = 그 릴리스를 latest 로).
## 켜면 releases/latest 의 version.json 을 보고, 빌드 번호가 크면 게임 데이터(POZ.pck)만 받아 exe 옆에 POZ.pck.new 로 둔다.
## 다른 게임 런처처럼(운영자 2026-10-06): 켤 때 새 버전이 있으면 "Updating…" 화면(진행 막대)을 띄우고 받은 뒤 저절로 다시 켠다 — PowerShell 이 게임이 닫히길 기다렸다가 새 pck 로 바꿔 끼우고 다시 실행한다(실행 중엔 pck 가 잠겨 있다).
## 엔진(exe)이 바뀐 릴리스면 설치 파일(POZ-Setup.exe)을 받아 조용히 돌리고 끈다 — 설치 파일이 같은 자리에 덮어 깔고 다시 켠다. 인터넷이 없으면 그냥 지금 버전으로

const LATEST := "https://github.com/EILE23/population-zero/releases/latest/download/version.json"
const PAGE := "https://population.town/"
const ENGINE := "4.3"

var status := ""          # "" | checking | downloading | ready | full | error
var latest := ""
var _http: HTTPRequest
var _new_pck := ""
var _kind := ""
var _setup_url := ""
var _ui: CanvasLayer = null
var _bar: ProgressBar = null
var _msg: Label = null

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
		status = "error" if _kind != "check" else ""
		if _ui: _ui.queue_free(); _ui = null   # 못 받았다 — 지금 버전으로 그냥 논다
		return
	if _kind == "check":
		var d: Variant = JSON.parse_string(body.get_string_from_utf8())
		if not (d is Dictionary): status = ""; return
		latest = String(d.get("version", ""))
		if build_of(latest) <= build_of(version()): status = ""; return
		_setup_url = String(d.get("setup_url", ""))
		_show("Updating POZ to %s…" % latest)
		if String(d.get("engine", ENGINE)) != ENGINE and _setup_url != "":   # 엔진이 바뀌었다 — 설치 파일로
			status = "downloading"; _kind = "setup"
			_http.download_file = OS.get_user_data_dir().path_join("POZ-Setup.exe")
			_http.request(_setup_url); return
		status = "downloading"; _kind = "pck"
		_http.download_file = _new_pck
		_http.request(String(d.get("pck_url", "")))
	elif _kind == "pck":
		status = "ready"
		_http.download_file = ""
		_msg.text = "Updated. Starting POZ %s…" % latest
		get_tree().create_timer(0.6).timeout.connect(func() -> void: apply(true))   # 바로 새 버전으로 다시 켠다
	elif _kind == "setup":
		_msg.text = "Installing POZ %s…" % latest
		OS.create_process(OS.get_user_data_dir().path_join("POZ-Setup.exe"), ["/SILENT", "/SUPPRESSMSGBOXES", "/NORESTART"])
		get_tree().create_timer(0.8).timeout.connect(func() -> void: get_tree().quit())

## 한 줄 안내(마을 위 오른쪽) — 비면 안 보인다
func line() -> String:
	match status:
		"downloading": return "Downloading update %s…" % latest
		"ready": return "Update %s ready — F9 restart now, or it applies when you quit" % latest
		"full": return "A new POZ (%s) needs a fresh download — press U" % latest
		"error": return "Update download failed — it will try again next launch"
	return ""

## 업데이트 화면 — 게임 위를 덮는다(받는 동안 놀지 않게), 진행 막대
func _show(text: String) -> void:
	if _ui: _msg.text = text; return
	_ui = CanvasLayer.new(); _ui.layer = 90; add_child(_ui)
	var bg := ColorRect.new(); bg.color = Color("f7f4ef"); bg.set_anchors_preset(Control.PRESET_FULL_RECT); _ui.add_child(bg)
	var c := CenterContainer.new(); c.set_anchors_preset(Control.PRESET_FULL_RECT); _ui.add_child(c)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 14); c.add_child(v)
	var logo := Label.new(); logo.text = "poz"; logo.add_theme_font_size_override("font_size", 48); logo.add_theme_color_override("font_color", Color("1b0c15")); logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(logo)
	_msg = Label.new(); _msg.text = text; _msg.add_theme_font_size_override("font_size", 18); _msg.add_theme_color_override("font_color", Color("7b526c")); _msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(_msg)
	_bar = ProgressBar.new(); _bar.custom_minimum_size = Vector2(420, 18); _bar.max_value = 1.0; _bar.show_percentage = false; v.add_child(_bar)

func _process(_d: float) -> void:
	if _bar and status == "downloading":
		var total := _http.get_body_size()
		_bar.value = float(_http.get_downloaded_bytes()) / float(total) if total > 0 else 0.0

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
