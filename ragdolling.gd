class_name Ragdolling
extends NodeStateMachine

var _this_state := NodeStateMachine.States.RAGDOLLING


var _hips_physical_bone: PhysicalBone3D


func _ready() -> void:
	# Ensure physical bones collision layer 1 is disabled by default
	_set_physical_bones_collision_layer.call_deferred(false)


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Do nothing if the player is not set
	if not player: return

	# If the player is ragdolling, pressing the "action" button will stop "ragdolling"
	if player.is_ragdolling and Input.is_action_just_pressed("action"):
		player.state_machine.travel(_this_state, NodeStateMachine.States.STANDING)


## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Do nothing if the player is not set
	if not player: return

	# Sync player global position to the hips physical bone position while ragdolling
	if player.is_ragdolling:
		var hips_bone := _get_hips_physical_bone()
		if hips_bone:
			player.global_position = hips_bone.global_position


## Start "ragdolling".
func start() -> void:
	# Enable _this_ state node
	process_mode = Node.PROCESS_MODE_INHERIT
	# Set the player's new state
	player.current_state = _this_state
	# Flag the player as "ragdolling"
	player.is_ragdolling = true
	# Detach player_model transform hierarchy while ragdolling so setting player.global_position does not shift physical bones
	if player.player_model:
		player.player_model.top_level = true
	# Disable the AnimationTree to prevent animations from continuing and playing audio via method tracks
	if player.animation_tree:
		player.animation_tree.active = false
	# Set collision layer 1 on physical bones
	_set_physical_bones_collision_layer(true)
	# Start skeleton physical bones simulation
	if player.physical_bone_simulator:
		player.physical_bone_simulator.physical_bones_start_simulation()
	# Disable main collision shape while ragdolling
	if player.collision_shape:
		player.collision_shape.disabled = true


## Stop "ragdolling".
func stop() -> void:
	# Disable _this_ state node
	process_mode = Node.PROCESS_MODE_DISABLED
	# Clear the player's state (if it is currently set to _this_ state)
	if player.current_state == _this_state:
		player.current_state = -1
	# Flag the player as not "ragdolling"
	player.is_ragdolling = false
	# Sync position one last time to hips bone position before restoring player_model
	var hips_bone := _get_hips_physical_bone()
	if hips_bone:
		player.global_position = hips_bone.global_position
	# Re-attach player_model transform hierarchy and restore initial transform
	if player.player_model:
		player.player_model.top_level = false
		player.player_model.transform = player.initial_player_model_transform
	# Re-enable the AnimationTree
	if player.animation_tree:
		player.animation_tree.active = true
	# Stop skeleton physical bones simulation
	if player.physical_bone_simulator:
		player.physical_bone_simulator.physical_bones_stop_simulation()
	# Remove collision layer 1 from physical bones
	_set_physical_bones_collision_layer(false)
	# Re-enable main collision shape
	if player.collision_shape:
		player.collision_shape.disabled = false
	_hips_physical_bone = null


func _get_hips_physical_bone() -> PhysicalBone3D:
	if is_instance_valid(_hips_physical_bone):
		return _hips_physical_bone
	if not player or not player.physical_bone_simulator:
		return null
	if player.physical_bone_simulator.has_node("Physical Bone Hips"):
		_hips_physical_bone = player.physical_bone_simulator.get_node("Physical Bone Hips") as PhysicalBone3D
		return _hips_physical_bone
	for bone in player.physical_bone_simulator.find_children("*", "PhysicalBone3D", true, false):
		if bone is PhysicalBone3D and (bone.bone_name == "Hips" or "Hips" in bone.name):
			_hips_physical_bone = bone as PhysicalBone3D
			return _hips_physical_bone
	return null


func _set_physical_bones_collision_layer(enabled: bool) -> void:
	if not player or not player.physical_bone_simulator:
		return
	for bone in player.physical_bone_simulator.find_children("*", "PhysicalBone3D", true, false):
		bone.set_collision_layer_value(1, enabled)
		bone.set_collision_mask_value(1, enabled)
