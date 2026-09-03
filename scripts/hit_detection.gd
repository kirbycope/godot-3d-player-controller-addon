class_name HitDetection
extends Node
## Applies knockback and [code]register_weapon_hit()[/code] to bodies entering the active attack hitboxes.
##
## Unarmed attacks use the hand hitboxes in player.tscn; armed attacks use the equipped weapon's
## child [Area3D] named "Hitbox". Hitboxes only monitor during attack swings, and each target is
## notified once per swing.

const KNOCKBACK_MULTIPLIER: float = 10.0 ## Scales [member Player.push_force] for attack knockback.

@export var player: Player
@export var left_hand_hitbox: Area3D
@export var right_hand_hitbox: Area3D

var _hitboxes: Array[Area3D] = [] ## Hitboxes of the current loadout (hands when unarmed).
var _swing_hit_targets: Array[Node] = [] ## Targets already notified during the current swing.
var _impulse_applied: bool = false ## One knockback impulse per swing.


func _ready() -> void:
	if player == null or not is_multiplayer_authority():
		return
	left_hand_hitbox.body_entered.connect(_on_hitbox_body_entered.bind(left_hand_hitbox, null))
	right_hand_hitbox.body_entered.connect(_on_hitbox_body_entered.bind(right_hand_hitbox, null))
	_hitboxes.assign([left_hand_hitbox, right_hand_hitbox])


## Every locomotion node change is a new swing; hitboxes monitor only while an attack node plays.
func _on_locomotion_node_changed(_state_path: String) -> void:
	_swing_hit_targets.clear()
	_impulse_applied = false
	var is_swinging: bool = player.is_attacking_1 or player.is_attacking_2 or player.is_attacking_3
	for hitbox: Area3D in _hitboxes:
		hitbox.monitoring = is_swinging


## Rebuilds the hitbox list from the equipped weapons (hands when unarmed).
func _on_equipment_changed() -> void:
	for hitbox: Area3D in _hitboxes:
		hitbox.monitoring = false
	_hitboxes.clear()
	if player.inventory.is_unarmed():
		_hitboxes.assign([left_hand_hitbox, right_hand_hitbox])
		return
	for equipment: Equipment in player.inventory.equipment:
		var hitbox: Area3D = equipment.get_node_or_null("Hitbox") as Area3D
		if not equipment.can_attack or hitbox == null:
			continue
		hitbox.monitoring = false
		if not hitbox.body_entered.is_connected(_on_hitbox_body_entered.bind(hitbox, equipment)):
			hitbox.body_entered.connect(_on_hitbox_body_entered.bind(hitbox, equipment))
		_hitboxes.append(hitbox)


## Notifies the hit target once per swing and applies the swing's single knockback impulse.
func _on_hitbox_body_entered(body: Node3D, hitbox: Area3D, equipment: Equipment) -> void:
	if body == player or body.get_parent() == player.physical_bone_simulator:
		return
	_register_weapon_hit(body, equipment if equipment else player)

	if _impulse_applied or not body.has_method("apply_impulse"):
		return
	if body.has_meta("no_knockback_until") and Time.get_ticks_msec() < int(body.get_meta("no_knockback_until")):
		return
	_impulse_applied = true

	var push_dir: Vector3 = (-player.global_transform.basis.z.normalized() + player.up_direction * 0.5).normalized()
	var body_mass: float = float(body.get("mass")) if body.get("mass") != null else 1.0
	var effective_mass: float = (player.mass * body_mass) / (player.mass + body_mass)
	var impulse: Vector3 = push_dir * player.push_force * KNOCKBACK_MULTIPLIER * effective_mass
	body.call("apply_impulse", impulse, hitbox.global_position - body.global_position)


## Notifies the nearest ancestor that handles weapon hits, once per target per swing.
func _register_weapon_hit(collider: Node, equipment: Node) -> void:
	var node: Node = collider
	while node:
		if node.has_method("register_weapon_hit"):
			if node not in _swing_hit_targets:
				_swing_hit_targets.append(node)
				node.call("register_weapon_hit", equipment, collider)
			return
		node = node.get_parent()
