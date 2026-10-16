class_name ClimbPoses
extends RefCounted
## Climb 팩 자세의 갈림길(코드 정리, run 159): stick3d_poses.gd 가 492줄이라 자세를 하나도 더 못 넣었다 — run 70 에 stick3d.gd 에서 떼어 냈던 것과 같은 이유.
## 탑의 마흔여섯 자세(run 118 updraft 의 `glide` 부터 run 164 외줄의 `tiptoe` 까지)는 각자 제 파일(stick3d_<pose>.gd)에 있고, 여기는 이름만 보고 그리로 넘긴다.
## StickPoses.lean 이 한 번, StickPoses.limbs 의 `_:` 가지가 한 번, owns_right_arm 이 한 번 부른다. 자세 이름·타이밍은 하나도 바꾸지 않았다 — 점검(probe_*)은 전과 같은 값을 본다.
## 새 Climb 자세는 여기 POSES 와 세 함수에 한 줄씩, stick3d.gd 의 CI_POSES 에 한 줄 — stick3d_poses.gd 는 손대지 않는다.

## 탑의 자세들(들어온 순서) — owns_right_arm 의 목록이기도 하다(loll·trail·bound 는 뺀다, 아래)
const POSES := ["glide", "bounce", "lurch", "sway", "ride", "duck", "tread", "dangle", "wade", "rail", "haul", "part", "heave", "kite", "shunt", "cling", "turn", "loll", "trail", "bound", "tug", "board", "zip", "fly", "perch", "shimmy", "crank", "unroll", "balance", "sink", "curl", "stomp", "puff", "yank", "spin", "scale", "peer", "hurdle", "wheel", "squint", "wipe", "brush", "hark", "plant", "limber", "tiptoe"]
## 해먹(run 135)·풍향계 리본(run 136)·다이빙 판(run 137)은 처음부터 오른팔 목록에 없었다 — 든 것을 오른손에 그대로 둔다(바뀐 것 없음)
const FREE_RIGHT := ["loll", "trail", "bound"]

## 상체 기울기(와 골반 높이) — 제 자세가 아니면 받은 lean 을 그대로 돌려준다
static func lean(f: Stick3D, p: String, lean: float) -> float:
	match p:
		"glide": return GlidePoses.lean(f)       # 상승기류에 뜬 몸(run 118)
		"bounce": return BouncePoses.lean(f)     # 버섯 갓에 튕겨 오른 몸(run 119)
		"lurch": return LurchPoses.lean(f)       # 발밑이 사라진 몸(run 120)
		"sway": return SwayPoses.lean(f)         # 흔들리는 밧줄 다리 위의 몸(run 121) — 골반째 기운다
		"ride": return RidePoses.lean(f)         # 풍차 바퀴의 컵에 선 몸(run 122)
		"duck": return DuckPoses.lean(f)         # 고드름 밑에 몸을 사린 몸(run 123)
		"tread": return TreadPoses.lean(f)       # 흐르는 톱니 띠 위에 선 몸(run 124)
		"dangle": return DanglePoses.lean(f)     # 흔들리는 추의 가로대에 매달린 몸(run 125)
		"wade": return WadePoses.lean(f)         # 솜구름에 발이 잠긴 몸(run 126)
		"rail": return RailPoses.lean(f)         # 굴러가는 서가 사다리의 몸(run 127)
		"haul": return HaulPoses.lean(f)         # 종 줄에 매달려 끌려 오르는 몸(run 128)
		"part": return PartPoses.lean(f)         # 덩굴 커튼 속의 몸(run 129)
		"heave": return HeavePoses.lean(f)       # 덤웨이터 줄을 당기는 몸(run 130)
		"kite": return KitePoses.lean(f)         # 연의 토글에 끌려가는 몸(run 131)
		"shunt": return ShuntPoses.lean(f)       # 서가를 미는 몸(run 132)
		"cling": return ClingPoses.lean(f)       # 등롱 장대를 안고 오르는 몸(run 133)
		"turn": return TurnPoses.lean(f)         # 회전문 잎을 밀며 도는 몸(run 134)
		"loll": return LollPoses.lean(f)         # 해먹 그물에 받혀 누운 몸(run 135) — 골반째 눕는다
		"trail": return TrailPoses.lean(f)       # 풍향계 리본에 끌려 도는 몸(run 136)
		"bound": return BoundPoses.lean(f)       # 다이빙 판에서 던져진 몸(run 137)
		"tug": return TugPoses.lean(f)           # 열기구 버너 줄을 당기는 몸(run 138)
		"board": return BoardPoses.lean(f)       # 파터노스터 칸을 타고 내리는 몸(run 139)
		"zip": return ZipPoses.lean(f)           # 집라인 트롤리에 매달린 몸(run 140)
		"fly": return FlyPoses.lean(f)           # 공중그네를 제 박자로 흔드는 몸(run 141)
		"perch": return PerchPoses.lean(f)       # 뻐꾸기시계 널빤지에 웅크린 몸(run 142)
		"shimmy": return ShimmyPoses.lean(f)     # 빨랫줄을 손 옮겨 가는 몸(run 143)
		"crank": return CrankPoses.lean(f)       # 도개교 윈치를 감는 몸(run 144)
		"unroll": return UnrollPoses.lean(f)     # 선반의 지도를 펼치는 몸(run 145)
		"balance": return BalancePoses.lean(f)   # 시소 화분 위의 몸(run 146)
		"sink": return SinkPoses.lean(f)         # 촛대 계단의 밀랍 위에 선 몸(run 147)
		"curl": return CurlPoses.lean(f)         # 튤립 봉오리 속에 말린 몸(run 148)
		"stomp": return StompPoses.lean(f)       # 풀무 윗판을 구르는 몸(run 149)
		"puff": return PuffPoses.lean(f)         # 민들레 홀씨를 부는 몸(run 150)
		"yank": return YankPoses.lean(f)         # 절벽의 서랍을 홱 당기는 몸(run 151)
		"spin": return SpinPoses.lean(f)         # 등대 렌즈의 손바퀴를 돌리는 몸(run 152)
		"scale": return ScalePoses.lean(f)       # 태피스트리를 손 바꿔 오르는 몸(run 153)
		"peer": return PeerPoses.lean(f)         # 망원경에 숙여 보는 몸(run 154)
		"hurdle": return HurdlePoses.lean(f)     # 허들 가로대를 넘는 몸(run 155)
		"wheel": return WheelPoses.lean(f)       # 허들 줄 끝에서 돌아서는 몸(run 156, 허들러)
		"squint": return SquintPoses.lean(f)     # 해시계를 읽는 몸(run 157)
		"wipe": return WipePoses.lean(f)         # 그노몬을 소매로 닦는 몸(run 158, 다이얼 키퍼)
		"brush": return BrushPoses.lean(f)       # 풍경의 통 사이를 지나는 몸(run 160)
		"hark": return HarkPoses.lean(f)         # 풍경의 화음을 듣는 몸(run 161, 풍경 점퍼)
		"plant": return PlantPoses.lean(f)       # 멀리뛰기 모래에 내리는 몸(run 162)
		"limber": return LimberPoses.lean(f)     # 구름판에서 다리를 터는 몸(run 163, 리퍼)
		"tiptoe": return TiptoePoses.lean(f)     # 외줄 위에 발끝으로 선 몸(run 164)
	return lean

## 한쪽 팔다리 — 제 자세를 가진 파일이 그리면 true. 각 파일이 pose_request 를 스스로 보니 순서는 뜻이 없다(한 자세에 한 파일)
static func limbs(f: Stick3D, s: float) -> bool:
	return GlidePoses.limbs(f, s) or BouncePoses.limbs(f, s) or LurchPoses.limbs(f, s) or SwayPoses.limbs(f, s) or RidePoses.limbs(f, s) or DuckPoses.limbs(f, s) or TreadPoses.limbs(f, s) or DanglePoses.limbs(f, s) or WadePoses.limbs(f, s) or RailPoses.limbs(f, s) or HaulPoses.limbs(f, s) or PartPoses.limbs(f, s) or HeavePoses.limbs(f, s) or KitePoses.limbs(f, s) or ShuntPoses.limbs(f, s) or ClingPoses.limbs(f, s) or TurnPoses.limbs(f, s) or LollPoses.limbs(f, s) or TrailPoses.limbs(f, s) or BoundPoses.limbs(f, s) or TugPoses.limbs(f, s) or BoardPoses.limbs(f, s) or ZipPoses.limbs(f, s) or FlyPoses.limbs(f, s) or PerchPoses.limbs(f, s) or ShimmyPoses.limbs(f, s) or CrankPoses.limbs(f, s) or UnrollPoses.limbs(f, s) or BalancePoses.limbs(f, s) or SinkPoses.limbs(f, s) or CurlPoses.limbs(f, s) or StompPoses.limbs(f, s) or PuffPoses.limbs(f, s) or YankPoses.limbs(f, s) or SpinPoses.limbs(f, s) or ScalePoses.limbs(f, s) or PeerPoses.limbs(f, s) or HurdlePoses.limbs(f, s) or WheelPoses.limbs(f, s) or SquintPoses.limbs(f, s) or WipePoses.limbs(f, s) or BrushPoses.limbs(f, s) or HarkPoses.limbs(f, s) or PlantPoses.limbs(f, s) or LimberPoses.limbs(f, s) or TiptoePoses.limbs(f, s)

## 오른팔을 제가 쓰는 탑의 자세 — stick3d.gd 가 든 것(carrying)을 오른손에 붙이기 전에 묻는다
static func owns_right_arm(p: String) -> bool:
	return p in POSES and not (p in FREE_RIGHT)
