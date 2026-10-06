class_name TownSocial
extends TownCabin
## 사람끼리(운영자 2026-10-06: "게임이 시작하는 거니까 채팅 같은 것도", "진짜 상호작용", "단축키 명령어도 따로 볼 수 있는 곳") — 같은 방(poz_net)의 사람과:
##   채팅: ChatBox(chat_box.gd, 미니게임도 같은 부품) — Enter 로 쓰고 Esc 로 닫는다. 쓰는 동안 몸은 멈춘다(typing → town_player)
##   감정 표현: 1 손 흔들기 · 2 환호 · 3 꾸벅 · 4 춤 · 5 하늘 보고 눕기 — 자세 이름이 방의 pose 로 가서 남의 화면에서도 같은 자세(poz_net)
##   밀치기: 앞 1.3m 의 사람에게 X — 그 사람 화면에서 밀려난다(hitp), 누가 밀었는지 토스트
##   Esc: 게임 메뉴(game_menu — 조작·키 바꾸기·설정·계정), H: 조작 화면 바로. 화면 아래엔 시각·날씨만

const EMOTE_T := 2.6
## 되풀이 자세(이름 → 한 번의 초) — 감정 표현과 산스장(town_mountain). 남의 화면에서도 같은 박자(poz_net)
const LOOPS := { "cheer": 0.65, "bow": 2.6, "dance": 0.65, "pullup": 1.5, "situp": 1.7, "twist": 1.1, "squat": 1.6 }

var chat: ChatBox
var emote := ""               # 지금 하는 감정 표현(방으로 가는 자세 이름)
var emote_until := 0.0
var _emote_t0 := 0.0
var menu: GameMenu
var typing: bool:
	get: return (chat != null and chat.busy()) or (menu != null and menu.open)

var _who: Label   # 오른쪽 위 한 줄 — 버전 · 계정(또는 S 안내·연결 코드) · 업데이트

func _social_init() -> void:
	var ui := get_node("UI") as CanvasLayer
	_who = Label.new(); _who.set_anchors_preset(Control.PRESET_TOP_RIGHT); _who.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; _who.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_who.position = Vector2(-12, 8); _who.add_theme_color_override("font_color", Color("7b526c")); _who.add_theme_color_override("font_outline_color", Color("f7f4ef")); _who.add_theme_constant_override("outline_size", 6); _who.add_theme_font_size_override("font_size", 13)
	ui.add_child(_who)
	GameMenu.ensure_actions()   # 채팅·감정 표현·줌·H 도 바꿀 수 있는 행동(game_menu)
	chat = ChatBox.new(); chat.me_node = body; ui.add_child(chat)
	menu = GameMenu.new(); menu.town = self; add_child(menu)   # Esc 메뉴 — 조작(키 바꾸기)·설정·계정·나가기
	get_tree().create_timer(3.0).timeout.connect(func() -> void: say_toast("Esc: menu  ·  %s: controls" % GameMenu.key_of("controls")))

## 마을 방에 붙을 때마다(처음·미니게임에서 돌아옴) — 내 감정 표현을 pose 에 싣고, 밀침을 받는다
func _net_town() -> void:
	super()
	var base := net.pos_source
	net.pos_source = func() -> Dictionary:
		var d: Dictionary = base.call()
		if emote != "": d["pose"] = emote
		return d
	if not net.message.is_connected(_on_room): net.message.connect(_on_room)

func _unhandled_key_input(e: InputEvent) -> void:
	if not e.pressed or e.echo or typing or driving or game_node != null: return
	var k: int = (e as InputEventKey).keycode
	for n in 5:
		if e.is_action_pressed("emote_%d" % (n + 1)): _emote(["wave", "cheer", "bow", "dance", "sky"][n]); return
	if e.is_action_pressed("sign_in") and net and net.account:
		if (e as InputEventKey).shift_pressed: net.account.sign_out()
		else: net.account.sign_in()
	elif k == KEY_F9 and net and net.update: net.update.apply(true)
	elif k == KEY_U and net and net.update and net.update.status == "full": net.update.open_download()

func _emote(e: String, secs := EMOTE_T) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if action_until >= now or not body.is_on_floor(): return   # 기술 중·공중엔 안 한다
	emote = e; emote_until = now + secs; _emote_t0 = now
	if e in ["wave", "sky"]: player.pose_request = e; use_until = emote_until
	else: player.action = "fight"; player.move = e

## 매 물리 프레임(town_player 맨 앞) — 감정 표현 진행·끝(움직이거나 기술을 쓰면 끊긴다), X 밀치기
func _social_tick(now: float, dir: Vector3) -> void:
	_inner_tick(now, dir)   # 문 열고 들어가면 방(town_interior)
	_cabin_tick(now)   # 차 안 — 내 자리·계기판·시점·경적·전조등·라디오(town_cabin)
	if _who and int(now * 2.0) != int((now - 0.02) * 2.0): _who.text = _who_line()
	if emote != "":
		var dance := LOOPS.has(emote)
		if now > emote_until or dir != Vector3.ZERO or driving or (dance and player.move != emote):
			if dance and player.move == emote: player.action = ""; player.move = ""; player.action_t = 0.0
			if player.pose_request == emote: player.pose_request = ""
			emote = ""
		elif dance:
			player.action_t = fmod((now - _emote_t0) / float(LOOPS[emote]), 1.0)
	if not typing and not driving and Input.is_action_just_pressed("hit"): _shove_near()

## 밀치기 — 앞 1.3m 안의 사람. 내 주먹은 평소대로 나가고, 그 사람에겐 hitp 가 간다
func _shove_near() -> void:
	if net == null or net.guest: return
	var p := body.global_position; var f := fwd_dir()
	for id in net.others:
		var g: Variant = net.others[id].get("node")
		if not (g is Node3D) or not is_instance_valid(g): continue
		var to: Vector3 = (g as Node3D).global_position - p; to.y = 0.0
		if to.length() < 1.3 and f.dot(to.normalized()) > 0.3:
			net.send_ev({ "k": "hitp", "who": id, "dx": f.x, "dy": f.z })
			return

## 내가 밀렸다 — 민 쪽 방향으로 튕기고 움찔. 차 안·미니게임 중엔 무시
func _on_room(m: Dictionary) -> void:
	if String(m.get("t", "")) != "ev" or net == null or game_node != null or driving: return
	var ev: Dictionary = m.get("ev", {})
	if String(ev.get("k", "")) != "hitp" or int(ev.get("who", 0)) != net.me: return
	body.velocity += Vector3(clampf(float(ev.get("dx", 0.0)), -1.0, 1.0) * 5.0, 3.0, clampf(float(ev.get("dy", 0.0)), -1.0, 1.0) * 5.0)
	player.action = "flinch"; player.action_t = 0.0; action_until = Time.get_ticks_msec() / 1000.0 + FightPoses.FLINCH_T
	var by: Dictionary = net.others.get(int(m.get("uid", m.get("by", 0))), {})
	say_toast("%s shoved you." % String(by.get("handle", "Someone")))

func _who_line() -> String:
	var parts: Array[String] = ["v" + PozUpdate.version()]
	if net == null: pass
	elif net.account and net.account.status == "linking": parts.append("Code %s — press Connect in your browser (%s opens it again)" % [net.account.code, GameMenu.key_of("sign_in")])
	elif not net.guest: parts.append(net.handle + (" · %d here" % net.online() if net.online() > 1 else ""))
	elif net.account: parts.append("Guest — press S to sign in")
	else: parts.append("Guest")
	if net and net.update and net.update.line() != "": parts.append(net.update.line())
	return "  ·  ".join(parts)
