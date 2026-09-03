class_name ProjectileSpawner
extends MultiplayerSpawner
## Spawns projectiles on every peer from one launch description.
##
## [method fire] runs on the server (or offline) directly and asks the server over RPC otherwise; the
## server spawns through [member MultiplayerSpawner.spawn_function] with the same data on all peers,
## so each peer simulates an identical round and resolves its hits locally. Add the node to the
## [code]ProjectileSpawner[/code] group so weapons can find it; without one, weapons fire locally.


func _ready() -> void:
	spawn_function = _spawn_projectile


## Launches [param scene] from [param origin] along [param direction]; returns the local copy on the
## server and null on clients (their copy arrives through the spawner).
func fire(scene: PackedScene, origin: Transform3D, direction: Vector3, speed: float, shooter: Node3D, weapon: Node = null) -> Projectile:
	var data: Dictionary = {
		"scene": scene.resource_path,
		"origin": origin,
		"direction": direction,
		"speed": speed,
		"shooter": String(shooter.get_path()) if shooter else "",
		"weapon": String(weapon.get_path()) if weapon else "",
	}
	if multiplayer.is_server():
		return spawn(data) as Projectile
	_request_fire.rpc_id(1, data)
	return null


@rpc("any_peer", "call_remote", "reliable")
func _request_fire(data: Dictionary) -> void:
	if multiplayer.is_server():
		spawn(data)


## Runs on every peer: builds the projectile; it launches itself once it enters the tree.
func _spawn_projectile(data: Dictionary) -> Node:
	var projectile: Projectile = (load(data["scene"]) as PackedScene).instantiate()
	projectile.pending_launch = data
	return projectile
