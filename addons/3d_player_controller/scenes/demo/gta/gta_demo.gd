extends DemoScene
## The Grand Theft Auto style on foot: a downtown intersection, a pistol on the sidewalk, a fixer with a job, a
## gang in the lot across the street, free aim over the shoulder with Aim held, a rifle in their stash, and the
## wanted stars that bring the law running when the shooting starts and fade once it stops.

const CASH: Item = preload("res://addons/3d_player_controller/resources/items/cash.tres")
const HEALTH_PACK: Item = preload("res://addons/3d_player_controller/resources/items/health_pack.tres")
const DATA_CARD: Item = preload("res://addons/3d_player_controller/resources/items/data_card.tres")

const HEALTH_PACK_HEAL: float = 50.0

@export var wanted: WantedLevel
@export var lot_gunmen: Node3D ## The gang; entering the lot sets them all on the Player.
@export var lot_trigger: Area3D

@onready var fixer: TalkingNpc = $People/Fixer


func setup_player(target: Player) -> void:
	target.skill_level = 8 # a practised shot: the pistol's spread is a hand's width at the lot's far wall
	wanted.player = target
	for gunman: Node in lot_gunmen.get_children():
		if gunman is EnemyNpc:
			(gunman as EnemyNpc).died.connect(_on_gunman_died)
	for pickup: Node in find_children("*", "ItemPickup", true, false):
		(pickup as ItemPickup).picked_up.connect(_on_picked_up)
	target.inventory.item_used.connect(_on_item_used)


## A health pack is used the moment it is taken; the data card is the job.
func _on_picked_up(by: Player, count: int) -> void:
	if by == null or by.inventory == null:
		return
	if by.inventory.count_of(DATA_CARD) > 0 and by.quest_log and not by.quest_log.is_objective_done(preload("res://addons/3d_player_controller/resources/quests/gta_alley.tres"), &"take_card"):
		by.quest_log.progress(&"take_card")
	var packs: int = by.inventory.count_of(HEALTH_PACK)
	if packs > 0:
		by.inventory.use_item(HEALTH_PACK, packs)


func _on_item_used(item: Item, count: int) -> void:
	if item == HEALTH_PACK and player:
		player.heal(HEALTH_PACK_HEAL * count)


## A gunman down counts for the job; the shooting heard from the street is the first offence, and the law is on
## its way by the time the last of the gang drops.
func _on_gunman_died() -> void:
	if player and player.quest_log:
		player.quest_log.progress(&"defeat_gunman")
	if wanted.stars == 0 and nearest_enemy(lot_gunmen, Vector3.ZERO) is Vector3:
		wanted.raise(1)


func _on_lot_trigger_body_entered(body: Node3D) -> void:
	if body is Player:
		for gunman: Node in lot_gunmen.get_children():
			if gunman is EnemyNpc and (gunman as EnemyNpc).health.is_alive():
				(gunman as EnemyNpc).aggro(body)


## The nearest living enemy of [param parent]'s children, or [param fallback] when none stands.
func nearest_enemy(parent: Node, fallback: Vector3) -> Variant:
	var best: EnemyNpc = null
	var best_distance: float = INF
	for enemy: Node in parent.get_children():
		if enemy is EnemyNpc and (enemy as EnemyNpc).health.is_alive():
			var distance: float = (enemy as EnemyNpc).global_position.distance_to(player.global_position)
			if distance < best_distance:
				best_distance = distance
				best = enemy
	return best if best else fallback


func _officers_standing() -> bool:
	for officer: EnemyNpc in wanted.officers:
		if is_instance_valid(officer) and officer.health.is_alive():
			return true
	return false


## The recording: the pistol and its clips, a few rounds down the street, the fixer's job, the lot shootout, the
## stash, the officers who answer the gunfire, the stars fading, and the pay-off.
func build_autopilot(pilot: DemoAutopilot) -> void:
	var here: Callable = func(marker: String) -> Transform3D: return (get_node("Markers/" + marker) as Marker3D).global_transform
	var south: Vector3 = Vector3(0.0, 0.0, 1.0)
	var lot_mouth: Vector3 = Vector3(-17.0, 1.0, 14.0)
	var gunman: Callable = func() -> Variant: return nearest_enemy(lot_gunmen, Vector3(-22.0, 1.0, 26.0))
	var gang_down: Callable = func() -> bool: return nearest_enemy(lot_gunmen, Vector3.ZERO) is Vector3
	var officer: Callable = func() -> Variant: return nearest_enemy(get_tree().current_scene if get_tree().current_scene else self, Vector3(-22.0, 1.0, 0.0))
	var law_gone: Callable = func() -> bool: return not _officers_standing()
	pilot.wait(1.2)
	pilot.walk_to($Sidewalk/Pistol, 4.0, 0.6).wait(0.6).walk_to($Sidewalk/AmmoBox, 4.0, 0.9).wait(0.4).tap(&"action").wait(0.6) # the pistol, then the clips
	pilot.aim(func() -> Variant: return lot_mouth, 2.6, 2.0).wait(0.4).tap(&"reload").wait(1.6) # rounds into the barrels by the lot
	pilot.warp(player, here.call("ByFixer")).wait(0.6)
	talk(pilot, 2) # the greeting, the job taken, the terms
	pilot.warp(player, here.call("LotMouth")).wait(0.4).walk(south, 1.1).wait(0.2)
	pilot.aim(gunman, 14.0, 2.5, gang_down).wait(0.8)
	pilot.warp(player, here.call("Stash")).wait(0.4).walk_to($Lot/Rifle, 4.0, 0.7).wait(0.6) # the rifle by the crate
	pilot.walk_to($Lot/LotMagazines, 4.0, 1.0).wait(0.3).tap(&"action").wait(0.5) # and its magazines
	pilot.walk_to($Lot/LotHealthPack, 5.0, 0.8).wait(0.3).tap(&"action").wait(0.4) # patched up before the law arrives
	pilot.wait_until(func() -> bool: return _officers_standing(), 10.0)
	pilot.aim(officer, 30.0, 4.0, law_gone, 22.0).wait(0.6) # bursts once each is in range; every one down brings another, to three
	pilot.walk_to($Lot/DataCard, 6.0, 1.1).wait(0.4).tap(&"action").wait(0.8) # the card from the stash
	pilot.warp(player, here.call("Street")).wait_until(func() -> bool: return wanted.stars == 0, 16.0).wait(0.6) # the stars fade
	pilot.warp(player, here.call("ByFixer")).wait(0.5)
	talk(pilot, 1).wait(1.0) # the pay-off
