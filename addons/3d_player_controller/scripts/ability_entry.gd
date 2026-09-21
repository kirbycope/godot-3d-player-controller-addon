@tool
@icon("res://addons/3d_player_controller/assets/game_icons/wizard-staff.svg")
class_name AbilityEntry
extends Node3D
## One ability in an [AbilityLibrary]: a node carrying the [Ability] resource, so the library's contents are nodes a
## project can see and add to in the editor (instance the library scene, make its children editable, add an entry).
##
## In the editor it takes the ability's name when it still has a default one, and the inspector shows the ability
## resource in place.
##
## It can also fire the ability in the editor, between the two nodes the library's [member AbilityLibrary.test_caster]
## and [member AbilityLibrary.test_target] name in a test scene (a Player and an EnemyNpc, say): the two buttons in the
## inspector play the channeling, casting and impact phases from one to the other, a bolt flying between them when
## the ability has one. It is the look and sound of the cast, not the gameplay: nothing takes damage.

const PREVIEW: StringName = &"Preview" ## What a cast's VFX and audio are named under this node, so they can be told from anything saved.
const HAND_HEIGHT: float = 1.3 ## Where a cast leaves a caster with no hand anchor, above its origin.
const CHEST_HEIGHT: float = 1.0 ## Where a bolt lands on a target, above its origin.

@export var ability: Ability: ## The ability this entry puts in the library; its [method Ability.get_id] is its name there.
	set(value):
		ability = value
		if Engine.is_editor_hint() and ability and (String(name).begins_with("AbilityEntry") or String(name).begins_with("Node3D")):
			name = _entry_name(ability)

@export_tool_button("Cast from caster to target", "Play") var cast_forward: Callable = _cast_forward
@export_tool_button("Cast from target to caster", "PlayBackwards") var cast_back: Callable = _cast_back

var _casting: bool = false


func _get_configuration_warnings() -> PackedStringArray:
	if ability == null:
		return ["No ability set: this entry puts nothing in the library."]
	return []


## Plays [member ability] from [param caster] to [param target] as a preview: the channeling VFX and sound on the
## caster for the cast time, then the casting phase, carried to the target as a bolt over [member Ability.projectile_speed]
## when the ability has one, then the impact at the target. Everything it makes lives under this node, unsaved, and
## frees itself after the ability's [member Ability.fx_lifetime]. Works in the editor and in a running scene alike.
func preview_cast(caster: Node3D, target: Node3D) -> void:
	if ability == null or caster == null or target == null or _casting:
		return
	_casting = true
	var from: Vector3 = caster.global_position + caster.global_basis.y * HAND_HEIGHT
	var to: Vector3 = target.global_position + target.global_basis.y * CHEST_HEIGHT
	if ability.cast_time > 0.0:
		var channeling: Node3D = _spawn(Ability.Phase.CHANNELING, from)
		await get_tree().create_timer(ability.cast_time).timeout
		if is_instance_valid(channeling):
			channeling.queue_free()
		if not is_inside_tree():
			_casting = false
			return
	if ability.projectile_speed > 0.0:
		var bolt: Node3D = _spawn(Ability.Phase.CASTING, from)
		if bolt:
			var flight: float = from.distance_to(to) / ability.projectile_speed
			var tween: Tween = create_tween()
			tween.tween_property(bolt, "global_position", to, flight)
			await tween.finished
			if is_instance_valid(bolt):
				bolt.queue_free()
		else:
			await get_tree().create_timer(from.distance_to(to) / ability.projectile_speed).timeout
	else:
		_spawn(Ability.Phase.CASTING, from)
	if is_inside_tree():
		_spawn(Ability.Phase.IMPACT, to)
	_casting = false


## An instance of [param phase]'s VFX at [param at], with its sound, under this node; null when the phase has no VFX.
func _spawn(phase: Ability.Phase, at: Vector3) -> Node3D:
	var stream: AudioStream = ability.get_sfx(phase)
	if stream:
		var audio: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		audio.name = PREVIEW + "Audio"
		audio.stream = stream
		add_child(audio)
		audio.global_position = at
		audio.play()
		audio.finished.connect(audio.queue_free)
		get_tree().create_timer(ability.fx_lifetime + 5.0).timeout.connect(audio.queue_free)
	var scene: PackedScene = ability.get_vfx(phase)
	if scene == null:
		return null
	var vfx: Node3D = scene.instantiate() as Node3D
	if vfx == null:
		return null
	vfx.name = PREVIEW + "Cast" + Ability.Phase.keys()[phase].capitalize()
	add_child(vfx)
	vfx.global_position = at
	if phase != Ability.Phase.CHANNELING:
		get_tree().create_timer(ability.fx_lifetime).timeout.connect(vfx.queue_free)
	return vfx


func _cast_forward() -> void:
	var library: AbilityLibrary = get_parent() as AbilityLibrary
	if library == null or library.test_caster == null or library.test_target == null:
		push_warning("AbilityEntry: set test_caster and test_target on the AbilityLibrary above this entry first.")
		return
	preview_cast(library.test_caster, library.test_target)


func _cast_back() -> void:
	var library: AbilityLibrary = get_parent() as AbilityLibrary
	if library == null or library.test_caster == null or library.test_target == null:
		push_warning("AbilityEntry: set test_caster and test_target on the AbilityLibrary above this entry first.")
		return
	preview_cast(library.test_target, library.test_caster)


## The node name for [param of]: its display name in PascalCase, or its id.
static func _entry_name(of: Ability) -> String:
	var base: String = of.display_name if not of.display_name.is_empty() else String(of.get_id())
	return base.to_pascal_case().validate_node_name()
