class_name Loading
extends CanvasLayer

var tips: Array[String] = [
	"Tip: Don't bother reading this, it's a waste of time.",
	"Tip: Press [Alt]+[F4] to rage quit!",
]
var _target_scene_path: String = ""
var _scene_properties: Dictionary = {}
var _scene_to_close: Node = null
var _activation_requested: bool = true
var _last_status: int = -1
var _load_started_at_msec: int = 0
var _dependency_paths: PackedStringArray = []
var _reported_dependency_paths: Dictionary = {}
var _cached_dependency_count: int = 0

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var tip: Label = $Tip
@onready var details: RichTextLabel = $Details


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	hide()
	tip.text = tips[randi() % tips.size()]


## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Return early if there's no target scene to load
	if _target_scene_path == "":
		return

	# Get the status of the threaded loading
	var progress: Array[float] = []
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(
		_target_scene_path,
		progress,
	)
	var progress_percent: int = roundi(progress[0] * 100.0) if not progress.is_empty() else 0
	progress_bar.value = progress_percent
	_report_newly_cached_dependencies()
	if status != _last_status:
		_append_detail(
			"Status: %s, activation requested: %s"
			% [_get_status_name(status), _activation_requested]
		)
		_last_status = status
	# Handle 100% progress
	if status == ResourceLoader.THREAD_LOAD_LOADED and _activation_requested:
		progress_bar.value = 100
		_complete()
	# Handle failure(s)
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_append_detail("Error loading scene: " + _target_scene_path)
		push_error("Error loading scene: " + _target_scene_path)
		_target_scene_path = ""
		hide()


## Starts loading a scene from the given path with optional properties to set on the scene.
## If activation is deferred, call activate() when the scene can be entered.
func start(
		path: String,
		properties: Dictionary = {},
		scene_to_close: Node = null,
		activate_when_loaded: bool = true,
) -> void:
	_target_scene_path = path
	_scene_properties = properties
	_scene_to_close = scene_to_close
	_activation_requested = activate_when_loaded
	_last_status = -1
	_load_started_at_msec = Time.get_ticks_msec()
	details.clear()
	_prepare_dependency_tracking(path)
	show()
	progress_bar.value = 0
	_append_detail(
		"Requesting %s, activate when loaded: %s"
		% [_target_scene_path, activate_when_loaded]
	)
	var request_error: Error = ResourceLoader.load_threaded_request(_target_scene_path)
	_append_detail("Request result: " + error_string(request_error))


## Allows a deferred scene load to enter the loaded scene.
func activate() -> void:
	_append_detail("Activation requested for " + _target_scene_path)
	_activation_requested = true


## Completes the loading process by instantiating the scene and applying properties.
func _complete() -> void:
	_append_detail("Retrieving loaded resource: " + _target_scene_path)
	var scene_resource: PackedScene = ResourceLoader.load_threaded_get(
		_target_scene_path
	) as PackedScene
	if scene_resource:
		_append_detail("Instantiating scene")
		var scene: Node = scene_resource.instantiate()
		for key: Variant in _scene_properties:
			scene.set(key, _scene_properties[key])

		_append_detail("Instantiation complete; adding scene to tree")
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		_append_detail("Current scene changed to " + scene.scene_file_path)
		if _scene_to_close:
			_scene_to_close.queue_free()
	else:
		push_error("[Loading] Loaded resource is not a PackedScene: " + _target_scene_path)
	_target_scene_path = ""


func _prepare_dependency_tracking(path: String) -> void:
	_dependency_paths.clear()
	_reported_dependency_paths.clear()
	_cached_dependency_count = 0
	for dependency: String in ResourceLoader.get_dependencies(path):
		var dependency_parts: PackedStringArray = dependency.split("::")
		var dependency_path: String = dependency_parts[dependency_parts.size() - 1]
		if not dependency_path.begins_with("res://"):
			continue
		_dependency_paths.append(dependency_path)
		if ResourceLoader.has_cached(dependency_path):
			_reported_dependency_paths[dependency_path] = true
			_cached_dependency_count += 1
	_append_detail(
		"Tracking %d direct dependencies; %d already cached"
		% [_dependency_paths.size(), _cached_dependency_count]
	)
	_append_detail(
		"Godot exposes completed cached dependencies, not the dependency currently processing"
	)


func _report_newly_cached_dependencies() -> void:
	for dependency_path: String in _dependency_paths:
		if _reported_dependency_paths.has(dependency_path):
			continue
		if not ResourceLoader.has_cached(dependency_path):
			continue
		_reported_dependency_paths[dependency_path] = true
		_cached_dependency_count += 1
		_append_detail(
			"Dependency cached (%d/%d): %s"
			% [_cached_dependency_count, _dependency_paths.size(), dependency_path]
		)


func _append_detail(message: String) -> void:
	details.append_text(_get_log_prefix() + message + "\n")


func _get_log_prefix() -> String:
	var elapsed_msec: int = Time.get_ticks_msec() - _load_started_at_msec
	return "[Loading +%d ms] " % elapsed_msec


func _get_status_name(status: ResourceLoader.ThreadLoadStatus) -> String:
	match status:
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			return "INVALID_RESOURCE"
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return "IN_PROGRESS"
		ResourceLoader.THREAD_LOAD_FAILED:
			return "FAILED"
		ResourceLoader.THREAD_LOAD_LOADED:
			return "LOADED"
	return "UNKNOWN"
