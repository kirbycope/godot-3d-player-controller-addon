class_name WantedLevel
extends Node
## The Grand Theft Auto wanted meter: stars that go up when the Player hurts the law, bring officers running from
## [member spawn_points], and fade a star at a time after [member decay_seconds] without another offence. Each
## star spawns one more [member officer_scene] (an [EnemyNpc]) at the nearest spawn point still
## [member min_spawn_distance] from the Player (never the one used last) and sets it on the Player; an officer hurt or killed raises the level again; at no stars the officers still
## standing lose interest and go. A [member stars_container] of [TextureRect]s shows the level on the HUD.

signal stars_changed(stars: int) ## The level went up or down.
signal officer_spawned(officer: EnemyNpc)

@export var player: Player ## Whom the officers hunt; the first Player in the tree when empty.
@export var officer_scene: PackedScene ## The [EnemyNpc] that answers each star.
@export var spawn_points: Node3D ## Its [Node3D] children are where officers appear.
@export var max_stars: int = 3
@export var min_spawn_distance: float = 20.0 ## Officers appear at the nearest spawn point at least this far from the Player: off screen, but not off their leash.
@export var decay_seconds: float = 20.0 ## Quiet time before a star fades; every offence restarts it.
@export var decay_timer: Timer
@export var stars_container: Container ## Holds one [TextureRect] per possible star; lit ones are at full alpha.

var stars: int = 0:
	set(value):
		value = clampi(value, 0, max_stars)
		if value == stars:
			return
		stars = value
		_refresh_stars()
		stars_changed.emit(stars)
		if stars == 0:
			_stand_down()
var officers: Array[EnemyNpc] = [] ## The officers still on the street.

var _last_spawn: int = -1


func _ready() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group(&"Player") as Player
	if decay_timer and not decay_timer.timeout.is_connected(_on_decay_timer_timeout):
		decay_timer.timeout.connect(_on_decay_timer_timeout)
	_refresh_stars()


## An offence: the level rises by [param by] (never past [member max_stars]), the fade restarts and one officer
## per new star comes running. Called for every offence, so a shootout keeps the meter up.
func raise(by: int = 1) -> void:
	var before: int = stars
	stars = stars + by
	if decay_timer:
		decay_timer.start(decay_seconds)
	for i: int in stars - before:
		_spawn_officer()


## Watches [param officer] (any [EnemyNpc], spawned here or placed in the scene): hurting it is an offence.
func watch(officer: EnemyNpc) -> void:
	if officer.health and not officer.health.damaged.is_connected(_on_officer_damaged):
		officer.health.damaged.connect(_on_officer_damaged.bind(officer))
	if not officer.died.is_connected(_on_officer_died):
		officer.died.connect(_on_officer_died.bind(officer))


func _spawn_officer() -> void:
	if officer_scene == null or spawn_points == null or spawn_points.get_child_count() == 0 or player == null:
		return
	var points: Array[Node] = spawn_points.get_children()
	var index: int = -1
	var nearest: float = INF
	var furthest_index: int = 0
	var furthest: float = -1.0
	for i: int in points.size():
		var point: Node3D = points[i] as Node3D
		if point == null or (i == _last_spawn and points.size() > 1):
			continue
		var distance: float = point.global_position.distance_to(player.global_position)
		if distance >= min_spawn_distance and distance < nearest:
			nearest = distance
			index = i
		if distance > furthest:
			furthest = distance
			furthest_index = i
	if index < 0:
		index = furthest_index
	_last_spawn = index
	var officer: EnemyNpc = officer_scene.instantiate() as EnemyNpc
	officer.global_transform = (points[index] as Node3D).global_transform
	get_parent().add_child(officer)
	officers.append(officer)
	watch(officer)
	officer.aggro(player)
	officer_spawned.emit(officer)


func _on_officer_damaged(_amount: float, _from: Vector3, officer: EnemyNpc) -> void:
	if officer.health and officer.health.is_alive():
		raise(1 if stars == 0 else 0)


func _on_officer_died(officer: EnemyNpc) -> void:
	officers.erase(officer)
	raise(1)


## A star fades only once no officer has the Player in their sights: lose them, or drop them, and the meter
## counts down from there.
func _on_decay_timer_timeout() -> void:
	if not is_chased():
		stars -= 1
	if stars > 0 and decay_timer:
		decay_timer.start(decay_seconds)


## Whether an officer still standing is hunting the Player.
func is_chased() -> bool:
	for officer: EnemyNpc in officers:
		if is_instance_valid(officer) and officer.health and officer.health.is_alive() and officer.target == player:
			return true
	return false


## No stars: the officers still up give up the chase and leave.
func _stand_down() -> void:
	for officer: EnemyNpc in officers:
		if is_instance_valid(officer):
			if player and officer.target == player:
				player.hunted_by(officer.get_path(), false)
			officer.queue_free()
	officers.clear()


func _refresh_stars() -> void:
	if stars_container == null:
		return
	var i: int = 0
	for star: Node in stars_container.get_children():
		if star is CanvasItem:
			(star as CanvasItem).modulate.a = 1.0 if i < stars else 0.25
		i += 1
