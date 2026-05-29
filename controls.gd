extends CanvasLayer

enum InputType {
	KEYBOARD_MOUSE,
	MICROSOFT,
	NINTENDO,
	SONY,
	TOUCH,
}

signal input_type_changed(input_type: InputType)

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
@export var keyboard_mouse_button_9_normal: Texture2D  
@export var keyboard_mouse_button_9_pressed: Texture2D 
@export var keyboard_mouse_button_10_normal: Texture2D
@export var keyboard_mouse_button_10_pressed: Texture2D
@export var keyboard_mouse_axis_4_plus_normal: Texture2D ## Keyboard [Mouse-Left] key (Pressed)
@export var keyboard_mouse_axis_4_plus_pressed: Texture2D ## Keyboard [Mouse-Left] key (Pressed)
@export var keyboard_mouse_axis_5_plus_normal: Texture2D ## Keyboard [Mouse-Right] key (Pressed)
@export var keyboard_mouse_axis_5_plus_pressed: Texture2D ## Keyboard [Mouse-Right] key (Pressed)
@export_category("Microsoft Textures")
@export var microsoft_button_0_normal: Texture2D  ## XBox A (Normal)
@export var microsoft_button_0_pressed: Texture2D ## XBox A (Pressed)
@export var microsoft_button_1_normal: Texture2D  ## XBox B (Normal)
@export var microsoft_button_1_pressed: Texture2D ## XBox B (Pressed)
@export var microsoft_button_2_normal: Texture2D  ## XBox X (Normal)
@export var microsoft_button_2_pressed: Texture2D ## XBox X (Pressed)
@export var microsoft_button_3_normal: Texture2D  ## XBox Y (Normal)
@export var microsoft_button_3_pressed: Texture2D ## XBox Y (Pressed)
@export_category("Nintendo Textures")
@export var nintendo_button_0_normal: Texture2D  ## Nintendo B (Normal)
@export var nintendo_button_0_pressed: Texture2D ## Nintendo B (Pressed)
@export var nintendo_button_1_normal: Texture2D  ## Nintendo A (Normal)
@export var nintendo_button_1_pressed: Texture2D ## Nintendo A (Pressed)
@export var nintendo_button_2_normal: Texture2D  ## Nintendo Y (Normal)
@export var nintendo_button_2_pressed: Texture2D ## Nintendo Y (Pressed)
@export var nintendo_button_3_normal: Texture2D  ## Nintendo X (Normal)
@export var nintendo_button_3_pressed: Texture2D ## Nintendo X (Pressed)
@export_category("Sony Textures")
@export var sony_button_0_normal: Texture2D  ## Sony Cross (Normal)
@export var sony_button_0_pressed: Texture2D ## Sony Cross (Pressed)
@export var sony_button_1_normal: Texture2D  ## Sony Circle (Normal)
@export var sony_button_1_pressed: Texture2D ## Sony Circle (Pressed)
@export var sony_button_2_normal: Texture2D  ## Sony Square (Normal)
@export var sony_button_2_pressed: Texture2D ## Sony Square (Pressed)
@export var sony_button_3_normal: Texture2D  ## Sony Triangle (Normal)
@export var sony_button_3_pressed: Texture2D ## Sony Triangle (Pressed)

@onready var joypad_button_0: TouchScreenButton = $BottomRight/JoypadButton0 ## Joypad Button 0 (Bottom Action, Sony Cross, XBox A, Nintendo B)
@onready var joypad_button_1: TouchScreenButton = $BottomRight/JoypadButton1 ## Joypad Button 1 (Right Action, Sony Circle, XBox B, Nintendo A)
@onready var joypad_button_2: TouchScreenButton = $BottomRight/JoypadButton2 ## Joypad Button 2 (Left Action, Sony Square, XBox X, Nintendo Y)
@onready var joypad_button_3: TouchScreenButton = $BottomRight/JoypadButton3 ## Joypad Button 3 (Top Action, Sony Triangle, XBox Y, Nintendo X)
@onready var joypad_button_4: TouchScreenButton = $TopCenter/JoypadButton4
@onready var joypad_button_15: TouchScreenButton = $TopCenter/JoypadButton15
@onready var joypad_button_6: TouchScreenButton = $TopCenter/JoypadButton6
@onready var joypad_button_7: TouchScreenButton = $BottomLeft/JoypadButton7
@onready var joypad_button_8: TouchScreenButton = $BottomRight/JoypadButton8
@onready var joypad_button_9: TouchScreenButton = $TopLeft/JoypadButton9
@onready var joypad_button_10: TouchScreenButton = $TopRight/JoypadButton10
@onready var joypad_axis_4_plus: TouchScreenButton = $TopLeft/JoypadAxis4Plus
@onready var joypad_axis_5_plus: TouchScreenButton = $TopRight/JoypadAxis5Plus
@onready var joypad_button_11: TouchScreenButton = $BottomLeft/JoypadButton11
@onready var joypad_button_12: TouchScreenButton = $BottomLeft/JoypadButton12
@onready var joypad_button_13: TouchScreenButton = $BottomLeft/JoypadButton13
@onready var joypad_button_14: TouchScreenButton = $BottomLeft/JoypadButton14
@onready var key_w: TouchScreenButton = $BottomLeft/KeyW
@onready var key_a: TouchScreenButton = $BottomLeft/KeyA
@onready var key_s: TouchScreenButton = $BottomLeft/KeyS
@onready var key_d: TouchScreenButton = $BottomLeft/KeyD
@onready var key_i: TouchScreenButton = $BottomLeft/KeyI
@onready var key_j: TouchScreenButton = $BottomLeft/KeyJ
@onready var key_k: TouchScreenButton = $BottomLeft/KeyK
@onready var key_l: TouchScreenButton = $BottomLeft/KeyL
@onready var left_joystick: VirtualJoystick = $BottomLeft/LeftJoystick
@onready var right_joystick: VirtualJoystick = $BottomRight/RightJoystick
@onready var key_up: TouchScreenButton = $BottomRight/KeyUp
@onready var key_left: TouchScreenButton = $BottomRight/KeyLeft
@onready var key_down: TouchScreenButton = $BottomRight/KeyDown
@onready var key_right: TouchScreenButton = $BottomRight/KeyRight


var current_input_type: InputType = InputType.TOUCH:
	set(value):
		if current_input_type != value:
			current_input_type = value
			input_type_changed.emit(value)


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Connect the input_type_changed signal to the update_input_ui function
	input_type_changed.connect(update_input_ui)


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


## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass # Replace with function body.


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
		left_joystick.hide()
		right_joystick.hide()
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
	elif input_type == InputType.NINTENDO:
		joypad_button_0.texture_normal = nintendo_button_0_normal
		joypad_button_0.texture_pressed = nintendo_button_0_pressed
		joypad_button_1.texture_normal = nintendo_button_1_normal
		joypad_button_1.texture_pressed = nintendo_button_1_pressed
		joypad_button_2.texture_normal = nintendo_button_2_normal
		joypad_button_2.texture_pressed = nintendo_button_2_pressed
		joypad_button_3.texture_normal = nintendo_button_3_normal
		joypad_button_3.texture_pressed = nintendo_button_3_pressed
	elif input_type == InputType.SONY:
		joypad_button_0.texture_normal = sony_button_0_normal
		joypad_button_0.texture_pressed = sony_button_0_pressed
		joypad_button_1.texture_normal = sony_button_1_normal
		joypad_button_1.texture_pressed = sony_button_1_pressed
		joypad_button_2.texture_normal = sony_button_2_normal
		joypad_button_2.texture_pressed = sony_button_2_pressed
		joypad_button_3.texture_normal = sony_button_3_normal
		joypad_button_3.texture_pressed = sony_button_3_pressed

	if input_type != InputType.KEYBOARD_MOUSE:
		joypad_button_11.show()
		joypad_button_12.show()
		joypad_button_13.show()
		joypad_button_14.show()
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
		left_joystick.show()
		right_joystick.show()
