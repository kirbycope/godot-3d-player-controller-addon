class_name HealAbility
extends Ability
## Heals whoever casts it through their `heal(amount) -> bool` method: stamina for the Player, health for NPCs.

@export var amount: float = 50.0


func activate(caster: Node3D) -> bool:
	return caster.has_method("heal") and caster.call("heal", amount)
