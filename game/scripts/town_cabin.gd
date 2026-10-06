class_name TownCabin
extends TownInterior
## 차 안(운영자 2026-10-06: "배틀그라운드처럼 차에 타면 차 내부를 볼 수도 있어야 하고, 차 안에서 어떤 동작들을 할 수도 있게", "GTA 나 배그처럼") —
##   자리: 내가 모는(또는 얻어 탄) 차엔 내 졸라맨이 운전석(조수석)에 앉아 보인다 — 전엔 몸을 숨겨 빈 차가 달렸다. 주민 운전사와 같은 drive 자세
##   시점(V): 3/4(마을) → 뒤따라가기(GTA) → 운전석 1인칭(배그 FPP: 운전대·계기판·속도계·백미러). 내리면 3/4 로
##   차 안 동작: 경적(Q — 앞 주민이 돌아본다), 전조등(L), 라디오(R — 방송국을 돌린다, 소리는 여기서 만든다), 창밖으로 손 흔들기·감정 표현(1~5)
## 키는 Esc 메뉴의 조작 화면에서 바꾼다(game_menu)

const VIEWS := ["Town view", "Chase view", "Driver's seat"]
const STATIONS := [
	{ "name": "Off" },
	{ "name": "POZ FM — the weather, read slowly", "notes": [60, 64, 67, 72, 67, 64], "beat": 0.42 },
	{ "name": "Hold Music 24/7", "notes": [57, 60, 64, 60, 62, 65, 69, 65], "beat": 0.32 },
	{ "name": "Municipal Jazz", "notes": [62, 65, 69, 72, 71, 67, 64, 60], "beat": 0.26 },
]

var car_view := 0
var _double: Stick3D = null      # 차 안의 내 졸라맨
var _dash: Node3D = null         # 운전대·계기판(차에 붙는다)
var _steer: Node3D = null
var _speedo: Label3D = null
var _car_hud: Label = null
var _lights_on := false
var _station := 0
var _radio: AudioStreamPlayer = null
var _pb: AudioStreamGeneratorPlayback = null
var _phase := 0.0
var _note_t := 0.0
var _note_i := 0
var _horn: AudioStreamWAV = null
var _chase := Vector3.ZERO

func _in_car() -> Car3D:
	return driving if driving else passenger

## 매 물리 프레임(town_social) — 자리·계기판·키
func _cabin_tick(now: float) -> void:
	var c := _in_car()
	if c == null:
		if _double: _leave_cabin()
		return
	if _double == null or _double.get_meta("car") != c: _enter_cabin(c)
	var seat_at := c.seat_pos() if driving else c.passenger_pos()
	_double.global_position = seat_at; _double.face(c.rotation.y + PI)
	_double.visible = car_view != 2
	if _double.pose_request == "" or _double.pose_request == "drive": _double.pose_request = "drive" if driving else ""
	if _steer: _steer.rotation.z = -float(c.input.get("steer", 0.0)) * 1.4 if driving else 0.0
	var kmh := int(absf(c.v) * 3.6)
	if _speedo: _speedo.text = "%d km/h" % kmh
	if _car_hud: _car_hud.text = "%d km/h  ·  %s  ·  %s" % [kmh, VIEWS[car_view], String(STATIONS[_station]["name"]) if _station > 0 else "Radio off"]
	_radio_fill()
	if get("typing"): return   # 채팅·메뉴 중(town_social)
	if Input.is_action_just_pressed("car_view"):
		car_view = (car_view + 1) % VIEWS.size(); say_toast(VIEWS[car_view])
	if Input.is_action_just_pressed("horn"): _honk(c)
	if Input.is_action_just_pressed("lights") and driving: _set_lights(c, not _lights_on)
	if Input.is_action_just_pressed("radio"): _tune((_station + 1) % STATIONS.size())
	for n in 5:
		if Input.is_action_just_pressed("emote_%d" % (n + 1)):
			_double.pose_request = "lwave"   # 운전석 창(왼쪽)으로 왼손을 흔든다
			get_tree().create_timer(2.0).timeout.connect(func() -> void: if _double: _double.pose_request = "")
			_wave_out(c)

func _enter_cabin(c: Car3D) -> void:
	_leave_cabin()
	_double = Stick3D.new(); _double.color = player.color; _double.head_color = player.head_color; _double.seated = true
	_double.set_meta("car", c); add_child(_double)
	_dash = Node3D.new(); c.add_child(_dash)
	var dark := _mat(Color("2a2a30")); var trim := _mat(Color("4a4a52"))
	_box(Vector3(1.25, 0.1, 0.3), Vector3(0, 0.42, -0.66), dark, false, _dash)   # 계기판 선반
	var wheel_root := Node3D.new(); wheel_root.position = Vector3(-0.28, 0.5, -0.5); wheel_root.rotation.x = -1.0; _dash.add_child(wheel_root)
	_steer = Node3D.new(); wheel_root.add_child(_steer)
	var tm := TorusMesh.new(); tm.inner_radius = 0.1; tm.outer_radius = 0.12; var w := MeshInstance3D.new(); w.mesh = tm; w.material_override = dark; w.rotation.x = PI / 2.0; _steer.add_child(w)
	_box(Vector3(0.2, 0.02, 0.025), Vector3.ZERO, trim, false, _steer)   # 바퀴살
	_speedo = Label3D.new(); _speedo.font_size = 40; _speedo.pixel_size = 0.0012; _speedo.modulate = Color("f2c84b"); _speedo.outline_size = 0
	_speedo.position = Vector3(-0.28, 0.5, -0.62); _speedo.rotation.x = -0.5; _dash.add_child(_speedo)
	var mirror := _box(Vector3(0.22, 0.06, 0.02), Vector3(0, 0.98, -0.5), _mat(Color("bfe3f2")), false, _dash); mirror.rotation.x = 0.2
	var radio_lb := Label3D.new(); radio_lb.text = "RADIO"; radio_lb.font_size = 24; radio_lb.pixel_size = 0.0012; radio_lb.modulate = Color("ad7096"); radio_lb.position = Vector3(0.0, 0.5, -0.62); radio_lb.rotation.x = -0.5; _dash.add_child(radio_lb)
	_car_hud = Label.new(); _car_hud.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT); _car_hud.grow_horizontal = Control.GROW_DIRECTION_BEGIN; _car_hud.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_car_hud.position = Vector2(-14, -34); _car_hud.add_theme_color_override("font_color", Color("1b0c15")); _car_hud.add_theme_color_override("font_outline_color", Color("f7f4ef")); _car_hud.add_theme_constant_override("outline_size", 6)
	(get_node("UI") as CanvasLayer).add_child(_car_hud)
	if not get_meta("cabin_told", false):
		set_meta("cabin_told", true)
		say_toast("%s: view  ·  %s: horn  ·  %s: lights  ·  %s: radio" % [GameMenu.key_of("car_view"), GameMenu.key_of("horn"), GameMenu.key_of("lights"), GameMenu.key_of("radio")])

func _leave_cabin() -> void:
	var c: Variant = _double.get_meta("car") if _double else null
	if _double: _double.queue_free(); _double = null
	if _dash and is_instance_valid(_dash): _dash.queue_free()
	_dash = null; _steer = null; _speedo = null
	if _car_hud: _car_hud.queue_free(); _car_hud = null
	if c is Car3D and is_instance_valid(c): _set_lights(c, false)
	_tune(0); car_view = 0

## 시점 — town3d 가 3/4 카메라를 놓은 뒤에 덮어쓴다
func _cabin_cam(delta: float) -> void:
	var c := _in_car()
	if c == null or car_view == 0: return
	var fwd := -c.global_transform.basis.z; var up := Vector3.UP
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	if car_view == 1:
		var want := c.global_position - fwd * 6.5 + up * 2.6
		if _chase == Vector3.ZERO or _chase.distance_to(want) > 30.0: _chase = want
		_chase = _chase.lerp(want, minf(1.0, delta * 6.0))   # 3/4 카메라와 따로 — 같은 cam 을 둘이 끌면 떨렸다
		cam.global_position = _chase
		cam.look_at(c.global_position + fwd * 4.0 + up * 0.8, Vector3.UP)
	else:
		var head := (c.seat_pos() if driving else c.passenger_pos()) + up * 0.82 - fwd * 0.12   # 눈높이 — 운전대·계기판이 아래쪽에 걸리게
		cam.global_position = head
		cam.look_at(head + fwd * 10.0 - up * 1.7 + c.global_transform.basis.x * float(c.input.get("steer", 0.0)) * 1.2, Vector3.UP)

# ── 동작 ──
func _honk(c: Car3D) -> void:
	if _horn == null: _horn = _tone_wav([420.0, 523.0], 0.45)
	var p := AudioStreamPlayer3D.new(); p.stream = _horn; p.unit_size = 8.0; c.add_child(p); p.play()
	p.finished.connect(p.queue_free)
	var fwd := -c.global_transform.basis.z
	for r in residents:
		var to: Vector3 = r.global_position - c.global_position
		if to.length() < 12.0 and r.state != "drive":
			r.fig.face(atan2(-to.x, -to.z))
			if fwd.dot(to.normalized()) > 0.5 and to.length() < 7.0: r.say(["Oi.", "All right, all right.", "Patience.", "I see you."][randi() % 4], 1.4)

func _wave_out(c: Car3D) -> void:
	for r in residents:
		if r.state != "drive" and r.global_position.distance_to(c.global_position) < 8.0:
			r.fig.face(atan2(c.global_position.x - r.global_position.x, c.global_position.z - r.global_position.z))
			r.say(["Hello.", "Morning.", "Mind the road."][randi() % 3], 1.4)
			return

func _set_lights(c: Car3D, on: bool) -> void:
	_lights_on = on
	for n in c.get_children():
		if n.has_meta("headlight"): n.queue_free()
	if not on: return
	for s in [-0.42, 0.42]:
		var l := SpotLight3D.new(); l.set_meta("headlight", true); l.light_color = Color("fff2cc"); l.light_energy = 2.2; l.spot_range = 20.0; l.spot_angle = 28.0
		l.position = Vector3(s, 0.45, -1.15); c.add_child(l)   # 앞(−z)을 비춘다 — SpotLight 는 −z 로 비춘다

func _tune(i: int) -> void:
	_station = i
	if i == 0:
		if _radio: _radio.stop()
		return
	if _radio == null:
		_radio = AudioStreamPlayer.new(); var g := AudioStreamGenerator.new(); g.mix_rate = 22050.0; g.buffer_length = 0.3; _radio.stream = g; _radio.volume_db = -14.0; add_child(_radio)
	_radio.play(); _pb = _radio.get_stream_playback() as AudioStreamGeneratorPlayback
	_note_i = 0; _note_t = 0.0
	say_toast(String(STATIONS[i]["name"]))

## 라디오 소리 — 방송국마다 음 몇 개를 박자에 맞춰 돌린다(부드러운 사인 + 배음 조금). 버퍼가 빈 만큼만 채운다
func _radio_fill() -> void:
	if _station == 0 or _pb == null or not _radio.playing: return
	var st: Dictionary = STATIONS[_station]
	var notes: Array = st["notes"]; var beat: float = st["beat"]
	var rate := 22050.0
	var n := _pb.get_frames_available()
	for i in n:
		_note_t += 1.0 / rate
		if _note_t >= beat: _note_t -= beat; _note_i = (_note_i + 1) % notes.size()
		var f := 440.0 * pow(2.0, (float(notes[_note_i]) - 69.0) / 12.0)
		_phase = fmod(_phase + f / rate, 1.0)
		var env := clampf(1.0 - _note_t / beat, 0.0, 1.0)
		var s := (sin(_phase * TAU) * 0.7 + sin(_phase * TAU * 2.0) * 0.2) * 0.35 * (0.3 + 0.7 * env)
		_pb.push_frame(Vector2(s, s))

static func _tone_wav(freqs: Array, secs: float) -> AudioStreamWAV:
	var rate := 22050; var count := int(rate * secs)
	var data := PackedByteArray(); data.resize(count * 2)
	for i in count:
		var t := float(i) / rate; var v := 0.0
		for f in freqs: v += (1.0 if fmod(t * float(f), 1.0) < 0.5 else -1.0) * 0.18
		v *= clampf(minf(t / 0.02, (secs - t) / 0.05), 0.0, 1.0)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w
