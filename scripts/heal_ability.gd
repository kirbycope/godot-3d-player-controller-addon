class_name HealAbility
extends Ability
## Restores stamina after a cast, standing in for a healing spell until the project has hit points.

@export var amount: float = 50.0 ## Stamina restored when the cast lands.


func activate(player: Player) -> bool:
	if player.stamina.stamina >= player.stamina.max_value:
		return false
	player.stamina.stamina += amount
	return true
