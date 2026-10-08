class_name MeshMerge
extends RefCounted
## 집 한 채를 그리기 몇 번으로(성능 — 상자 수십 개짜리 집이 각자 그리기 한 번이라 마을이 커지면 그리기가 수천 번이었다).
## 집이 다 지어진 뒤 그 집의 움직이지 않는 상자·원기둥을 "같은 생김새의 재질"(빛깔·무늬·UV·삼면 투영)끼리 한 메시로 합친다.
## 원래 노드는 숨기기만 한다(충돌·자리·굴뚝 연기 기준점 같은 참조는 그대로) — 문짝(경첩 아래)·물건·불빛을 단 메시는 건드리지 않는다

static func merge(parent: Node3D, nodes: Array, exclude: Array) -> int:
	var groups := {}   # 재질 열쇠 -> [SurfaceTool, 재질]
	var hidden := 0
	var stack: Array = nodes.duplicate()
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if not is_instance_valid(n) or n in exclude or n.has_meta("flatpack") or n.has_meta("kind"): continue
		for ch in n.get_children(): stack.append(ch)
		if not (n is MeshInstance3D): continue
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.mesh.get_surface_count() != 1 or not mi.visible: continue
		if _has_live_child(mi): continue
		var mat: Material = mi.material_override if mi.material_override else mi.mesh.surface_get_material(0)
		if not (mat is StandardMaterial3D): continue
		var sm := mat as StandardMaterial3D
		if sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: continue
		var key := "%s|%s|%s|%s|%s|%s" % [sm.albedo_color.to_html(), str(sm.albedo_texture.resource_path if sm.albedo_texture else ""), str(sm.uv1_scale), sm.uv1_triplanar, sm.uv1_world_triplanar, sm.vertex_color_use_as_albedo]
		if not groups.has(key):
			var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key] = [st, sm]
		(groups[key][0] as SurfaceTool).append_from(mi.mesh, 0, parent.global_transform.affine_inverse() * mi.global_transform)
		mi.visible = false; hidden += 1
	for key in groups:
		var st: SurfaceTool = groups[key][0]
		var out := MeshInstance3D.new(); out.mesh = st.commit(); out.material_override = groups[key][1]; out.name = "Merged"
		parent.add_child(out)
	return hidden

## 숨기면 안 되는 메시 — 불빛·글자·다른 움직이는 것을 아래에 달고 있다
static func _has_live_child(mi: Node) -> bool:
	for ch in mi.get_children():
		if ch is Light3D or ch is Label3D or ch is GPUParticles3D or ch is CPUParticles3D or ch is AnimatableBody3D: return true
	return false
