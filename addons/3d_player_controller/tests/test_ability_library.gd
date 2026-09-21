extends GutTest

## Purpose: An AbilityLibrary is one node in the scene holding every ability, keyed by id, warmed once at ready so a
## first cast has no hitch. Casters, the Player's Abilities and an NpcCaster alike, take their abilities from it so
## all of them share the one loaded copy; without a library they keep their own.

const LIBRARY_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/ability_library.tscn")
const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")
const HEAL: Ability = preload("res://addons/3d_player_controller/resources/abilities/heal.tres")
const STEALTH: Ability = preload("res://addons/3d_player_controller/resources/abilities/stealth.tres")

var root: Node3D


func before_each() -> void:
	root = Node3D.new()
	add_child_autofree(root)


func _library() -> AbilityLibrary:
	var library: AbilityLibrary = LIBRARY_SCENE.instantiate()
	root.add_child(library)
	return library


func test_an_ability_is_named_by_its_id_or_its_file() -> void:
	assert_eq(HEAL.get_id(), &"heal", "No id set: the file name")
	var named: Ability = Ability.new()
	named.id = &"big_heal"
	assert_eq(named.get_id(), &"big_heal")


func test_the_library_is_found_and_answers_by_id() -> void:
	assert_null(AbilityLibrary.find(root), "No library in the scene yet")
	var library: AbilityLibrary = _library()
	assert_eq(AbilityLibrary.find(root), library, "Found through its group from anywhere in the tree")
	assert_eq(library.get_ability(&"heal"), HEAL)
	assert_eq(library.get_ability(&"stealth"), STEALTH)
	assert_true(library.has_ability(&"heal"))
	assert_null(library.get_ability(&"fireball"), "Nothing the library was not given")
	assert_eq(library.get_abilities(), [HEAL, STEALTH], "In the entries' order")


func test_a_consumer_adds_entries_as_children() -> void:
	var library: AbilityLibrary = _library()
	var extra: Ability = Ability.new()
	extra.id = &"sparkle"
	var entry: AbilityEntry = AbilityEntry.new()
	entry.ability = extra
	library.add_child(entry)
	library._collect()
	assert_eq(library.get_ability(&"sparkle"), extra, "An entry added under the library is in it")
	assert_eq(library.resolve(extra), extra)
	var stranger: Ability = Ability.new()
	stranger.id = &"unknown"
	assert_eq(library.resolve(stranger), stranger, "An ability the library does not know resolves to itself")


func test_warming_instances_every_vfx_once_and_frees_it() -> void:
	var library: AbilityLibrary = LIBRARY_SCENE.instantiate()
	library.warm_on_ready = false
	root.add_child(library)
	assert_false(library.is_warm)
	# A spell with a VFX for two of its phases, the way a game's spells have (the addon's own two carry none)
	var vfx: PackedScene = PackedScene.new()
	vfx.pack(Node3D.new())
	var spell: Ability = Ability.new()
	spell.id = &"sparkle"
	spell.casting_vfx = vfx
	spell.impact_vfx = vfx
	var entry: AbilityEntry = AbilityEntry.new()
	entry.ability = spell
	library.add_child(entry)
	library._collect()
	watch_signals(library)
	library.warm()
	assert_eq(library.get_child_count(), 3 + 2, "Every phase VFX is instanced under the library for a frame")
	await wait_process_frames(3)
	assert_true(library.is_warm)
	assert_signal_emitted(library, "warmed")
	assert_eq(library.get_child_count(), 3, "and freed again, leaving the entries")


func test_the_players_abilities_are_the_librarys_copies() -> void:
	var library: AbilityLibrary = _library()
	var mine: Ability = HEAL.duplicate()
	mine.id = &"heal" # a copy, as a scene might carry, that answers to the same name
	assert_ne(mine, HEAL)
	var player: Player = PLAYER_SCENE.instantiate()
	(player.get_node("Hud/Abilities") as Abilities).abilities = [mine, STEALTH]
	root.add_child(player)
	await wait_physics_frames(1)
	assert_eq(player.abilities.abilities[0], HEAL, "Resolved by id to the library's loaded copy")
	assert_eq(player.abilities.abilities[1], STEALTH)
	assert_eq(player.abilities.active_ability, HEAL)


func test_without_a_library_a_caster_keeps_its_own() -> void:
	var mine: Ability = HEAL.duplicate()
	var player: Player = PLAYER_SCENE.instantiate()
	(player.get_node("Hud/Abilities") as Abilities).abilities = [mine]
	root.add_child(player)
	await wait_physics_frames(1)
	assert_eq(player.abilities.abilities[0], mine, "Nothing to resolve through")


func test_a_cast_by_name_reaches_the_librarys_ability() -> void:
	var library: AbilityLibrary = _library()
	var player: Player = PLAYER_SCENE.instantiate()
	(player.get_node("Hud/Abilities") as Abilities).abilities = []
	root.add_child(player)
	await wait_physics_frames(1)
	watch_signals(player.abilities)
	player.abilities.cast_id(&"stealth")
	assert_signal_emitted(player.abilities, "ability_activated", "Stealth is not the Player's own, but the library has it")
	player.abilities.cast_id(&"nothing_by_this_name")
	assert_signal_emit_count(player.abilities, "ability_activated", 1, "An unknown name does nothing")
	assert_true(library.has_ability(&"stealth"))


func test_a_preview_cast_plays_the_phases_between_two_bodies() -> void:
	var library: AbilityLibrary = LIBRARY_SCENE.instantiate()
	library.warm_on_ready = false
	root.add_child(library)
	var vfx: PackedScene = PackedScene.new()
	vfx.pack(Node3D.new())
	var bolt_spell: Ability = Ability.new()
	bolt_spell.id = &"bolt"
	bolt_spell.projectile_speed = 40.0
	bolt_spell.casting_vfx = vfx
	bolt_spell.impact_vfx = vfx
	bolt_spell.fx_lifetime = 0.3
	var entry: AbilityEntry = AbilityEntry.new()
	entry.ability = bolt_spell
	library.add_child(entry)
	var caster: Node3D = Node3D.new()
	var target: Node3D = Node3D.new()
	root.add_child(caster)
	root.add_child(target)
	target.global_position = Vector3(4.0, 0.0, 0.0)
	entry.preview_cast(caster, target)
	await wait_process_frames(1)
	var bolt: Node3D = entry.get_node_or_null("PreviewCastCasting")
	assert_not_null(bolt, "The casting VFX leaves the caster as a bolt")
	assert_between(bolt.global_position.x, 0.0, 3.5, "on its way from the caster's hand to the target")
	assert_between(bolt.global_position.y, AbilityEntry.CHEST_HEIGHT - 0.01, AbilityEntry.HAND_HEIGHT + 0.01, "between hand height and chest height")
	await wait_seconds(0.25)
	assert_not_null(entry.get_node_or_null("PreviewCastImpact"), "and the impact lands once it has flown the four metres at forty a second")
	await wait_seconds(0.5)
	assert_null(entry.get_node_or_null("PreviewCastImpact"), "One-shot previews free themselves after the ability's fx_lifetime")


func test_the_buttons_need_the_librarys_test_rig() -> void:
	var library: AbilityLibrary = _library()
	var entry: AbilityEntry = library.get_child(0)
	entry.cast_forward.call() # no rig on the library: a warning, nothing spawned
	await wait_process_frames(1)
	assert_eq(entry.get_child_count(), 0, "Nothing fires without a caster and a target")
	var caster: Node3D = Node3D.new()
	var target: Node3D = Node3D.new()
	root.add_child(caster)
	root.add_child(target)
	library.test_caster = caster
	library.test_target = target
	entry.cast_back.call()
	await wait_process_frames(1)
	assert_true(entry._casting, "With the rig set the cast runs, from the target back to the caster")
