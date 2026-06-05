extends CanvasLayer

@export var player: Player


## Called every frame. '_delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if player:
		$VBoxContainer/is_falling.button_pressed = player.is_falling
		$VBoxContainer/is_jumping.button_pressed = (player.is_jump_queued or player.is_jumping)
		$VBoxContainer/is_sprinting.button_pressed = player.is_sprinting
