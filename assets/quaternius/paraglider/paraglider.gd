extends Node3D

@export var player: Player
@export var paragliding_state_name: String = "Paragliding"


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if not visible and player.is_paragliding:
		await get_tree().create_timer(0.5).timeout
		visible = true
		await get_tree().create_timer(0.3).timeout
		$LeftWing.visible = true
		$RightWing.visible = true
	elif visible and not player.is_paragliding:
		visible = false
		$LeftWing.visible = false
		$RightWing.visible = false
