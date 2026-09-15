class_name DamageAbility
extends Ability
## Hurts the target through its `take_hit(damage, from)`: a fireball, a bolt, a smite. With a
## [member Ability.projectile_speed] the casting VFX flies to the target as a [SpellProjectile] and the damage
## lands on arrival; the [member Ability.elements] apply on impact as for any ability, so a fire bolt sets the
## grass alight. [member splash_radius] hurts everyone in the "Focusable" group that close to the impact too.

@export var damage: float = 30.0
@export var splash_radius: float = 0.0 ## Others within this of the impact take [member damage] as well; 0 hits the target alone.


func _init() -> void:
	target_mode = Target.FOCUS


func activate(_caster: Node3D) -> bool:
	return true


func impact(caster: Node3D, target: Node3D) -> void:
	var from: Vector3 = caster.global_position if is_instance_valid(caster) else Vector3.ZERO
	if is_instance_valid(target) and target.has_method("take_hit"):
		target.call("take_hit", damage, from)
	if splash_radius <= 0.0 or not is_instance_valid(target):
		return
	var at: Vector3 = target.global_position
	for other: Node in target.get_tree().get_nodes_in_group(&"Focusable"):
		if other == target or other == caster or not other is Node3D or not other.has_method("take_hit"):
			continue
		if (other as Node3D).global_position.distance_to(at) <= splash_radius:
			other.call("take_hit", damage, from)
