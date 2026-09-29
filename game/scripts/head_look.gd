class_name HeadLook
extends SkeletonModifier3D
## 외부 모델의 머리를 사람 쪽으로 돌린다(운영자 2026-09-29: 동물이 애교도 부려야 — 달려와서 멍하니 서 있지 않고 쳐다본다).
## 애니메이션이 매 프레임 머리 포즈를 쓰고 난 뒤(모디파이어 단계) 요·피치를 덧씌운다. 한계 ±70°·±35°, 부드럽게 켜고 끈다.

var target := Vector3.ZERO
var looking := false   # (active 는 SkeletonModifier3D 의 네이티브 속성이라 못 쓴다)
var weight := 0.0
var bone := -1

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null: return
	if bone < 0:
		bone = sk.find_bone("Head")
		if bone < 0: return
	weight = move_toward(weight, 1.0 if looking else 0.0, 0.05)
	if weight <= 0.001: return
	var pose := sk.get_bone_global_pose(bone)
	var to_local: Vector3 = sk.global_transform.affine_inverse() * target - pose.origin
	if to_local.length() < 0.05: return
	# 몸의 앞(+z, 뼈대 공간)에 대한 요·피치
	var yaw := clampf(atan2(to_local.x, to_local.z), -1.2, 1.2)
	var pitch := clampf(-atan2(to_local.y, Vector2(to_local.x, to_local.z).length()), -0.6, 0.6)
	var rot := Basis(Vector3.UP, yaw * weight) * Basis(Vector3.RIGHT, pitch * weight)
	var new_global := Transform3D(rot * pose.basis, pose.origin)
	var parent := sk.get_bone_parent(bone)
	var parent_global := sk.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
	var local := parent_global.affine_inverse() * new_global
	sk.set_bone_pose_rotation(bone, Quaternion(local.basis.orthonormalized()))
