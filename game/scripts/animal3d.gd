class_name Animal3D
extends Node3D
## 외부 모델 동물(운영자 2026-09-28: "외부 에셋 같은 걸 따로 구하는 게 좋을 거 같은데") — CC0 glTF(Quaternius Ultimate Animated Animals)를
## 불러 마을이 쓰는 같은 상태 API(state·speed·look·sulk·act)로 애니메이션을 고른다. 절차 리그(Quad3D·Bird3D)와 바꿔 끼울 수 있게 이름을 맞췄다.
## 모델별 스케일·앞방향·상태→클립 표는 SPECS 에. 새 동물은 표 한 줄.

const SPECS := {
	"dog":    { "path": "res://assets/models/animals/quaternius/ShibaInu.gltf", "scale": 0.155, "yaw": 0.0, "walk_speed": 1.4, "run_speed": 3.2,
		"map": { "idle": "Idle", "idle2": "Idle_2", "walk": "Walk", "run": "Gallop", "stalk": "Walk", "sit": "Idle_2", "lie": "Idle_2_HeadLow", "sniff": "Idle_2_HeadLow",
			"eat": "Eating", "hurt": "Idle_HitReact1", "bite": "Attack", "bow": "Idle_2_HeadLow", "roll": "Death", "stun": "Death", "stretch": "Idle_2_HeadLow", "yawn": "Idle_2", "pet": "Idle_2_HeadLow", "shake": "Idle_HitReact2", "scratch": "Idle_2", "jump": "Gallop_Jump",
			"nuzzle": "Idle_2_HeadLow", "hop": "Gallop_Jump", "beg": "Idle_2" } },
	"fox":    { "path": "res://assets/models/animals/quaternius/Fox.gltf", "scale": 0.15, "yaw": 0.0, "walk_speed": 1.4, "run_speed": 3.6,
		"map": { "idle": "Idle", "idle2": "Idle_2", "walk": "Walk", "run": "Gallop", "stalk": "Walk", "sit": "Idle_2", "lie": "Idle_2_HeadLow", "sniff": "Idle_2_HeadLow",
			"eat": "Eating", "hurt": "Idle_HitReact1", "bite": "Attack", "stretch": "Idle_2_HeadLow", "yawn": "Idle_2", "jump": "Gallop_Jump", "stun": "Death" } },
	"wolf":   { "path": "res://assets/models/animals/quaternius/Wolf.gltf", "scale": 0.19, "yaw": 0.0, "walk_speed": 1.5, "run_speed": 4.0,
		"map": { "idle": "Idle", "idle2": "Idle_2", "walk": "Walk", "run": "Gallop", "stalk": "Walk", "lie": "Idle_2_HeadLow", "eat": "Eating", "hurt": "Idle_HitReact1", "bite": "Attack", "stun": "Death" } },
	"deer":   { "path": "res://assets/models/animals/quaternius/Deer.gltf", "scale": 0.2, "yaw": 0.0, "walk_speed": 1.5, "run_speed": 4.5,
		"map": { "idle": "Idle", "idle2": "Idle_2", "walk": "Walk", "run": "Gallop", "lie": "Idle_Headlow", "eat": "Eating", "hurt": "Idle_HitReact1", "bite": "Attack_Headbutt", "jump": "Gallop_Jump", "stun": "Death" } },
}

var kind := "dog"
var state := "idle"           # idle | walk | run | stalk | sit | lie | … (act 로 잠깐 바뀐다)
var speed := 0.0              # m/s — 걷기·달리기 클립 속도에 맞춘다
var look := false
var look_at_pos := Vector3.ZERO
var carry := false            # 입에 문 채(여우 노획, CI run 69) — town_systems._fox 가 켠다
var head: Node3D              # 입 앞(물건을 무는 자리) — Head 뼈에 붙은 BoneAttachment3D
var head_r := 0.1
var sulk := false             # 맞은 뒤(귀·꼬리는 모델이라 못 내리지만 습성은 town 이 처리)
var flying := false           # 새 호환
var swimming := false
var feed := false

var _spec: Dictionary = {}
var _ap: AnimationPlayer
var _model: Node3D
var _act_until := -1.0
var _idle_next := 4.0
var _bang: Label3D
var _bang_until := -1.0
var _cur := ""
var _look: HeadLook
var _roll_t := -1.0          # 뒹굴기 진행(초), -1 = 아님
var _pivot: Node3D
var _roll_back := false
var _stun_t := -1.0      # 뒹굴기 후반: Death 클립을 거꾸로 돌려 일어나는 중
var _pitch := 0.0            # 놀자 자세: 앞을 낮춘다(모델 노드 기울임)

## 모델을 불러 크기·방향을 맞춘다. 절차 리그와 같은 시그니처가 아니므로 town_build 가 kind 로 고른다
func setup(k: String) -> void:
	kind = k
	_spec = SPECS[k]
	var ps: PackedScene = load(_spec["path"])
	_model = ps.instantiate()
	_model.scale = Vector3.ONE * float(_spec["scale"])
	_model.rotation.y = float(_spec["yaw"])   # 모델의 앞을 +z(마을의 앞)로
	_pivot = Node3D.new(); add_child(_pivot); _pivot.add_child(_model)   # 뒹굴 때 몸 중심을 축으로 돌리려고(발끝 원점으로 돌리면 땅속으로 들어갔다)
	_ap = _model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for nm in _ap.get_animation_list():
		var an := _ap.get_animation(nm)
		an.loop_mode = Animation.LOOP_LINEAR if not (nm.to_lower() in ["death", "dead"] or "HitReact" in nm or nm.begins_with("Attack") or nm == "attack" or "Jump" in nm) else Animation.LOOP_NONE
	_bang = Label3D.new(); _bang.text = "!"; _bang.font_size = 64; _bang.pixel_size = 0.003; _bang.modulate = Color("ff2d55")
	_bang.outline_size = 10; _bang.outline_modulate = Color("f7f4ef"); _bang.billboard = BaseMaterial3D.BILLBOARD_ENABLED; _bang.no_depth_test = true
	_bang.position = Vector3(0, height() + 0.3, 0); _bang.visible = false; add_child(_bang)
	var sks := _model.find_children("*", "Skeleton3D", true, false)
	head = Node3D.new()
	if not sks.is_empty() and (sks[0] as Skeleton3D).find_bone("Head") >= 0:
		var ba := BoneAttachment3D.new(); ba.bone_name = "Head"; (sks[0] as Skeleton3D).add_child(ba)
		var inv := Node3D.new(); inv.scale = Vector3.ONE / float(_spec["scale"]); ba.add_child(inv); inv.add_child(head)   # 모델 스케일을 되돌려 물건이 제 크기로
	else:
		head.position = Vector3(0, height() * 0.8, 0.3); add_child(head)
	# 머리 따라보기(HeadLook)는 얼굴이 찌그러져(운영자 2026-09-29) 시트로 검증하기 전엔 붙이지 않는다
	_play("idle")

## 모델 높이(m) — 이름표·"!" 위치용
func height() -> float:
	var lo := 1e9; var hi := -1e9
	for sk in _model.find_children("*", "Skeleton3D", true, false):
		var s := sk as Skeleton3D
		for i in s.get_bone_count():
			var y: float = (s.get_bone_global_rest(i)).origin.y
			lo = minf(lo, y); hi = maxf(hi, y)
	return (hi - lo) * float(_spec["scale"]) if hi > lo else 0.4

## 잠깐의 동작 — 클립 길이만큼 하고 idle 로
func act(name: String) -> void:
	if not _spec["map"].has(name): return
	state = name
	_ap.speed_scale = 1.0
	_play(name, true)
	_act_until = Time.get_ticks_msec() / 1000.0 + _ap.current_animation_length
	if name == "roll":
		# 뒹굴기(운영자 2026-09-29: 다리를 접으며 자연스럽게): Death 클립으로 옆으로 눕고(다리가 접힌다) → 몸 중심 축으로 배를 위로 돌려 버둥 → Death 를 거꾸로 돌려 일어난다
		_roll_t = 0.0; _roll_back = false; _act_until = Time.get_ticks_msec() / 1000.0 + 3.4
		var body_h := height()
		_pivot.position.y = body_h * 0.14; _model.position.y = -body_h * 0.14
	if name == "stun":
		# 기절: 쓰러진 채(Death 끝 프레임) 1.6초 → 거꾸로 돌려 일어난다
		_stun_t = 0.0; _act_until = Time.get_ticks_msec() / 1000.0 + _ap.current_animation_length * 2.0 + 1.6
	if name == "bow": _act_until = Time.get_ticks_msec() / 1000.0 + 1.4
	if name == "beg": _act_until = Time.get_ticks_msec() / 1000.0 + 1.8
	if name == "hurt": _bang.visible = true; _bang_until = Time.get_ticks_msec() / 1000.0 + 0.8

func _play(key: String, restart := false) -> void:
	var clip: String = _spec["map"].get(key, _spec["map"]["idle"])
	if clip == _cur and not restart: return
	_cur = clip
	_ap.play(clip, 0.18)
	if restart: _ap.seek(0.0, true)

func _process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if _bang.visible and now > _bang_until: _bang.visible = false
	if _look: _look.looking = look and state != "hurt"; _look.target = look_at_pos
	var moving := speed > 0.05
	# 뒹굴기·놀자 자세는 모델 노드를 굴리고 기울여 만든다(클립엔 없다)
	if _roll_t >= 0.0:
		_roll_t += delta
		var death_len := _ap.get_animation(_spec["map"]["roll"]).length
		var mid := clampf((_roll_t - death_len) / 0.35, 0.0, 1.0) * clampf((death_len + 1.2 - _roll_t) / 0.35, 0.0, 1.0)   # 눕고 난 뒤 ~1.2초 동안만 배를 위로
		_pivot.rotation.z = smoothstep(0.0, 1.0, mid) * sin(_roll_t * 8.0) * 0.14   # 배를 위로 기울이며 좌우로 버둥(부호는 시트로 확인)
		if not _roll_back and _roll_t >= death_len + 1.2:
			_roll_back = true; _ap.play(_spec["map"]["roll"], -1, -1.0, true)   # 거꾸로 재생 → 일어난다
		if _roll_t >= death_len * 2.0 + 1.2:
			_roll_t = -1.0; _pivot.rotation.z = 0.0; _pivot.position.y = 0.0; _model.position.y = 0.0; _ap.speed_scale = 1.0
	if _stun_t >= 0.0:
		_stun_t += delta
		var dl := _ap.get_animation(_spec["map"]["stun"]).length
		if _stun_t >= dl + 1.6 and _ap.speed_scale > 0.0: _ap.play(_spec["map"]["stun"], -1, -1.0, true)
		if _stun_t >= dl * 2.0 + 1.6: _stun_t = -1.0; _ap.speed_scale = 1.0
	_pitch = lerpf(_pitch, (0.35 if state == "bow" else (-0.45 if state == "beg" else 0.0)), minf(1.0, delta * 8.0))
	_model.rotation.x = _pitch
	if _act_until > 0.0:
		if moving and speed > 0.3 and not (state in ["bite", "stun"]):
			_act_until = -1.0; state = "walk"; _roll_t = -1.0; _pivot.rotation.z = 0.0; _pivot.position.y = 0.0; _model.position.y = 0.0; _ap.speed_scale = 1.0   # 움직이면 동작을 접는다(맞은 개가 굳은 채 미끄러지던 리뷰 버그)
		elif now < _act_until: return
		else: _act_until = -1.0; state = "idle"
	if flying: _play("fly"); _ap.speed_scale = 1.6; return
	if swimming and moving: _play("swim"); _ap.speed_scale = 0.9; return
	if feed: _play("feed"); _ap.speed_scale = 1.0; return
	match state:
		"walk", "run", "stalk":
			if not moving:
				_play("idle"); _ap.speed_scale = 1.0
			elif state == "run" or speed > float(_spec["walk_speed"]) * 1.6:
				_play("run"); _ap.speed_scale = clampf(speed / float(_spec["run_speed"]), 0.7, 1.4)
			else:
				_play("walk"); _ap.speed_scale = clampf(speed / float(_spec["walk_speed"]), 0.6, 1.5) * (0.6 if state == "stalk" else 1.0)
		"idle":
			_ap.speed_scale = 1.0
			_idle_next -= delta
			if _idle_next <= 0.0:
				_idle_next = randf_range(4.0, 9.0)
				if _spec["map"].has("idle2") and randf() < 0.5: _play("idle2", true)
				else: _play("idle", true)
		_:
			_play(state); _ap.speed_scale = 1.0
