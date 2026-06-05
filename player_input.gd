class_name InputSynchronizer
extends MultiplayerSynchronizer

# Synchronized controls
#@export var aiming: bool = false
#@export var shoot_target := Vector3()
@export var motion := Vector2()
#@export var shooting: bool = false
# This is handled via RPC for now
#@export var jumping: bool = false


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return


## Called every frame. '_delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	motion = Vector2(
			Input.get_action_strength(&"move_right") - Input.get_action_strength(&"move_left"),
			Input.get_action_strength(&"move_up") - Input.get_action_strength(&"move_down"))
	var camera_move := Vector2(
			Input.get_action_strength(&"look_right") - Input.get_action_strength(&"look_left"),
			Input.get_action_strength(&"look_up") - Input.get_action_strength(&"look_down"))
