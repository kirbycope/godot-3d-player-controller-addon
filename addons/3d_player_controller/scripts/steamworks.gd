extends Node
## The Steam session: initialises Steamworks and holds who you are and which lobby you are in.
##
## Register this as an autoload named [code]Steamworks[/code] and everything in the addon that wants
## Steam finds it at [code]/root/Steamworks[/code]. Nothing requires it: every caller looks it up with
## [method Node.get_node_or_null] and falls back to peer ids, so a project without Steam, or a web
## export, simply runs without it.
##
## Steam is only initialised on a desktop Forward+ build with the GodotSteam extension present and the
## client actually running. Where any of that is untrue the node stays in the tree with
## [member steam_id] at 0, which is what the callers read as "no Steam".

signal steam_ready ## Emitted once Steam is up and [member steam_id] and [member username] are filled.
signal steam_failed(reason: String) ## Steam is absent, not running, or refused to initialise.

var app_id: int = ProjectSettings.get_setting("steam/initialization/app_data/app_id", 480)
var steam_id: int = 0 ## The signed-in account, 0 when Steam is not running.
var username: String = "Player" ## The Steam persona name, unchanged when Steam is not running.
var lobby_id: int = 0 ## The lobby currently joined; the lobby manager writes this.


func _ready() -> void:
	# The extension has no web library, and Steam wants a desktop renderer.
	if OS.has_feature("web") or ProjectSettings.get_setting("rendering/renderer/rendering_method") != "forward_plus":
		return
	initialize()


## Brings Steamworks up and reads the account off it. Safe to call when Steam is not there; it reports
## through [signal steam_failed] rather than failing.
func initialize() -> void:
	if not Engine.has_singleton("Steam"):
		steam_failed.emit("The GodotSteam extension is not installed.")
		return
	var steam: Object = Engine.get_singleton("Steam")
	if not steam.isSteamRunning():
		steam_failed.emit("The Steam client is not running.")
		return
	var result: Dictionary = steam.steamInitEx(app_id, true)
	if result.get("status", -1) != steam.get("STEAM_API_INIT_RESULT_OK"):
		steam_failed.emit("Steam refused to initialise: %s" % result.get("verbal", ""))
		return
	steam_id = steam.getSteamID()
	username = steam.getPersonaName()
	steam_ready.emit()
