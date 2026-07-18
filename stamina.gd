extends TextureProgressBar

@export var player: Player
@export var drain_sprint: float = 20.0
@export var drain_paraglide: float = 12.0
@export var drain_climb: float = 5.0
@export var regen_rate: float = 15.0
@export var regen_rate_falling: float = 3.0

@onready var timer: Timer = $Timer ## Used to hide the [TextureProgressBar] onace stamina has refilled


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	step = 0.01
	value = 100


## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Check if the player is sprinting or actively moving while climbing
	var climbing_moving := player.is_climbing and player.velocity.length() > 0.1
	var climbing_sprint := climbing_moving and Input.is_action_pressed("sprint")
	if (player.is_sprinting or climbing_moving or player.is_paragliding) \
	# and the current value is above the minimum
	and value > min_value:
		show()
		# Sprinting or sprint-climbing drains fast; paragliding medium; climbing drains slowly
		var drain_rate := drain_sprint if (player.is_sprinting or climbing_sprint) else drain_paraglide if player.is_paragliding else drain_climb
		value = max(value - drain_rate * delta, min_value)
		if value <= min_value and (player.is_climbing or player.is_paragliding):
			player.is_exhausted = true

	# Check if the player is exhausted and falling — slow regen
	elif player.is_exhausted and player.is_falling \
	and value < max_value:
		value = min(value + regen_rate_falling * delta, max_value)

	# Check if the player is exhausted and not moving
	elif (player.is_exhausted and abs(player.velocity.length()) < 0.2) \
	# and the current value less than the maximum
	and value < max_value:
		# Regenerate stamina when exhausted and not moving
		value = min(value + regen_rate * delta, max_value)

	# Check if the player is not exhausted and not sprinting and not climbing and not paragliding
	elif (not player.is_exhausted and not player.is_sprinting and not player.is_climbing and not player.is_paragliding) \
	# and the current value less than the maximum
	and value < max_value:
		# Regenerate stamina when not exhausted and not sprinting
		value = min(value + regen_rate * delta, max_value)

	# Check if the player is exhausted but at full stamina
	elif player.is_exhausted and value >= max_value:
		# Remove exhaustion when at full stamina
		player.is_exhausted = false

	# Check if the the [TextureProgressBar] is still showing and the stamina is full
	if visible and value >= max_value \
	# and the timer is not already started
	and timer.is_stopped():
		timer.start()
	
	# Check if the player is flagged as exhausted but has regained some stamina — remove exhaustion
	elif player.is_exhausted and value > (max_value * 0.25):
		player.is_exhausted = false


## Called when the "full stamina" timer elapses.
func _on_timer_timeout() -> void:
	hide()
