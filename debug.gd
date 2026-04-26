extends CanvasLayer

@export var player: Player


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if visible:
		$List/Input/X.text = "X: %.2f" % player.current_input_vector.x
		$List/Input/Y.text = "Y: %.2f" % player.current_input_vector.y
		$List/Velocity/X.text = "X: %.2f" % player.velocity.x
		$List/Velocity/Y.text = "Y: %.2f" % player.velocity.y
		$List/Velocity/Z.text = "Z: %.2f" % player.velocity.z
		$List/State/Value.text = str(player.playback.get_current_node())

		$States/is_crouching.button_pressed = player.is_crouching
		$States/is_sliding.button_pressed = player.is_sliding
		$States/is_sprinting.button_pressed = player.is_sprinting
		$States/is_strafing.button_pressed = player.is_strafing
