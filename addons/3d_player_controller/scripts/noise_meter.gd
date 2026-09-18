@tool
class_name NoiseMeter
extends Control
## The noise readout, after Breath of the Wild's: a round dark badge with a line across the middle that
## answers how much noise the Player is making.
##
## Silent, it is a flat line. As [member PlayerNoise.level] rises the line breaks into a waveform, taller and
## busier the louder it gets, so the shape says at a glance whether a sneak is working. The badge and the line
## keep the colours the placeholder was drawn with.

@export var noise: PlayerNoise: ## Whose noise to draw; the first Player's when empty.
	set(value):
		if noise and noise.level_changed.is_connected(_on_level_changed):
			noise.level_changed.disconnect(_on_level_changed)
		noise = value
		if noise and not noise.level_changed.is_connected(_on_level_changed):
			noise.level_changed.connect(_on_level_changed)

@export var line_color: Color = Color(0.5294118, 0.33333334, 0.43529412) ## The placeholder's mauve.
@export var line_thickness: float = 2.0
@export var quiet_thickness: float = 2.0 ## The flat line's height, which it keeps when silent.
@export var amplitude: float = 11.0 ## How far the waveform swings at a reading of 1.
@export var waves: float = 3.0 ## Peaks across the badge at a reading of 1; a louder noise is busier as well as taller.
@export var speed: float = 9.0 ## How fast the waveform travels, so a loud reading moves rather than sitting still.
@export var points: int = 33 ## Samples across the width; enough for a smooth line on a 36px badge.

var level: float = 0.0 ## What is being drawn, smoothed by [PlayerNoise] before it arrives here.

var _phase: float = 0.0


func _ready() -> void:
	if noise == null and not Engine.is_editor_hint():
		var player: Player = get_tree().get_first_node_in_group(&"Player") as Player
		if player:
			noise = player.get_node_or_null(^"PlayerNoise") as PlayerNoise
	set_process(true)


func _process(delta: float) -> void:
	# A flat line has nothing to animate, so a silent meter costs a redraw only while it is settling
	if level <= 0.001 and is_equal_approx(_phase, 0.0):
		return
	_phase = fposmod(_phase + delta * speed * maxf(level, 0.1), TAU)
	queue_redraw()


func _on_level_changed(value: float) -> void:
	level = clampf(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var width: float = size.x
	var middle: float = size.y * 0.5
	if width <= 0.0:
		return
	if level <= 0.001:
		# Flat: the placeholder's own line, a bar across the middle
		draw_rect(Rect2(0.0, middle - quiet_thickness * 0.5, width, quiet_thickness), line_color)
		return
	var swing: float = amplitude * level
	var cycles: float = maxf(waves * level, 0.5)
	var line: PackedVector2Array = []
	for i: int in points:
		var along: float = float(i) / float(points - 1)
		# Tapered at both ends, so the wave sits inside the badge instead of being clipped by it
		var taper: float = sin(along * PI)
		var y: float = middle + sin(along * TAU * cycles + _phase) * swing * taper
		line.append(Vector2(along * width, y))
	draw_polyline(line, line_color, line_thickness, true)
