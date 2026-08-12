extends CanvasLayer

signal input_type_changed(input_type: InputType)

enum InputType {
	KEYBOARD_MOUSE,
	MICROSOFT,
	NINTENDO,
	SONY,
	TOUCH,
}

@export var input_deadzone: float = 0.05 ## Address joystick drift by setting a deadzone threshold for joystick motion inputs
@export_category("Keyboard and Mouse Textures")
@export var keyboard_mouse_button_0_normal: Texture2D ## Keyboard [E] key (Normal)
@export var keyboard_mouse_button_0_pressed: Texture2D ## Keyboard [E] key (Pressed)
@export var keyboard_mouse_button_1_normal: Texture2D ## Keyboard [Shift] key (Normal)
@export var keyboard_mouse_button_1_pressed: Texture2D ## Keyboard [Shift] key (Pressed)
@export var keyboard_mouse_button_2_normal: Texture2D ## Keyboard [Alt] key (Normal)
@export var keyboard_mouse_button_2_pressed: Texture2D ## Keyboard [Alt] key (Pressed)
@export var keyboard_mouse_button_3_normal: Texture2D ## Keyboard [Space] key (Normal)
@export var keyboard_mouse_button_3_pressed: Texture2D ## Keyboard [Space] key (Pressed)
@export var keyboard_mouse_button_4_normal: Texture2D ## Keyboard [F5] key (Normal)
@export var keyboard_mouse_button_4_pressed: Texture2D ## Keyboard [F5] key (Pressed)
@export var keyboard_mouse_button_15_normal: Texture2D ## Keyboard [Print] key (Normal)
@export var keyboard_mouse_button_15_pressed: Texture2D ## Keyboard [Print] key (Pressed)
@export var keyboard_mouse_button_6_normal: Texture2D ## Keyboard [Esc] key (Normal)
@export var keyboard_mouse_button_6_pressed: Texture2D ## Keyboard [Esc] key (Pressed)
@export var keyboard_mouse_button_7_normal: Texture2D ## Keyboard [Ctrl] key (Normal)
@export var keyboard_mouse_button_7_pressed: Texture2D ## Keyboard [Ctrl] key (Pressed)
@export var keyboard_mouse_button_8_normal: Texture2D ## Keyboard [Mouse-Scroll] key (Normal)
@export var keyboard_mouse_button_8_pressed: Texture2D ## Keyboard [Mouse-Scroll] key (Pressed)
@export var keyboard_mouse_button_9_normal: Texture2D ## Keyboard [Q] key (Normal)
@export var keyboard_mouse_button_9_pressed: Texture2D ## Keyboard [Q] key (Pressed)
@export var keyboard_mouse_button_10_normal: Texture2D ## Keyboard [T] key (Normal)
@export var keyboard_mouse_button_10_pressed: Texture2D ## Keyboard [T] key (Pressed)
@export var keyboard_mouse_axis_4_plus_normal: Texture2D ## Keyboard [Mouse-Left] key (Normal)
@export var keyboard_mouse_axis_4_plus_pressed: Texture2D ## Keyboard [Mouse-Left] key (Pressed)
@export var keyboard_mouse_axis_5_plus_normal: Texture2D ## Keyboard [Mouse-Right] key (Normal)
@export var keyboard_mouse_axis_5_plus_pressed: Texture2D ## Keyboard [Mouse-Right] key (Pressed)
@export_category("Microsoft Textures")
@export var microsoft_button_0_normal: Texture2D ## XBox A (Normal)
@export var microsoft_button_0_pressed: Texture2D ## XBox A (Pressed)
@export var microsoft_button_1_normal: Texture2D ## XBox B (Normal)
@export var microsoft_button_1_pressed: Texture2D ## XBox B (Pressed)
@export var microsoft_button_2_normal: Texture2D ## XBox X (Normal)
@export var microsoft_button_2_pressed: Texture2D ## XBox X (Pressed)
@export var microsoft_button_3_normal: Texture2D ## XBox Y (Normal)
@export var microsoft_button_3_pressed: Texture2D ## XBox Y (Pressed)
@export var microsoft_button_4_normal: Texture2D ## XBox Back(Normal)
@export var microsoft_button_4_pressed: Texture2D ## XBox Back (Pressed)
@export var microsoft_button_15_normal: Texture2D ## XBox Share (Normal)
@export var microsoft_button_15_pressed: Texture2D ## XBox Share (Pressed)
@export var microsoft_button_6_normal: Texture2D ## XBox Forward (Normal)
@export var microsoft_button_6_pressed: Texture2D ## XBox Forward (Pressed)
@export var microsoft_button_7_normal: Texture2D ## XBox LS (Normal)
@export var microsoft_button_7_pressed: Texture2D ## XBox LS (Pressed)
@export var microsoft_button_8_normal: Texture2D ## XBox RS (Normal)
@export var microsoft_button_8_pressed: Texture2D ## XBox RS (Pressed)
@export var microsoft_button_9_normal: Texture2D ## XBox LB (Normal)
@export var microsoft_button_9_pressed: Texture2D ## XBox LB (Pressed)
@export var microsoft_button_10_normal: Texture2D ## XBox RB (Normal)
@export var microsoft_button_10_pressed: Texture2D ## XBox RB (Pressed)
@export var microsoft_axis_4_plus_normal: Texture2D ## XBox LT (Normal)
@export var microsoft_axis_4_plus_pressed: Texture2D ## XBox LT (Pressed)
@export var microsoft_axis_5_plus_normal: Texture2D ## XBox RT (Normal)
@export var microsoft_axis_5_plus_pressed: Texture2D ## XBox RT (Pressed)
@export_category("Nintendo Textures")
@export var nintendo_button_0_normal: Texture2D ## Nintendo B (Normal)
@export var nintendo_button_0_pressed: Texture2D ## Nintendo B (Pressed)
@export var nintendo_button_1_normal: Texture2D ## Nintendo A (Normal)
@export var nintendo_button_1_pressed: Texture2D ## Nintendo A (Pressed)
@export var nintendo_button_2_normal: Texture2D ## Nintendo Y (Normal)
@export var nintendo_button_2_pressed: Texture2D ## Nintendo Y (Pressed)
@export var nintendo_button_3_normal: Texture2D ## Nintendo X (Normal)
@export var nintendo_button_3_pressed: Texture2D ## Nintendo X (Pressed)
@export var nintendo_button_4_normal: Texture2D ## Nintendo - (Normal)
@export var nintendo_button_4_pressed: Texture2D ## Nintendo - (Pressed)
@export var nintendo_button_15_normal: Texture2D ## Nintendo Share (Normal)
@export var nintendo_button_15_pressed: Texture2D ## Nintendo Share (Pressed)
@export var nintendo_button_6_normal: Texture2D ## Nintendo + (Normal)
@export var nintendo_button_6_pressed: Texture2D ## Nintendo + (Pressed)
@export var nintendo_button_7_normal: Texture2D ## Nintendo LS (Normal)
@export var nintendo_button_7_pressed: Texture2D ## Nintendo LS (Pressed)
@export var nintendo_button_8_normal: Texture2D ## Nintendo RS (Normal)
@export var nintendo_button_8_pressed: Texture2D ## Nintendo RS (Pressed)
@export var nintendo_button_9_normal: Texture2D ## Nintendo L (Normal)
@export var nintendo_button_9_pressed: Texture2D ## Nintendo L (Pressed)
@export var nintendo_button_10_normal: Texture2D ## Nintendo R (Normal)
@export var nintendo_button_10_pressed: Texture2D ## Nintendo R (Pressed)
@export var nintendo_axis_4_plus_normal: Texture2D ## Nintendo ZL (Normal)
@export var nintendo_axis_4_plus_pressed: Texture2D ## Nintendo ZL (Pressed)
@export var nintendo_axis_5_plus_normal: Texture2D ## Nintendo ZR (Normal)
@export var nintendo_axis_5_plus_pressed: Texture2D ## Nintendo ZR (Pressed)
@export_category("Sony Textures")
@export var sony_button_0_normal: Texture2D ## Sony Cross (Normal)
@export var sony_button_0_pressed: Texture2D ## Sony Cross (Pressed)
@export var sony_button_1_normal: Texture2D ## Sony Circle (Normal)
@export var sony_button_1_pressed: Texture2D ## Sony Circle (Pressed)
@export var sony_button_2_normal: Texture2D ## Sony Square (Normal)
@export var sony_button_2_pressed: Texture2D ## Sony Square (Pressed)
@export var sony_button_3_normal: Texture2D ## Sony Triangle (Normal)
@export var sony_button_3_pressed: Texture2D ## Sony Triangle (Pressed)
@export var sony_button_4_normal: Texture2D ## Sony Select (Normal)
@export var sony_button_4_pressed: Texture2D ## Sony Select (Pressed)
@export var sony_button_15_normal: Texture2D ## Sony Share (Normal)
@export var sony_button_15_pressed: Texture2D ## Sony Share (Pressed)
@export var sony_button_6_normal: Texture2D ## Sony Options (Normal)
@export var sony_button_6_pressed: Texture2D ## Sony Options (Pressed)
@export var sony_button_7_normal: Texture2D ## Sony L3 (Normal)
@export var sony_button_7_pressed: Texture2D ## Sony L3 (Pressed)
@export var sony_button_8_normal: Texture2D ## Sony R3 (Normal)
@export var sony_button_8_pressed: Texture2D ## Sony R3 (Pressed)
@export var sony_button_9_normal: Texture2D ## Sony L1 (Normal)
@export var sony_button_9_pressed: Texture2D ## Sony L1 (Pressed)
@export var sony_button_10_normal: Texture2D ## Sony R1 (Normal)
@export var sony_button_10_pressed: Texture2D ## Sony R1 (Pressed)
@export var sony_axis_4_plus_normal: Texture2D ## Sony L2 (Normal)
@export var sony_axis_4_plus_pressed: Texture2D ## Sony L2 (Pressed)
@export var sony_axis_5_plus_normal: Texture2D ## Sony R2 (Normal)
@export var sony_axis_5_plus_pressed: Texture2D ## Sony R2 (Pressed)

@onready var joypad_button_0: TouchScreenButton = $BottomRight/JoypadButton0 ## Joypad Button 0 (Bottom Action, Sony Cross, XBox A, Nintendo B)
@onready var joypad_button_0_label: Label = $BottomRight/JoypadButton0/Label
@onready var joypad_button_1: TouchScreenButton = $BottomRight/JoypadButton1 ## Joypad Button 1 (Right Action, Sony Circle, XBox B, Nintendo A)
@onready var joypad_button_1_label: Label = $BottomRight/JoypadButton1/Label
@onready var joypad_button_2: TouchScreenButton = $BottomRight/JoypadButton2 ## Joypad Button 2 (Left Action, Sony Square, XBox X, Nintendo Y)
@onready var joypad_button_2_label: Label = $BottomRight/JoypadButton2/Label
@onready var joypad_button_3: TouchScreenButton = $BottomRight/JoypadButton3 ## Joypad Button 3 (Top Action, Sony Triangle, XBox Y, Nintendo X)
@onready var joypad_button_3_label: Label = $BottomRight/JoypadButton3/Label
@onready var joypad_button_4: TouchScreenButton = $TopCenter/JoypadButton4 ## Joypad Button 4 (Back, Sony Select, XBox Back, Nintendo -)
@onready var joypad_button_4_label: Label = $TopCenter/JoypadButton4/Label
@onready var joypad_button_15: TouchScreenButton = $TopCenter/JoypadButton15 ## Joypad Button 15 (Share Action, Sony Share, XBox Share, Nintendo Share)
@onready var joypad_button_15_label: Label = $TopCenter/JoypadButton15/Label
@onready var joypad_button_6: TouchScreenButton = $TopCenter/JoypadButton6 ## Joypad Button 6 (Start, Sony Options, XBox Menu, Nintendo Plus)
@onready var joypad_button_6_label: Label = $TopCenter/JoypadButton6/Label
@onready var joypad_button_7: TouchScreenButton = $BottomLeft/JoypadButton7 ## Joypad Button 7 (Left Stick, Sony L3, XBox Left Stick, Nintendo Left Stick)
@onready var joypad_button_7_label: Label = $BottomLeft/JoypadButton7/Label
@onready var joypad_button_8: TouchScreenButton = $BottomRight/JoypadButton8 ## Joypad Button 8 (Right Stick, Sony R3, XBox Right Stick, Nintendo Right Stick)
@onready var joypad_button_8_label: Label = $BottomRight/JoypadButton8/Label
@onready var joypad_button_9: TouchScreenButton = $TopLeft/JoypadButton9 ## Joypad Button 9 (Left Shoulder, Sony L1, XBox L, Nintendo L)
@onready var joypad_button_9_label: Label = $TopLeft/JoypadButton9/Label
@onready var joypad_button_10: TouchScreenButton = $TopRight/JoypadButton10 ## Joypad Button 10 (Right Shoulder, Sony R1, XBox RB, Nintendo R)
@onready var joypad_button_10_label: Label = $TopRight/JoypadButton10/Label
@onready var joypad_axis_4_plus: TouchScreenButton = $TopLeft/JoypadAxis4Plus ## Joypad Axis 4 + (Left Trigger, Sony L2, XBox LT, Nintendo ZL)
@onready var joypad_axis_4_plus_label: Label = $TopLeft/JoypadAxis4Plus/Label
@onready var joypad_axis_5_plus: TouchScreenButton = $TopRight/JoypadAxis5Plus ## Joypad Axis 5 + (Right Trigger, Sony R2, XBox RT, Nintendo ZR)
@onready var joypad_axis_5_plus_label: Label = $TopRight/JoypadAxis5Plus/Label
@onready var joypad_button_11: TouchScreenButton = $BottomLeft/JoypadButton11 ## Joypad Button 11 (DPad Up)
@onready var joypad_button_11_label: Label = $BottomLeft/JoypadButton11/Label
@onready var joypad_button_12: TouchScreenButton = $BottomLeft/JoypadButton12 ## Joypad Button 12 (DPad Down)
@onready var joypad_button_12_label: Label = $BottomLeft/JoypadButton12/Label
@onready var joypad_button_13: TouchScreenButton = $BottomLeft/JoypadButton13 ## Joypad Button 13 (DPad Left)
@onready var joypad_button_13_label: Label = $BottomLeft/JoypadButton13/Label
@onready var joypad_button_14: TouchScreenButton = $BottomLeft/JoypadButton14 ## Joypad Button 14 (DPad Right)
@onready var joypad_button_14_label: Label = $BottomLeft/JoypadButton14/Label
@onready var key_w: TouchScreenButton = $BottomLeft/KeyW ## Keyboard [W] key
@onready var key_w_label: Label = $BottomLeft/KeyW/Label
@onready var key_a: TouchScreenButton = $BottomLeft/KeyA ## Keyboard [A] key
@onready var key_a_label: Label = $BottomLeft/KeyA/Label
@onready var key_s: TouchScreenButton = $BottomLeft/KeyS ## Keyboard [S] key
@onready var key_s_label: Label = $BottomLeft/KeyS/Label
@onready var key_d: TouchScreenButton = $BottomLeft/KeyD ## Keyboard [D] key
@onready var key_d_label: Label = $BottomLeft/KeyD/Label
@onready var key_i: TouchScreenButton = $BottomLeft/KeyI ## Keyboard [I] key
@onready var key_i_label: Label = $BottomLeft/KeyI/Label
@onready var key_j: TouchScreenButton = $BottomLeft/KeyJ ## Keyboard [J] key
@onready var key_j_label: Label = $BottomLeft/KeyJ/Label
@onready var key_k: TouchScreenButton = $BottomLeft/KeyK ## Keyboard [K] key
@onready var key_k_label: Label = $BottomLeft/KeyK/Label
@onready var key_l: TouchScreenButton = $BottomLeft/KeyL ## Keyboard [L] key
@onready var key_l_label: Label = $BottomLeft/KeyL/Label
@onready var left_joystick: VirtualJoystick = $BottomLeft/LeftJoystick ## Virtual Joystick (introduced in Godot 4.7) for player movement
@onready var left_joystick_label: Label = $BottomLeft/LeftJoystick/Label
@onready var right_joystick: VirtualJoystick = $BottomRight/RightJoystick ## Virtual Joystick (introduced in Godot 4.7) for camera movement
@onready var right_joystick_label: Label = $BottomRight/RightJoystick/Label
@onready var key_up: TouchScreenButton = $BottomRight/KeyUp ## Keyboard [Up] key
@onready var key_up_label: Label = $BottomRight/KeyUp/Label
@onready var key_left: TouchScreenButton = $BottomRight/KeyLeft ## Keyboard [Left] key
@onready var key_left_label: Label = $BottomRight/KeyLeft/Label
@onready var key_down: TouchScreenButton = $BottomRight/KeyDown ## Keyboard [Down] key
@onready var key_down_label: Label = $BottomRight/KeyDown/Label
@onready var key_right: TouchScreenButton = $BottomRight/KeyRight ## Keyboard [Right] key
@onready var key_right_label: Label = $BottomRight/KeyRight/Label

var current_input_type: InputType = InputType.TOUCH:
	set(value):
		if current_input_type != value:
			current_input_type = value
			input_type_changed.emit(value)

var all_buttons: Array[TouchScreenButton] = []
var _label_texts: Dictionary = {}
var _normal_textures: Dictionary = {}


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_process(is_multiplayer_authority())
	set_physics_process(is_multiplayer_authority())
	set_process_input(is_multiplayer_authority())

	# Connect the input_type_changed signal to the update_input_ui function
	input_type_changed.connect(update_input_ui)

	all_buttons = [
		joypad_button_0, joypad_button_1, joypad_button_2, joypad_button_3,
		joypad_button_4, joypad_button_15, joypad_button_6, joypad_button_7,
		joypad_button_8, joypad_button_9, joypad_button_10, joypad_axis_4_plus,
		joypad_axis_5_plus, joypad_button_11, joypad_button_12, joypad_button_13,
		joypad_button_14, key_w, key_a, key_s, key_d, key_i, key_j, key_k,
		key_l, key_up, key_left, key_down, key_right,
	]

	# Cache the [Label] initial `.text` values
	for button in all_buttons:
		if button.has_node("Label"):
			var label = button.get_node("Label") as Label
			_label_texts[label] = label.text
	_label_texts[left_joystick_label] = left_joystick_label.text
	_label_texts[right_joystick_label] = right_joystick_label.text

	update_input_ui(current_input_type)

	# "move_up" { Controller: (left-stick) forward, Keyboard: [W] }
	if not InputMap.has_action("move_up"):
		# Add the [move_up] action to the Input Map
		InputMap.add_action("move_up")
		# Keyboard 🅆
		var key_event = InputEventKey.new()
		key_event.physical_keycode = KEY_W
		InputMap.action_add_event("move_up", key_event)
		# Controller (left-stick) forward]
		var joystick_event = InputEventJoypadMotion.new()
		joystick_event.axis = JOY_AXIS_LEFT_Y
		joystick_event.axis_value = -1.0
		InputMap.action_add_event("move_up", joystick_event)

	# "move_down" { Controller: (left-stick) backward, Keyboard: [S] }
	if not InputMap.has_action("move_down"):
		# Add the [move_down] action to the Input Map
		InputMap.add_action("move_down")
		# Keyboard 🅂
		var key_event = InputEventKey.new()
		key_event.physical_keycode = KEY_S
		InputMap.action_add_event("move_down", key_event)
		# Controller (left-stick) backward]
		var joystick_event = InputEventJoypadMotion.new()
		joystick_event.axis = JOY_AXIS_LEFT_Y
		joystick_event.axis_value = 1.0
		InputMap.action_add_event("move_down", joystick_event)

	# "move_left" { Controller: (left-stick) left, Keyboard: [A] }
	if not InputMap.has_action("move_left"):
		# Add the [move_left] action to the Input Map
		InputMap.add_action("move_left")
		# Keyboard 🄰
		var key_event = InputEventKey.new()
		key_event.physical_keycode = KEY_A
		InputMap.action_add_event("move_left", key_event)
		# Controller (left-stick) left]
		var joystick_event = InputEventJoypadMotion.new()
		joystick_event.axis = JOY_AXIS_LEFT_X
		joystick_event.axis_value = -1.0
		InputMap.action_add_event("move_left", joystick_event)
	
	# "move_right" { Controller: (left-stick) right, Keyboard: [D] }
	if not InputMap.has_action("move_right"):
		# Add the [move_right] action to the Input Map
		InputMap.add_action("move_right")
		# Keyboard 🄳
		var key_event = InputEventKey.new()
		key_event.physical_keycode = KEY_D
		InputMap.action_add_event("move_right", key_event)
		# Controller (left-stick) right]
		var joystick_event = InputEventJoypadMotion.new()
		joystick_event.axis = JOY_AXIS_LEFT_X
		joystick_event.axis_value = 1.0
		InputMap.action_add_event("move_right", joystick_event)

	# "look_up" { Controller: (right-stick) up, Keyboard: [Up] }
	if not InputMap.has_action("look_up"):
		# Add the [look_up] action to the Input Map
		InputMap.add_action("look_up")
		# Keyboard [Up]
		var key_event = InputEventKey.new()
		key_event.physical_keycode = KEY_UP
		InputMap.action_add_event("look_up", key_event)
		# Controller (right-stick) up]
		var joystick_event = InputEventJoypadMotion.new()
		joystick_event.axis = JOY_AXIS_RIGHT_Y
		joystick_event.axis_value = -1.0
		InputMap.action_add_event("look_up", joystick_event)

	# "look_down" { Controller: (right-stick) down, Keyboard: [Down] }
	if not InputMap.has_action("look_down"):
		# Add the [look_down] action to the Input Map
		InputMap.add_action("look_down")
		# Keyboard [Down]
		var key_event = InputEventKey.new()
		key_event.physical_keycode = KEY_DOWN
		InputMap.action_add_event("look_down", key_event)
		# Controller (right-stick) down]
		var joystick_event = InputEventJoypadMotion.new()
		joystick_event.axis = JOY_AXIS_RIGHT_Y
		joystick_event.axis_value = 1.0
		InputMap.action_add_event("look_down", joystick_event)

	# "look_left" { Controller: (right-stick) left, Keyboard: [Left] }
	if not InputMap.has_action("look_left"):
		# Add the [look_left] action to the Input Map
		InputMap.add_action("look_left")
		# Keyboard [Left]
		var key_event = InputEventKey.new()
		key_event.physical_keycode = KEY_LEFT
		InputMap.action_add_event("look_left", key_event)
		# Controller (right-stick) left]
		var joystick_event = InputEventJoypadMotion.new()
		joystick_event.axis = JOY_AXIS_RIGHT_X
		joystick_event.axis_value = -1.0
		InputMap.action_add_event("look_left", joystick_event)

	# "look_right" { Controller: (right-stick) right, Keyboard: [Right] }
	if not InputMap.has_action("look_right"):
		# Add the [look_right] action to the Input Map
		InputMap.add_action("look_right")
		# Keyboard [Right]
		var key_event = InputEventKey.new()
		key_event.physical_keycode = KEY_RIGHT
		InputMap.action_add_event("look_right", key_event)
		# Controller (right-stick) right]
		var joystick_event = InputEventJoypadMotion.new()
		joystick_event.axis = JOY_AXIS_RIGHT_X
		joystick_event.axis_value = 1.0
		InputMap.action_add_event("look_right", joystick_event)

	# "action" { Microsoft: Ⓐ, Nintendo: Ⓑ, Sony: Ⓧ, Keyboard: [E] }
	if not InputMap.has_action("action"):
		# Add the [action] action to the Input Map
		InputMap.add_action("action")
		# Microsoft Ⓐ, Nintendo Ⓑ, Sony Ⓧ
		var joystick_event = InputEventJoypadButton.new()
		joystick_event.button_index = JOY_BUTTON_A
		InputMap.action_add_event("action", joystick_event)
		# Keyboard [E]
		var key_event = InputEventKey.new()
		key_event.physical_keycode = KEY_E
		InputMap.action_add_event("action", key_event)

	# "sprint" { Microsoft: Ⓑ, Nintendo: Ⓐ, Sony: Ⓞ, Keyboard: [Shift] }
	if not InputMap.has_action("sprint"):
		# Add the [sprint] action to the Input Map
		InputMap.add_action("sprint")
		# Microsoft Ⓑ, Nintendo Ⓐ, Sony Ⓞ
		var joystick_event = InputEventJoypadButton.new()
		joystick_event.button_index = JOY_BUTTON_B
		InputMap.action_add_event("sprint", joystick_event)
		# Keyboard [Shift]
		var key_event = InputEventKey.new()
		key_event.physical_keycode = KEY_SHIFT
		InputMap.action_add_event("sprint", key_event)

	# "attack" { Microsoft: Ⓧ, Nintendo: Ⓨ, Sony: 🟗, Keyboard: [Alt] }
	if not InputMap.has_action("attack"):
		# Add the [attack] action to the Input Map
		InputMap.add_action("attack")
		# Microsoft Ⓧ, Nintendo Ⓨ, Sony 🟗
		var joystick_event = InputEventJoypadButton.new()
		joystick_event.button_index = JOY_BUTTON_X
		InputMap.action_add_event("attack", joystick_event)
		# Keyboard [Alt]
		var key_event = InputEventKey.new()
		key_event.physical_keycode = KEY_ALT
		InputMap.action_add_event("attack", key_event)

	# "jump" { Microsoft: Ⓨ, Nintendo: Ⓧ, Sony: 🟕, Keyboard: [Space] }
	if not InputMap.has_action("jump"):
		# Add the [jump] action to the Input Map
		InputMap.add_action("jump")
		# Microsoft Ⓨ, Nintendo Ⓧ, Sony 🟕
		var joystick_event = InputEventJoypadButton.new()
		joystick_event.button_index = JOY_BUTTON_Y
		InputMap.action_add_event("jump", joystick_event)
		# Keyboard [Space]
		var key_event = InputEventKey.new()
		key_event.physical_keycode = KEY_SPACE
		InputMap.action_add_event("jump", key_event)

	# "crouch" { Microsoft: Ⓛ, Nintendo: Ⓛ, Sony: Ⓛ, Keyboard: [Ctrl] }
	if not InputMap.has_action("crouch"):
		# Add the [crouch] action to the Input Map
		InputMap.add_action("crouch")
		# Microsoft Ⓛ, Nintendo Ⓛ, Sony Ⓛ
		var joystick_event = InputEventJoypadButton.new()
		joystick_event.button_index = JOY_BUTTON_LEFT_STICK
		InputMap.action_add_event("crouch", joystick_event)
		# Keyboard [Ctrl]
		var key_event = InputEventKey.new()
		key_event.physical_keycode = KEY_CTRL
		InputMap.action_add_event("crouch", key_event)

	# "scope" { Microsoft: 🄬, Nintendo: 🄬, Sony: 🄬, Mouse: [Middle-Mouse] }
	if not InputMap.has_action("scope"):
		# Add the [scope] action to the Input Map
		InputMap.add_action("scope")
		# Microsoft 🄬, Nintendo 🄬, Sony 🄬
		var joystick_event = InputEventJoypadButton.new()
		joystick_event.button_index = JOY_BUTTON_RIGHT_STICK
		InputMap.action_add_event("scope", joystick_event)
		# Mouse [Middle-Mouse]
		var mouse_event = InputEventMouseButton.new()
		mouse_event.button_index = MOUSE_BUTTON_MIDDLE
		InputMap.action_add_event("scope", mouse_event)

	# "focus" { Microsoft: 🄻T, Nintendo: Z🄻, Sony: 🄻2, Mouse: [Right-Click] }
	if not InputMap.has_action("focus"):
		# Add the [focus] action to the Input Map
		InputMap.add_action("focus")
		# Microsoft 🄻T, Nintendo Z🄻, Sony 🄻2
		var joystick_event = InputEventJoypadMotion.new()
		joystick_event.axis = JOY_AXIS_TRIGGER_LEFT
		joystick_event.axis_value = 1.0
		InputMap.action_add_event("focus", joystick_event)
		# Mouse [Right-Click]
		var mouse_event = InputEventMouseButton.new()
		mouse_event.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("focus", mouse_event)

	# "shoot" { Microsoft: 🅁T, Nintendo: Z🅁, Sony: 🅁2, Mouse: [Right-Click] }
	if not InputMap.has_action("shoot"):
		# Add the [shoot] action to the Input Map
		InputMap.add_action("shoot")
		# Microsoft 🅁T, Nintendo Z🅁, Sony 🅁2
		var joystick_event = InputEventJoypadMotion.new()
		joystick_event.axis = JOY_AXIS_TRIGGER_RIGHT
		joystick_event.axis_value = 1.0
		InputMap.action_add_event("shoot", joystick_event)
		# Mouse [Left-Click]
		var mouse_event = InputEventMouseButton.new()
		mouse_event.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("shoot", mouse_event)

	# "ability" { Microsoft: 🄻B, Nintendo: L, Sony: L1, Keyboard: [Q] }
	if not InputMap.has_action("ability"):
		# Add the [ability] action to the Input Map
		InputMap.add_action("ability")
		# Microsoft 🄻B, Nintendo L, Sony L1
		var joystick_event = InputEventJoypadButton.new()
		joystick_event.button_index = JOY_BUTTON_LEFT_SHOULDER
		InputMap.action_add_event("ability", joystick_event)
		# Keyboard [Q]
		var key_event = InputEventKey.new()
		key_event.physical_keycode = KEY_Q
		InputMap.action_add_event("ability", key_event)

	# "throw" { Microsoft: 🅁B, Nintendo: R, Sony: R1, Keyboard: [T] }
	if not InputMap.has_action("throw"):
		# Add the [throw] action to the Input Map
		InputMap.add_action("throw")
		# Microsoft 🅁B, Nintendo R, Sony R1
		var joystick_event = InputEventJoypadButton.new()
		joystick_event.button_index = JOY_BUTTON_RIGHT_SHOULDER
		InputMap.action_add_event("throw", joystick_event)
		# Keyboard [T]
		var key_event = InputEventKey.new()
		key_event.physical_keycode = KEY_T
		InputMap.action_add_event("throw", key_event)

	# "perspective" { Microsoft: ⧉, Nintendo: ⊝, Sony: ⦀, Keyboard: [F5] }
	if not InputMap.has_action("perspective"):
		# Add the [perspective] action to the Input Map
		InputMap.add_action("perspective")
		# Microsoft ⧉, Nintendo ⊝, Sony ⦀
		var joystick_event = InputEventJoypadButton.new()
		joystick_event.button_index = JOY_BUTTON_BACK
		InputMap.action_add_event("perspective", joystick_event)
		# Keyboard [F5]
		var key_event = InputEventKey.new()
		key_event.physical_keycode = KEY_F5
		InputMap.action_add_event("perspective", key_event)

	# "share" { Microsoft: ⧉, Nintendo: ⧇, Sony: ?, Keyboard: [PrtScn] }
	if not InputMap.has_action("share"):
		# Add the [share] action to the Input Map
		InputMap.add_action("share")
		# Microsoft ⧉, Nintendo ⧇, Sony ?
		var joystick_event = InputEventJoypadButton.new()
		joystick_event.button_index = JOY_BUTTON_MISC1
		InputMap.action_add_event("share", joystick_event)
		# Keyboard [PrtScn]
		var key_event = InputEventKey.new()
		key_event.physical_keycode = KEY_PRINT
		InputMap.action_add_event("share", key_event)

	# "pause" { Microsoft: ☰, Nintendo: ⊕, Sony: ☰, Keyboard: [Esc] }
	if not InputMap.has_action("start"):
		# Add the [pause] action to the Input Map
		InputMap.add_action("start")
		# Microsoft ☰, Nintendo ⊕, Sony ☰
		var joystick_event = InputEventJoypadButton.new()
		joystick_event.button_index = JOY_BUTTON_START
		InputMap.action_add_event("start", joystick_event)
		# Keyboard [Esc]
		var key_event = InputEventKey.new()
		key_event.physical_keycode = KEY_ESCAPE
		InputMap.action_add_event("start", key_event)

	# "seeker" { Controller: DPad Up, Keyboard: [I] }
	if not InputMap.has_action("seeker"):
		# Add the [seeker] action to the Input Map
		InputMap.add_action("seeker")
		# Controller DPad Up
		var joystick_event = InputEventJoypadButton.new()
		joystick_event.button_index = JOY_BUTTON_DPAD_UP
		InputMap.action_add_event("seeker", joystick_event)
		# Keyboard [I]
		var key_event = InputEventKey.new()
		key_event.physical_keycode = KEY_I
		InputMap.action_add_event("seeker", key_event)

	# "whistle" { Controller: DPad Down, Keyboard: [K] }
	if not InputMap.has_action("whistle"):
		# Add the [whistle] action to the Input Map
		InputMap.add_action("whistle")
		# Controller DPad Down
		var joystick_event = InputEventJoypadButton.new()
		joystick_event.button_index = JOY_BUTTON_DPAD_DOWN
		InputMap.action_add_event("whistle", joystick_event)
		# Keyboard [K]
		var key_event = InputEventKey.new()
		key_event.physical_keycode = KEY_K
		InputMap.action_add_event("whistle", key_event)

	# "last_weapon" { Controller: DPad Left, Keyboard: [J] }
	if not InputMap.has_action("last_weapon"):
		# Add the [last_weapon] action to the Input Map
		InputMap.add_action("last_weapon")
		# Controller DPad Left
		var joystick_event = InputEventJoypadButton.new()
		joystick_event.button_index = JOY_BUTTON_DPAD_LEFT
		InputMap.action_add_event("last_weapon", joystick_event)
		# Keyboard [J]
		var key_event = InputEventKey.new()
		key_event.physical_keycode = KEY_J
		InputMap.action_add_event("last_weapon", key_event)

	# "next_weapon" { Controller: DPad Right, Keyboard: [L] }
	if not InputMap.has_action("next_weapon"):
		# Add the [next_weapon] action to the Input Map
		InputMap.add_action("next_weapon")
		# Controller DPad Right
		var joystick_event = InputEventJoypadButton.new()
		joystick_event.button_index = JOY_BUTTON_DPAD_RIGHT
		InputMap.action_add_event("next_weapon", joystick_event)
		# Keyboard [L]
		var key_event = InputEventKey.new()
		key_event.physical_keycode = KEY_L
		InputMap.action_add_event("next_weapon", key_event)

	# "ui_accept" { Microsoft: Ⓐ, Keyboard: [Enter], [Numpad Enter], [Space] }
	if not InputMap.has_action("ui_accept"):
		# Add the [ui_accept] action to the Input Map
		InputMap.add_action("ui_accept", 0.5)
		# Microsoft Ⓐ, Nintendo Ⓑ, Sony Ⓧ
		var joystick_event = InputEventJoypadButton.new()
		joystick_event.button_index = JOY_BUTTON_A
		InputMap.action_add_event("ui_accept", joystick_event)
		# Keyboard [Enter]
		var key_event = InputEventKey.new()
		key_event.keycode = KEY_ENTER
		InputMap.action_add_event("ui_accept", key_event)
		# Keyboard [Numpad Enter]
		key_event = InputEventKey.new()
		key_event.keycode = KEY_KP_ENTER
		InputMap.action_add_event("ui_accept", key_event)
		# Keyboard [Space]
		key_event = InputEventKey.new()
		key_event.physical_keycode = KEY_SPACE
		InputMap.action_add_event("ui_accept", key_event)

	# "ui_left" { Controller: DPad Left }
	if not InputMap.has_action("ui_left"):
		# Add the [ui_left] action to the Input Map
		InputMap.add_action("ui_left", 0.5)
		# Controller DPad Left
		var joystick_event = InputEventJoypadButton.new()
		joystick_event.button_index = JOY_BUTTON_DPAD_LEFT
		InputMap.action_add_event("ui_left", joystick_event)

	# "ui_right" { Controller: DPad Right }
	if not InputMap.has_action("ui_right"):
		# Add the [ui_right] action to the Input Map
		InputMap.add_action("ui_right", 0.5)
		# Controller DPad Right
		var joystick_event = InputEventJoypadButton.new()
		joystick_event.button_index = JOY_BUTTON_DPAD_RIGHT
		InputMap.action_add_event("ui_right", joystick_event)

	# "ui_up" { Controller: DPad Up }
	if not InputMap.has_action("ui_up"):
		# Add the [ui_up] action to the Input Map
		InputMap.add_action("ui_up", 0.5)
		# Controller DPad Up
		var joystick_event = InputEventJoypadButton.new()
		joystick_event.button_index = JOY_BUTTON_DPAD_UP
		InputMap.action_add_event("ui_up", joystick_event)

	# "ui_down" { Controller: DPad Down }
	if not InputMap.has_action("ui_down"):
		# Add the [ui_down] action to the Input Map
		InputMap.add_action("ui_down", 0.5)
		# Controller DPad Down
		var joystick_event = InputEventJoypadButton.new()
		joystick_event.button_index = JOY_BUTTON_DPAD_DOWN
		InputMap.action_add_event("ui_down", joystick_event)

	# "emote" { Keyboard: [M] }
	if not InputMap.has_action("emote"):
		# Add the [emote] action to the Input Map
		InputMap.add_action("emote", 0.2)
		# Keyboard [M]
		var key_event = InputEventKey.new()
		key_event.physical_keycode = KEY_M
		InputMap.action_add_event("emote", key_event)

	# "unequip" { Keyboard: [Q] }
	if not InputMap.has_action("unequip"):
		# Add the [unequip] action to the Input Map
		InputMap.add_action("unequip", 0.2)
		# Keyboard [Q]
		var key_event = InputEventKey.new()
		key_event.physical_keycode = KEY_Q
		InputMap.action_add_event("unequip", key_event)

	# "debug" { Keyboard: [F11] }
	if not InputMap.has_action("debug"):
		# Add the [debug] action to the Input Map
		InputMap.add_action("debug", 0.2)
		# Keyboard [F11]
		var key_event = InputEventKey.new()
		key_event.keycode = KEY_F11
		InputMap.action_add_event("debug", key_event)


## Called when there is an input event.
func _input(event: InputEvent) -> void:

	# Check if the input is a keyboard or mouse event
	if event is InputEventKey or (event is InputEventMouse and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED):
		# Set the current input type to Keyboard and Mouse
		current_input_type = InputType.KEYBOARD_MOUSE
	# Check if the input is a joystick event
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and abs(event.axis_value) > input_deadzone):
		# Get the name of the connected joystick
		var joystick_name = Input.get_joy_name(event.device).to_lower()
		# Check if the device name indicates it is a Microsoft [XBox] controller
		if joystick_name.contains("xinput") or joystick_name.contains("standard"):
			# Set the current input type to Microsoft
			current_input_type = InputType.MICROSOFT
		# Check if the device name indicates it is a Nintendo [Switch] controller
		elif joystick_name.contains("nintendo"):
			# Set the current input type to Nintendo
			current_input_type = InputType.NINTENDO
		# Check if the device name indicates it is a Sony [PlayStation] controller
		elif joystick_name.contains("dualsense wireless controller") or joystick_name.contains("ps"):
			# Set the current input type to Sony
			current_input_type = InputType.SONY
	# Check if the input is a touch event
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		# Set the current input type to Touch
		current_input_type = InputType.TOUCH

	# Check the action of any touchscreen button and display visual press/release state
	for btn in all_buttons:
		if btn == null or btn.action.is_empty():
			continue
		if event.is_action(btn.action):
			if event.is_action_pressed(btn.action):
				if btn.texture_pressed != null:
					btn.texture_normal = btn.texture_pressed
			elif event.is_action_released(btn.action):
				if btn in _normal_textures:
					btn.texture_normal = _normal_textures[btn]


func reset_labels() -> void:
	for label: Variant in _label_texts.keys():
		if label:
			label.text = _label_texts[label]


func set_labels(label_texts: Dictionary) -> void:
	var final_texts: Dictionary = label_texts.duplicate()
	if left_joystick_label in final_texts and not key_s_label in final_texts:
		final_texts[key_s_label] = final_texts[left_joystick_label]
	if right_joystick_label in final_texts and not key_down_label in final_texts:
		final_texts[key_down_label] = final_texts[right_joystick_label]

	for label: Variant in _label_texts.keys():
		if label:
			if label in final_texts:
				label.text = final_texts[label]
			else:
				# Don't clear joystick labels if they are not explicitly specified
				if label != left_joystick_label and label != right_joystick_label:
					label.text = ""


func update_input_ui(input_type: InputType) -> void:
	if input_type == InputType.KEYBOARD_MOUSE:
		joypad_button_0.texture_normal = keyboard_mouse_button_0_normal
		joypad_button_0.texture_pressed = keyboard_mouse_button_0_pressed
		joypad_button_1.texture_normal = keyboard_mouse_button_1_normal
		joypad_button_1.texture_pressed = keyboard_mouse_button_1_pressed
		joypad_button_2.texture_normal = keyboard_mouse_button_2_normal
		joypad_button_2.texture_pressed = keyboard_mouse_button_2_pressed
		joypad_button_3.texture_normal = keyboard_mouse_button_3_normal
		joypad_button_3.texture_pressed = keyboard_mouse_button_3_pressed
		joypad_button_4.texture_normal = keyboard_mouse_button_4_normal
		joypad_button_4.texture_pressed = keyboard_mouse_button_4_pressed
		joypad_button_15.texture_normal = keyboard_mouse_button_15_normal
		joypad_button_15.texture_pressed = keyboard_mouse_button_15_pressed
		joypad_button_6.texture_normal = keyboard_mouse_button_6_normal
		joypad_button_6.texture_pressed = keyboard_mouse_button_6_pressed
		joypad_button_7.texture_normal = keyboard_mouse_button_7_normal
		joypad_button_7.texture_pressed = keyboard_mouse_button_7_pressed
		joypad_button_8.texture_normal = keyboard_mouse_button_8_normal
		joypad_button_8.texture_pressed = keyboard_mouse_button_8_pressed
		joypad_button_9.texture_normal = keyboard_mouse_button_9_normal
		joypad_button_9.texture_pressed = keyboard_mouse_button_9_pressed
		joypad_button_10.texture_normal = keyboard_mouse_button_10_normal
		joypad_button_10.texture_pressed = keyboard_mouse_button_10_pressed
		joypad_axis_4_plus.texture_normal = keyboard_mouse_axis_4_plus_normal
		joypad_axis_4_plus.texture_pressed = keyboard_mouse_axis_4_plus_pressed
		joypad_axis_5_plus.texture_normal = keyboard_mouse_axis_5_plus_normal
		joypad_axis_5_plus.texture_pressed = keyboard_mouse_axis_5_plus_pressed
		joypad_button_11.hide()
		joypad_button_12.hide()
		joypad_button_13.hide()
		joypad_button_14.hide()
		left_joystick.hide()
		right_joystick.hide()
		key_w.show()
		key_a.show()
		key_s.show()
		key_d.show()
		key_i.show()
		key_j.show()
		key_k.show()
		key_l.show()
		key_up.show()
		key_down.show()
		key_left.show()
		key_right.show()
	elif input_type == InputType.MICROSOFT \
	or input_type == InputType.TOUCH:
		joypad_button_0.texture_normal = microsoft_button_0_normal
		joypad_button_0.texture_pressed = microsoft_button_0_pressed
		joypad_button_1.texture_normal = microsoft_button_1_normal
		joypad_button_1.texture_pressed = microsoft_button_1_pressed
		joypad_button_2.texture_normal = microsoft_button_2_normal
		joypad_button_2.texture_pressed = microsoft_button_2_pressed
		joypad_button_3.texture_normal = microsoft_button_3_normal
		joypad_button_3.texture_pressed = microsoft_button_3_pressed
		joypad_button_4.texture_normal = microsoft_button_4_normal
		joypad_button_4.texture_pressed = microsoft_button_4_pressed
		joypad_button_15.texture_normal = microsoft_button_15_normal
		joypad_button_15.texture_pressed = microsoft_button_15_pressed
		joypad_button_6.texture_normal = microsoft_button_6_normal
		joypad_button_6.texture_pressed = microsoft_button_6_pressed
		joypad_button_7.texture_normal = microsoft_button_7_normal
		joypad_button_7.texture_pressed = microsoft_button_7_pressed
		joypad_button_8.texture_normal = microsoft_button_8_normal
		joypad_button_8.texture_pressed = microsoft_button_8_pressed
		joypad_button_9.texture_normal = microsoft_button_9_normal
		joypad_button_9.texture_pressed = microsoft_button_9_pressed
		joypad_button_10.texture_normal = microsoft_button_10_normal
		joypad_button_10.texture_pressed = microsoft_button_10_pressed
		joypad_axis_4_plus.texture_normal = microsoft_axis_4_plus_normal
		joypad_axis_4_plus.texture_pressed = microsoft_axis_4_plus_pressed
		joypad_axis_5_plus.texture_normal = microsoft_axis_5_plus_normal
		joypad_axis_5_plus.texture_pressed = microsoft_axis_5_plus_pressed
	elif input_type == InputType.NINTENDO:
		joypad_button_0.texture_normal = nintendo_button_0_normal
		joypad_button_0.texture_pressed = nintendo_button_0_pressed
		joypad_button_1.texture_normal = nintendo_button_1_normal
		joypad_button_1.texture_pressed = nintendo_button_1_pressed
		joypad_button_2.texture_normal = nintendo_button_2_normal
		joypad_button_2.texture_pressed = nintendo_button_2_pressed
		joypad_button_3.texture_normal = nintendo_button_3_normal
		joypad_button_3.texture_pressed = nintendo_button_3_pressed
		joypad_button_4.texture_normal = nintendo_button_4_normal
		joypad_button_4.texture_pressed = nintendo_button_4_pressed
		joypad_button_15.texture_normal = nintendo_button_15_normal
		joypad_button_15.texture_pressed = nintendo_button_15_pressed
		joypad_button_6.texture_normal = nintendo_button_6_normal
		joypad_button_6.texture_pressed = nintendo_button_6_pressed
		joypad_button_7.texture_normal = nintendo_button_7_normal
		joypad_button_7.texture_pressed = nintendo_button_7_pressed
		joypad_button_8.texture_normal = nintendo_button_8_normal
		joypad_button_8.texture_pressed = nintendo_button_8_pressed
		joypad_button_9.texture_normal = nintendo_button_9_normal
		joypad_button_9.texture_pressed = nintendo_button_9_pressed
		joypad_button_10.texture_normal = nintendo_button_10_normal
		joypad_button_10.texture_pressed = nintendo_button_10_pressed
		joypad_axis_4_plus.texture_normal = nintendo_axis_4_plus_normal
		joypad_axis_4_plus.texture_pressed = nintendo_axis_4_plus_pressed
		joypad_axis_5_plus.texture_normal = nintendo_axis_5_plus_normal
		joypad_axis_5_plus.texture_pressed = nintendo_axis_5_plus_pressed
	elif input_type == InputType.SONY:
		joypad_button_0.texture_normal = sony_button_0_normal
		joypad_button_0.texture_pressed = sony_button_0_pressed
		joypad_button_1.texture_normal = sony_button_1_normal
		joypad_button_1.texture_pressed = sony_button_1_pressed
		joypad_button_2.texture_normal = sony_button_2_normal
		joypad_button_2.texture_pressed = sony_button_2_pressed
		joypad_button_3.texture_normal = sony_button_3_normal
		joypad_button_3.texture_pressed = sony_button_3_pressed
		joypad_button_4.texture_normal = sony_button_4_normal
		joypad_button_4.texture_pressed = sony_button_4_pressed
		joypad_button_15.texture_normal = sony_button_15_normal
		joypad_button_15.texture_pressed = sony_button_15_pressed
		joypad_button_6.texture_normal = sony_button_6_normal
		joypad_button_6.texture_pressed = sony_button_6_pressed
		joypad_button_7.texture_normal = sony_button_7_normal
		joypad_button_7.texture_pressed = sony_button_7_pressed
		joypad_button_8.texture_normal = sony_button_8_normal
		joypad_button_8.texture_pressed = sony_button_8_pressed
		joypad_button_9.texture_normal = sony_button_9_normal
		joypad_button_9.texture_pressed = sony_button_9_pressed
		joypad_button_10.texture_normal = sony_button_10_normal
		joypad_button_10.texture_pressed = sony_button_10_pressed
		joypad_axis_4_plus.texture_normal = sony_axis_4_plus_normal
		joypad_axis_4_plus.texture_pressed = sony_axis_4_plus_pressed
		joypad_axis_5_plus.texture_normal = sony_axis_5_plus_normal
		joypad_axis_5_plus.texture_pressed = sony_axis_5_plus_pressed

	if input_type != InputType.KEYBOARD_MOUSE:
		# Show joypad controls
		joypad_button_11.show()
		joypad_button_12.show()
		joypad_button_13.show()
		joypad_button_14.show()
		left_joystick.show()
		right_joystick.show()
		# Hide keyboard controls
		key_w.hide()
		key_a.hide()
		key_s.hide()
		key_d.hide()
		key_i.hide()
		key_j.hide()
		key_k.hide()
		key_l.hide()
		key_up.hide()
		key_down.hide()
		key_left.hide()
		key_right.hide()

	# Cache normal textures for visual pressed/released state feedback
	for btn in all_buttons:
		if btn != null:
			_normal_textures[btn] = btn.texture_normal
