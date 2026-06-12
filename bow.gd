class_name Bow
extends Equipment


func _physics_process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Proceed once the player has been initialized
	if player:
		# Get the animation currently playing in the locomotion state machine
		var locomotion_state_currently_playing_animation = player.locomotion_state.get_current_node()

		# Track was drawing_arrow using the state BEFORE updating input
		var was_drawing_arrow := player.is_drawing_arrow

		# Track was_firing_arrow using the state BEFORE updating input
		var was_firing_arrow := player.is_firing_arrow

		# Update archery flags on the player based on the currently playing animation in the locomotion state machine
		player.is_aiming_bow = player.equipped_bow and locomotion_state_currently_playing_animation == "ArcheryLocomotion"
		player.is_drawing_arrow = player.equipped_bow and locomotion_state_currently_playing_animation == "BowDrawArrow"
		player.is_firing_arrow = player.equipped_bow and locomotion_state_currently_playing_animation == "BowFireArrow"

		# Check if the player has a bow equipped
		if player.equipped_bow:
			# Get the bow instance from the player's equipment
			var bow: Node3D = null
			for item in player.equipment:
				if "equipment_type" in item and item.equipment_type == item.EquipmentType.BOW:
					bow = item
					break
			if bow:
				# Get the arrow instance from the player's equipped bow
				var arrow_node = bow.get_node_or_null("Arrow")
				if arrow_node:
					# Show the arrow when "aiming" but not drawing or firing
					if player.is_shooting \
					and not player.is_drawing_arrow \
					and not player.is_firing_arrow:
						arrow_node.show()
					else:
						arrow_node.hide()

		# Have the player look at the crosshair when aiming
		if player.is_aiming_bow:
			player.look_at_modifier.target_node = player.look_at_target.get_path()
			player.look_at_modifier.active = true
		# Reset the look at modifier when not aiming
		else:
			player.look_at_modifier.target_node = NodePath("")
			player.look_at_modifier.active = false

		## Fire arrow
		if player.equipped_bow \
		and player.is_firing_arrow \
		and not was_firing_arrow:
			var bow: Node3D = null
			for item in player.equipment:
				if "equipment_type" in item and item.equipment_type == item.EquipmentType.BOW:
					bow = item
					break
			if bow:
				# Duplicate the bow's $Arrow node
				var arrow_node = bow.get_node("Arrow")
				var arrow_instance = arrow_node.duplicate()
				set_collision_shapes_disabled(arrow_instance, false)
				get_tree().current_scene.add_child(arrow_instance)
				arrow_instance.global_transform = arrow_node.global_transform
				arrow_instance.visible = true
				# Tween the arrow's position from the bow to a point in front of the player
				player.projectile_raycast.force_raycast_update()
				var target_position: Vector3
				if player.projectile_raycast.is_colliding():
					target_position = player.projectile_raycast.get_collision_point()
				else:
					target_position = player.projectile_raycast.global_transform.origin + -player.projectile_raycast.global_transform.basis.z * 40.0
				if arrow_instance.global_transform.origin.distance_to(target_position) > 0.1:
					arrow_instance.look_at(target_position, Vector3.UP)
					arrow_instance.rotate_object_local(Vector3.RIGHT, -PI / 2.0)
				var distance: float = arrow_instance.global_transform.origin.distance_to(target_position)
				var projectile_speed: float = bow.projectile_speed if "projectile_speed" in bow else 45.0
				var duration: float = distance / projectile_speed
				var tween: Tween = create_tween()
				tween.tween_property(arrow_instance, "global_transform:origin", target_position, duration)
				tween.tween_interval(0.1)
				tween.tween_callback(Callable(arrow_instance, "queue_free"))

		## Play Bow sound(s) once when entering draw/fire arrow animations.
		if player.equipped_bow:
			var bow: Node3D = null
			for item in player.equipment:
				if "equipment_type" in item and item.equipment_type == item.EquipmentType.BOW:
					bow = item
					break
			if bow:
				if player.is_drawing_arrow and not was_drawing_arrow and bow.has_node("BowDrawArrow"):
					bow.get_node("BowDrawArrow").play()
				if player.is_firing_arrow and not was_firing_arrow and bow.has_node("BowFireArrow"):
					bow.get_node("BowFireArrow").play()
					if not player.projectile_raycast.is_colliding():
						bow.get_node("Arrow/Swish").play()
					else:
						var hit_object := player.projectile_raycast.get_collider()
						if hit_object and hit_object is RigidBody3D:
							var collision_point := player.projectile_raycast.get_collision_point()
							var collision_normal := player.projectile_raycast.get_collision_normal()
							var force_direction := player.projectile_raycast.global_transform.basis.z
							var force_magnitude := 10.0
							(hit_object as RigidBody3D).apply_impulse(collision_point - hit_object.global_transform.origin, force_direction * force_magnitude)
						#bow.get_node("Arrow/Twang").play()


## Sets the collision shape to disabled or enabled for the given node and all of its children recursively.
func set_collision_shapes_disabled(node: Node, disabled: bool) -> void:
	if node is CollisionShape3D:
		node.disabled = disabled
	for child in node.get_children():
		set_collision_shapes_disabled(child, disabled)
