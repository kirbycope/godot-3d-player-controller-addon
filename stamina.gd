extends TextureProgressBar

@export var player: Player

@onready var timer: Timer = $Timer ## Used to hide the [TextureProgressBar] onace stamina has refilled


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	step = 0.01
	value = 100


## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Check if the player is sprinting
	if player.is_sprinting \
	# and the current value is above the minimum
	and value > min_value:
		show()
		# Decrease stamina when sprinting
		value = max(value - 20.0 * delta, min_value)

	# Check if the player is exhausted and not moving
	elif (player.is_exhausted and abs(player.velocity.length()) < 0.2) \
	# and the current value less than the maximum
	and value < max_value:
		# Regenerate stamina when exhausted and not moving
		value = min(value + 15.0 * delta, max_value)

	# Check if the player is not exhausted and not sprinting
	elif (not player.is_exhausted and not player.is_sprinting) \
	# and the current value less than the maximum
	and value < max_value:
		# Regenerate stamina when not exhausted and not sprinting
		value = min(value + 15.0 * delta, max_value)

	# Check if the player is exhausted but at full stamina
	elif player.is_exhausted and value >= max_value:
		# Remove exhaustion when at full stamina
		player.is_exhausted = false

	# Check if the the [TextureProgressBar] is still showing and the stamina is full
	if visible and value >= max_value \
	# and the timer is not already started
	and timer.is_stopped():
		timer.start()


## Called when the "full stamina" timer elapses.
func _on_timer_timeout() -> void:
	hide()
