extends DemoScene
## The platformer style: Jump on the bottom button, a double jump, islands in the sky with coins taken on touch,
## a moving platform, a mushroom that throws you up, goons to stomp, checkpoints along the way, a fall into the
## sea that costs a life, and a flag to reach.

const QUEST: Quest = preload("res://addons/3d_player_controller/resources/quests/platformer_skyline.tres")
const COIN: Item = preload("res://addons/3d_player_controller/resources/items/gold_coin.tres")

@export var goons: Node3D
@export var goal: Area3D

var coins_taken: int = 0
var flag_reached: bool = false


func setup_player(target: Player) -> void:
	target.enable_double_jump = true
	target.instant_jump = true
	target.air_jumps = 1
	target.enable_stamina = false
	for pickup: Node in find_children("*", "ItemPickup", true, false):
		(pickup as ItemPickup).picked_up.connect(_on_coin_taken)
	for goon: Node in goons.get_children():
		for stomp: Node in goon.find_children("*", "Stompable", true, false):
			(stomp as Stompable).stomped.connect(_on_goon_stomped)
	if target.quest_log:
		target.quest_log.start(QUEST)


func _on_coin_taken(_by: Player, count: int) -> void:
	coins_taken += count
	if player and player.quest_log:
		player.quest_log.progress(&"collect_coin", count)


func _on_goon_stomped(_by: Player) -> void:
	pass


func _on_goal_body_entered(body: Node3D) -> void:
	if body is Player and not flag_reached:
		flag_reached = true
		if player and player.quest_log:
			player.quest_log.progress(&"reach_flag")


func goons_standing() -> int:
	var standing: int = 0
	for goon: Node in goons.get_children():
		if goon is EnemyNpc and not (goon as EnemyNpc).is_dead:
			standing += 1
	return standing


## The recording: the coins on the first island, a running jump, a double jump up, the moving platform, the
## mushroom, two goons stomped, the double jump to the top, the flag.
func build_autopilot(pilot: DemoAutopilot) -> void:
	var here: Callable = func(marker: String) -> Transform3D: return (get_node("Markers/" + marker) as Marker3D).global_transform
	var north: Vector3 = Vector3(0.0, 0.0, -1.0)
	var platform: MovingPlatform = $Islands/Platform
	var landed: Callable = func() -> bool: return player.is_on_floor()
	pilot.wait(1.0)
	for i: int in 4:
		pilot.walk_to(get_node("Islands/Coins/Coin%d" % (i + 1)), 4.0, 0.4)
	pilot.wait(0.3)
	pilot.warp(player, here.call("EdgeStart")).wait(0.4).hop(north, 2.2, [0.45]).wait_until(landed, 2.0).wait(0.3) # a running jump
	pilot.walk_to($Islands/Coins/Coin5, 3.0, 0.4).walk_to($Islands/Coins/Coin6, 3.0, 0.4)
	pilot.warp(player, here.call("EdgeIsland1")).wait(0.4).hop(north, 2.4, [0.35, 0.85]).wait_until(landed, 2.0).wait(0.3) # a double jump up
	pilot.walk_to($Islands/Coins/Coin7, 3.0, 0.4).walk_to($Islands/Coins/Coin8, 3.0, 0.4)
	pilot.warp(player, here.call("EdgeIsland2")).wait(0.2)
	pilot.wait_until(func() -> bool: return platform.global_position.z > -25.0 and platform.global_position.z < -24.6, 10.0)
	pilot.hop(north, 1.4, [0.3]).wait_until(landed, 2.0) # onto the platform as it arrives
	pilot.wait_until(func() -> bool: return platform.global_position.z < -32.3, 10.0)
	pilot.hop(north, 1.6, [0.25]).wait_until(landed, 2.0).wait(0.5) # and off it at the far end
	pilot.walk_to($Islands/Coins/Coin9, 5.0, 0.4).walk_to($Islands/Coins/Coin10, 5.0, 0.4)
	pilot.warp(player, here.call("EdgeIsland3")).wait(0.3).hop(north, 1.7, [0.35]).wait_until(landed, 4.0).wait(0.4) # the mushroom throws you to the fourth
	for i: int in 2:
		var goon: EnemyNpc = goons.get_child(i)
		var toward_goon: Callable = func() -> Vector3: return (goon.global_position - player.global_position).slide(Vector3.UP).normalized()
		pilot.walk_to(goon, 4.0, 2.4).wait_until(func() -> bool: return goon.is_dead or goon.global_position.distance_to(player.global_position) < 1.5, 4.0)
		pilot.hop(toward_goon, 0.7, [0.0]).wait_until(landed, 2.5).wait(0.4) # straight up and onto its head
	pilot.walk_to($Islands/Coins/Coin11, 3.0, 0.4).walk_to($Islands/Coins/Coin12, 3.0, 0.4).walk_to($Islands/Coins/Coin13, 3.0, 0.4)
	pilot.warp(player, here.call("EdgeIsland4")).wait(0.3).hop(Vector3(5.5, 0.0, -7.0).normalized(), 2.8, [0.45, 0.85]).wait_until(landed, 3.0).wait(0.3) # the double jump to the top
	pilot.walk_to($Islands/Coins/Coin14, 3.0, 0.4).walk_to($Islands/Coins/Coin15, 3.0, 0.4).walk_to($Islands/Goal, 4.0, 1.0).wait(2.0)
