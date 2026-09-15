class_name WaveSpawner
extends Node
## Enemies in waves: [method start] brings the first wave of [member waves] (a count per wave) in at
## [member spawn_points]' children, set on the Player; when the last of a wave is down the next comes after
## [member between_waves] seconds, and [signal all_cleared] fires after the last. A horde mode, a defence, a
## boss rush with [member enemy_scenes] cycled per spawn.

signal wave_started(index: int, count: int)
signal wave_cleared(index: int)
signal all_cleared
signal enemy_spawned(enemy: EnemyNpc)

@export var player: Player ## Whom the waves hunt; the first Player in the tree when empty.
@export var enemy_scenes: Array[PackedScene] = [] ## Cycled through as enemies spawn.
@export var spawn_points: Node3D ## Its children are where they appear, cycled too.
@export var waves: Array[int] = [3, 4, 5]
@export var between_waves: float = 4.0
@export var autostart: bool = false

var wave: int = -1 ## The wave in progress; -1 before the first.
var alive: Array[EnemyNpc] = []
var running: bool = false

var _spawned: int = 0
var _timer: Timer


func _ready() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group(&"Player") as Player
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_next_wave)
	add_child(_timer)
	if autostart:
		start()


## The first wave, now.
func start() -> void:
	if running:
		return
	running = true
	wave = -1
	_next_wave()


## Every wave came and went.
func is_done() -> bool:
	return wave >= waves.size() and alive.is_empty()


func _next_wave() -> void:
	wave += 1
	if wave >= waves.size():
		running = false
		all_cleared.emit()
		return
	for i: int in waves[wave]:
		_spawn()
	wave_started.emit(wave, waves[wave])


func _spawn() -> void:
	if enemy_scenes.is_empty() or spawn_points == null or spawn_points.get_child_count() == 0:
		return
	var scene: PackedScene = enemy_scenes[_spawned % enemy_scenes.size()]
	var point: Node3D = spawn_points.get_child(_spawned % spawn_points.get_child_count()) as Node3D
	_spawned += 1
	var enemy: EnemyNpc = scene.instantiate() as EnemyNpc
	enemy.global_transform = point.global_transform
	get_parent().add_child(enemy)
	alive.append(enemy)
	enemy.died.connect(_on_enemy_died.bind(enemy))
	if player:
		enemy.aggro(player)
	enemy_spawned.emit(enemy)


func _on_enemy_died(enemy: EnemyNpc) -> void:
	alive.erase(enemy)
	if alive.is_empty():
		wave_cleared.emit(wave)
		if wave + 1 >= waves.size():
			wave += 1
			running = false
			all_cleared.emit()
		else:
			_timer.start(between_waves)
