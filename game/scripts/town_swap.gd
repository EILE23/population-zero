class_name TownSwap
extends TownSites
## 하나 두고 하나 가져가기("Leave one, take one" — 마을이 설계한 열일곱째 시스템): 한 사람이 돌보는 작은 선반, 하나 놓고 하나 가져간다. 동전은 없다.
## 1조각(run 98) 책 상자: 빵집 서쪽 옆, 기둥 위 두 칸 상자에 책등 여섯 칸. 책을 들고 C = 꽂기, 빈손 C = 하나 꺼내기 — 같은 shelve 자세, 손이 칸에 닿는 순간(SHELVE_IN) 책이 바뀐다.
## 가져가기만 해도 된다(평범한 C 는 막지 않는다 — 곁의 관리인이 한마디 할 뿐). 주민도 지나가다 같은 자세로 바꾸고 꺼낸다(resident_shelf.gd).
## 사슬: … → woods → sites → **swap** → player → town3d. 다음 조각(씨앗 깡통·연장 디딤돌·준 사람 기억)도 여기에

const BOOK_MAX := 6
var bookbox: Dictionary = {}   # 책 상자 자리 {pos, kind "swap", yaw, stock, shown: 책등 여섯, taken(칸 둘 — 관리인과 손님)}

## 기둥 + 앞이 열린 두 칸 상자(뒤판·옆판·두 선반·빵집 지붕 색 지붕 판). 윗면 0.97 — 허리 높이. 책등은 세워 꽂고 키를 조금씩 다르게(픽셀까지 대칭인 건 없다)
func _bookbox(at: Vector3) -> void:
	var wood := _mat(Color("8a6a4a"))
	_box(Vector3(0.1, 0.4, 0.1), at, _mat(Color("6b4a35")))
	_box(Vector3(0.7, 0.04, 0.32), at + Vector3(0, 0.4, 0), wood, false)
	_box(Vector3(0.7, 0.04, 0.32), at + Vector3(0, 0.66, 0), wood, false)
	_box(Vector3(0.7, 0.52, 0.03), at + Vector3(0, 0.4, -0.145), wood)
	for sx: float in [-0.335, 0.335]: _box(Vector3(0.03, 0.52, 0.32), at + Vector3(sx, 0.4, 0), wood)
	_box(Vector3(0.8, 0.05, 0.38), at + Vector3(0, 0.92, 0.02), _mat(Color("b56a5a")), false)
	var shown: Array = []
	for i in BOOK_MAX:
		var b := make_item("book", Vector3.ZERO)
		var hk := 0.85 + 0.15 * fmod(i * 0.37 + 0.2, 1.0)
		b.scale = Vector3(1.0, 1.0, hk); b.rotation = Vector3(PI / 2.0, PI, PI / 2.0)   # 눕힌 책(가로 0.16·두께 0.04·키 0.22)을 세워 책등이 앞(+z)으로
		b.position = at + Vector3(-0.22 + (i % 3) * 0.075 + (0.12 if i >= 3 else 0.0), (0.7 if i >= 3 else 0.44) + 0.11 * hk, 0.02)
		shown.append(b)
	bookbox = { "pos": at + Vector3(0, 0, 0.7), "kind": "swap", "yaw": PI, "stock": 4, "shown": shown }
	_show_stock(bookbox)
	spots.append(bookbox)

## 손이 칸 끝에 닿은 순간 — 그 책이 아직 손에 있고 칸이 남았으면 책은 사라지고 책등 하나가 보인다. 사람도 주민도 이걸 부른다
func shelve_book(fig: Stick3D, book: Node3D) -> bool:
	if book == null or fig.carrying != book or int(bookbox["stock"]) >= BOOK_MAX: return false
	fig.release(self, Vector3.ZERO).queue_free()
	bookbox["stock"] = int(bookbox["stock"]) + 1; _show_stock(bookbox)
	return true

## 꺼내기 — 손이 비었고 남은 책이 있으면 책등 하나가 사라지고 손에 책. 사람도 주민도 이걸 부른다
func unshelve_book(fig: Stick3D) -> bool:
	if fig.carrying != null or not counter_take(bookbox): return false
	fig.hold(make_item("book", Vector3.ZERO))
	return true

## 곁에 서 있는 관리인(문에 "librarian") — 없으면 null
func librarian_here() -> ResidentBase:
	for r in residents:
		if r.job == "librarian" and r.state == "busy" and is_same(r.spot, bookbox): return r
	return null

## 사람이 상자 앞(1.1m)에서 C(town_player) — 책을 들었으면 꽂고, 빈손이면 하나 꺼낸다(SHELVE_T 한 바퀴). 칸이 다 찼거나 비었으면 false — 호출자가 다음 규칙(읽기·내려놓기)으로
func swap_use(now: float) -> bool:
	if bookbox.is_empty() or body.global_position.distance_to(bookbox["pos"]) > 1.1: return false
	var book := player.carrying
	var put := book != null and String(book.get_meta("kind", "")) == "book"
	if (put and int(bookbox["stock"]) >= BOOK_MAX) or (not put and (book != null or int(bookbox["stock"]) <= 0)): return false
	player.face(bookbox["yaw"]); reading = false
	player.pose_request = "shelve"; use_until = now + ShelfPoses.SHELVE_T; action_until = now + ShelfPoses.SHELVE_T
	get_tree().create_timer(ShelfPoses.SHELVE_IN).timeout.connect(_shelve_hand.bind(put, book))
	var k := librarian_here()
	if k and not put: k.say(k.mind.line("book_swap"), 1.6)   # 꺼내기만 해도 막지 않는다 — 관리인은 한마디만
	return true

func _shelve_hand(put: bool, book: Node3D) -> void:
	if player.pose_request != "shelve": return   # 그새 움직였거나 맞았다 — 없던 일
	if put: shelve_book(player, book)
	else: unshelve_book(player)
