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

@onready var joypad_button_0: TouchScreenButton = $BottomRight/JoypadButton0 ## Joypad Button 0 (Bottom Action, Sony Cross, XBox A, Nintendo B)
@onready var joypad_button_1: TouchScreenButton = $BottomRight/JoypadButton1 ## Joypad Button 1 (Right Action, Sony Circle, XBox B, Nintendo A)
@onready var joypad_button_2: TouchScreenButton = $BottomRight/JoypadButton2 ## Joypad Button 2 (Left Action, Sony Square, XBox X, Nintendo Y)
@onready var joypad_button_3: TouchScreenButton = $BottomRight/JoypadButton3 ## Joypad Button 3 (Top Action, Sony Triangle, XBox Y, Nintendo X)


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
		# Show Keyboard and Mouse UI elements
		print("Input type changed to: Keyboard and Mouse")

		# Set the JoypadButton0's TextureNormal to [E] key outline image
		joypad_button_0.texture_normal = load("uid://5ralud042mx3")
		# Set the JoypadButton0's TexturePressed to [E] key image
		joypad_button_0.texture_pressed = load("uid://cmkoi6h1swd7x")

		# Set the JoypadButton1's TextureNormal to [Shift] key outline image
		joypad_button_1.texture_normal = load("uid://4rb1ivk0g56d")
		# Set the JoypadButton1's TexturePressed to [Shift] key image
		joypad_button_1.texture_pressed = load("uid://cf1ovwiublnx0")

		# Set the JoypadButton2's TextureNormal to [] key outline image
		#joypad_button_2.texture_normal = load("")
		# Set the JoypadButton2's TexturePressed to [] key image
		#joypad_button_2.texture_pressed = load("")

		# Set the JoypadButton3's TextureNormal to [Space] key outline image
		joypad_button_3.texture_normal = load("uid://blxkplufvt6vo")
		# Set the JoypadButton3's TexturePressed to [Space] key image
		joypad_button_3.texture_pressed = load("uid://coyvdy1y0wvhn")

	elif input_type == InputType.MICROSOFT:
		# Show Microsoft controller UI elements
		print("Input type changed to: Microsoft Controller")

		# Set the JoypadButton0's TextureNormal to (A) button outline image
		joypad_button_0.texture_normal = load("uid://bn5f4wvar6tor")
		# Set the JoypadButton0's TexturePressed to (A) button key image
		joypad_button_0.texture_pressed = load("uid://corxgxm4mi0l8")

		# Set the JoypadButton1's TextureNormal to (B) button outline image
		joypad_button_1.texture_normal = load("uid://dpc825bf8ua8i")
		# Set the JoypadButton1's TexturePressed to (B) button image
		joypad_button_1.texture_pressed = load("uid://bumejmnr3to5g")

		# Set the JoypadButton2's TextureNormal to (X) button outline image
		joypad_button_2.texture_normal = load("uid://bojfftndyi7ux")
		# Set the JoypadButton2's TexturePressed to (X) button image
		joypad_button_2.texture_pressed = load("uid://uhxr6ne3h322")

		# Set the JoypadButton3's TextureNormal to (Y) button outline image
		joypad_button_3.texture_normal = load("uid://f71afsg8l76k")
		# Set the JoypadButton3's TexturePressed to (Y) button image
		joypad_button_3.texture_pressed = load("uid://na0ycwh1x0k8")

	elif input_type == InputType.NINTENDO:
		# Show Nintendo controller UI elements
		print("Input type changed to: Nintendo Controller")

	elif input_type == InputType.SONY:
		# Show Sony controller UI elements
		print("Input type changed to: Sony Controller")

		# Set the JoypadButton0's TextureNormal to (Cross) button outline image
		joypad_button_0.texture_normal = load("uid://cdew4cemfiitk")
		# Set the JoypadButton0's TexturePressed to (Cross) button key image
		joypad_button_0.texture_pressed = load("uid://bxjf63yifb35a")

		# Set the JoypadButton1's TextureNormal to (Circle) button outline image
		joypad_button_1.texture_normal = load("uid://qtrlr1x0yxl6")
		# Set the JoypadButton1's TexturePressed to (Circle) button image
		joypad_button_1.texture_pressed = load("uid://dlyw5843hlpwi")

		# Set the JoypadButton2's TextureNormal to (Square) button outline image
		joypad_button_2.texture_normal = load("uid://k5tx57ld55c5")
		# Set the JoypadButton2's TexturePressed to (Square) button image
		joypad_button_2.texture_pressed = load("uid://duuk8t5f522sd")

		# Set the JoypadButton3's TextureNormal to (Triangle) button outline image
		joypad_button_3.texture_normal = load("uid://b16rh4gfnvnuo")
		# Set the JoypadButton3's TexturePressed to (Triangle) button image
		joypad_button_3.texture_pressed = load("uid://sa7dbyh4pm56")

	elif input_type == InputType.TOUCH:
		# Show touch UI elements
		print("Input type changed to: Touch Controls")
