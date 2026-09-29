class_name Animal3D
extends Node3D
## 외부 모델 동물(운영자 2026-09-28: "외부 에셋 같은 걸 따로 구하는 게 좋을 거 같은데") — CC0 glTF(Quaternius Ultimate Animated Animals)를
## 불러 마을이 쓰는 같은 상태 API(state·speed·look·sulk·act)로 애니메이션을 고른다. 절차 리그(Quad3D·Bird3D)와 바꿔 끼울 수 있게 이름을 맞췄다.
## 모델별 스케일·앞방향·상태→클립 표는 SPECS 에. 새 동물은 표 한 줄.

const SPECS := {
	"dog":    { "path": "res://assets/models/animals/quaternius/ShibaInu.gltf", "scale": 0.155, "yaw": 0.0, "walk_speed": 1.4, "run_speed": 3.2,
		"map": { "idle": "Idle", "idle2": "Idle_2", "walk": "Walk", "run": "Gallop", "stalk": "Walk", "sit": "Idle_2", "lie": "Idle_2_HeadLow", "sniff": "Idle_2_HeadLow",
			"eat": "Eating", "hurt": "Idle_HitReact1", "bite": "Attack", "bow": "Idle_2", "roll": "Idle_HitReact2", "stretch": "Idle_2_HeadLow", "yawn": "Idle_2", "pet": "Idle_2", "shake": "Idle_HitReact2", "scratch": "Idle_2", "jump": "Gallop_Jump" } },
	"fox":    { "path": "res://assets/models/animals/quaternius/Fox.gltf", "scale": 0.15, "yaw": 0.0, "walk_speed": 1.4, "run_speed": 3.6,
		"map": { "idle": "Idle", "idle2": "Idle_2", "walk": "Walk", "run": "Gallop", "stalk": "Walk", "sit": "Idle_2", "lie": "Idle_2_HeadLow", "sniff": "Idle_2_HeadLow",
			"eat": "Eating", "hurt": "Idle_HitReact1", "bite": "Attack", "stretch": "Idle_2_HeadLow", "yawn": "Idle_2", "jump": "Gallop_Jump" } },
	"wolf":   { "path": "res://assets/models/animals/quaternius/Wolf.gltf", "scale": 0.19, "yaw": 0.0, "walk_speed": 1.5, "run_speed": 4.0,
		"map": { "idle": "Idle", "idle2": "Idle_2", "walk": "Walk", "run": "Gallop", "stalk": "Walk", "lie": "Idle_2_HeadLow", "eat": "Eating", "hurt": "Idle_HitReact1", "bite": "Attack" } },
	"deer":   { "path": "res://assets/models/animals/quaternius/Deer.gltf", "scale": 0.2, "yaw": 0.0, "walk_speed": 1.5, "run_speed": 4.5,
		"map": { "idle": "Idle", "idle2": "Idle_2", "walk": "Walk", "run": "Gallop", "lie": "Idle_Headlow", "eat": "Eating", "hurt": "Idle_HitReact1", "bite": "Attack_Headbutt", "jump": "Gallop_Jump" } },
}

var kind := "dog"
var state := "idle"           # idle | walk | run | stalk | sit | lie | … (act 로 잠깐 바뀐다)
var speed := 0.0              # m/s — 걷기·달리기 클립 속도에 맞춘다
var look := false
var look_at_pos := Vector3.ZERO
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

## 모델을 불러 크기·방향을 맞춘다. 절차 리그와 같은 시그니처가 아니므로 town_build 가 kind 로 고른다
func setup(k: String) -> void:
	kind = k
	_spec = SPECS[k]
	var ps: PackedScene = load(_spec["path"])
	_model = ps.instantiate()
	_model.scale = Vector3.ONE * float(_spec["scale"])
	_model.rotation.y = float(_spec["yaw"])   # 모델의 앞을 +z(마을의 앞)로
	add_child(_model)
	_ap = _model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for nm in _ap.get_animation_list():
		var an := _ap.get_animation(nm)
		an.loop_mode = Animation.LOOP_LINEAR if not (nm.to_lower() in ["death", "dead"] or "HitReact" in nm or nm.begins_with("Attack") or nm == "attack" or "Jump" in nm) else Animation.LOOP_NONE
	_bang = Label3D.new(); _bang.text = "!"; _bang.font_size = 64; _bang.pixel_size = 0.003; _bang.modulate = Color("ff2d55")
	_bang.outline_size = 10; _bang.outline_modulate = Color("f7f4ef"); _bang.billboard = BaseMaterial3D.BILLBOARD_ENABLED; _bang.no_depth_test = true
	_bang.position = Vector3(0, height() + 0.3, 0); _bang.visible = false; add_child(_bang)
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
	_play(name, true)
	_act_until = Time.get_ticks_msec() / 1000.0 + _ap.current_animation_length / _ap.speed_scale
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
	if _act_until > 0.0:
		if now < _act_until: return
		_act_until = -1.0; state = "idle"
	var moving := speed > 0.05
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
