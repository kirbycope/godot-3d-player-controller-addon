class_name InputSynchronizer
extends MultiplayerSynchronizer

# Synchronized controls
@export var motion := Vector2()


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_process(is_multiplayer_authority())
	set_physics_process(is_multiplayer_authority())
	set_process_input(is_multiplayer_authority())


## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	var player := get_parent() as Player
	if player and (player.is_paused or player.is_ragdolling):
		motion = Vector2.ZERO
		return

	motion = Vector2(
			Input.get_action_strength(&"move_right") - Input.get_action_strength(&"move_left"),
			Input.get_action_strength(&"move_up") - Input.get_action_strength(&"move_down")
	).limit_length(1.0)
