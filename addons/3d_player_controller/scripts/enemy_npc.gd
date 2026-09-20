class_name EnemyNpc
extends FollowerNpc
## A hostile NPC: idles until the Player attacks it or steps within its aggro area, then chases over the
## navigation mesh and attacks in reach with a melee swing whose weapon hitbox must touch you, a projectile
## weapon, or abilities cast in range with line of sight. When the hunted Player dies, or strays further than
## [member leash_distance] from the post (a respawn far away counts), it turns on any other living Player still
## inside its aggro area or walks back to where it started, stands as it stood and heals to full. A Player in a
## vehicle is never chased: it is attacked while inside attack range and given up on once it drives out of it.
## Fire sets it ablaze ([method burn], through [method Ability.burn_around] from a fire arrow, an incendiary round, a
## fire spell or the torch): the flame shows on every peer while the server ticks the damage, and water puts it out.
## Locomotion is a blend space (Idle, Walk, Run) fed by a smoothed [member locomotion_blend], as LittleBuddy's is,
## and root motion as for the Player: the navigation decides where to face and how fast it wants to go, and the
## animation's Root bone carries the body. Health, death and the animation state replicate from
## the server; hits from clients relay.

signal aggroed(target: Node3D)
signal attacked(target: Node3D) ## A melee swing or a shot was started.
signal struck(body: Node3D) ## The weapon hitbox connected.
signal headshot(projectile: Projectile) ## A round landed on the head: an outright kill.
signal fired(projectile: Projectile) ## A round left the muzzle; on every peer, so the muzzle flash plays for all. Null except on the server, whose spawner hands the round back.
signal died
signal returned_home ## Back at the spawn point after the hunted Player died.

const LOCOMOTION_STATE: String = "Locomotion" ## The blend space state; attacks and hit reactions return to it.
const LOCOMOTION_BLEND_PATH: String = "parameters/Locomotion/blend_position"

@export var is_boss: bool = false ## Puts the name and health on the hunted player's HUD boss bar.
@export var attack_range: float = 1.6 ## Distance the attack lands from: melee reach, or firing range for projectiles.
@export var attack_damage: float = 15.0 ## Melee damage dealt by the weapon hitbox; projectiles carry their own.
@export var attack_interval: float = 1.5 ## Seconds between attacks or ability casts.
@export var attack_animation: String = "SwordAttack" ## AnimationTree state played for each attack.
@export var strike_delay: float = 0.45 ## Seconds into the attack animation when the hit or shot happens.
@export var projectile_scene: PackedScene ## Archers and riflemen fire this; empty means melee.
@export var projectile_speed: float = 30.0
@export var accuracy: Accuracy ## Spread cone of the weapon it shoots, the same resource the Player's copy uses; empty fires dead straight.
@export var skill_level: int = 0 ## Marksmanship: shrinks [member accuracy]'s spread (0 novice, expert at the resource's expert_level).
@export var melee_hit_damage: float = 25.0 ## Damage taken from one of the Player's melee swings.
@export var leash_distance: float = 30.0 ## A target further than this from the post is given up on; the enemy resets.
@export var patrol_points: Node3D ## With nobody to hunt, walks its [Node3D] children in a loop; empty stands at the post.
@export var patrol_wait: float = 1.5 ## Seconds paused at each patrol point.
@export var patrol_speed: float = 1.4 ## Walking pace on patrol.
@export var sneak_attack_multiplier: float = 1.0 ## A melee hit from a Player this enemy is not hunting lands this many times harder: a takedown from behind.
@export var footstep_sfx: AudioStream ## Played by the walk and run animations' method tracks.

var target: Node3D ## The Player being hunted; abilities read it through [method Ability.get_target].
var is_returning_home: bool = false ## Walking back to the spawn point with nobody to hunt.
var patrol_index: int = 0 ## The patrol point walked to next.
var _patrol_pause: float = 0.0
var _control_speed: float = 0.0 ## How fast the navigation wants to go this frame; picks Idle, Walking or Running.
var _spawn_transform: Transform3D
var is_dead: bool = false: ## Replicated; the setter drops the body into the ragdoll on every peer.
	set(value):
		if value == is_dead:
			return
		is_dead = value
		if value and is_node_ready():
			_apply_death()
var anim_state: String = LOCOMOTION_STATE: ## Replicated AnimationTree state.
	set(value):
		anim_state = value
		if playback and String(playback.get_current_node()) != value:
			playback.start(value)
var locomotion_blend: float = 0.0: ## Replicated: 0 idle, 0.5 walk, 1 run, eased toward what the navigation asks for.
	set(value):
		locomotion_blend = value
		if animation_tree:
			animation_tree.set(LOCOMOTION_BLEND_PATH, value)
var is_burning: bool = false: ## Replicated: ablaze, the flame showing on every peer while the server ticks the damage.
	set(value):
		is_burning = value
		if is_node_ready():
			_update_burn_vfx()
var _burn_ticks_left: int = 0
var _burn_tick_damage: float = 0.0

@onready var mannequin: Node3D = $Mannequin_M ## The animated model; root motion is in its space.
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
@onready var attack_timer: Timer = $AttackTimer ## Cooldown between attacks.
@onready var strike_timer: Timer = $StrikeTimer ## Delay from the swing's start to its hit or shot.
@onready var muzzle: Marker3D = $Muzzle ## Where projectiles leave.
@onready var weapon_hitbox: MeleeHitbox = $Mannequin_M/Armature/GeneralSkeleton/WeaponAttachment/WeaponHitbox ## Live during the swing's strike frames.
@onready var caster: NpcCaster = $NpcCaster
@onready var health: Health = $Health
@onready var boss: Boss = $Boss
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var aggro_area: Area3D = $AggroArea
@onready var footstep_audio: AudioStreamPlayer3D = $FootstepAudio
@onready var physical_bone_simulator: PhysicalBoneSimulator3D = $Mannequin_M/Armature/GeneralSkeleton/PhysicalBoneSimulator3D
@onready var burn_vfx: Node3D = $BurnVFX ## The flame shown while [member is_burning].
@onready var burn_tick_timer: Timer = $BurnTickTimer ## Ticks the burn damage; its timeout is wired in the scene.


func _ready() -> void:
	super()
	_spawn_transform = global_transform
	animation_tree.active = true
	attack_timer.wait_time = attack_interval
	strike_timer.wait_time = strike_delay
	_update_burn_vfx()
	if is_dead:
		_apply_death()


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority() or is_dead or delta <= 0.0: # root motion is divided by delta
		return
	if caster.casting:
		# Stand and face the target through the cast
		if player:
			_face_player(delta)
		_stop_moving()
		return
	if is_returning_home:
		_return_home(delta)
		_update_locomotion()
		return
	if target == null and patrol_points and patrol_points.get_child_count() > 0:
		_patrol(delta)
		_update_locomotion()
		return
	var drove_off: bool = target != null and target.get("is_riding") and global_position.distance_to(target.global_position) > attack_range * 1.25
	if target and (drove_off or target.global_position.distance_to(_spawn_transform.origin) > leash_distance):
		# Off the leash (a respawn at the far spawn point, a chase that went too far) or driven out of reach: reset
		_drop_target()
		is_returning_home = true
		_return_home(delta)
		_update_locomotion()
		return
	super(delta)
	_update_locomotion()
	if target == null or target.get("is_stealthed") or not attack_timer.is_stopped():
		return
	if not caster.abilities.is_empty() and caster.try_cast(target):
		attack_timer.start()
		return
	if global_position.distance_to(target.global_position) <= attack_range and (projectile_scene == null or caster.has_line_of_sight(target)):
		_attack()


## Hunts [param who]; only living Players are worth chasing.
func aggro(who: Node) -> void:
	if is_dead or not who is Player or target == who or not (who as Player).health.is_alive():
		return
	if is_instance_valid(target):
		target.health.died.disconnect(_on_target_died)
		target.hunted_by(get_path(), false)
	target = who
	player = who
	is_returning_home = false
	target.health.died.connect(_on_target_died)
	target.hunted_by(get_path(), true)
	if is_boss:
		boss.engage(who.get_multiplayer_authority())
	aggroed.emit(target)


## Gives up the hunt on purpose (a [VisionCone] that lost sight of the Player) and heads back to the post.
func lose_target() -> void:
	if target == null:
		return
	_drop_target()
	is_returning_home = true


## Walks the patrol points in turn, pausing [member patrol_wait] at each, at [member patrol_speed].
func _patrol(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if _patrol_pause > 0.0:
		_patrol_pause -= delta
		_stop_moving()
		return
	var point: Node3D = patrol_points.get_child(patrol_index % patrol_points.get_child_count()) as Node3D
	if point == null:
		return
	if _walk_toward(point.global_position, delta, patrol_speed):
		patrol_index = (patrol_index + 1) % patrol_points.get_child_count()
		_patrol_pause = patrol_wait


## One step along the navigation mesh toward [param point] at [param speed]; true once within reach of it.
func _walk_toward(point: Vector3, delta: float, speed: float) -> bool:
	if (point - global_position).slide(up_direction).length() <= 0.5:
		_stop_moving()
		return true
	navigation_agent_3d.target_position = point
	var next: Vector3 = navigation_agent_3d.get_next_path_position() if navigation_agent_3d.is_target_reachable() else point
	var direction: Vector3 = global_position.direction_to(next).slide(up_direction)
	if direction.length_squared() < 0.0001:
		direction = global_position.direction_to(point).slide(up_direction)
	direction = direction.normalized()
	global_transform = global_transform.interpolate_with(global_transform.looking_at(global_position + direction, up_direction), turn_speed * delta)
	_move_with_control(direction * speed * movement_scale)
	return false


## Gives up the hunt: the target died or went past the leash.
func _drop_target() -> void:
	if is_instance_valid(target):
		target.health.died.disconnect(_on_target_died)
		target.hunted_by(get_path(), false)
	target = null
	player = null
	caster.interrupt()
	boss.disengage()


## The hunted Player died: turn on another living Player still inside the aggro area, or head home.
func _on_target_died() -> void:
	_drop_target()
	for body: Node3D in aggro_area.get_overlapping_bodies():
		if body is Player and (body as Player).health.is_alive() and not (body as Player).is_stealthed:
			aggro(body)
			return
	is_returning_home = true


## Walks the navigation mesh back to the spawn point, then turns to stand as it stood.
func _return_home(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	var home: Vector3 = _spawn_transform.origin
	if (home - global_position).slide(up_direction).length() > 0.5:
		navigation_agent_3d.target_position = home
		var next: Vector3 = navigation_agent_3d.get_next_path_position() if navigation_agent_3d.is_target_reachable() else home
		var direction: Vector3 = global_position.direction_to(next).slide(up_direction).normalized()
		global_transform = global_transform.interpolate_with(global_transform.looking_at(global_position + direction, up_direction), turn_speed * delta)
		_move_with_control(direction * move_speed * movement_scale)
		return
	_stop_moving()
	var facing: Transform3D = global_transform.looking_at(global_position - _spawn_transform.basis.z, up_direction)
	global_transform = global_transform.interpolate_with(facing, turn_speed * delta)
	if global_transform.basis.z.angle_to(_spawn_transform.basis.z) < 0.05:
		is_returning_home = false
		# Back at the post: a full reset, as a WoW mob heals up after a leash
		health.health = health.max_health
		health.energy = health.max_energy
		returned_home.emit()


## Wired to the AggroArea's body_entered: a Player on foot, or the driver of a vehicle passing through.
func _on_aggro_area_body_entered(body: Node3D) -> void:
	var who: Node = body if body is Player else body.get("player")
	if who is Player and not (who as Player).is_stealthed and (who == body or (who as Player).riding == body):
		aggro(who)


## Called by [HitDetection]; unarmed swings pass the Player itself as the equipment.
func register_weapon_hit(equipment: Node = null, _hit_node: Node = null) -> void:
	var attacker: Node = (equipment as Equipment).player if equipment is Equipment else equipment
	var from: Vector3 = (attacker as Node3D).global_position if attacker is Node3D else global_position
	# Caught unaware (not hunting the one who struck): the sneak attack lands harder
	var damage: float = melee_hit_damage * (sneak_attack_multiplier if target != attacker and sneak_attack_multiplier > 1.0 else 1.0)
	take_hit(damage, from)
	aggro(attacker)


## Called by a landing [Projectile]; one on the Head hurtbox kills outright.
func register_projectile_hit(projectile: Projectile, point: Vector3, _normal: Vector3) -> void:
	var damage: float = projectile.damage
	if projectile.hit_part and projectile.hit_part.name == "Head":
		damage = health.max_health
		headshot.emit(projectile)
	take_hit(damage, point)
	aggro(projectile.shooter)


## Damage counts on the server; clients relay theirs. The hit reaction faces where it came from.
func take_hit(damage: float, from: Vector3) -> void:
	if is_dead:
		return
	if not multiplayer.is_server():
		_request_hit.rpc_id(1, damage, from)
		return
	health.damage(damage, from)
	if not health.is_alive():
		return
	caster.interrupt()
	var side: float = global_transform.basis.x.dot(global_position.direction_to(from))
	anim_state = "ReactionHitOnRightSide" if side > 0.35 else ("ReactionHitOnLeftSide" if side < -0.35 else "GettingHit")


@rpc("any_peer", "call_remote", "reliable")
func _request_hit(damage: float, from: Vector3) -> void:
	if multiplayer.is_server():
		take_hit(damage, from)


## Sets the enemy ablaze for [param seconds], costing [param damage_per_second] in ticks of the BurnTickTimer; a
## new burn restarts the clock. Only the authority burns; the flame reaches the peers through [member is_burning].
func burn(seconds: float, damage_per_second: float) -> void:
	if is_dead or not is_multiplayer_authority() or seconds <= 0.0:
		return
	_burn_ticks_left = maxi(1, roundi(seconds / burn_tick_timer.wait_time))
	_burn_tick_damage = damage_per_second * burn_tick_timer.wait_time
	is_burning = true
	burn_tick_timer.start()


## Puts the fire out: water ([Buoyancy] and a Water spell call it on anything that has it), death, or the last tick.
func extinguish() -> void:
	burn_tick_timer.stop()
	_burn_ticks_left = 0
	if is_multiplayer_authority():
		is_burning = false


## Wired to BurnTickTimer.timeout: a tick of fire damage straight to the health, so the enemy fights on through it
## instead of flinching every half second; the last tick puts the fire out.
func _on_burn_tick_timer_timeout() -> void:
	if is_dead:
		extinguish()
		return
	health.damage(_burn_tick_damage, global_position)
	_burn_ticks_left -= 1
	if _burn_ticks_left <= 0:
		extinguish()


func _update_burn_vfx() -> void:
	burn_vfx.visible = is_burning
	for particles: Node in burn_vfx.find_children("*", "GPUParticles3D", true, false):
		(particles as GPUParticles3D).emitting = is_burning


func can_heal() -> bool:
	return health.can_heal()


## Restores health; false when already full, so a heal ability is not wasted.
func heal(amount: float) -> bool:
	return health.heal(amount)


## Wired to Health.died on every peer; only the authority flips the replicated flag.
func _on_health_died() -> void:
	if is_multiplayer_authority():
		is_dead = true


func _attack() -> void:
	attack_timer.start()
	anim_state = attack_animation
	strike_timer.start()
	attacked.emit(target)


## Wired to the NpcCaster: the casting pose plays for the cast.
func _on_cast_started(_ability: Ability) -> void:
	anim_state = attack_animation


## Wired to the StrikeTimer: the swing connects or the shot leaves.
func _on_strike_timer_timeout() -> void:
	if is_dead or not is_instance_valid(target):
		return
	if projectile_scene:
		_fire()
	else:
		# The blade decides: only a body it overlaps during the active frames is hurt
		weapon_hitbox.damage = attack_damage
		weapon_hitbox.swing()


func _on_weapon_hitbox_hit(body: Node3D) -> void:
	struck.emit(body)


## Fires the projectile from the muzzle at the target's focus point, off the line by [member accuracy]'s spread
## for [member skill_level], through the spawner when the scene has one. [signal fired] goes out on every peer.
func _fire() -> Projectile:
	var origin: Transform3D = Transform3D(Basis(), muzzle.global_position)
	var direction: Vector3 = muzzle.global_position.direction_to(Focus.get_focus_target_position(target))
	if accuracy:
		direction = accuracy.scatter(direction, skill_level)
	var spawner: ProjectileSpawner = ProjectileSpawner.find_for(self)
	var projectile: Projectile
	if spawner:
		projectile = spawner.fire(projectile_scene, origin, direction, projectile_speed, self)
	else:
		projectile = projectile_scene.instantiate()
		get_parent().add_child(projectile)
		projectile.launch(origin, direction, projectile_speed, self)
	if is_multiplayer_authority():
		_fired_remote.rpc()
	fired.emit(projectile)
	return projectile


## The authority's shot relayed to the other peers so their muzzle flashes too; the round itself arrives through
## the spawner.
@rpc("authority", "call_remote", "unreliable")
func _fired_remote() -> void:
	fired.emit(null)


## Root motion moves the body: the navigation's wish only decides the animation, then the Root bone's
## travel this frame becomes the velocity, so the feet never slide.
func _move_with_control(control_velocity: Vector3) -> void:
	_control_speed = control_velocity.slide(up_direction).length()
	if is_on_floor() and not is_swimming:
		control_velocity = (mannequin.global_basis * animation_tree.get_root_motion_position() / get_physics_process_delta_time()).slide(up_direction)
	super(control_velocity)


## Called by the Mixamo walk and run animations' method tracks.
func sfx_footsteps_play() -> void:
	if footstep_sfx:
		footstep_audio.stream = footstep_sfx
		footstep_audio.play()


## Eases the blend toward what the navigation asked for (0 idle, 0.5 walk at walk_speed, 1 run at move_speed),
## as LittleBuddy does, so a wish that flickers at the follow distance never restarts a clip.
func _update_locomotion() -> void:
	var wanted_blend: float = 0.0
	if _control_speed > 0.05:
		if _control_speed <= walk_speed:
			wanted_blend = _control_speed / maxf(walk_speed, 0.001) * 0.5
		else:
			wanted_blend = 0.5 + clampf((_control_speed - walk_speed) / maxf(move_speed - walk_speed, 0.001), 0.0, 1.0) * 0.5
	locomotion_blend = move_toward(locomotion_blend, wanted_blend, (8.0 if wanted_blend < locomotion_blend else 6.0) * get_physics_process_delta_time())
	if String(playback.get_current_node()) != LOCOMOTION_STATE and playback.get_travel_path().is_empty() and not playback.is_playing():
		anim_state = LOCOMOTION_STATE


## What a [SaveGame] keeps: where it stands, its pools and whether it is dead. Server only, as the enemy is.
func save_state() -> Dictionary:
	return {
		"transform": global_transform,
		"health": health.health,
		"energy": health.energy,
		"is_dead": is_dead,
	}


## Puts a [method save_state] back: a saved corpse dies where it fell, a saved fighter stands up again.
func load_state(state: Dictionary) -> void:
	if bool(state.get("is_dead", false)):
		if not is_dead:
			health.health = 0.0
		if state.has("transform") and not is_dead:
			global_transform = state["transform"]
		return
	if is_dead:
		revive()
	_drop_target()
	is_returning_home = false
	if state.has("transform"):
		global_transform = state["transform"]
		velocity = Vector3.ZERO
	health.health = float(state.get("health", health.max_health))
	health.energy = float(state.get("energy", health.max_energy))


## Undoes [method _apply_death]: the animation drives the body again, it collides, it can be focused and hunts.
## Only the authority revives; the flag replicates the rest.
func revive(at_post: bool = false) -> void:
	if not is_dead or not is_multiplayer_authority():
		return
	is_dead = false
	if at_post:
		global_transform = _spawn_transform
		velocity = Vector3.ZERO
	physical_bone_simulator.physical_bones_stop_simulation()
	for bone: Node in physical_bone_simulator.find_children("*", "PhysicalBone3D", true, false):
		(bone as PhysicalBone3D).set_collision_layer_value(1, false)
		(bone as PhysicalBone3D).set_collision_mask_value(1, false)
	collision_shape.disabled = false
	animation_tree.active = true
	anim_state = LOCOMOTION_STATE
	add_to_group("Focusable")
	set_physics_process(true)
	if health.health <= 0.0:
		health.health = health.max_health


## The ragdoll takes over and the enemy stops being a threat or a target.
func _apply_death() -> void:
	extinguish()
	caster.interrupt()
	boss.disengage()
	if is_instance_valid(target):
		# Let go of the Player's died signal, not just the reference to them. Clearing target on its own left
		# the callable connected, so an enemy that died and was revived connected it a second time the next
		# time it hunted the same Player, and Godot refused the second connect. Guarded rather than
		# unconditional because this runs on every peer while only the authority ever aggroes.
		if target.health.died.is_connected(_on_target_died):
			target.health.died.disconnect(_on_target_died)
		if is_multiplayer_authority():
			target.hunted_by(get_path(), false)
	target = null
	player = null
	animation_tree.active = false
	for bone: Node in physical_bone_simulator.find_children("*", "PhysicalBone3D", true, false):
		(bone as PhysicalBone3D).set_collision_layer_value(1, true)
		(bone as PhysicalBone3D).set_collision_mask_value(1, true)
	physical_bone_simulator.physical_bones_start_simulation()
	collision_shape.disabled = true
	remove_from_group("Focusable")
	set_physics_process(false)
	died.emit()
