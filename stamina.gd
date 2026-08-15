extends TextureProgressBar

@export var player: Player
@export var drain_sprint: float = 20.0
@export var drain_paraglide: float = 12.0
@export var drain_climb: float = 5.0
@export var drain_swim: float = 8.0
@export var sprint_multiplier: float = 1.5 ## Drain multiplier when sprinting while climbing/swimming
@export var regen_rate: float = 15.0
@export var regen_rate_falling: float = 3.0
@export var hide_delay: float = 1.0 ## Delay in seconds before hiding the stamina bar after refilling

var stamina: float = 100.0:
	set(val):
		stamina = clampf(val, min_value, max_value)
		value = stamina

@onready var timer: Timer = $Timer ## Used to hide the [TextureProgressBar] once stamina has refilled


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	hide()
	set_process(is_multiplayer_authority())
	set_physics_process(is_multiplayer_authority())
	set_process_input(is_multiplayer_authority())
	exp_edit = false
	step = 0.01
	stamina = max_value
	timer.one_shot = true
	timer.wait_time = hide_delay
	if not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)


## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not player.enable_stamina:
		stamina = max_value
		player.is_exhausted = false
		hide()
		return

	# Determine which stamina-draining activity (if any) the player is doing
	var climbing_moving: bool = player.is_climbing and player.velocity.length() > 0.1
	var swimming_moving: bool = player.is_swimming and player.velocity.length() > 0.1
	# Sprinting in place costs nothing — drain requires actual movement input
	var sprinting_on_land: bool = player.is_sprinting \
			and player.player_input.motion.length() > 0.0 \
			and not player.is_climbing \
			and not player.is_swimming \
			and not player.is_paragliding
	var draining: bool = sprinting_on_land or climbing_moving or swimming_moving \
			or player.is_paragliding

	# Drain stamina while doing a draining activity
	if draining and not player.is_exhausted and stamina > min_value:
		show()
		if not timer.is_stopped():
			timer.stop()
		var drain_rate: float = drain_sprint
		if climbing_moving:
			drain_rate = drain_climb * (sprint_multiplier if player.is_sprinting else 1.0)
		elif swimming_moving:
			drain_rate = drain_swim * (sprint_multiplier if player.is_sprinting else 1.0)
		elif player.is_paragliding:
			drain_rate = drain_paraglide
		stamina -= drain_rate * delta
		# Flag the player as exhausted once stamina is fully depleted
		if stamina <= min_value:
			player.is_exhausted = true

	# Regenerate stamina when not draining (slowly while falling or in water)
	# Idle climbing holds stamina instead of regenerating (BotW); hanging still regens
	elif stamina < max_value and not player.is_climbing:
		show()
		if not timer.is_stopped():
			timer.stop()
		var current_regen_rate: float = regen_rate
		if player.is_falling or player.is_swimming:
			current_regen_rate = regen_rate_falling
		stamina += current_regen_rate * delta

	# Exhaustion clears only once stamina has fully refilled (BotW style)
	if player.is_exhausted and stamina >= max_value:
		player.is_exhausted = false

	# Check if the [TextureProgressBar] is still showing and the stamina is full
	if visible and stamina >= max_value and timer.is_stopped():
		timer.start()


## Called when the "full stamina" timer elapses.
func _on_timer_timeout() -> void:
	hide()
