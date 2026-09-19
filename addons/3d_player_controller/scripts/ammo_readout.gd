class_name AmmoReadout
extends HudReadout

## The equipped firearm's magazine and reserve, under the crosshair.
##
## [Firearm] drives it, so the readout ships with the guns rather than with the button HUD: a project that takes
## this addon for its firearms gets the count with them. See [HudReadout] for why it is its own scene.

const NO_RESERVE: int = -1 ## Passed as the reserve by a firearm that does not carry one, which then shows alone.

@onready var label: Label = %Label ## Shown only while a firearm is in hand.


## Shows [param rounds] in the magazine against [param reserve] in reserve.
func set_ammo(rounds: int, reserve: int) -> void:
	label.text = "%d" % rounds if reserve == NO_RESERVE else "%d / %d" % [rounds, reserve]
	label.visible = true


## Nothing is in hand to count.
func hide_ammo() -> void:
	label.visible = false
