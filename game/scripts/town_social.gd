class_name TownSocial
extends TownGrowth
## 사람끼리(운영자 2026-10-06: "게임이 시작하는 거니까 채팅 같은 것도", "진짜 상호작용", "단축키 명령어도 따로 볼 수 있는 곳") — 같은 방(poz_net)의 사람과:
##   채팅: ChatBox(chat_box.gd, 미니게임도 같은 부품) — Enter 로 쓰고 Esc 로 닫는다. 쓰는 동안 몸은 멈춘다(typing → town_player)
##   감정 표현: 1 손 흔들기 · 2 환호 · 3 꾸벅 · 4 춤 · 5 하늘 보고 눕기 — 자세 이름이 방의 pose 로 가서 남의 화면에서도 같은 자세(poz_net)
##   밀치기: 앞 1.3m 의 사람에게 X — 그 사람 화면에서 밀려난다(hitp), 누가 밀었는지 토스트
##   H: 조작법 창(KeyHelp) — 범례 줄엔 "H controls · Enter chat" 만

const EMOTES := { KEY_1: "wave", KEY_2: "cheer", KEY_3: "bow", KEY_4: "dance", KEY_5: "sky" }
const EMOTE_T := 2.6
const HELP := [
	["MOVE", "Arrows   (double-tap: dash)"],
	["JUMP", "SPACE   (hold: higher)"],
	["PUNCH", "X   again: jab > cross > hook > uppercut"],
	["KICK", "Z   again: front > push kick > roundhouse"],
	["MIX", "X after Z: backfist · Z after X: knee"],
	["IN THE AIR", "X hammer · Z flying kick"],
	["USE", "C   pick up, sit, doors, give, sell, game doors, cars"],
	["CARRY / THROW", "C on furniture · hold X while holding"],
	["CAR", "Up/Down drive · Left/Right steer · SPACE drift (boost) · C out"],
	["SOMEONE'S CAR", "C: ride along · X at the door: pull them out"],
	["CHAT", "Enter: type · Enter: send · Esc: close"],
	["EMOTES", "1 wave · 2 cheer · 3 bow · 4 dance · 5 lie down"],
	["PEOPLE", "X next to a player: shove"],
	["CAMERA", "mouse wheel or - / =   (zoom out over the town)"],
	["HELP", "H"],
]

var chat: ChatBox
var emote := ""               # 지금 하는 감정 표현(방으로 가는 자세 이름)
var emote_until := 0.0
var typing: bool:
	get: return chat != null and chat.busy()

func _social_init() -> void:
	var ui := get_node("UI") as CanvasLayer
	chat = ChatBox.new(); chat.me_node = body; ui.add_child(chat)
	var h := KeyHelp.new(); h.chat = chat; h.setup("CONTROLS — TOWN", HELP); ui.add_child(h)

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
	if EMOTES.has(k): _emote(String(EMOTES[k]))

func _emote(e: String) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if action_until >= now or not body.is_on_floor(): return   # 기술 중·공중엔 안 한다
	emote = e; emote_until = now + EMOTE_T
	if e in ["wave", "sky"]: player.pose_request = e; use_until = emote_until
	else: player.action = "fight"; player.move = e

## 매 물리 프레임(town_player 맨 앞) — 감정 표현 진행·끝(움직이거나 기술을 쓰면 끊긴다), X 밀치기
func _social_tick(now: float, dir: Vector3) -> void:
	if emote != "":
		var dance := emote in ["cheer", "bow", "dance"]
		if now > emote_until or dir != Vector3.ZERO or driving or (dance and player.move != emote):
			if dance and player.move == emote: player.action = ""; player.move = ""; player.action_t = 0.0
			if player.pose_request == emote: player.pose_request = ""
			emote = ""
		elif dance:
			player.action_t = fmod((now - (emote_until - EMOTE_T)) / (EMOTE_T if emote == "bow" else 0.65), 1.0)
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
