extends CanvasLayer

@export var player: Player

@onready var button_a: TouchScreenButton = $"../Controls/BottomRight/A"
@onready var button_a_normal_texture: Texture2D = button_a.texture_normal
@onready var button_b: TouchScreenButton = $"../Controls/BottomRight/B"
@onready var button_b_normal_texture: Texture2D = button_b.texture_normal
@onready var button_x: TouchScreenButton = $"../Controls/BottomRight/X"
@onready var button_x_normal_texture: Texture2D = button_x.texture_normal
@onready var button_y: TouchScreenButton = $"../Controls/BottomRight/Y"
@onready var button_y_normal_texture: Texture2D = button_y.texture_normal


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

		set_touch_button_state(button_a, "crouch", button_a_normal_texture)
		set_touch_button_state(button_b, "sprint", button_b_normal_texture)
		set_touch_button_state(button_x, "use", button_x_normal_texture)
		set_touch_button_state(button_y, "jump", button_y_normal_texture)


## Swaps the "normal" texture with the "pressed" texture of a TouchScreenButton based on whether the corresponding action is pressed or not.
func set_touch_button_state(button: TouchScreenButton, action: StringName, normal_texture: Texture2D) -> void:
	if Input.is_action_pressed(action) and button.texture_pressed:
		button.texture_normal = button.texture_pressed
	else:
		button.texture_normal = normal_texture
