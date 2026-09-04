class_name Firearm
extends Equipment
## A gun: while shoot is held it launches [member projectile_scene] along the Player's projectile ray,
## level with [member muzzle], so every round flies exactly through the crosshair; aiming or shooting
## turns the Player's spine toward the crosshair and shows [member laser_sight] from the muzzle to it.
## It carries [member magazine_size] rounds plus [member reserve_rounds]; the "reload" action or an
## empty trigger pull refills the magazine from the reserve after [member reload_time]. Every shot
## kicks the pad and a reload pulses it, through [method Controls.rumble].
##
## Shoot and focus are held inputs with no signal, so the equipped copy polls them each physics frame.

signal fired(projectile: Projectile) ## Emitted for every round that leaves the muzzle (null on clients, whose copy arrives through the spawner).
signal ammo_changed(rounds: int, reserve_rounds: int) ## Emitted when a round leaves or a reload lands.

const RAY_MISS_DISTANCE: float = 100.0 ## Aim point distance when the projectile ray hits nothing.

@export var projectile_scene: PackedScene ## The [Projectile] scene to spawn per shot.
@export var automatic: bool = true ## Keep firing every [member fire_interval] while shoot is held.
@export var fire_interval: float = 0.12 ## Seconds between rounds.
@export var magazine_size: int = 12 ## Rounds per magazine.
@export var reserve_rounds: int = 48 ## Rounds carried outside the magazine; reloads draw from here.
@export var reload_time: float = 1.5 ## Seconds a reload blocks the trigger.
@export var muzzle: Marker3D ## Where rounds spawn; its -Z is the barrel direction.
@export var fire_timer: Timer ## One-shot timer that spaces rounds and times reloads (child of the weapon).
@export var laser_sight: LaserSight ## Optional pointer shown while aiming.
@export var fire_sfx: AudioStreamPlayer3D ## Optional shot sound.
@export var reload_sfx: AudioStreamPlayer3D ## Optional reload sound.

var rounds: int = 0: ## Rounds left in the magazine.
	set(value):
		rounds = value
		ammo_changed.emit(rounds, reserve_rounds)
var is_reloading: bool = false
var _trigger_was_held: bool = false
var _aiming: bool = false


func _ready() -> void:
	set_physics_process(false)
	set_process_unhandled_input(false)
	rounds = magazine_size
	if laser_sight:
		laser_sight.hide()
	if player and player.is_multiplayer_authority():
		player.inventory.equipment_changed.connect(_on_equipment_changed)
		ammo_changed.connect(player.controls.set_ammo)


## Only the equipped copy aims, fires, reloads and owns the HUD's ammo counter.
func _on_equipment_changed() -> void:
	var equipped: bool = player.inventory.equipment.has(self)
	set_physics_process(equipped)
	set_process_unhandled_input(equipped)
	if equipped:
		player.controls.set_ammo(rounds, reserve_rounds)
	elif not player.has_firearm_equipped:
		player.controls.hide_ammo()
	if not equipped:
		_set_aiming(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reload"):
		reload()


func _physics_process(_delta: float) -> void:
	var shooting: bool = player.is_shooting
	_set_aiming(shooting or player.is_focusing)
	if laser_sight and _aiming:
		laser_sight.aim(muzzle.global_position, get_aim_point())
	if shooting and fire_timer.is_stopped() and (automatic or not _trigger_was_held):
		fire()
		fire_timer.start(fire_interval)
	_trigger_was_held = shooting


## Turns the spine (as the bow does) and then the gun hand toward the crosshair through the Player's two
## LookAtModifier3D nodes, and shows the laser.
func _set_aiming(aiming: bool) -> void:
	if aiming == _aiming:
		return
	_aiming = aiming
	player.set_look_at_target(player.look_at_target if aiming else null)
	player.weapon_look_at_modifier.active = aiming
	if laser_sight:
		laser_sight.visible = aiming


## Where the Player's camera-aligned projectile ray lands, or a point far along it.
func get_aim_point() -> Vector3:
	var ray: RayCast3D = player.projectile_raycast
	ray.force_raycast_update()
	if ray.is_colliding():
		return ray.get_collision_point()
	return ray.global_position - ray.global_basis.z * RAY_MISS_DISTANCE


## Launches one projectile on the projectile ray, level with the muzzle, toward the aim point; an empty
## magazine reloads instead. The round rides the crosshair line, so it lands where the crosshair is.
func fire() -> Projectile:
	if projectile_scene == null or muzzle == null:
		return null
	if rounds <= 0:
		reload()
		return null
	rounds -= 1
	var ray: RayCast3D = player.projectile_raycast
	var aim: Vector3 = get_aim_point()
	var along: Vector3 = -ray.global_basis.z
	var origin: Transform3D = muzzle.global_transform
	origin.origin = ray.global_position + along * maxf((muzzle.global_position - ray.global_position).dot(along), 0.0)
	var direction: Vector3 = (aim - origin.origin).normalized()
	var projectile: Projectile
	var spawner: ProjectileSpawner = get_tree().get_first_node_in_group(&"ProjectileSpawner") as ProjectileSpawner
	if spawner:
		projectile = spawner.fire(projectile_scene, origin, direction, projectile_speed, player, self)
	else:
		projectile = projectile_scene.instantiate() as Projectile
		var world: Node = get_tree().current_scene if get_tree().current_scene else player.get_parent()
		world.add_child(projectile)
		projectile.launch(origin, direction, projectile_speed, player, self)
	if fire_sfx:
		fire_sfx.play()
	player.controls.rumble(0.0, 0.8, 0.1)
	fired.emit(projectile)
	return projectile


## Refills the magazine from the reserve once [member reload_time] has passed; nothing happens while
## already reloading, full, or out of reserve rounds. The fire timer doubles as the reload timer.
func reload() -> void:
	if is_reloading or rounds == magazine_size or reserve_rounds <= 0:
		return
	is_reloading = true
	if reload_sfx:
		reload_sfx.play()
	player.controls.rumble(0.3, 0.0, 0.2)
	fire_timer.start(reload_time)
	await fire_timer.timeout
	var moved: int = mini(magazine_size - rounds, reserve_rounds)
	reserve_rounds -= moved
	rounds += moved
	is_reloading = false
