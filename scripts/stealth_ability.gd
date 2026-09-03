class_name StealthAbility
extends Ability
## Toggles [member Player.is_stealthed]: the model fades, followers lose the Player and any attack ends it.


func _init() -> void:
	is_toggle = true
	ends_on_attack = true


func activate(player: Player) -> bool:
	player.is_stealthed = true
	return true


func deactivate(player: Player) -> void:
	player.is_stealthed = false
