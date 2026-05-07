extends CanvasLayer

@export var player: Player

@onready var controls: CanvasLayer = $"../Controls"

var touch_buttons: Array[TouchScreenButton] = []
var button_normal_textures: Dictionary = {}


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	cache_touch_buttons(controls)


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

		for button in touch_buttons:
			set_touch_button_state(button, button.action, button_normal_textures.get(button))


func cache_touch_buttons(node: Node) -> void:
	for child in node.get_children():
		if child is TouchScreenButton:
			var button := child as TouchScreenButton
			touch_buttons.append(button)
			button_normal_textures[button] = button.texture_normal
		cache_touch_buttons(child)


## Swaps the "normal" texture with the "pressed" texture of a TouchScreenButton based on whether the corresponding action is pressed or not.
func set_touch_button_state(button: TouchScreenButton, action: StringName, normal_texture: Texture2D) -> void:
	if action.is_empty():
		button.texture_normal = normal_texture
		return

	if Input.is_action_pressed(action) and button.texture_pressed:
		button.texture_normal = button.texture_pressed
	else:
		button.texture_normal = normal_texture
