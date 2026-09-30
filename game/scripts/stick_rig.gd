class_name StickRig
extends Node3D
## 입체 졸라맨의 몸 — 관절은 구, 뼈는 캡슐, 어깨와 골반엔 가로대, 꾸미기 소켓, 들기·입기. 코드로 조립한다(운영자 2026-09-28: "졸라맨 자체도 입체화되서 움직임이 자연스러워져야").
## 움직임은 stick3d.gd(Stick3D extends StickRig)에 — 파일 500줄 상한(2026-09-28 코드 위생 규칙)으로 몸과 동작을 나눴다.
## 2D figure.gd 와 같은 관절 논리를 3D 각도로 옮겼다: 걸음 위상은 이동 거리에 걸려 발이 미끄러지지 않고, 팔은 다리와 반대 위상,
## 무릎은 뒤로 갈 때 접히고, 상체는 달릴 때 앞으로 기울고, 엉덩이는 보폭마다 살짝 뜬다. 몸은 이동 방향으로 부드럽게 돈다.
## 회전 부호 약속(2026-09-28 수정 — 처음엔 팔꿈치가 뒤로, 무릎이 앞으로 꺾여 "팔이 따로 놀았다"):
##   매달린 뼈(팔다리)는 rotation.x 가 −면 끝이 앞(+z, 얼굴 방향)으로 간다(Godot 오른손 좌표계). 코드는 '앞 = 양수' 로 읽히게 쓰고 대입에서 -( ) 로 뒤집는다.
##   2026-09-28 두 번째 수정: 처음엔 + 가 앞인 줄 알고 넣어서 다리가 진행 방향과 반대로 저었다(운영자: "지금 무슨 문워크 하냐"). 위로 뻗는 몸통(torso)은 + 가 앞이 맞다.
## 크기: 키 1.0m(2D 의 42px). 발끝이 원점. 두께는 3/4 카메라 거리에서 읽히게 2D 보다 굵다.

@export var color: Color = Color("1b0c15")
@export var head_color: Color = Color("1b0c15")

const HIP_Y := 0.42
const SHOULDER_Y := 0.84
const HEAD_Y := 1.0
const THIGH := 0.26
const SHIN := 0.24
const UPPER := 0.19   # 팔은 다리보다 확실히 짧게(운영자 2026-09-28: 팔이 너무 길다) — 팔 0.37 : 다리 0.50
const FORE := 0.18
const R := 0.042          # 뼈 두께 — 2D 의 2.4px/42px 보다 굵게(멀리서 선으로 읽히게)
const SHOULDER_W := 0.115 # 어깨 반폭
const HIP_W := 0.075      # 골반 반폭
const STRIDE := 1.35      # 한 걸음(위상 2π)에 나아가는 거리 — 발 미끄러짐 없음

var _pivots: Array[Node3D] = []   # 블렌딩 대상 관절 전부
var _mat: StandardMaterial3D
var _head_mat: StandardMaterial3D
var pelvis: Node3D
var torso: Node3D
var chest: Node3D
var neck: Node3D
var hand_r: Node3D
var hand_l: Node3D
var socket_hat: Node3D
var socket_face: Node3D
var socket_back: Node3D
var socket_belt: Node3D
var hips := {}     # side → Node3D (thigh pivot)
var knees := {}
var shoulders := {}
var elbows := {}

func _ready() -> void:
	_mat = _material(color)
	_head_mat = _material(head_color)
	pelvis = _pivot(self, Vector3(0, HIP_Y, 0))
	_bar(pelvis, HIP_W)                                  # 골반대
	torso = _pivot(pelvis, Vector3.ZERO)
	var half := (SHOULDER_Y - HIP_Y) / 2.0
	_bone(torso, half, _mat)                              # 허리
	chest = _pivot(torso, Vector3(0, half, 0))
	_joint(chest, 0.95)
	_bone(chest, half, _mat)                              # 가슴 — 여기서 한 번 더 굽어 척추가 곡선이 된다
	neck = _pivot(chest, Vector3(0, half, 0))
	_bar(neck, SHOULDER_W)                               # 쇄골
	_joint(neck, 1.0)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.19; sm.height = 0.38; sm.radial_segments = 24; sm.rings = 12  # 캐주얼: 머리를 더 크게(운영자 2026-09-28)
	head.mesh = sm; head.material_override = _head_mat
	head.position = Vector3(0, HEAD_Y - SHOULDER_Y + 0.02, 0)
	neck.add_child(head)
	for side in [-1.0, 1.0]:
		var hip := _pivot(pelvis, Vector3(side * HIP_W, 0, 0))
		_joint(hip, 1.1)
		_bone(hip, -THIGH, _mat)
		var knee := _pivot(hip, Vector3(0, -THIGH, 0))
		_bone(knee, -SHIN, _mat)
		_joint(knee, 1.05)
		_foot(knee)
		hips[side] = hip; knees[side] = knee
		var sh := _pivot(neck, Vector3(side * SHOULDER_W, 0, 0))
		_joint(sh, 1.1)
		_bone(sh, -UPPER, _mat)
		var el := _pivot(sh, Vector3(0, -UPPER, 0))
		_bone(el, -FORE, _mat)
		_joint(el, 1.05)
		shoulders[side] = sh; elbows[side] = el
	_pivots = [torso, chest, neck, hips[-1.0], hips[1.0], knees[-1.0], knees[1.0], shoulders[-1.0], shoulders[1.0], elbows[-1.0], elbows[1.0]]
	hand_r = _pivot(elbows[1.0], Vector3(0, -FORE, 0))
	_joint(hand_r, 1.45)   # 주먹(운영자 그림 2026-09-28: 발과 주먹이 있는 실루엣)
	hand_l = _pivot(elbows[-1.0], Vector3(0, -FORE, 0))
	_joint(hand_l, 1.45)
	# 꾸미기용 소켓(운영자 2026-09-28: 캐릭터 꾸미기) — 모자·안경·가방·벨트는 여기에 자식으로 붙인다. 위치는 리그 기준이라 자세와 함께 움직인다
	socket_hat = _pivot(neck, Vector3(0, HEAD_Y - SHOULDER_Y + 0.02 + 0.15, 0))
	socket_face = _pivot(neck, Vector3(0, HEAD_Y - SHOULDER_Y + 0.02, 0.15))
	socket_back = _pivot(chest, Vector3(0, (SHOULDER_Y - HIP_Y) * 0.2, -R * 1.6))
	socket_belt = _pivot(pelvis, Vector3(0, 0.02, 0))

func _material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # 잉크 선처럼 평평하게(운영자: 2D 느낌) — 툰 명암을 주면 튜브로 보였다
	return m

func _pivot(parent: Node3D, at: Vector3) -> Node3D:
	var n := Node3D.new(); n.position = at; parent.add_child(n); return n

## 피벗에서 아래(-y) 또는 위(+y)로 len 만큼 뻗는 캡슐
func _bone(pivot: Node3D, len: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new(); cm.radius = R; cm.height = absf(len) + R * 2.0; cm.radial_segments = 10; cm.rings = 4
	mi.mesh = cm; mi.material_override = mat
	mi.position = Vector3(0, len / 2.0, 0)
	pivot.add_child(mi)

## 가로대 — 어깨(쇄골)와 골반: 팔다리가 몸통에 붙어 보이게 한다
func _bar(pivot: Node3D, half: float) -> void:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new(); cm.radius = R * 0.9; cm.height = half * 2.0 + R * 1.8; cm.radial_segments = 10; cm.rings = 4
	mi.mesh = cm; mi.material_override = _mat
	mi.rotation.z = PI / 2.0
	pivot.add_child(mi)

## 발 — 정강이 끝(무릎 피벗의 -SHIN)에서 앞(+z)으로 향한 납작한 상자. 발끝이 지면에 닿는 높이
func _foot(knee: Node3D) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(R * 2.1, R * 1.3, 0.13)
	mi.mesh = bm; mi.material_override = _mat
	mi.position = Vector3(0, -SHIN + R * 0.4, 0.045)
	knee.add_child(mi)

func _joint(pivot: Node3D, k: float) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = R * k * 1.15; sm.height = R * k * 2.3; sm.radial_segments = 10; sm.rings = 5
	mi.mesh = sm; mi.material_override = _mat
	pivot.add_child(mi)

var carrying: Node3D = null    # 오른손에 든 것(hand_r 의 자식)
var umbr_k := 0.0              # 우산 펴짐 0..1(CI run 76) — stick3d 가 자세로 올리고 내린다
var worn := {}   # slot → Node3D (hat · face · back)

## 입기 — 소켓에 붙인다. 같은 슬롯에 있던 건 돌려준다(없으면 null)
func wear(item: Node3D) -> Node3D:
	var slot := String(item.get_meta("slot", "hat"))
	var prev: Node3D = worn.get(slot, null)
	if prev: prev.get_parent().remove_child(prev)
	if item.get_parent(): item.get_parent().remove_child(item)
	var sock: Node3D = { "hat": socket_hat, "face": socket_face, "back": socket_back }[slot]
	sock.add_child(item); item.position = Vector3.ZERO; item.rotation = Vector3.ZERO; item.scale = Vector3.ONE
	if slot == "face": item.position = Vector3(0, 0.02, 0.03)
	worn[slot] = item
	if carrying == item:
		carrying = null; _promote()   # 왼손 것이 오른손으로(전엔 빈손인 채 왼손에 남아 못 내려놓았다 — 리뷰 버그)
	return prev

## 벗기 — 그 슬롯의 것을 떼어 돌려준다
func take_off(slot: String) -> Node3D:
	var it: Node3D = worn.get(slot, null)
	if it == null: return null
	it.get_parent().remove_child(it); worn.erase(slot)
	return it

## 손에 들기 — item 은 hand_r 의 자식이 되고, 놓으면 다시 세계로
var pocket: Array[Node3D] = []   # 두 번째·세 번째 것(왼손·허리) — 최대 셋(운영자 2026-09-28: "여러 개 주울 수 있어야")

## 손에 들기 — 새것이 오른손(맨 위), 들고 있던 건 왼손으로, 왼손 것은 허리로. 셋이면 못 든다(false)
func hold(item: Node3D) -> bool:
	if carrying and pocket.size() >= 2:
		return false
	if carrying:
		pocket.push_front(carrying)
	if item.get_parent(): item.get_parent().remove_child(item)
	hand_r.add_child(item)
	item.position = Vector3(0, -0.06, 0.06); item.rotation = Vector3(PI / 2.0, 0, 0) if item.has_meta("umb") else Vector3.ZERO   # 우산은 자루가 +z 로 누운 물건 — 손에선 -y(CI run 76)
	carrying = item
	_place_pocket()
	return true

## 왼손·허리 자리 다시 붙이기
func _place_pocket() -> void:
	for i in pocket.size():
		var it := pocket[i]
		var sock: Node3D = hand_l if i == 0 else socket_belt
		if it.get_parent() != sock:
			if it.get_parent(): it.get_parent().remove_child(it)
			sock.add_child(it)
		it.rotation = Vector3.ZERO
		it.position = Vector3(0, -0.06, 0.06) if i == 0 else Vector3(0.12, -0.02, -0.1)

## 맨 위 것을 놓는다 — 왼손 것이 오른손으로, 허리 것이 왼손으로 올라온다
func release(into: Node3D, at: Vector3) -> Node3D:
	var item := carrying
	if item == null:
		return null
	hand_r.remove_child(item)
	into.add_child(item)
	item.global_position = at; item.rotation = Vector3.ZERO
	if item.has_meta("umb"): (item.get_meta("umb") as Node3D).scale = Vector3(0.15, 1.0, 0.15); umbr_k = 0.0   # 손을 떠난 우산은 접힌다
	carrying = null
	_promote()
	return item

## 왼손 것이 오른손으로, 허리 것이 왼손으로
func _promote() -> void:
	if pocket.is_empty(): return
	var nxt: Node3D = pocket.pop_front()
	nxt.get_parent().remove_child(nxt); hand_r.add_child(nxt)
	nxt.position = Vector3(0, -0.06, 0.06); nxt.rotation = Vector3.ZERO
	carrying = nxt
	_place_pocket()
