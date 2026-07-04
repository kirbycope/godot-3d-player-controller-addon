class_name Jumping
extends NodeStateMachine


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Do nothing if the player is not set
	if not player: return


## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Do nothing if the player is not set
	if not player: return

	# Check if the player has reached the floor
	if player.is_on_floor() and not player.is_jump_queued:
		# "Stop "jumping"
		stop()


## Start "jumping".
func start() -> void:
	# Enable _this_ state node
	process_mode = Node.PROCESS_MODE_INHERIT
	# Set the player's new state
	player.current_state = NodeStateMachine.States.JUMPING
	# Flag the player as "falling"
	player.is_jumping = true
	# Perform a forward jump if there is motion input
	if player.player_input.motion.length() > 0.0:
		if player.has_heavy_weapon_equipped():
			player.locomotion_state.travel("GreatSwordJumpForward")
		elif player.has_equipment(Equipment.EquipmentType.BOW):
			player.locomotion_state.travel("BowJumpForward")
		elif player.has_one_handed_or_shield_equipped():
			player.locomotion_state.travel("ShieldJumpForward")
		elif player.has_equipment(Equipment.EquipmentType.PISTOL):
			player.locomotion_state.travel("PistolJumpForward")
		elif player.has_equipment(Equipment.EquipmentType.RIFLE):
			player.locomotion_state.travel("RifleJumpForward")
		else:
			player.locomotion_state.travel("RunningJump")
	# Otherwise perform a vertical jump
	else:
		if player.has_heavy_weapon_equipped():
			player.locomotion_state.travel("GreatSwordJump")
		elif player.has_equipment(Equipment.EquipmentType.BOW):
			player.locomotion_state.travel("BowJump")
		elif player.has_one_handed_or_shield_equipped():
			player.locomotion_state.travel("ShieldJump")
		elif player.has_equipment(Equipment.EquipmentType.PISTOL):
			player.locomotion_state.travel("PistolJump")
		elif player.has_equipment(Equipment.EquipmentType.RIFLE):
			player.locomotion_state.travel("RifleJumpUp")
		else:
			player.locomotion_state.travel("JumpingUp")
	# Flag the player as having a "jump queued"
	player.is_jump_queued = true


## Stop "jumping".
func stop() -> void:
	# Disable _this_ state node
	process_mode = Node.PROCESS_MODE_DISABLED
	# Clear the player's state (if it is currently set to _this_ state)
	if player.current_state == NodeStateMachine.States.JUMPING:
		player.current_state = -1
	# Flag the player as not "falling"
	player.is_jumping = false
	# Flag the player as not having a "jump queued"
	player.is_jump_queued = false
