@tool
class_name ControlScheme
extends Resource

## One pad layout: which action each of the four face buttons carries, and what Focus does.
##
## The keyboard keys behind the buttons ([constant PlayerControls.PLAYER_ACTIONS]), the shoulders, the
## triggers, the sticks and the d-pad are the same in every scheme, so a scheme is only the four faces plus
## [member locks_on]. The ones that ship are in [code]resources/control_schemes/[/code]; a game that wants its
## own writes another [code].tres[/code] beside them and assigns it to [member Player.control_scheme], with
## nothing in this addon to edit.

@export var scheme_name: String = "" ## What the settings menu calls this layout.

@export_group("Face buttons")
## The action the bottom face button carries: A on an Xbox pad, Cross on a PlayStation one.
@export var action_button_0: StringName = &""
## The action the right face button carries: B on an Xbox pad, Circle on a PlayStation one.
@export var action_button_1: StringName = &""
## The action the left face button carries: X on an Xbox pad, Square on a PlayStation one.
@export var action_button_2: StringName = &""
## The action the top face button carries: Y on an Xbox pad, Triangle on a PlayStation one.
@export var action_button_3: StringName = &""

@export_group("Focus")
## Focus locks on to a target, Breath of the Wild style. Off, Focus is a free over-the-shoulder aim, Grand
## Theft Auto style. [method Player.lock_on_enabled] is this flag, and [Camera] and [Focus] follow it.
@export var locks_on: bool = true


## The slot-to-action mapping [method PlayerControls.apply_control_scheme] applies, keyed by the slot's export
## name on the HUD.
func slots() -> Dictionary[String, StringName]:
	return {
		"action_button_0": action_button_0,
		"action_button_1": action_button_1,
		"action_button_2": action_button_2,
		"action_button_3": action_button_3,
	}
