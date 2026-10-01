class_name ResidentMind
extends RefCounted
## 주민의 자아(운영자 2026-09-30: "주민들도 나와같은 사고방식 등등 각개의 자아가 존재해야해") — 성격·욕구·기분·기억·관계·말투.
## LLM 은 없다(운영비 0 규칙): 성격·말투는 data/minds.json(없으면 이름 해시), 욕구는 시간이 깎고 자리가 채운다, 기억은 user://minds.json 에 남아 다음 판에도 이어진다.
## 결정은 효용 점수의 가중 무작위 — 같은 성격이라도 매번 같은 걸 고르진 않는다(주민은 자유다). 몸이 하는 일은 resident*.gd, 여기는 '왜'만

const SAVE := "user://minds.json"
const REST := ["bed", "chair", "bench", "grass"]
const FUN := ["swing", "seesaw", "boat", "lookout", "tree", "grass"]
const SOCIAL := ["bench", "counter", "door"]

static var _data: Dictionary = {}
static var _saved: Dictionary = {}
static var _loaded := false
static var _saved_at := 0.0

var r: ResidentBase
# 성격 0..1
var social := 0.5
var temper := 0.5
var curious := 0.5
var lazy := 0.5
var brave := 0.5
var likes: Array = []
var topics: Array = []
var rel: Dictionary = {}       # handle -> "friend" | "rival"
var voice: Dictionary = {}
var likes_rain := false
# 욕구 0..1 (1 = 채워짐) — 시작값은 사람마다 조금씩 다르다
var energy := 1.0
var full := 0.7
var company := 0.6
var fun := 0.6
var mood := 0.3
# 플레이어에 대한 기억
var fond := 0.0                # -1 미움 .. 1 좋아함
var met := 0                   # 인사를 나눈 횟수
var hurt := 0                  # 맞은 횟수(누적, 판을 넘어 남는다)
var last_hurt := -999.0
var last_greet := -999.0
var spoke_at := -999.0         # 알아보고 먼저 말 건 시각
var notice_at := 0.0
var friends: Dictionary = {}   # 다른 주민 uid -> -1..1 (수다·소문이 움직인다)
var recent: Array = []         # 최근 간 자리 종류 넷 — 호기심 많은 사람은 새 데를 원한다
var reason := ""               # 방금 고른 이유(욕구 이름) — 혼잣말로 나온다

static func _load() -> void:
	if _loaded: return
	_loaded = true
	var f := FileAccess.open("res://data/minds.json", FileAccess.READ)
	if f: _data = JSON.parse_string(f.get_as_text())
	if FileAccess.file_exists(SAVE):
		var g := FileAccess.open(SAVE, FileAccess.READ)
		var s: Variant = JSON.parse_string(g.get_as_text())
		if s is Dictionary: _saved = s

func _init(res: ResidentBase) -> void:
	r = res; _load()
	var p: Dictionary = (_data.get("people", {}) as Dictionary).get(res.handle, {})
	var t: Array = p.get("t", [])
	var hs: int = absi(res.handle.hash())
	if t.size() == 5:
		social = t[0]; temper = t[1]; curious = t[2]; lazy = t[3]; brave = t[4]
	else:
		# 명부에만 있는 사람: 이름에서 뽑는다(같은 이름은 언제나 같은 성격)
		social = float(hs % 97) / 96.0; temper = float((hs / 97) % 89) / 88.0; curious = float((hs / 8633) % 83) / 82.0
		lazy = float((hs / 716539) % 79) / 78.0; brave = float((hs / 7) % 73) / 72.0
		var all := ["bench", "grass", "lamp", "tree", "lookout", "swing", "counter", "bank", "shelf", "seesaw"]
		likes = [all[hs % all.size()], all[(hs / 11) % all.size()]]
	likes = p.get("likes", likes); topics = p.get("topics", []); rel = p.get("rel", {})
	var lines: Dictionary = p.get("lines", {})
	likes_rain = lines.has("rain_like")
	voice = (_data.get("default", {}) as Dictionary).duplicate()
	for k in lines: voice[k] = lines[k]
	if topics.is_empty(): topics = voice.get("topics", ["Hm."])
	energy = 0.7 + 0.3 * float(hs % 10) / 9.0; full = 0.4 + 0.5 * float((hs / 10) % 10) / 9.0; fun = 0.3 + 0.5 * curious
	var m: Dictionary = _saved.get(str(res.uid), {})
	fond = float(m.get("fond", 0.0)); met = int(m.get("met", 0)); hurt = int(m.get("hurt", 0))
	var fr: Dictionary = m.get("friends", {})
	for k in fr: friends[int(k)] = float(fr[k])

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## 말투 — 이 사람의 목소리에서 한 줄
func line(cat: String) -> String:
	var arr: Array = voice.get(cat, ["Hm."])
	return String(arr[randi() % arr.size()])

func topic() -> String:
	return String(topics[randi() % topics.size()])

## 매 프레임: 욕구가 닳고 쉬는 자리·노는 자리·수다가 채운다. 기분은 욕구·날씨·맞은 기억이 정한다. 미움도 호감도 아주 천천히 옅어진다(반감기 약 20분)
func tick(delta: float) -> void:
	var now := _now()
	var k: String = r.spot.get("kind", "") if r.state == "busy" else ""
	var night: bool = r.town.is_night()
	var drain := (0.0025 + 0.003 * lazy) * (1.7 if night else 1.0)
	energy = clampf(energy + delta * (0.02 if k == "bed" else (0.008 if k in REST else -drain)), 0.0, 1.0)
	full = clampf(full - delta * 0.0022, 0.0, 1.0)
	fun = clampf(fun + delta * (0.012 if k in FUN else -0.0025 * (0.5 + curious)), 0.0, 1.0)
	company = clampf(company + delta * (0.03 if r.fig.pose_request == "talk" else -0.003 * (0.3 + social)), 0.0, 1.0)
	var wet: bool = r.weather == "rain" and not r.has_umb and not likes_rain
	var want := 0.2 + 0.35 * (energy - 0.5) + 0.35 * (full - 0.5) + 0.3 * (company - 0.5) + 0.3 * (fun - 0.5) - (0.25 if wet else 0.0) - (0.6 if now - last_hurt < 30.0 else 0.0)
	mood = lerpf(mood, clampf(want, -1.0, 1.0), minf(1.0, delta * 0.3))
	fond = lerpf(fond, 0.0, minf(1.0, delta * 0.0006))

## 자리 고르기 — 좋아하는 곳, 일과, 모자란 욕구, 친구가 있는 곳, 최근에 안 간 곳, 가까운 곳(게으를수록). 미운 사람 곁은 피한다
func score(sp: Dictionary, sched: Array) -> float:
	var k: String = sp["kind"]
	var s := 1.0
	if k in likes: s += 1.5
	if k in sched: s += 1.2
	if k in REST: s += (1.0 - energy) * 3.0 * (0.5 + lazy)
	if k == "counter": s += (1.0 - full) * 4.0
	if k in FUN: s += (1.0 - fun) * 2.5 * (0.5 + curious)
	if k in SOCIAL: s += (1.0 - company) * 2.0 * social
	for o in sp.get("taken", []):
		if o != null and o != r: s += 1.5 * relation_k(o)   # 친구가 앉은 벤치로, 앙숙이 있는 벤치는 피해서
	if k in recent: s *= 0.45 if curious > 0.5 else 0.85
	var pos: Vector3 = sp["pos"]
	s /= 1.0 + r.global_position.distance_to(pos) * 0.04 * (0.3 + lazy)
	if fond < -0.3 and pos.distance_to(r.town.body.global_position) < 5.0: s *= 0.15
	return maxf(s, 0.05)

func pick(free: Array, sched: Array) -> Dictionary:
	var ws: Array = []; var sum := 0.0
	var n := {}   # 같은 종류가 많은 자리(나무 스무 그루)가 수로 이기지 않게 — 종류 수의 제곱근으로 나눈다
	for sp in free: n[sp["kind"]] = n.get(sp["kind"], 0) + 1
	for sp in free:
		var w := pow(score(sp, sched), 2.0) / sqrt(float(n[sp["kind"]])); ws.append(w); sum += w
	var x := randf() * sum
	var got: Dictionary = free[free.size() - 1]
	for i in free.size():
		x -= ws[i]
		if x <= 0.0: got = free[i]; break
	var k: String = got["kind"]
	reason = ""
	if k == "counter" and full < 0.35: reason = "hungry"
	elif k in REST and energy < 0.3: reason = "tired"
	elif k in FUN and fun < 0.3: reason = "bored"
	elif k in SOCIAL and company < 0.25: reason = "lonely"
	recent.push_front(k)
	if recent.size() > 4: recent.pop_back()
	return got

func ate() -> void:
	full = minf(1.0, full + 0.7); mood = minf(1.0, mood + 0.1)

## 다른 주민과의 사이 -1..1 — 명부의 관계(친구·앙숙)에 수다로 쌓인 정이 더해진다
func relation_k(o: ResidentBase) -> float:
	var k: float = friends.get(o.uid, 0.0)
	var tag: String = rel.get(o.handle, (o.mind.rel as Dictionary).get(r.handle, "") if o.mind else "")
	if tag == "friend": k += 0.6
	elif tag == "rival": k -= 0.5
	return clampf(k, -1.0, 1.0)

func befriend(o: ResidentBase, d: float) -> void:
	friends[o.uid] = clampf(float(friends.get(o.uid, 0.0)) + d, -1.0, 1.0)

# ── 플레이어 ──
func greeted() -> void:
	var now := _now()
	met += 1; company = minf(1.0, company + 0.15)
	if now - last_greet > 20.0: fond = clampf(fond + (0.12 if fond > -0.5 else 0.05), -1.0, 1.0)   # 인사 연타는 안 쌓인다, 깊은 미움은 조금씩만 풀린다
	last_greet = now

func greet_line() -> String:
	if fond < -0.3: return line("grudge" if _now() - last_hurt < 120.0 else "greet_cold")
	if fond > 0.3: return line("greet_fond")
	return line("greet_new")

func gifted() -> void:
	fond = clampf(fond + 0.3, -1.0, 1.0); mood = minf(1.0, mood + 0.25)

func hurt_by_player(heavy: bool) -> void:
	hurt += 1; last_hurt = _now()
	fond = clampf(fond - (0.3 if heavy else 0.15), -1.0, 1.0); mood = maxf(-1.0, mood - 0.3)

func witnessed() -> void:
	fond = clampf(fond - 0.08, -1.0, 1.0)

## 맞고 나서 — 쫓아가 되갚을까(성미·배짱), 아니면 피할까
func retaliates() -> bool:
	return randf() < clampf(temper * 0.9 + brave * 0.3 - 0.2 + (0.2 if hurt > 2 else 0.0), 0.05, 0.95)

func flees() -> bool:
	return brave < 0.45 and temper < 0.6

## 이름표 아래 한 줄(인사하면 잠깐 보인다) — 지금 이 사람의 속
func status() -> String:
	var out: Array = []
	if full < 0.3: out.append("hungry")
	if energy < 0.3: out.append("tired")
	if fun < 0.25: out.append("bored")
	if company < 0.25: out.append("lonely")
	if out.is_empty(): out.append("cheerful" if mood > 0.45 else ("grumpy" if mood < -0.15 else "fine"))
	if fond > 0.3: out.append("likes you")
	elif fond < -0.3: out.append("angry at you" if _now() - last_hurt < 120.0 else "wary of you")
	elif met == 0: out.append("new to you")
	return " · ".join(out.slice(0, 3))

## 기억 저장 — 판을 끄고 켜도 누가 때렸고 누가 반겼는지 남는다(30초마다, 한 사람이 모두를)
static func save_all(residents: Array, force := false) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if not force and now - _saved_at < 30.0: return
	if DisplayServer.get_name() == "headless" or "--sheet" in OS.get_cmdline_user_args() or "-s" in OS.get_cmdline_args() or "--script" in OS.get_cmdline_args(): return   # 점검·시트 판은 진짜 기억을 더럽히지 않는다
	_saved_at = now
	for x in residents:
		var m: ResidentMind = x.mind
		if m == null: continue
		var fr := {}
		for k in m.friends: fr[str(k)] = snappedf(m.friends[k], 0.01)
		_saved[str(x.uid)] = { "fond": snappedf(m.fond, 0.01), "met": m.met, "hurt": m.hurt, "friends": fr }
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(_saved))
