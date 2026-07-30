class_name Attacking
extends NodeStateMachine

@export var boxing_inactivity_delay: float = 2.0

var _this_state := NodeStateMachine.States.ATTACKING
var _has_entered_attack: bool = false
var boxing_inactivity_delay_remaining: float = 0.0


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

	# Handle boxing inactivity timer to auto-exit boxing stance
	if player.is_boxing:
		if boxing_inactivity_delay_remaining > 0.0:
			boxing_inactivity_delay_remaining = max(boxing_inactivity_delay_remaining - delta, 0.0)
		if boxing_inactivity_delay_remaining <= 0.0:
			stop()
			return

	# Determine which attack is currently in progress.
	var current_node: String = String(player.locomotion_state.get_current_node())

	# Track if we have entered an active attack animation node
	if current_node in [
		"GreatSwordDownwardSlash",
		"GreatSwordLowSlash",
		"GreatSwordPowerSlash",
		"ShieldDownwardSlash",
		"ShieldCrossSlash",
		"ShieldPowerSlash",
		"ShortHeadJab",
		"BackHandCross",
	]:
		_has_entered_attack = true

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
			player.is_boxing = true
			player.is_attacking = true
			boxing_inactivity_delay_remaining = boxing_inactivity_delay
			if current_node == "ShortHeadJab": ## Unarmed / Boxing, Attack 1 of 2
				player.attack_sequence = 1
			elif current_node == "BackHandCross": ## Unarmed / Boxing, Attack 2 of 2
				player.attack_sequence = 2

	# Check if the player is no longer attacking (only after having entered an attack animation)
	if _has_entered_attack and player.locomotion_state.get_current_node() not in [
		"GreatSwordDownwardSlash", ## 2-Handed Weapon, Attack 1 of 3
		"GreatSwordLowSlash", ## 2-Handed Weapon, Attack 2 of 3
		"GreatSwordPowerSlash", ## 2-Handed Weapon, Attack 3 of 3
		"ShieldDownwardSlash", ## Sword and Shield, Attack 1 of 3
		"ShieldCrossSlash", ## Sword and Shield, Attack 2 of 3
		"ShieldPowerSlash", ## Sword and Shield, Attack 3 of 3
		"ShortHeadJab", ## Unarmed / Boxing, Attack 1 of 2
		"BackHandCross", ## Unarmed / Boxing, Attack 2 of 2
	]:
		if player.inventory and player.inventory.is_unarmed() and player.is_boxing:
			# Finished attack animation while boxing: turn off active attack flag, but stay in Attacking node to count down boxing_inactivity_delay_remaining
			player.is_attacking = false
			_has_entered_attack = false
			player.attack_sequence = 0
		else:
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
	_has_entered_attack = false
	# Flag as boxing if unarmed and set inactivity delay
	if player.inventory and player.inventory.is_unarmed():
		player.is_boxing = true
		boxing_inactivity_delay_remaining = boxing_inactivity_delay
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
	player.is_boxing = false
	_has_entered_attack = false
	boxing_inactivity_delay_remaining = 0.0
	# Stop the attack sequence timer
	player.attack_sequence_timer.stop()
	# Reset the state variables
	player.attack_sequence = 0
