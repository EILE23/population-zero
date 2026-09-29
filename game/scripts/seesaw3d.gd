class_name Seesaw3D
extends Node3D
## 시소(운영자 2026-09-29: "시소도 동작해야하고 시소로 점프 높게 뛸 수도") — 재사용 부품(운동회 미니게임도 쓴다).
## 판 하나가 받침 위에서 기운다. 양 끝에 한 명씩(사람 "player" 또는 주민 노드). 물리: 무게 차이로 기울고, 낮은 쪽이 SPACE 로 박차면 반대로,
## 판이 땅에 쾅 닿는 순간의 각속도만큼 높은 쪽 사람이 튀어 오른다(launch). 끝에 뛰어내려 밟아도(stomp) 반대쪽이 튄다.
## angle > 0 이면 오른쪽(+x) 끝이 올라간다.

const L := 1.4            # 받침에서 끝까지(m)
const LIMIT := 0.34       # 최대 기울기(rad) — 끝이 땅에 닿는 각
const PIVOT_Y := 0.5

var angle := LIMIT
var omega := 0.0
var riders := [null, null]   # 0 = 왼쪽(-x), 1 = 오른쪽(+x)
var _plank: Node3D
var _launched: Array = []    # 이번 프레임 튀어 오른 {who, side, vy}

func build(wood: Material, iron: Material) -> void:
	var base := MeshInstance3D.new(); var bm := CylinderMesh.new(); bm.top_radius = 0.08; bm.bottom_radius = 0.22; bm.height = PIVOT_Y; bm.radial_segments = 4
	base.mesh = bm; base.material_override = iron; base.position.y = PIVOT_Y / 2.0; add_child(base)
	_plank = Node3D.new(); _plank.position.y = PIVOT_Y; add_child(_plank)
	var pm := MeshInstance3D.new(); var pb := BoxMesh.new(); pb.size = Vector3(L * 2.0 + 0.1, 0.08, 0.3); pm.mesh = pb; pm.material_override = wood; _plank.add_child(pm)
	for sx in [-1.0, 1.0]:
		var h := MeshInstance3D.new(); var hb := BoxMesh.new(); hb.size = Vector3(0.05, 0.25, 0.36); h.mesh = hb; h.material_override = iron
		h.position = Vector3(sx * (L - 0.35), 0.16, 0); _plank.add_child(h)   # 손잡이
	var ab := AnimatableBody3D.new(); var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = pb.size; cs.shape = bs; ab.add_child(cs); _plank.add_child(ab)
	_plank.rotation.z = angle

## 끝 자리(앉는 곳) 세계 좌표
func seat_pos(side: int) -> Vector3:
	var sx := -L if side == 0 else L
	var local := Vector3(sx * cos(angle) * 0.92, PIVOT_Y + sx * sin(angle) * 0.92 + 0.04, 0)
	return global_transform * local

func side_near(p: Vector3) -> int:
	var lp := global_transform.affine_inverse() * p
	return 0 if lp.x < 0.0 else 1

func sit(who, side: int) -> bool:
	if riders[side] != null: return false
	riders[side] = who; return true

func leave(who) -> void:
	for i in 2: if riders[i] == who: riders[i] = null

func side_of(who) -> int:
	for i in 2: if riders[i] == who: return i
	return -1

## 낮은 쪽이면 박차고 올라간다(높은 쪽이 누르면 무시)
func push(side: int) -> void:
	var low := (side == 1 and angle < -LIMIT * 0.6) or (side == 0 and angle > LIMIT * 0.6)
	if low: omega += (3.6 if side == 1 else -3.6)

## 끝을 위에서 밟음(뛰어내려 착지) — 속도만큼 그쪽을 내리꽂는다
func stomp(side: int, down_speed: float) -> void:
	omega += (-1.0 if side == 1 else 1.0) * clampf(down_speed, 0.0, 12.0) * 0.55

## 매 프레임. 튀어 오른 사람 목록을 돌려준다
func step(delta: float) -> Array:
	_launched = []
	var wl := 1.0 if riders[0] != null else 0.0
	var wr := 1.0 if riders[1] != null else 0.0
	var torque := (wl - wr) * 5.0
	if wl == 0.0 and wr == 0.0: torque = 1.5 * signf(angle if absf(angle) > 0.01 else 1.0)   # 빈 시소는 한쪽으로 쉰다
	omega += torque * delta
	omega *= 1.0 - 0.8 * delta
	angle += omega * delta
	if absf(angle) > LIMIT:
		var hit := absf(omega)
		var down_side := 1 if angle < 0.0 else 0     # 땅에 닿은 쪽
		angle = clampf(angle, -LIMIT, LIMIT)
		if hit > 1.2:
			var up := 1 - down_side
			if riders[up] != null:
				_launched.append({ "who": riders[up], "side": up, "vy": hit * L * 2.4 })
				riders[up] = null
		omega = -omega * 0.25   # 쾅 — 조금 튕긴다
	_plank.rotation.z = angle
	return _launched
