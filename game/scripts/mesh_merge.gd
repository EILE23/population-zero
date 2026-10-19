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
		if not is_instance_valid(n) or n in exclude or n.has_meta("flatpack") or n.has_meta("kind") or n.has_meta("nomerge"): continue
		for ch in n.get_children(): stack.append(ch)
		if not (n is MeshInstance3D): continue
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.mesh.get_surface_count() == 0 or not mi.visible: continue
		if _has_live_child(mi): continue
		var mats: Array = []   # 면마다 — 팩 모델(Kenney)은 한 메시에 잎·줄기처럼 재질 여럿이다. 하나라도 못 합치면 통째로 둔다
		var ok := true
		for si in mi.mesh.get_surface_count():
			var mat: Material = mi.material_override if mi.material_override else (mi.get_surface_override_material(si) if mi.get_surface_override_material(si) else mi.mesh.surface_get_material(si))
			if not (mat is StandardMaterial3D) or (mat as StandardMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: ok = false; break
			mats.append(mat)
		if not ok: continue
		var xf := parent.global_transform.affine_inverse() * mi.global_transform
		var sz := mi.get_aabb().size * mi.global_transform.basis.get_scale()
		var detail := sz.y < 1.6 and maxf(sz.x, sz.z) < 3.0   # 잔것(울타리 토막·꽃·우편함·화분) — 따로 묶어 멀면 감추고 그림자를 안 드리운다
		for si in mats.size():
			var sm := mats[si] as StandardMaterial3D
			var key := _key(sm) + ("|d" if detail else "")
			if not groups.has(key):
				var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = [st, sm]
			(groups[key][0] as SurfaceTool).append_from(mi.mesh, si, xf)
		mi.visible = false; hidden += 1
	for key in groups:
		var st: SurfaceTool = groups[key][0]
		var out := MeshInstance3D.new(); out.mesh = st.commit(); out.material_override = groups[key][1]; out.name = "Merged"
		out.set_meta("hm", true)   # 구역 합치기(merge_district)가 다시 묶는다
		if String(key).ends_with("|d"): detail_lod(out); out.set_meta("detail", true)
		parent.add_child(out)
	return hidden

static func _key(sm: StandardMaterial3D) -> String:
	return "%s|%s|%s|%s|%s|%s" % [sm.albedo_color.to_html(), str(sm.albedo_texture.resource_path if sm.albedo_texture else ""), str(sm.uv1_scale), sm.uv1_triplanar, sm.uv1_world_triplanar, sm.vertex_color_use_as_albedo]

## 구역 하나의 집들을 다시 한 번 — 집마다 합친 메시(재질마다 하나 — 집 한 채가 그리기 20~30번, 마을 450채면 1만 3천 번이었다, 2026-10-19)를
## 구역 전체에서 재질마다 하나로. 집이 더 지어지면 다시 부른다(합친 것도 "hm" 이라 같이 묶인다). 묶은 수를 돌려준다
static func merge_district(parent: Node3D) -> int:
	var groups := {}
	for ch in parent.get_children():
		if not (ch is MeshInstance3D) or not ch.has_meta("hm") or not (ch as MeshInstance3D).visible or ch.is_queued_for_deletion(): continue
		var mi := ch as MeshInstance3D
		if not (mi.material_override is StandardMaterial3D) or mi.mesh == null: continue
		var key := _key(mi.material_override as StandardMaterial3D) + ("|d" if mi.has_meta("detail") else "")
		if not groups.has(key): groups[key] = [null, mi.material_override, []]
		(groups[key][2] as Array).append(mi)
	var n := 0
	for key in groups:
		var parts: Array = groups[key][2]
		if parts.size() < 2: continue
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for mi in parts:
			for si in (mi as MeshInstance3D).mesh.get_surface_count(): st.append_from((mi as MeshInstance3D).mesh, si, (mi as MeshInstance3D).transform)
		var out := MeshInstance3D.new(); out.mesh = st.commit(); out.material_override = groups[key][1]; out.name = "Merged"
		out.set_meta("hm", true)
		if String(key).ends_with("|d"): detail_lod(out); out.set_meta("detail", true)
		parent.add_child(out)
		for mi in parts: (mi as Node).queue_free()
		n += parts.size()
	return n

## 잔것 — 150m 밖은 안 그린다, 그림자 없음(위에서 내려다본 마을이 그리기 7800번·2백만 삼각형이었다, 2026-10-19)
static func detail_lod(g: GeometryInstance3D) -> void:
	g.visibility_range_end = 150.0; g.visibility_range_end_margin = 10.0; g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## 숨기면 안 되는 메시 — 불빛·글자·다른 움직이는 것을 아래에 달고 있다
static func _has_live_child(mi: Node) -> bool:
	for ch in mi.get_children():
		if ch is Light3D or ch is Label3D or ch is GPUParticles3D or ch is CPUParticles3D or ch is AnimatableBody3D: return true
	return false
