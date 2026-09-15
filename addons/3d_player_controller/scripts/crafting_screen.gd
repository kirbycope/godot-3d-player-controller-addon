class_name CraftingScreen
extends PlayerMenuLayer
## The list a [CraftingStation] opens: one row per recipe with what it costs, greyed while the bag cannot pay,
## Craft on a press. Closes on the "start" action like the other menus, or its Close button.

@export var rows: VBoxContainer
@export var title_label: Label
@export var close_button: Button

var station: CraftingStation = null

var _buttons: Array[Button] = []


func _ready() -> void:
	super()
	add_to_group(&"CraftingScreen")
	visible = false
	if close_button and not close_button.pressed.is_connected(hide_menu):
		close_button.pressed.connect(hide_menu)


## Fills the list with [param at]'s recipes for [param who] and shows it.
func open_for(who: Player, at: CraftingStation) -> void:
	player = who
	station = at
	if title_label:
		title_label.text = at.station_name
	_rebuild()
	show_menu()
	if _buttons.size() > 0:
		_buttons[0].grab_focus()


## Makes the recipe at [param index] in the open station's list; the row refreshes with what is left.
func craft_index(index: int) -> bool:
	if station == null or index < 0 or index >= station.recipes.size():
		return false
	var made: bool = station.craft(player, station.recipes[index])
	_refresh()
	return made


func _rebuild() -> void:
	for button: Button in _buttons:
		button.queue_free()
	_buttons.clear()
	if rows == null or station == null:
		return
	for i: int in station.recipes.size():
		var recipe: Recipe = station.recipes[i]
		var button: Button = Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.icon = recipe.icon if recipe.icon else (recipe.result.icon if recipe.result else null)
		button.expand_icon = true
		button.custom_minimum_size = Vector2(0.0, 36.0)
		button.pressed.connect(craft_index.bind(i))
		rows.add_child(button)
		_buttons.append(button)
	_refresh()


func _refresh() -> void:
	if station == null:
		return
	for i: int in _buttons.size():
		var recipe: Recipe = station.recipes[i]
		var name_text: String = recipe.title if not recipe.title.is_empty() else (recipe.result.get_display_name() if recipe.result else "?")
		_buttons[i].text = "%s    (%s)" % [name_text, recipe.describe_ingredients()]
		_buttons[i].disabled = player == null or not recipe.can_craft(player.inventory)
