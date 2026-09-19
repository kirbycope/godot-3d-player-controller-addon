@tool
class_name PlayerControls
extends Controls

## The player controller's on-screen controls: the [Controls] HUD from the Controls addon, mapped to this
## addon's action names and carrying the throw charge, which is an input hint like the buttons around it.
##
## The gameplay readouts used to hang here too. They are their own scenes now, each beside the system that
## drives it: [BossBar], [AmmoReadout] and [CastBar]. See [HudReadout].
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
	"flashlight": {"keys": [KEY_F]}, ## A [Flashlight] on or off; a scene that wants it on the pad rebinds a slot ([method bind_slot]). Keyboard: [F]
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

## Which game's pad the face buttons are laid out like. The keyboard keys behind them
## ([constant PLAYER_ACTIONS]), the shoulders, the triggers, the sticks and the d-pad are the same in every
## scheme; a scheme moves the four face buttons about and decides what Focus does (see
## [method Player.lock_on_enabled]). [member Player.control_scheme] picks it.
##
## The layouts that ship with the addon, in the order the settings menu lists them. Each one is a
## [ControlScheme] resource rather than a branch in code, so a game adds a layout of its own by writing
## another [code].tres[/code] in [code]resources/control_schemes/[/code] and assigning it to
## [member Player.control_scheme]. Only the settings menu's list is built from this array; nothing else in
## the addon needs to know which schemes exist.
const BUILT_IN_SCHEMES: Array[ControlScheme] = [
	preload("res://addons/3d_player_controller/resources/control_schemes/totk.tres"),
	preload("res://addons/3d_player_controller/resources/control_schemes/smo.tres"),
	preload("res://addons/3d_player_controller/resources/control_schemes/dark_souls.tres"),
	preload("res://addons/3d_player_controller/resources/control_schemes/half_life.tres"),
	preload("res://addons/3d_player_controller/resources/control_schemes/metal_gear.tres"),
	preload("res://addons/3d_player_controller/resources/control_schemes/resident_evil.tres"),
]

## Layouts another addon or the game itself has added to the settings menu, in the order they registered.
static var _registered_schemes: Array[ControlScheme] = []

## What each slot outside the four faces carried before a scheme moved it, so the next scheme that does not
## mention that slot can hand it back rather than leaving the last layout's binding behind.
var _slots_before_scheme: Dictionary[String, StringName] = {}

## Adds [param scheme] to the layouts the settings menu offers, for an addon or a game that ships one of its
## own. Registering the same scheme twice does nothing, so this is safe to call from every scene that wants it.
##
## The player controller must not preload out of another addon, or the template would depend on an addon that
## may not be installed; so a layout living elsewhere is announced this way instead. The settings save the
## player's pick by name rather than by position, so a scheme registering late does not change what an already
## saved choice means.
static func register_scheme(scheme: ControlScheme) -> void:
	if scheme == null or BUILT_IN_SCHEMES.has(scheme) or _registered_schemes.has(scheme):
		return
	_registered_schemes.append(scheme)


## Forgets every registered layout. For tests, which share one process and would otherwise leak a scheme from
## one script into the next.
static func forget_registered_schemes() -> void:
	_registered_schemes.clear()


## Every layout the settings menu offers: the ones that ship here, then whatever registered.
static func schemes() -> Array[ControlScheme]:
	var out: Array[ControlScheme] = BUILT_IN_SCHEMES.duplicate()
	out.append_array(_registered_schemes)
	return out


## The layout called [param scheme_name], or null when nothing answers to it (an addon that shipped it is not
## installed any more, so the player falls back to what the scene set).
static func scheme_named(scheme_name: String) -> ControlScheme:
	if scheme_name.is_empty():
		return null
	for scheme: ControlScheme in schemes():
		if scheme.scheme_name == scheme_name:
			return scheme
	return null


## The layout a Player falls back to when a scene leaves [member Player.control_scheme] empty.
const DEFAULT_SCHEME: ControlScheme = preload("res://addons/3d_player_controller/resources/control_schemes/totk.tres")

## What a face button reads when nothing contextual is showing, by the action it stands for; the scene's own
## label texts are for the Zelda layout, so a swapped button takes its text from here.
const ACTION_LABELS: Dictionary[StringName, String] = {
	&"action": "Action", &"sprint": "Sprint", &"attack": "Attack", &"jump": "Jump",
}

@export var player: Player

var _seeker_shown: String = "" ## What [method seeker_label_text] said when the labels were last applied.
var _hud_ready: bool = false ## The base has bound the slots and cached the art; a scheme change from here on rebinds live.
## The actions a PlayerControls registered itself, across every instance there has been. The base takes any
## action that exists before it registers its own for the project's, and leaves it alone; but a second Player (a
## restart, a second local player) finds the first one's actions already there, and those are ours to rebind.
static var _registered_actions: Dictionary[StringName, bool] = {}



func _ready() -> void:
	_clusters.append($BottomCenter) # the readouts under the crosshair scale with the corners
	if player == null and get_parent() is Player:
		player = get_parent() as Player
	# The scheme's slots go on before the base registers them, so the pad is bound the way the Player asked
	if player and not Engine.is_editor_hint():
		apply_control_scheme(player.control_scheme)
	extra_actions = PLAYER_ACTIONS
	super()
	if Engine.is_editor_hint():
		return
	_hud_ready = is_multiplayer_authority()
	for action_name: StringName in _own_action_names():
		if not _foreign_actions.has(String(action_name)):
			_registered_actions[action_name] = true
	contextual_labels_requested.connect(_on_contextual_labels_requested)


## Lays the face buttons out for [param scheme]. Before the HUD is ready it only fills the slot exports, and the
## base class binds them; afterwards it also moves each button off the action it stood for, binds it to the new
## one, swaps the resting labels and redraws, so the switch works from the settings menu mid-game. An action the
## project bound for itself is left exactly as it is, as the base leaves it.
func apply_control_scheme(scheme: ControlScheme) -> void:
	if scheme == null:
		return
	var slots: Dictionary[String, StringName] = scheme.slots()
	# is_node_ready() is already true inside _ready, so the base's own setup is waited for explicitly
	if not _hud_ready:
		# Before the base has registered anything there is nothing to rebind, so the exports are simply filled
		# and the base picks them up; the same goes for the slots beyond the four faces.
		for slot: String in slots:
			set(slot, slots[slot])
		for slot: String in scheme.extra_slots:
			if SLOT_EVENTS.has(slot):
				_slots_before_scheme[slot] = get("action_" + slot)
				set("action_" + slot, scheme.extra_slots[slot])
		return
	for slot: String in slots:
		var previous: StringName = get(slot)
		var wanted: StringName = slots[slot]
		var events: Array[InputEvent] = _events_for(SLOT_EVENTS[slot.trim_prefix("action_")])
		# Off the old action first, or A would still sprint after it became Action
		if not previous.is_empty() and previous != wanted and _owns_action(previous):
			for event: InputEvent in events:
				if InputMap.action_has_event(previous, event):
					InputMap.action_erase_event(previous, event)
		set(slot, wanted)
		if wanted.is_empty():
			continue
		if not InputMap.has_action(wanted):
			InputMap.add_action(wanted, 0.2)
			_registered_actions[wanted] = true
		if _owns_action(wanted):
			for event: InputEvent in events:
				if not InputMap.action_has_event(wanted, event):
					InputMap.action_add_event(wanted, event)
	_apply_slot_actions()
	for slot: String in slots:
		var label: Label = get("joypad_%s_label" % slot.trim_prefix("action_"))
		if label:
			_label_texts[label] = ACTION_LABELS.get(slots[slot], String(slots[slot]).capitalize())
	_apply_extra_slots(scheme.extra_slots)
	update_input_ui()
	reset_labels()
	if player:
		player.refresh_contextual_controls()


## Moves the shoulders, triggers, stick clicks and d-pad a layout asks for, and hands back any slot the last
## layout moved that this one does not mention, so one scheme's reach does not survive into the next.
func _apply_extra_slots(wanted: Dictionary[String, StringName]) -> void:
	for slot: String in _slots_before_scheme.keys():
		if not wanted.has(slot):
			bind_slot(slot, _slots_before_scheme[slot])
			_slots_before_scheme.erase(slot)
	for slot: String in wanted:
		if not SLOT_EVENTS.has(slot):
			push_warning("ControlScheme asks for a slot the HUD does not have: %s" % slot)
			continue
		if not _slots_before_scheme.has(slot):
			_slots_before_scheme[slot] = get("action_" + slot)
		bind_slot(slot, wanted[slot], ACTION_LABELS.get(wanted[slot], String(wanted[slot]).capitalize()))


## Puts [param action] on one face, shoulder or d-pad [param slot] ("button_12" for d-pad down) live, the way a
## scheme moves the four face buttons: the button comes off the action it carried, goes on to the new one, and
## reads [param label] at rest. A scene that needs a button the layout lacks (a horror game's flashlight on the
## d-pad) asks for it here; a project-bound action is left as it is, as the base leaves it.
func bind_slot(slot: String, action: StringName, label: String = "") -> void:
	var property: String = "action_" + slot
	var previous: StringName = get(property)
	if previous == action:
		return
	var events: Array[InputEvent] = _events_for(SLOT_EVENTS[slot])
	if not previous.is_empty() and _owns_action(previous):
		for event: InputEvent in events:
			if InputMap.action_has_event(previous, event):
				InputMap.action_erase_event(previous, event)
	set(property, action)
	if not action.is_empty():
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
			_registered_actions[action] = true
		if _owns_action(action):
			for event: InputEvent in events:
				if not InputMap.action_has_event(action, event):
					InputMap.action_add_event(action, event)
	_apply_slot_actions()
	var label_node: Label = get("joypad_%s_label" % slot) as Label
	if label_node:
		_label_texts[label_node] = label if not label.is_empty() else String(action).capitalize()
	update_input_ui()
	reset_labels()
	if player:
		player.refresh_contextual_controls()


## The gameplay actions this HUD registered for its Player: the slots and the extra keys, ui_* aside.
func _own_action_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for action_name: StringName in get_slot_actions().values():
		if not action_name.is_empty() and not String(action_name).begins_with("ui_") and not names.has(action_name):
			names.append(action_name)
	for key: String in extra_actions:
		if not key.begins_with("ui_") and not names.has(StringName(key)):
			names.append(StringName(key))
	return names


## Whether [param action_name] is this HUD's to rebind: one a PlayerControls created, rather than one the
## project declared in its own input map.
func _owns_action(action_name: StringName) -> bool:
	return _registered_actions.has(action_name) or not _foreign_actions.has(String(action_name))


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

