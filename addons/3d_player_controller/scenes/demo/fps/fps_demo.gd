extends DemoScene
## The first-person shooter style: the camera in the head, a base on lockdown, a pistol off a desk, sentries in
## the corridor, a security card that opens the armoury door, a rifle behind it, the alarm that brings a wave, and
## the lift out. Health packs heal on touch; clips and magazines reload from the bag.

const QUEST: Quest = preload("res://addons/3d_player_controller/resources/quests/fps_breakout.tres")
const HEALTH_PACK: Item = preload("res://addons/3d_player_controller/resources/items/health_pack.tres")
const SECURITY_CARD: Item = preload("res://addons/3d_player_controller/resources/items/security_card.tres")
const HEALTH_PACK_HEAL: float = 50.0

@export var door: LockedDoor
@export var spawner: WaveSpawner
@export var lift: Area3D
@export var navigation_region: NavigationRegion3D
@export var alarm_delay: float = 7.0 ## Seconds between the armoury door opening and the wave arriving.

var lift_reached: bool = false


func _ready() -> void:
	super()
	bake_navigation(navigation_region) # after the setup, so the enemies path around the walls a frame or two in


func setup_player(target: Player) -> void:
	target.skill_level = 8
	if target.camera is Camera and (target.camera as Camera).perspective != Camera.Perspective.FIRST_PERSON:
		(target.camera as Camera).toggle_perspective()
	target.inventory.item_used.connect(_on_item_used)
	for pickup: Node in find_children("*", "ItemPickup", true, false):
		(pickup as ItemPickup).picked_up.connect(_on_picked_up)
	door.opened.connect(_on_door_opened)
	spawner.player = target
	if target.quest_log:
		target.quest_log.start(QUEST)


func _on_picked_up(by: Player, _count: int) -> void:
	if by == null or by.inventory == null:
		return
	if by.inventory.count_of(SECURITY_CARD) > 0 and by.quest_log and not by.quest_log.is_objective_done(QUEST, &"find_card"):
		by.quest_log.progress(&"find_card")
	var packs: int = by.inventory.count_of(HEALTH_PACK)
	if packs > 0:
		by.inventory.use_item(HEALTH_PACK, packs)


func _on_item_used(item: Item, count: int) -> void:
	if item == HEALTH_PACK and player:
		player.heal(HEALTH_PACK_HEAL * count)


## The armoury open trips the alarm: the wave comes through the control room [member alarm_delay] seconds on,
## time enough to take the rifle off its desk.
func _on_door_opened(_by: Player) -> void:
	if player and player.quest_log:
		player.quest_log.progress(&"open_door")
	get_tree().create_timer(alarm_delay).timeout.connect(func() -> void:
		if is_inside_tree() and not spawner.running and spawner.wave < 0:
			spawner.start())


func _on_lift_body_entered(body: Node3D) -> void:
	if body is Player and not lift_reached:
		lift_reached = true
		if player and player.quest_log:
			player.quest_log.progress(&"reach_lift")


## The nearest living enemy anywhere in the scene, or [param fallback].
func nearest_enemy(fallback: Vector3) -> Variant:
	var best: EnemyNpc = null
	var best_distance: float = INF
	for enemy: Node in get_tree().get_nodes_in_group(&"Focusable"):
		if enemy is EnemyNpc and not (enemy as EnemyNpc).is_dead:
			var distance: float = (enemy as EnemyNpc).global_position.distance_to(player.global_position)
			if distance < best_distance:
				best_distance = distance
				best = enemy
	return best if best else fallback


func enemies_standing(within: float) -> bool:
	var nearest: Variant = nearest_enemy(Vector3.ZERO)
	return nearest is EnemyNpc and (nearest as EnemyNpc).global_position.distance_to(player.global_position) <= within


## The recording: the pistol and clips, the corridor sentries, the control room, the card, the door, the rifle,
## the wave, the lift.
func build_autopilot(pilot: DemoAutopilot) -> void:
	var here: Callable = func(marker: String) -> Transform3D: return (get_node("Markers/" + marker) as Marker3D).global_transform
	var north: Vector3 = Vector3(0.0, 0.0, -1.0)
	var enemy: Callable = func() -> Variant: return nearest_enemy(player.global_position + north * 10.0)
	var quiet_nearby: Callable = func() -> bool: return not enemies_standing(22.0)
	pilot.wait(1.2).walk_to($CellBlock/Pistol, 4.0, 0.8).wait(0.5).walk_to($CellBlock/Clips, 4.0, 0.9).wait(0.3).tap(&"action").wait(0.5)
	pilot.walk_to($CellBlock/HealthPack1, 5.0, 0.8).wait(0.3).tap(&"action").wait(0.4)
	pilot.warp(player, here.call("CorridorMouth")).wait(0.4).walk(north, 0.8).wait(0.3)
	pilot.aim(enemy, 20.0, 2.5, quiet_nearby, 24.0).wait(0.5) # the corridor sentries
	pilot.tap(&"reload").wait(1.4)
	pilot.warp(player, here.call("ControlMouth")).wait(0.4).walk(north, 0.9).wait(0.2)
	pilot.aim(enemy, 20.0, 2.5, quiet_nearby, 24.0).wait(0.5) # the control room
	pilot.walk_to($Control/SecurityCard, 8.0, 1.0).wait(0.3).tap(&"action").wait(0.8) # the card
	pilot.warp(player, here.call("ByDoor")).wait(0.4).walk_to(door, 4.0, 1.2).wait(0.5).tap(&"action").wait(1.6) # Open, and the alarm
	pilot.warp(player, here.call("ArmouryDoor")).wait(0.3).walk_to($Armoury/Rifle, 6.0, 0.9).wait(0.5).walk_to($Armoury/Magazines, 4.0, 0.9).wait(0.3).tap(&"action").wait(0.4)
	pilot.warp(player, here.call("ArmouryBack")).wait(0.3)
	pilot.wait_until(func() -> bool: return enemies_standing(14.0), 12.0)
	pilot.aim(enemy, 40.0, 4.0, quiet_nearby, 24.0).wait(0.6) # the wave, from the armoury doorway
	pilot.walk_to($Armoury/HealthPack3, 6.0, 0.8).wait(0.3).tap(&"action").wait(0.3)
	pilot.warp(player, here.call("LiftMouth")).wait(0.3).walk_to($Lift/LiftTrigger, 6.0, 1.0).wait(2.5)
