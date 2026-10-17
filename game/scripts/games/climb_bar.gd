class_name ClimbBar
extends Node3D
## Climb 콘텐츠 팩 '높이뛰기 바'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 바람 절벽(Wind cliffs) 층의 still 발판 하나(오르는 순서에서 앞 발판이 있는 것 — 들어오는 쪽은 앞 발판 쪽) — 들어오는 턱에서 run 만큼 달려 온 자리에 쇠 기둥 둘(절벽 쪽·bar_d 앞, 앞길은 비어 있다)과 눈금(notches) 셋, 그 층의 눈금(notches[n mod 3])에 가벼운 가로대가 놓이고, 건너편에 두꺼운 매트(mat_w)가 깔린다.
## 공중의 몸이 가로대의 면(bx)을 지나는 틱(flight — 앞 틱의 x 와 지금 x 가 면을 사이에 둔다): 발이 가로대 위면 넘는다(cleared — 탑의 하루 day_s 에 한 번 센다, 쉼터 판이 note(n) 으로 읽는다), 낮으면(몸 44 px 의 머리가 가로대 밑에 닿으면) 가로대가 눈금에서 떨어진다(knocked, clatter): drop_s 동안 매트로 굴러 떨어져 reset_s 눕고 lift_s 에 걸쳐 눈금으로 돌아간다(thump).
## 누운 가로대는 세지도 떨어지지도 않는다. 단단한 것이 없고 값도 없다: 걸어서 지나는 몸은 어느 눈금에도 안 닿고(눈금은 모두 선 몸보다 높다), 면에 닿지 않는 점프와 발판을 달려 지나는 길은 그대로(평이한 결과 100%) — 가로대는 그것을 향해 뛴 몸에만 있다.
## 허들(가로대 20 px — 걸음의 속도가 가른다)·멀리뛰기 모래(길이)와 다르다: 이건 높이를 재는 첫 조각 — 충전한 점프가 가른다(톡 뜀 430 은 38 px, 1.6 m 는 충전의 1/5, 2.4 m 는 반 넘게). 자세는 arch(stick3d_arch.gd — 운영자 보드의 '스포츠 — 높이뛰기' 가족): 무릎 드라이브 → 활처럼 젖은 등·머리 위 팔·젖힌 고개 → 다리를 차 넘기며 매트를 본다; 시계는 몸의 x(meta arch_k, 가로대 위가 0.5); 떨어뜨리면 넘김이 사림(arch_hit)이 된다.
## 바람 있는 층의 가로대는 눈금 위에서 떤다(quiver — 바람 없는 층도 그 1/3; 살아 있는 건 움직인다).
## 로더가 할 일(climb.gd, 운영자 세션): `var cb := ClimbBar.new(); add_child(cb); signs.notes.append(cb.note)`; 층을 지을 때 `var kp := ck.plan(n, plats, wind_of(n)); var hop_top := cu.plan(n, plats) + ci.plan(n, plats) + kp; cb.build(root, cb.plan(n, plats, wind_of(n), hop_top + ch.plan(n, plats, hop_top) + cd.plan(n, plats, wind_of(n), kp + cv.plan(n, plats, wind_of(n), kp))))`
## (통풍구·고드름·연·허들 줄·민들레의 계획을 taken 으로 — 한 발판을 둘이 안 나눈다); 매 틱 `cb.sync(_t)`;
## 공중(on 이 비고 매달림·붙잡음·연·홀씨가 다 빈)에서 x·y 를 옮긴 뒤(_wall_push 뒤) `var r := cb.flight(ox, x, y, z, fig); if r["in_flight"]: fig.pose_request = "arch"` (팩이 meta arch_k·arch_hit 를 적는다) `elif fig.pose_request == "arch": fig.pose_request = ""` (가로대에서 멀어지면 — 팩이 메타를 지운다);
## 착지(landed 가 차고 was_air)에서 `if fig.pose_request == "arch": fig.pose_request = ""; cb.leave(fig)` (매트든 발판이든 로더의 착지 그대로 — 매트는 그림이다).
## flight 의 count: 비우면 플레이어(판에 세고 me_t 를 적는다 — 선수가 기다리고 따라 뛴다), 다른 몸(주민 반쪽)은 거짓을 준다. 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_bar.gd
## 주민 반쪽(run 171): 바마다 높이뛰기 선수 하나(climb_highjumper.gd — 바 노드 아래 Stick3D)가 들어오는 턱 안쪽에 서서 탑의 1분마다, 그리고 플레이어의 비행이 끝난 뒤 1 s 뒤에 그 눈금만큼 웅크려 같은 flight(count 거짓)·같은 arch 로 넘어 매트에 눕고(sprawl) 기둥을 돌아 집에 온다;
## 다섯 번에 한 번 일부러 떨어뜨리고 제 손으로 세운다(reset — held 인 동안 혼자 돌아가는 눈금은 기다린다; 플레이어가 떨어뜨리고 간 것도 세운다). 로더가 더 할 일은 없다 — build 가 세우고 _process 가 몬다.

const PACK := "res://data/climb/bar.json"
const C = preload("res://scripts/games/climb.gd")
const BAND_LO := 20.0      # taken 조각이 이 발판의 것인가: y 가 발판 윗면 − BAND_LO 부터 윗면 + BAND_HI 앞까지(run 152 의 띠 규칙)
const BAND_HI := 60.0
const BODY_UP := 50.0      # 선 몸의 키(px) — 상자 위쪽 여유
const BODY_H := 44.0       # 몸의 키(px) — 발에서 머리끝까지; 머리가 가로대 밑에 닿으면 떨어뜨린다
const POST_OVER := 12.0    # 기둥이 가장 높은 눈금 위로 더 선 높이(px)
const QUIVER_S := 0.37     # 가로대 떨림 한 주기(s)

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.bar
var bars: Array = []            # 지은 바 {id, kind "bar", n, hop_id, hop_kind, hop_w, x, w, y, y_top, z, d, hz, hd, bx, dir, h, run, mat, wind, node, bar, fell_t, lifted, held, day, me_t, clatter, thump, jumper}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("bar", {})

func sync(now: float) -> void:
	t = now

## 눈금 높이들(px) — 모두 선 몸(BODY_H)보다 높게: 걸어서 지나는 몸이 안 닿는다
func notches() -> Array:
	var out: Array = []
	for v in (kind.get("notches", [56.0, 72.0, 88.0]) as Array): out.append(maxf(BODY_H + 2.0 * bar_r() + 4.0, float(v)))
	if out.is_empty(): out.append(56.0)
	return out

## 층 n 의 가로대 높이(px) — 눈금을 층으로 돌려 쓴다
func notch(n: int) -> float:
	var ns := notches()
	return float(ns[posmod(n, ns.size())])

func top_h() -> float:
	var top := 0.0
	for v in notches(): top = maxf(top, float(v))
	return top

func bar_r() -> float:
	return maxf(1.0, float(kind.get("bar_r", 2.0)))

func bar_d() -> float:
	return maxf(8.0, float(kind.get("bar_d", 34.0)))

func post() -> float:
	return maxf(1.0, float(kind.get("post", 4.0)))

func run_w(wide: bool) -> float:
	return maxf(2.0 * C.HW, float(kind.get("run" if wide else "run_min", 70.0 if wide else 50.0)))

func mat_w(wide: bool) -> float:
	return maxf(2.0 * C.HW, float(kind.get("mat_w" if wide else "mat_min", 50.0 if wide else 40.0)))

func mat_h() -> float:
	return maxf(2.0, float(kind.get("mat_h", 14.0)))

func edge() -> float:
	return maxf(0.0, float(kind.get("edge", 16.0)))

func approach() -> float:
	return maxf(C.HW, float(kind.get("approach", 60.0)))

func drop_s() -> float:
	return maxf(0.05, float(kind.get("drop_s", 0.5)))

func reset_s() -> float:
	return maxf(drop_s(), float(kind.get("reset_s", 20.0)))

func lift_s() -> float:
	return maxf(0.05, float(kind.get("lift_s", 0.6)))

func day_s() -> float:
	return maxf(1.0, float(kind.get("day_s", 600.0)))

func quiver_px() -> float:
	return maxf(0.0, float(kind.get("quiver", 1.5)))

## 탑의 오늘 — 로더의 시계를 day_s 로 나눈 몫
func day() -> int:
	return floori(t / day_s())

## 바가 서는 데 필요한 발판 폭(px) — 달려 올 자리, 가로대, 매트, 끝의 여유
func need_w(wide: bool) -> float:
	return run_w(wide) + bar_r() + 2.0 + mat_w(wide) + edge()

## 층 n(테마 층)의 still 발판(조각의 on, 앞 발판이 있는 것) 중 바가 서는 폭이고(넓은 run, 안 되면 좁은 run), 바의 상자(들어오는 턱..매트 끝 ± 손 하나, 윗면..선 몸)를 다른 발판이 가르지 않고, taken 조각이 띠 안에 없는 것들 중 가장 넓은 것 하나. 같은 층·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, wind: float = 0.0, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	var hops: Array = plats.filter(func(p: Dictionary) -> bool: return not (String(p["kind"]) in ["rest", "short", "ledge"]))   # 오르는 순서(band() 는 그렇게 쌓는다) — 앞 발판 쪽이 들어오는 쪽
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var kinds: Array = piece.get("on", ["std", "ice"])
		var found: Array = []
		for i in range(1, hops.size()):
			var p: Dictionary = hops[i]; var prev: Dictionary = hops[i - 1]
			if not (String(p["kind"]) in kinds): continue
			var w := float(p["w"]); var y := float(p["y"])
			var wide := w >= need_w(true)
			if not wide and w < need_w(false): continue
			var pc := float(p["x"]) + w / 2.0; var qc := float(prev["x"]) + float(prev["w"]) / 2.0
			var dir := 1.0 if qc <= pc else -1.0   # 들어오는 턱에서 매트 쪽으로 — 앞 발판이 왼쪽이면 +x
			var ex := float(p["x"]) if dir > 0.0 else float(p["x"]) + w
			var bx := ex + dir * run_w(wide)
			var mat_end := bx + dir * (bar_r() + 2.0 + mat_w(wide))
			var lo := minf(ex, mat_end); var hi := maxf(ex, mat_end)
			if not _clear(plats, p, lo - C.HW, hi + C.HW, y + 1.0, y + BODY_UP): continue
			if not _free(taken, lo, hi, y - BAND_LO, y + BAND_HI): continue
			found.append({ "hop_w": w, "hop_id": String(p["id"]), "hop_kind": String(p["kind"]), "y": y, "bx": bx, "dir": dir, "run": run_w(wide), "mat": mat_w(wide), "x": lo, "w": hi - lo, "hz": float(p.get("z", C.WALL_Z + C.DEPTH_HALF)), "hd": float(p.get("d", C.DEPTH_HALF * 2.0)) })
		found.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["hop_w"]) > float(q["hop_w"]) if float(p["hop_w"]) != float(q["hop_w"]) else float(p["y"]) < float(q["y"]))
		for i in range(0, mini(int(piece.get("max", 1)), found.size())):
			var g: Dictionary = found[i]
			var s: Dictionary = g.duplicate(true)
			s["id"] = "%d.B%d" % [n, i]; s["kind"] = "bar"; s["n"] = n; s["h"] = notch(n); s["wind"] = wind
			s["y_top"] = float(g["y"]) + top_h() + POST_OVER   # 기둥 꼭대기 — 다른 팩의 _free 가 읽는 키
			s["z"] = C.WALL_Z + bar_d() / 2.0; s["d"] = bar_d()   # 가로대의 깊이 — 절벽에서 bar_d 까지
			out.append(s)
	return out

## 바의 상자에 그 발판 말고 다른 발판이 걸리지 않나 — 움직이는 발판은 진폭째
static func _clear(plats: Array, a: Dictionary, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for pv in plats:
		var p: Dictionary = pv
		if p["id"] == a["id"]: continue
		var py := float(p["y"])
		if py < ylo or py > yhi: continue
		var amp := float(p.get("amp", 0.0))
		var px0 := float(p["x"]) - amp - 10.0; var px1 := float(p["x"]) + float(p["w"]) + amp + 10.0
		if x1 > px0 and x0 < px1: return false
	return true

## 다른 팩의 조각(taken: x, 있으면 w·rail_y·beam_y·y_top)이 바의 x 와 겹치고 높이 띠 [ylo, yhi) 에 들면 그 발판은 그 팩의 것 — 통풍구는 발판 가운데(w 없음), 고드름은 턱 위, 허들 줄은 발판 위, 연·민들레는 틈
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qx0 := float(q.get("x", 0.0)) - 10.0; var qx1 := float(q.get("x", 0.0)) + float(q.get("w", 0.0)) + 10.0
		var qy := float(q.get("y", 0.0)); var qtop := qy
		for key: String in ["rail_y", "beam_y", "y_top"]:
			if q.has(key): qtop = maxf(qtop, float(q[key]))
		if x1 > qx0 and x0 < qx1 and qtop >= ylo and qy < yhi: return false
	return true

## 가로대가 눈금 위에 있나 — 떨어진 뒤 reset_s + lift_s 가 지나면 다시
func up(s: Dictionary) -> bool:
	var since := t - float(s["fell_t"])
	return since < 0.0 or since >= reset_s() + lift_s()

## 공중의 매 틱 — {in_flight, k, cleared, knocked, id}: 가로대 approach 안의 몸(발판 윗면보다 몸 하나 넘게 낮으면 틈에 떨어지는 중 — 아니다)은 in_flight 와 자리 k(들어오는 쪽 끝 0, 가로대 위 0.5, 매트 쪽 끝 1 — 가는 방향으로)를 받고 fig 의 meta arch_k 에 적힌다;
## 앞 틱의 x 와 지금 x 가 가로대의 면을 사이에 두면 발(y)이 가로대 윗면 위에 있으면 넘고(cleared — count 면 오늘 센다), 머리(y + BODY_H)가 가로대 밑면에 닿으면 떨어뜨린다(knocked — 가로대가 구른다, meta arch_hit); 누운 가로대는 이 비행에서 떨어뜨린 몸(arch_hit)만 자세를 잇고 다른 몸엔 없다. 멀어지면 메타를 지운다(로더가 pose_request 를 비운다)
func flight(ox: float, x: float, y: float, z: float, fig: Stick3D = null, count := true) -> Dictionary:
	var none := { "in_flight": false, "k": 0.0, "cleared": false, "knocked": false, "id": "" }
	for sv in bars:
		var s: Dictionary = sv
		if absf(z - float(s["z"])) >= float(s["d"]) / 2.0 + C.HZ: continue
		var bx := float(s["bx"]); var hy := float(s["y"])
		if absf(x - bx) > approach() or y < hy - BODY_H: continue
		var is_up := up(s)
		if not is_up and not (fig != null and fig.has_meta("arch_hit")): continue
		var dir := signf(x - ox) if absf(x - ox) > 0.01 else float(s["dir"])
		var r := none.duplicate(); r["id"] = String(s["id"]); r["in_flight"] = true
		if count: s["me_t"] = t   # 플레이어가 가로대 곁의 공중에 있다 — 선수가 기다렸다 따라 뛴다(제 비행은 count 거짓이라 안 적는다)
		r["k"] = clampf((x - bx) * dir / (2.0 * approach()) + 0.5, 0.0, 1.0)
		if is_up and ox != x and (ox - bx) * (x - bx) <= 0.0:   # 이 틱에 가로대의 면을 지났다
			var by := hy + float(s["h"])
			if y >= by + bar_r():
				r["cleared"] = true
				if count: s["day"] = day()
			elif y + BODY_H >= by - bar_r():
				r["knocked"] = true; s["fell_t"] = t; s["lifted"] = false
				_play(s["clatter"] as AudioStreamPlayer3D)
				if fig: fig.set_meta("arch_hit", 1.0)
		if fig: fig.set_meta("arch_k", float(r["k"]))
		return r
	leave(fig)
	return none

## 가로대에서 멀어진 몸 — 자세의 메타를 지운다(로더가 pose_request 를 비운다)
func leave(fig: Stick3D) -> void:
	if fig == null: return
	if fig.has_meta("arch_k"): fig.remove_meta("arch_k")
	if fig.has_meta("arch_hit"): fig.remove_meta("arch_hit")

## n0..n1 층의 지은 바에서 오늘 넘은 수·전체·넘은 것 중 가장 높은 가로대(px) — {done, total, best}
func cleared_today(n0: int, n1: int) -> Dictionary:
	var done := 0; var total := 0; var best := 0.0
	for sv in bars:
		var s: Dictionary = sv
		if int(s["n"]) < n0 or int(s["n"]) > n1: continue
		total += 1
		if int(s["day"]) == day(): done += 1; best = maxf(best, float(s["h"]))
	return { "done": done, "total": total, "best": best }

## 쉼터 판(n 층)에 붙는 줄 — 위 다섯 층(n..n+4)의 바, 없으면 아래 다섯 층(n−5..n−1)의 바, 그것도 없으면 빈 줄. climb_signs.notes 에 넣는다. 높이는 탑의 m(36 px)
func note(n: int) -> String:
	for span: Array in [[n, n + 4], [n - 5, n - 1]]:
		var v := cleared_today(int(span[0]), int(span[1]))
		if int(v["total"]) > 0:
			var line := "High jump, floors %d–%d: %d of %d %s cleared today" % [int(span[0]), int(span[1]), int(v["done"]), int(v["total"]), "bar" if int(v["total"]) == 1 else "bars"]
			if int(v["done"]) > 0: line += ", the highest %.1f m" % (float(v["best"]) * C.K)
			return line + "."
	return ""

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 노드를 지금 자리로 — 누운 가로대가 reset_s 를 채우는 프레임에 thump(눈금으로 돌아가기 시작)
func _process(delta: float) -> void:
	t += delta
	bars = bars.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_hurdle 과 같은 식)
	for sv in bars:
		var s: Dictionary = sv
		if bool(s.get("held", false)) and not bool(s["lifted"]) and t - float(s["fell_t"]) > reset_s() - 0.001:
			s["fell_t"] = t - reset_s() + 0.001   # 선수가 세우러 오는 중 — 혼자 돌아가지 않고 누운 채 기다린다(선수가 손을 대면 fell_t 를 돌려놓는다)
		if not bool(s["lifted"]) and t - float(s["fell_t"]) >= reset_s():
			s["lifted"] = true; _play(s["thump"] as AudioStreamPlayer3D)
		_place(s)
		if s.has("jumper"): (s["jumper"] as ClimbHighJumper).step(delta)   # 선수의 틱

## 가로대의 자리 — 눈금 위면 바람에 떤다; 떨어지면 drop_s 동안 매트 쪽으로 기울며 굴러 한 번 튀고, reset_s 까지 매트 위에 누웠다가, lift_s 에 걸쳐 눈금으로 돌아간다
func _place(s: Dictionary) -> void:
	var bar: Node3D = s["bar"]; var since := t - float(s["fell_t"])
	var h := float(s["h"]) * C.K; var mat_y := (mat_h() + bar_r()) * C.K
	var mx := float(s["dir"]) * (bar_r() + 2.0 + float(s["mat"]) / 2.0) * C.K
	if since < 0.0 or since >= reset_s() + lift_s():
		var k := 0.33 + 0.67 * clampf(absf(float(s["wind"])) / 120.0, 0.0, 1.0)
		bar.position = Vector3(0.0, h + quiver_px() * k * sin(t * TAU / QUIVER_S + float(s["bx"]) * 0.01) * C.K, 0.0); bar.rotation.x = 0.0
	elif since < drop_s():
		var u := since / drop_s(); var e := smoothstep(0.0, 1.0, u)
		bar.position = Vector3(mx * e, lerpf(h, mat_y, e) + 0.06 * sin(u * PI), 0.0); bar.rotation.x = 0.8 * sin(u * PI)
	elif since < reset_s():
		bar.position = Vector3(mx, mat_y, 0.0); bar.rotation.x = 0.0
	else:
		var v := smoothstep(0.0, 1.0, (since - reset_s()) / lift_s())
		bar.position = Vector3(mx * (1.0 - v), lerpf(mat_y, h, v), 0.0); bar.rotation.x = 0.0

## 바를 짓는다 — root 는 그 층의 노드. 노드 원점은 (가로대의 x, 발판 윗면, 절벽); 기둥 둘(절벽 쪽·앞쪽), 기둥마다 눈금 셋(가로대 쪽으로 나온 쇠 나사), 도는 가로대 노드(강조색 — 가는 선만), 매트(바랜 천 — 윗면에 가는 띠), 소리 둘
func build(root: Node3D, planned: Array) -> void:
	var bd := bar_d() * C.K; var pt := post() * C.K; var ph := (top_h() + POST_OVER) * C.K
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate(true)
		var node := Node3D.new(); node.position = C.to3(float(s["bx"]), float(s["y"]), C.WALL_Z * C.K); root.add_child(node)
		var iron := _mat(Color("4a4a52")); var brass := _mat(Color("c9a35a")); var cloth := _mat(Color("d8d2c6")); var acc := _mat(Color("ad7096"))
		for zz: float in [pt / 2.0, bd - pt / 2.0]:
			_box(node, Vector3(pt, ph, pt), iron).position = Vector3(0.0, ph / 2.0, zz)   # 기둥
			for hv in notches():
				_box(node, Vector3(pt * 2.2, pt * 0.5, pt), brass).position = Vector3(-float(s["dir"]) * pt * 0.6, float(hv) * C.K - pt * 0.25, zz)   # 눈금 — 들어오는 쪽으로 나온 나사 머리에 가로대가 걸린다
		var bar := Node3D.new(); node.add_child(bar)   # 가로대 — _place 가 눈금 위에 두고, 떨어지면 매트로
		_box(bar, Vector3(pt * 0.8, pt * 0.8, bd), acc).position = Vector3(0.0, 0.0, bd / 2.0)
		var mw := float(s["mat"]) * C.K; var mh := mat_h() * C.K; var mx := float(s["dir"]) * (bar_r() + 2.0 + float(s["mat"]) / 2.0) * C.K
		_box(node, Vector3(mw, mh, bd * 1.2), cloth).position = Vector3(mx, mh / 2.0, bd / 2.0)   # 매트
		_box(node, Vector3(mw * 0.9, 0.012, bd * 1.2 + 0.01), acc).position = Vector3(mx, mh, bd / 2.0)   # 매트 윗면의 띠 — 강조색은 가는 선 하나
		s["node"] = node; s["bar"] = bar; s["fell_t"] = -99.0; s["lifted"] = true; s["held"] = false; s["day"] = -1; s["me_t"] = -99.0
		s["clatter"] = _snd(node, float(kind.get("clatter_hz", 180)), 0.15, -12.0); s["thump"] = _snd(node, float(kind.get("thump_hz", 110)), 0.1, -16.0)
		s["jumper"] = ClimbHighJumper.new(self, s, node)   # 주민 반쪽 — 들어오는 턱 안쪽에 선 높이뛰기 선수
		bars.append(s)
		_place(s)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

func _snd(parent: Node3D, hz: float, secs: float, db: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new(); p.stream = _tick_wav(hz, secs); p.volume_db = db; p.unit_size = 6.0; p.max_distance = 30.0
	parent.add_child(p); return p

## 소리 — 짧은 기음이 잦아든다: clatter(0.15초, 메마르게 — 가벼운 가로대가 눈금에서 튀어 매트에 구른다)·thump(0.1초, 낮게 — 가로대가 눈금에 다시 놓인다). 한 번 재생, 반복 없음
static func _tick_wav(hz: float, secs: float) -> AudioStreamWAV:
	var rate := 22050; var n := int(rate * secs)
	var data := PackedByteArray(); data.resize(n * 2)
	for i in n:
		var k := float(i) / n
		var ph := float(i) * hz * TAU / rate
		var v := (sin(ph) * 0.5 + sin(ph * 2.7) * 0.2) * exp(-k * 7.0)
		data.encode_s16(i * 2, int(v * 22000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w
