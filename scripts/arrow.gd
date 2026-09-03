class_name Arrow
extends RigidBody3D
## A bow projectile: flies nose-first, sticks on impact and frees itself after [member lifetime].

const SHOOTER_EXCEPTION_SECONDS: float = 0.15 ## How long the arrow ignores the shooter's body after firing.

@export var is_template: bool = true ## If true, this is the frozen template arrow on the Bow model.
@export var lifetime: float = 10.0 ## Seconds before a fired arrow is freed from the scene.

var shooter: Node3D = null ## The body that fired the arrow.


func _ready() -> void:
	if is_template or not is_multiplayer_authority():
		freeze = true
		set_physics_process(false)
		return

	freeze = false
	for shape: Node in find_children("*", "CollisionShape3D", true, false):
		(shape as CollisionShape3D).disabled = false
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

	# Ignore the shooter briefly so the arrow can leave the body it was fired from.
	if shooter:
		add_collision_exception_with(shooter)
		get_tree().create_timer(SHOOTER_EXCEPTION_SECONDS).timeout.connect(_on_shooter_exception_timeout)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)


func _physics_process(_delta: float) -> void:
	# Point the arrow along its trajectory while in flight
	if not freeze and linear_velocity.length() > 0.1:
		var dir: Vector3 = linear_velocity.normalized()
		var up: Vector3 = global_basis.y.normalized()
		if absf(dir.dot(up)) > 0.99:
			up = global_basis.z.normalized()
		look_at(global_position + dir, up)
		rotate_object_local(Vector3.RIGHT, -PI / 2.0)


func _on_shooter_exception_timeout() -> void:
	if is_instance_valid(shooter):
		remove_collision_exception_with(shooter)


## Stick into whatever the arrow hits.
func _on_body_entered(body: Node) -> void:
	if body != shooter:
		freeze = true
