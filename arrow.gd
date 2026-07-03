class_name Arrow
extends RigidBody3D

@export var is_template := true ## If true, this is the main template arrow on the Bow model that shouldn't move
@export var lifetime := 10.0 ## How long in seconds before the arrow is freed from the scene

var shooter: Node3D = null ## Reference to the CharacterBody3D that fired the arrow


func _ready() -> void:
	# If this is the main template arrow, keep it frozen and do not process physics
	if is_template:
		freeze = true
		set_physics_process(false)
		return

	# Enable contacts reporting to detect collisions on body entered
	contact_monitor = true
	max_contacts_reported = 4
	
	body_entered.connect(_on_body_entered)
	
	# Prevent the arrow from colliding with the shooter immediately upon firing.
	# Remove the exception after a short delay so the shooter can dodge returning arrows.
	if shooter:
		add_collision_exception_with(shooter)
		get_tree().create_timer(0.15).timeout.connect(func():
			if is_instance_valid(self) and is_instance_valid(shooter):
				remove_collision_exception_with(shooter)
		)
		
	# Delete the arrow after its lifetime expires
	get_tree().create_timer(lifetime).timeout.connect(queue_free)


func _physics_process(_delta: float) -> void:
	# Point the arrow toward its movement trajectory while in flight
	if not freeze and linear_velocity.length() > 0.1:
		var dir := linear_velocity.normalized()
		var up := global_basis.y.normalized()
		if abs(dir.dot(up)) > 0.99:
			up = global_basis.z.normalized()
		look_at(global_position + dir, up)
		rotate_object_local(Vector3.RIGHT, -PI / 2.0)


## Stop the arrow's movement and freeze it upon hitting an object.
func _on_body_entered(body: Node) -> void:
	if body == shooter:
		return
	freeze = true
