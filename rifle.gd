class_name Rifle
extends Equipment


var was_shooting: bool = false


## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Proceed once the player has been initialized
	if player:
		# Check if the player has a rifle equipped
		var has_rifle := player.has_equipment(Equipment.EquipmentType.RIFLE)
		# Return early if the player does not have a rifle equipped
		if not has_rifle:
			return

		# Have the player look at the crosshair when aiming
		#if player.is_shooting:
		#	player.look_at_modifier.target_node = player.look_at_target.get_path()
		#	player.look_at_modifier.active = true
		# Reset the look at modifier when not aiming
		#else:
		#	player.look_at_modifier.target_node = NodePath("")
		#	player.look_at_modifier.active = false

		var emote_state = player.animation_tree.get(player.EMOTE_STATE_PLAYBACK_PATH)

		# Play the "RifleFiringStanding" animation using Emote Blend
		if has_rifle and player.is_shooting:
			player.animation_tree.set("parameters/EmoteSpineBlend2/blend_amount", 1.0)
			if not was_shooting or emote_state.get_current_node() != "RifleFiringStanding":
				emote_state.start("RifleFiringStanding")

		# Stop playing the "RifleFiringStanding" animation when no longer shooting
		if not player.is_shooting and was_shooting:
			player.animation_tree.set("parameters/EmoteSpineBlend2/blend_amount", 0.0)
			emote_state.start("Idle")

		was_shooting = player.is_shooting
