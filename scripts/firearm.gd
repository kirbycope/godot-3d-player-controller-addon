class_name Firearm
extends Equipment
## A gun: fires [member projectile_scene] from [member muzzle] toward the Player's projectile ray
## while shoot is held, and shows [member laser_sight] along that ray while aiming or shooting.
##
## Shoot and focus are held inputs with no signal, so the equipped copy polls them each physics frame.

signal fired(projectile: Projectile) ## Emitted for every round that leaves the muzzle (null on clients, whose copy arrives through the spawner).

const RAY_MISS_DISTANCE: float = 100.0 ## Aim point distance when the projectile ray hits nothing.

@export var projectile_scene: PackedScene ## The [Projectile] scene to spawn per shot.
@export var automatic: bool = true ## Keep firing every [member fire_interval] while shoot is held.
@export var fire_interval: float = 0.12 ## Seconds between rounds.
@export var muzzle: Marker3D ## Where rounds spawn; its -Z is the barrel direction.
@export var fire_timer: Timer ## One-shot timer that spaces rounds (child of the weapon).
@export var laser_sight: LaserSight ## Optional pointer shown while aiming.
@export var fire_sfx: AudioStreamPlayer3D ## Optional shot sound.

var _trigger_was_held: bool = false


func _ready() -> void:
	set_physics_process(false)
	if laser_sight:
		laser_sight.hide()
	if player and player.is_multiplayer_authority():
		player.inventory.equipment_changed.connect(_on_equipment_changed)


## Only the equipped copy aims and fires.
func _on_equipment_changed() -> void:
	var equipped: bool = player.inventory.equipment.has(self)
	set_physics_process(equipped)
	if not equipped and laser_sight:
		laser_sight.hide()


func _physics_process(_delta: float) -> void:
	var shooting: bool = player.is_shooting
	if laser_sight:
		laser_sight.visible = shooting or player.is_focusing
		if laser_sight.visible:
			laser_sight.aim(muzzle.global_position, get_aim_point())
	if shooting and fire_timer.is_stopped() and (automatic or not _trigger_was_held):
		fire()
		fire_timer.start(fire_interval)
	_trigger_was_held = shooting


## Where the Player's camera-aligned projectile ray lands, or a point far along it.
func get_aim_point() -> Vector3:
	var ray: RayCast3D = player.projectile_raycast
	ray.force_raycast_update()
	if ray.is_colliding():
		return ray.get_collision_point()
	return ray.global_position - ray.global_basis.z * RAY_MISS_DISTANCE


## Spawns one projectile at the muzzle and launches it at the aim point.
func fire() -> Projectile:
	if projectile_scene == null or muzzle == null:
		return null
	var direction: Vector3 = (get_aim_point() - muzzle.global_position).normalized()
	var projectile: Projectile
	var spawner: ProjectileSpawner = get_tree().get_first_node_in_group(&"ProjectileSpawner") as ProjectileSpawner
	if spawner:
		projectile = spawner.fire(projectile_scene, muzzle.global_transform, direction, projectile_speed, player, self)
	else:
		projectile = projectile_scene.instantiate() as Projectile
		var world: Node = get_tree().current_scene if get_tree().current_scene else player.get_parent()
		world.add_child(projectile)
		projectile.launch(muzzle.global_transform, direction, projectile_speed, player, self)
	if fire_sfx:
		fire_sfx.play()
	fired.emit(projectile)
	return projectile
