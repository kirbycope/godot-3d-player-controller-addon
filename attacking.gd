class_name Attacking
extends NodeStateMachine

var _this_state := NodeStateMachine.States.ATTACKING


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

	# Determine which attack is currently in progress.
	var current_node: String = String(player.locomotion_state.get_current_node())

	# Attack { Microsoft: Ⓧ, Nintendo: Ⓨ, Sony: 🟗, Keyboard: [Alt] }
	if Input.is_action_just_pressed("attack") and player.inventory.can_player_attack:
		# Start the attack sequence timer
		player.attack_sequence_timer.start()

		# Attack Sequence: 1-Handed Weapon and Shield
		if player.inventory.has_one_handed_or_shield_equipped():
			# Queue the next attack in the sequence (changing the variable causes the AnimationTree to travel)
			if current_node == "ShieldDownwardSlash": ## Sword and Shield, Attack 1 of 3
				player.attack_sequence = 1
			elif current_node == "ShieldCrossSlash": ## Sword and Shield, Attack 2 of 3
				player.attack_sequence = 2
			elif current_node == "ShieldPowerSlash": ## Sword and Shield, Attack 3 of 3
				player.attack_sequence = 3

		# Attack Sequence: 2-Handed Weapon
		elif player.inventory.has_heavy_weapon_equipped():
			if current_node == "GreatSwordDownwardSlash": ## 2-Handed Weapon, Attack 1 of 3
				player.attack_sequence = 1
			elif current_node == "GreatSwordLowSlash": ## 2-Handed Weapon, Attack 2 of 3
				player.attack_sequence = 2
			elif current_node == "GreatSwordPowerSlash": ## 2-Handed Weapon, Attack 3 of 3
				player.attack_sequence = 3

		# Attack Sequence: Unarmed / Boxing
		elif player.inventory.is_unarmed():
			if current_node == "ShortHeadJab": ## Unarmed / Boxing, Attack 1 of 2
				player.attack_sequence = 1
			elif current_node == "BackHandCross": ## Unarmed / Boxing, Attack 2 of 2
				player.attack_sequence = 2

	# Check if the player is no longer attacking
	if player.locomotion_state.get_current_node() not in [
		"GreatSwordDownwardSlash", ## 2-Handed Weapon, Attack 1 of 3
		"GreatSwordLowSlash", ## 2-Handed Weapon, Attack 2 of 3
		"GreatSwordPowerSlash", ## 2-Handed Weapon, Attack 3 of 3
		"ShieldDownwardSlash", ## Sword and Shield, Attack 1 of 3
		"ShieldCrossSlash", ## Sword and Shield, Attack 2 of 3
		"ShieldPowerSlash", ## Sword and Shield, Attack 3 of 3
		"ShortHeadJab", ## Unarmed / Boxing, Attack 1 of 2
		"BackHandCross", ## Unarmed / Boxing, Attack 2 of 2
	]:
		# Stop "attacking"
		stop()


## Start "attacking".
func start() -> void:
	# Enable _this_ state node
	process_mode = Node.PROCESS_MODE_INHERIT
	# Set the player's new state
	player.current_state = _this_state
	# Flag the player as "attacking"
	player.is_attacking = true
	# Flag as boxing if unarmed
	if player.inventory and player.inventory.is_unarmed():
		player.is_boxing = true
	# Start the attack sequence timer
	player.attack_sequence_timer.start()
	# Reset the attack state variables
	player.attack_sequence = 0


## Stop "attacking".
func stop() -> void:
	# Disable _this_ state node
	process_mode = Node.PROCESS_MODE_DISABLED
	# Clear the player's state (if it is currently set to _this_ state)
	if player.current_state == _this_state:
		player.current_state = -1
	# Flag the player as not "attacking"
	player.is_attacking = false
	# Stop the attack sequence timer
	player.attack_sequence_timer.stop()
	# Reset the state variables
	player.attack_sequence = 0
