extends DemoScene
## The third-person shooter style: over the shoulder with Aim held, a floodlit compound at night, sandbags and
## crates to crouch behind, a rifle and a pistol with their ammunition, three waves over the breached wall, health
## packs and ammo caches between them, and the gate that opens on the last one down, with the extraction pad past it.

const QUEST: Quest = preload("res://addons/3d_player_controller/resources/quests/tps_holdout.tres")
const HEALTH_PACK: Item = preload("res://addons/3d_player_controller/resources/items/health_pack.tres")
const HEALTH_PACK_HEAL: float = 50.0

@export var spawner: WaveSpawner
@export var gate: LockedDoor
@export var extraction: Area3D
@export var hold_position: Area3D
@export var navigation_region: NavigationRegion3D

var extracted: bool = false


func _ready() -> void:
	super()
	bake_navigation(navigation_region) # after the setup, so the enemies path around the walls a frame or two in


func setup_player(target: Player) -> void:
	target.skill_level = 8
	target.inventory.item_used.connect(_on_item_used)
	for pickup: Node in find_children("*", "ItemPickup", true, false):
		(pickup as ItemPickup).picked_up.connect(_on_picked_up)
	spawner.player = target
	spawner.wave_cleared.connect(_on_wave_cleared)
	spawner.all_cleared.connect(_on_all_cleared)
	if target.quest_log:
		target.quest_log.start(QUEST)


func _on_picked_up(by: Player, _count: int) -> void:
	if by and by.inventory and by.inventory.count_of(HEALTH_PACK) > 0:
		by.inventory.use_item(HEALTH_PACK, by.inventory.count_of(HEALTH_PACK))


func _on_item_used(item: Item, count: int) -> void:
	if item == HEALTH_PACK and player:
		player.heal(HEALTH_PACK_HEAL * count)


## Reaching the sandbags starts the holdout.
func _on_hold_position_body_entered(body: Node3D) -> void:
	if body is Player and not spawner.running and spawner.wave < 0:
		spawner.start()


func _on_wave_cleared(_index: int) -> void:
	if player and player.quest_log:
		player.quest_log.progress(&"clear_wave")


## The last wave down unseals the gate.
func _on_all_cleared() -> void:
	gate.sealed = false
	gate.open(player)


func _on_extraction_body_entered(body: Node3D) -> void:
	if body is Player and not extracted:
		extracted = true
		if player and player.quest_log:
			player.quest_log.progress(&"reach_extraction")


func nearest_enemy(fallback: Vector3) -> Variant:
	var best: EnemyNpc = null
	var best_distance: float = INF
	for enemy: EnemyNpc in spawner.alive:
		if is_instance_valid(enemy) and not enemy.is_dead:
			var distance: float = enemy.global_position.distance_to(player.global_position)
			if distance < best_distance:
				best_distance = distance
				best = enemy
	return best if best else fallback


## The recording: rifle, pistol and magazines, into cover, three waves from behind the sandbags with a run for
## ammunition and a health pack between them, the gate, the pad.
func build_autopilot(pilot: DemoAutopilot) -> void:
	var here: Callable = func(marker: String) -> Transform3D: return (get_node("Markers/" + marker) as Marker3D).global_transform
	var north: Vector3 = Vector3(0.0, 0.0, -1.0)
	var enemy: Callable = func() -> Variant: return nearest_enemy(player.global_position + north * 20.0)
	var wave_over: Callable = func() -> bool: return spawner.alive.is_empty()
	var wave_on: Callable = func() -> bool: return not spawner.alive.is_empty()
	pilot.wait(1.0).walk_to($Gear/Pistol, 4.0, 0.7).wait(0.4).walk_to($Gear/Magazines, 4.0, 0.9).wait(0.5).tap(&"action").wait(0.4).walk_to($Gear/Rifle, 4.0, 0.7).wait(0.5) # the rifle last, so it is the one in hand
	pilot.warp(player, here.call("CoverA")).wait(0.3).walk(north, 0.4).wait_until(wave_on, 8.0).wait(0.6)
	pilot.press(&"crouch").wait(0.4).aim(enemy, 45.0, 4.0, wave_over, 30.0).release(&"crouch").wait(0.4).tap(&"reload").wait(1.4) # wave one from behind the bags
	pilot.walk_to($Gear/AmmoCache1, 5.0, 0.9).wait(0.5).tap(&"action").wait(0.4)
	pilot.warp(player, here.call("CoverC")).wait(0.3).wait_until(wave_on, 8.0).wait(0.4)
	pilot.press(&"crouch").wait(0.4).aim(enemy, 50.0, 4.0, wave_over, 30.0).release(&"crouch").wait(0.4).tap(&"reload").wait(1.4) # wave two
	pilot.walk_to($Gear/HealthPack1, 5.0, 0.8).wait(0.5).tap(&"action").wait(0.4)
	pilot.warp(player, here.call("CoverB")).wait(0.3).wait_until(wave_on, 8.0).wait(0.4)
	pilot.aim(enemy, 60.0, 4.0, wave_over, 32.0).wait(0.8) # wave three, standing and moving
	pilot.wait_until(func() -> bool: return gate.is_open, 4.0).wait(0.6)
	pilot.warp(player, here.call("GateMouth")).wait(0.4).walk_to($Extraction/ExtractionTrigger, 8.0, 1.2).wait(2.5)
