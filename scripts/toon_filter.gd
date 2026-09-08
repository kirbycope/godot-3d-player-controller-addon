class_name ToonFilter
extends MeshInstance3D
## Toon shading for the Player's camera, in three looks. NEWSPAPER is this full-screen quad with a spatial
## post-process shader that posterises the opaque scene into a few luminance bands and inks outlines where the depth
## buffer jumps; it reads only the screen and depth textures, so it runs in every renderer, and it is drawn in the 3D
## pass, so every CanvasLayer (the HUD, the menus) sits above it. CEL is a [CelCompositorEffect] on the camera's
## [member Camera3D.compositor]: hard light bands and bold ink from depth and normal discontinuities, Forward+ only.
## BINBUN is not a screen pass at all: every opaque [BaseMaterial3D] surface in the tree is overridden with Binbun's
## stylized shader ([member binbun_material]) wearing the surface's own albedo texture and colour, so light is stepped
## per object with a rim and a tinted shadow; shader materials (water, grass, the sky, VFX) and transparent surfaces
## keep their own, and meshes added while it is on get it too. Purely local: a video setting kept in
## [PlayerSettingsResource], never replicated. A camera compositor replaces the [WorldEnvironment]'s, so CEL copies
## that one's effects in ahead of its own and hands the view back to it when it leaves. The "toggle_toon" action
## ([F6]) cycles Off, Newspaper, Cel, Binbun (Cel skipped off Forward+); the Video settings' "Toon shading" option
## picks one directly.

signal toggled(enabled: bool) ## The filter went on or off, by the key or the setting.
signal mode_changed(mode: Mode) ## The look changed, by the key or the setting.

enum Mode { OFF, NEWSPAPER, CEL, BINBUN }

const FORWARD_PLUS: String = "forward_plus"

@export var mode: Mode = Mode.OFF: ## The current look; the saved setting overrides this at start.
	set = set_mode
@export var binbun_material: ShaderMaterial = preload("res://addons/3d_player_controller/resources/binbun_toon.tres") ## The BINBUN template; each surface gets a copy carrying its own albedo.

var enabled: bool: ## True in any mode but OFF; setting it picks NEWSPAPER or OFF.
	get:
		return mode != Mode.OFF
	set(value):
		set_mode(Mode.NEWSPAPER if value else Mode.OFF)

var compositor: Compositor ## The compositor CEL puts on the camera, the world's effects plus the cel one; null in the other modes.

var _binbun_originals: Dictionary = {} ## Instance id of each overridden MeshInstance3D to its surface overrides from before.
var _binbun_cache: Dictionary = {} ## Albedo texture and colour key to the BINBUN material made for it; one per look, not per surface.


func _ready() -> void:
	set_process_unhandled_input(is_multiplayer_authority())
	set_mode(PlayerSettingsResource.load_or_create().toon_mode as Mode)


func _exit_tree() -> void:
	_restore_binbun()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_toon"):
		cycle()
		get_viewport().set_input_as_handled()


## The renderer in use; overridden by tests to cover both cycles headless.
func _rendering_method() -> String:
	return RenderingServer.get_current_rendering_method()


## CEL needs the Forward+ compositor's normal-roughness buffer.
func is_cel_available() -> bool:
	return _rendering_method() == FORWARD_PLUS


## Shows the quad for NEWSPAPER, puts the [CelCompositorEffect] on the camera for CEL, overrides the tree's materials
## for BINBUN and undoes each otherwise. Asking for CEL where it is not available gives NEWSPAPER. Does not save; see
## [method cycle] and the Video settings.
func set_mode(value: Mode) -> void:
	if value == Mode.CEL and not is_cel_available():
		value = Mode.NEWSPAPER
	mode = value
	visible = mode == Mode.NEWSPAPER
	_apply_compositor()
	_apply_binbun()
	toggled.emit(enabled)
	mode_changed.emit(mode)


## Steps to the next look, skipping CEL off Forward+, and saves the choice with the other video settings.
func cycle() -> void:
	var next: Mode = ((mode + 1) % Mode.size()) as Mode
	if next == Mode.CEL and not is_cel_available():
		next = Mode.BINBUN
	set_mode(next)
	var settings: PlayerSettingsResource = PlayerSettingsResource.load_or_create()
	settings.toon_mode = mode
	settings.save()


## Flips between OFF and NEWSPAPER and saves; kept for callers of the old two-state filter.
func toggle() -> void:
	set_mode(Mode.OFF if enabled else Mode.NEWSPAPER)
	var settings: PlayerSettingsResource = PlayerSettingsResource.load_or_create()
	settings.toon_mode = mode
	settings.save()


func _apply_compositor() -> void:
	var camera: Camera3D = get_parent() as Camera3D
	if not is_instance_valid(camera):
		return
	if mode == Mode.CEL:
		if compositor == null:
			compositor = Compositor.new()
			var effects: Array[CompositorEffect] = _world_effects()
			effects.append(CelCompositorEffect.new())
			compositor.compositor_effects = effects
		camera.compositor = compositor
	elif compositor != null:
		if camera.compositor == compositor:
			camera.compositor = null
		compositor = null # Drops the cel effect, which frees its shader; the world's effects live on in its compositor


## The effects of the first [WorldEnvironment]'s compositor (the volumetric clouds on Forward+), which a camera
## compositor would otherwise replace. Copied, not moved: the WorldEnvironment keeps its own.
func _world_effects() -> Array[CompositorEffect]:
	var effects: Array[CompositorEffect] = []
	if not is_inside_tree():
		return effects
	var environments: Array[Node] = get_tree().root.find_children("*", "WorldEnvironment", true, false)
	if environments.is_empty():
		return effects
	var environment: WorldEnvironment = environments[0] as WorldEnvironment
	if environment.compositor != null:
		effects.append_array(environment.compositor.compositor_effects)
	return effects


## BINBUN overrides every MeshInstance3D in the tree now and, through the tree's node_added, every one that arrives
## while it is on; any other mode puts the originals back.
func _apply_binbun() -> void:
	if not is_inside_tree():
		return
	var tree: SceneTree = get_tree()
	if mode == Mode.BINBUN:
		if not tree.node_added.is_connected(_on_node_added):
			tree.node_added.connect(_on_node_added)
		for node: Node in tree.root.find_children("*", "MeshInstance3D", true, false):
			_override_mesh(node as MeshInstance3D)
	else:
		if tree.node_added.is_connected(_on_node_added):
			tree.node_added.disconnect(_on_node_added)
		_restore_binbun()


## Deferred so a mesh set right after add_child is seen too.
func _on_node_added(node: Node) -> void:
	if node is MeshInstance3D:
		_override_mesh.call_deferred(node)


## Gives each opaque BaseMaterial3D surface of [param mesh_instance] the Binbun look; a mesh with a whole-mesh
## material_override, a ShaderMaterial surface or a transparent one is left as it is.
func _override_mesh(mesh_instance: MeshInstance3D) -> void:
	if mode != Mode.BINBUN or not is_instance_valid(mesh_instance) or mesh_instance == self:
		return
	if mesh_instance.mesh == null or mesh_instance.material_override != null or _binbun_originals.has(mesh_instance.get_instance_id()):
		return
	var originals: Array[Material] = []
	var changed: bool = false
	for surface: int in mesh_instance.mesh.get_surface_count():
		originals.append(mesh_instance.get_surface_override_material(surface))
		var base: BaseMaterial3D = mesh_instance.get_active_material(surface) as BaseMaterial3D
		if base == null or base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue
		mesh_instance.set_surface_override_material(surface, _binbun_material_for(base))
		changed = true
	if changed:
		_binbun_originals[mesh_instance.get_instance_id()] = originals


## The template wearing [param base]'s albedo texture and colour, shared by every surface with the same pair.
func _binbun_material_for(base: BaseMaterial3D) -> ShaderMaterial:
	var texture_id: int = base.albedo_texture.get_instance_id() if base.albedo_texture != null else 0
	var key: String = "%d|%s" % [texture_id, base.albedo_color.to_html()]
	if _binbun_cache.has(key):
		return _binbun_cache[key]
	var material: ShaderMaterial = binbun_material.duplicate() as ShaderMaterial
	material.set_shader_parameter(&"albedo_texture", base.albedo_texture)
	material.set_shader_parameter(&"albedo_color", base.albedo_color)
	_binbun_cache[key] = material
	return material


func _restore_binbun() -> void:
	for id: int in _binbun_originals:
		var mesh_instance: MeshInstance3D = instance_from_id(id) as MeshInstance3D
		if not is_instance_valid(mesh_instance):
			continue
		var originals: Array = _binbun_originals[id]
		for surface: int in mini(originals.size(), mesh_instance.get_surface_override_material_count()):
			mesh_instance.set_surface_override_material(surface, originals[surface])
	_binbun_originals.clear()
	_binbun_cache.clear()
