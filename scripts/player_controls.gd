class_name PlayerControls
extends Controls

## The player controller's on-screen controls: the [Controls] HUD from the Controls addon, mapped to this
## addon's action names and carrying the four readouts only a player has - the throw charge, the cast bar, the
## boss bar and the ammo count.
##
## The mapping itself is in [code]player_controls.tscn[/code], on the exported action names, so the HUD's own
## repository knows nothing about walking, sprinting or firearms. What is here is the part that needs a
## [Player]: the labels that follow what is equipped, and the readouts the player's own scripts drive.

## The bindings an on-screen button cannot describe on its own. Each slot registers the pad button it is drawn
## on, so this only adds the keyboard keys and mouse buttons behind them, plus the actions with no button on
## the HUD at all.
const PLAYER_ACTIONS: Dictionary = {
	# Keys and mouse buttons behind a button that is on the HUD.
	"action": {"keys": [KEY_E]}, ## Keyboard: [E]
	"sprint": {"keys": [KEY_SHIFT]}, ## Keyboard: [Shift]
	"attack": {"keys": [KEY_ALT]}, ## Keyboard: [Alt]
	"jump": {"keys": [KEY_SPACE]}, ## Keyboard: [Space]
	"crouch": {"keys": [KEY_CTRL]}, ## Keyboard: [Ctrl]
	"scope": {"mouse": [MOUSE_BUTTON_MIDDLE]}, ## Mouse: [Middle-Mouse]
	"focus": {"mouse": [MOUSE_BUTTON_RIGHT]}, ## Mouse: [Right-Click]
	"shoot": {"mouse": [MOUSE_BUTTON_LEFT]}, ## Mouse: [Left-Click]
	"ability": {"keys": [KEY_Q]}, ## Keyboard: [Q]
	"throw": {"keys": [KEY_T]}, ## Keyboard: [T]
	"perspective": {"keys": [KEY_F5]}, ## Keyboard: [F5]
	"share": {"keys": [KEY_PRINT]}, ## Keyboard: [PrtScn]
	"start": {"keys": [KEY_ESCAPE]}, ## Pause menu. Keyboard: [Esc]
	"seeker": {"keys": [KEY_I]}, ## Keyboard: [I]
	"whistle": {"keys": [KEY_K]}, ## Keyboard: [K]
	"last_weapon": {"keys": [KEY_J]}, ## Keyboard: [J]
	"next_weapon": {"keys": [KEY_L]}, ## Keyboard: [L]

	# Actions with no button on the HUD.
	"reload": {"keys": [KEY_R]}, ## Refill the equipped firearm; an empty magazine also reloads on the next trigger pull. Keyboard: [R]
	"broadcast": {"keys": [KEY_V]}, ## Push-to-talk. Keyboard: [V]
	"chat": {"keycodes": [KEY_ENTER, KEY_KP_ENTER]}, ## Opens the chat window; handled in _unhandled_input so menus keep Enter. Keyboard: [Enter]
	"debug": {"keycodes": [KEY_F3]}, ## Debug HUD. Keyboard: [F3]
	"toggle_toon": {"keycodes": [KEY_F6]}, ## Toon shading filter on or off. Keyboard: [F6]

	# The menus are driven by the engine's own actions, which the HUD's buttons no longer stand for.
	"ui_accept": {"deadzone": 0.5, "keycodes": [KEY_ENTER, KEY_KP_ENTER], "keys": [KEY_SPACE], "buttons": [JOY_BUTTON_A]},
	"ui_left": {"deadzone": 0.5, "buttons": [JOY_BUTTON_DPAD_LEFT]},
	"ui_right": {"deadzone": 0.5, "buttons": [JOY_BUTTON_DPAD_RIGHT]},
	"ui_up": {"deadzone": 0.5, "buttons": [JOY_BUTTON_DPAD_UP]},
	"ui_down": {"deadzone": 0.5, "buttons": [JOY_BUTTON_DPAD_DOWN]},
}

@export var player: Player

var _seeker_shown: String = "" ## What [method seeker_label_text] said when the labels were last applied.

@onready var cast_bar: ProgressBar = %CastBar ## Fills while an ability with a cast time is cast.
@onready var cast_label: Label = %CastLabel ## Names the ability being cast on the cast bar.
@onready var boss_bar: VBoxContainer = %BossBar ## Name and health of the boss this player is fighting.
@onready var boss_name_label: Label = %BossName
@onready var boss_health_bar: ProgressBar = %BossHealth
@onready var ammo_label: Label = %AmmoLabel ## Magazine / reserve of the equipped firearm; [Firearm] drives it.


func _ready() -> void:
	if player == null and get_parent() is Player:
		player = get_parent() as Player
	extra_actions = PLAYER_ACTIONS
	super()
	contextual_labels_requested.connect(_on_contextual_labels_requested)


## The seeker label follows the aim, so holding or releasing focus has to be seen here too.
func _input(event: InputEvent) -> void:
	super(event)
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		return
	if InputMap.has_action(&"focus") and (event.is_action_pressed(&"focus") or event.is_action_released(&"focus")):
		refresh_seeker_label()


## After a plain reset the labels that follow what is equipped have to go back on: what the trigger aims, what
## the seeker wheel would offer, and which ability the shoulder button casts.
func _apply_contextual_labels() -> void:
	if player == null:
		return
	if player.has_firearm_equipped:
		joypad_axis_4_plus_label.text = "Aim"
	var seeker: String = seeker_label_text()
	if seeker != "":
		joypad_button_11_label.text = seeker
		key_i_label.text = seeker
	if player.abilities != null and player.abilities.active_ability:
		joypad_button_9_label.text = player.abilities.active_ability.display_name
	_seeker_shown = seeker


func _labels_applied() -> void:
	_seeker_shown = seeker_label_text()


## A prompt gave the Action button back, so the state the player is in re-applies its own labels.
func _on_contextual_labels_requested() -> void:
	if player != null:
		player.refresh_contextual_controls()


## What Seeker (D-pad Up / I) opens right now, as [method SeekerWheel.get_aimed_weapon] decides: the arrow kinds
## while the bow is aimed (focus held or the string drawn), the ammunition while a gun is aimed, else the scene's
## default label (empty means keep it): a slung bow opens the throwables, not the arrows.
func seeker_label_text() -> String:
	if player == null or player.inventory == null or player.seeker_wheel == null:
		return ""
	var aimed: Equipment = player.seeker_wheel.get_aimed_weapon()
	if aimed is Bow:
		return "Arrows"
	if aimed is Firearm:
		return "Ammo"
	return ""


## The seeker label follows the aim: wired to Player.locomotion_node_changed (the string drawn or let go) and called on
## the focus action, it re-applies the state's labels only when what the wheel would offer has changed.
func refresh_seeker_label() -> void:
	if player != null and seeker_label_text() != _seeker_shown:
		player.refresh_contextual_controls()


func _on_locomotion_node_changed(_state_path: String) -> void:
	refresh_seeker_label()


## Shows the boss bar for [param boss_name] at [param ratio] (0-1) health; [Boss] drives these three.
func show_boss(boss_name: String, ratio: float) -> void:
	boss_name_label.text = boss_name
	boss_health_bar.value = ratio
	boss_bar.show()


func update_boss(ratio: float) -> void:
	boss_health_bar.value = ratio


func hide_boss() -> void:
	boss_bar.hide()


## Shows rounds in the magazine and in reserve while a firearm is equipped.
func set_ammo(rounds: int, reserve: int) -> void:
	ammo_label.text = "%d / %d" % [rounds, reserve]
	ammo_label.show()


func hide_ammo() -> void:
	ammo_label.hide()
