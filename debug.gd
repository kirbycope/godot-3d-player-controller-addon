extends CanvasLayer

@export var player: Player


## Called every frame. '_delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if player:
		$VBoxContainer/is_crouching.button_pressed = player.is_crouching
		$VBoxContainer/is_falling.button_pressed = player.is_falling
		$VBoxContainer/is_focusing.button_pressed = player.is_focusing
		$VBoxContainer/is_jumping.button_pressed = (player.is_jump_queued or player.is_jumping)
		$VBoxContainer/is_sliding.button_pressed = player.is_sliding
		$VBoxContainer/is_sprinting.button_pressed = player.is_sprinting
