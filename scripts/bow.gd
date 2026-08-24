class_name Bow
extends Equipment


const DRAW_ARROW_RUMBLE_DELAY_SECONDS: float = 1.0

var _draw_arrow_rumble_request_id: int = 0
var _was_drawing_arrow: bool = false
var _was_firing_arrow: bool = false


## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	# Proceed once the player has been initialized
	if player:
		# Track prior frame archery states for edge-triggered effects.
		var was_drawing_arrow: bool = _was_drawing_arrow
		var was_firing_arrow: bool = _was_firing_arrow

		var has_bow: bool = player.inventory.has_equipment(Equipment.EquipmentType.BOW)
		var is_holding_throwable: bool = player.is_throwing or (player.held_object and player.held_object.is_holding_object())
		var is_drawing_arrow_now: bool = player.is_drawing_arrow and not is_holding_throwable
		var is_firing_arrow_now: bool = player.is_firing_arrow and not is_holding_throwable
		if not player.is_aiming_bow and not player.is_drawing_arrow:
			_draw_arrow_rumble_request_id += 1
		var bow: Node3D = player.inventory.get_equipment_by_type(Equipment.EquipmentType.BOW)

		# Check if the player has a bow equipped
		if has_bow and bow:
			# Get the arrow instance from the player's equipped bow
			var arrow_node = bow.get_node_or_null("Arrow")
			if arrow_node:
				arrow_node.freeze = true
				set_collision_shapes_disabled(arrow_node, true)
				# Show the arrow when "aiming" but not drawing or firing
				if player.is_shooting \
				and not is_holding_throwable \
				and not player.is_drawing_arrow \
				and not player.is_firing_arrow:
					arrow_node.show()
				else:
					arrow_node.hide()

		# Have the player look at the crosshair when aiming
		if player.is_aiming_bow and not is_holding_throwable:
			player.look_at_modifier.target_node = player.look_at_target.get_path()
			player.look_at_modifier.active = true
		# Reset the look at modifier when not aiming
		else:
			player.look_at_modifier.target_node = NodePath("")
			player.look_at_modifier.active = false

		## Fire arrow
		if has_bow \
		and is_firing_arrow_now \
		and not was_firing_arrow \
		and bow:
				# Duplicate the bow's $Arrow node
				var arrow_node = bow.get_node("Arrow")
				var arrow_instance = arrow_node.duplicate()
				arrow_instance.is_template = false
				arrow_instance.shooter = player
				set_collision_shapes_disabled(arrow_instance, false)
				
				var tree := get_tree()
				if tree and tree.current_scene:
					tree.current_scene.add_child(arrow_instance)
				arrow_instance.global_transform = arrow_node.global_transform
				arrow_instance.freeze = false
				arrow_instance.visible = true
				
				player.projectile_raycast.force_raycast_update()
				var target_position: Vector3
				if player.projectile_raycast.is_colliding():
					target_position = player.projectile_raycast.get_collision_point()
				else:
					target_position = player.projectile_raycast.global_transform.origin + -player.projectile_raycast.global_transform.basis.z * 40.0
				
				var launch_direction = (target_position - arrow_instance.global_transform.origin).normalized()
				var projectile_speed: float = bow.projectile_speed if "projectile_speed" in bow else 45.0
				
				if arrow_instance.global_transform.origin.distance_to(target_position) > 0.1:
					arrow_instance.look_at(target_position, player.up_direction)
					arrow_instance.rotate_object_local(Vector3.RIGHT, -PI / 2.0)
				
				arrow_instance.linear_velocity = launch_direction * projectile_speed

		## Play Bow sound(s) once when entering draw/fire arrow animations.
		if has_bow and bow:
			if is_drawing_arrow_now and not was_drawing_arrow and bow.has_node("BowDrawArrow"):
				bow.get_node("BowDrawArrow").play()
				# Rumble when arrow is knocked
				if player.controls.current_input_type not in [player.controls.InputType.KEYBOARD_MOUSE, player.controls.InputType.TOUCH]:
					Input.start_joy_vibration(0, 0.0, 0.2, 0.5)
			if is_firing_arrow_now and not was_firing_arrow and bow.has_node("BowFireArrow"):
				bow.get_node("BowFireArrow").play()
				# Rumble when arrow is fired
				if player.controls.current_input_type not in [player.controls.InputType.KEYBOARD_MOUSE, player.controls.InputType.TOUCH]:
					Input.start_joy_vibration(0, 0.4, 0.0, 0.5)
				if not player.projectile_raycast.is_colliding():
					bow.get_node("Arrow/Swish").play()
				else:
					var hit_object := player.projectile_raycast.get_collider()
					if hit_object and hit_object is RigidBody3D:
						var collision_point := player.projectile_raycast.get_collision_point()
						var force_direction := player.projectile_raycast.global_transform.basis.z
						var force_magnitude := 10.0
						(hit_object as RigidBody3D).apply_impulse(collision_point - hit_object.global_transform.origin, force_direction * force_magnitude)
					#bow.get_node("Arrow/Twang").play()

		_was_drawing_arrow = is_drawing_arrow_now
		_was_firing_arrow = is_firing_arrow_now


## Sets the collision shape to disabled or enabled for the given node and all of its children recursively.
func set_collision_shapes_disabled(node: Node, disabled: bool) -> void:
	if node is CollisionShape3D:
		node.disabled = disabled
	for child in node.get_children():
		set_collision_shapes_disabled(child, disabled)
