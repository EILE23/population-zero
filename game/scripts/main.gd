extends Node2D
## 메인 — 무대 하나, 플레이어 하나, 카메라. 세계는 World 노드를 -cam 만큼 밀어서 스크롤한다(웹 광장과 같은 방식).

@onready var world: Node2D = $World
@onready var player: Player = $World/Player
@onready var stage: Stage = $Stage
@onready var legend: Label = $Legend

var cam: float = 0.0

func _ready() -> void:
	player.world_w = stage.world_w
	cam = clampf(player.x - Stage.W / 2.0, 0.0, stage.world_w - Stage.W)
	legend.text = "Arrows move · SPACE hold, release to jump · X punch · Z kick"

func _process(delta: float) -> void:
	cam = Stage.follow(cam, player.x, stage.world_w, delta)
	world.position.x = -cam
