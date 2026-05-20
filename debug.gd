extends CanvasLayer

@export var player: Player

@onready var controls: CanvasLayer = $"../Controls"
@onready var left_joystick: VirtualJoystick = $"../Controls/BottomLeft/LeftJoystick"
@onready var right_joystick: VirtualJoystick = $"../Controls/BottomRight/RightJoystick"

var touch_buttons: Array[TouchScreenButton] = []
var button_normal_textures: Dictionary = {}
var joystick_normal_styleboxes: Dictionary = {}
var joystick_pressed_styleboxes: Dictionary = {}


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	cache_touch_buttons(controls)
	# cache joystick styleboxes once; helper reads from these maps
	joystick_normal_styleboxes[left_joystick] = left_joystick.get_theme_stylebox("normal_tip", "VirtualJoystick")
	joystick_normal_styleboxes[right_joystick] = right_joystick.get_theme_stylebox("normal_tip", "VirtualJoystick")
	joystick_pressed_styleboxes[left_joystick] = left_joystick.get_theme_stylebox("pressed_tip", "VirtualJoystick")
	joystick_pressed_styleboxes[right_joystick] = right_joystick.get_theme_stylebox("pressed_tip", "VirtualJoystick")


## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if visible:

		#$List/Input/X.text = "X: %.2f" % player.current_input_vector.x
		#$List/Input/Y.text = "Y: %.2f" % player.current_input_vector.y
		$List/Velocity/X.text = "X: %.2f" % player.velocity.x
		$List/Velocity/Y.text = "Y: %.2f" % player.velocity.y
		$List/Velocity/Z.text = "Z: %.2f" % player.velocity.z
		$List/State/Value.text = str(player.playback_locomotion.get_current_node())

		$States/is_crouching.button_pressed = player.is_crouching
		$States/is_exhausted.button_pressed = player.is_exhausted
		$States/is_falling.button_pressed = player.is_falling
		$States/is_jumping.button_pressed = player.is_jumping
		$States/is_paragliding.button_pressed = player.is_paragliding
		$States/is_sliding.button_pressed = player.is_sliding
		$States/is_sprinting.button_pressed = player.is_sprinting
		$States/is_strafing.button_pressed = player.is_strafing

		# Visually update the touch buttons to reflect the controller/keyboard input
		for button in touch_buttons:
			set_touch_button_state(
				button, button.action,
				button_normal_textures.get(button),
			)

		# Visually update the joysticks to reflect the controller/keyboard input
		set_virtual_control_state(left_joystick)
		set_virtual_control_state(right_joystick)


func cache_touch_buttons(node: Node) -> void:
	for child in node.get_children():
		if child is TouchScreenButton:
			var button := child as TouchScreenButton
			touch_buttons.append(button)
			button_normal_textures[button] = button.texture_normal
		cache_touch_buttons(child)


## Swaps the joystick "normal_tip" style based on whether related input actions are currently pressed.
func set_virtual_control_state(
	joystick: VirtualJoystick,
	deadzone: float = 0.2
) -> void:
	var normal_stylebox: StyleBox = joystick_normal_styleboxes.get(joystick)
	var pressed_stylebox: StyleBox = joystick_pressed_styleboxes.get(joystick)
	if normal_stylebox == null or pressed_stylebox == null:
		return

	var input_vector := Input.get_vector(
		joystick.action_left,
		joystick.action_right,
		joystick.action_up,
		joystick.action_down,
		deadzone
	)
	if input_vector.length() > deadzone:
		joystick.add_theme_stylebox_override("normal_tip", pressed_stylebox)
	else:
		joystick.add_theme_stylebox_override("normal_tip", normal_stylebox)


## Swaps the "normal" texture with the "pressed" texture of a TouchScreenButton based on whether the corresponding action is pressed or not.
func set_touch_button_state(button: TouchScreenButton, action: StringName, normal_texture: Texture2D) -> void:
	if action.is_empty():
		button.texture_normal = normal_texture
		return

	if Input.is_action_pressed(action) and button.texture_pressed:
		button.texture_normal = button.texture_pressed
	else:
		button.texture_normal = normal_texture
