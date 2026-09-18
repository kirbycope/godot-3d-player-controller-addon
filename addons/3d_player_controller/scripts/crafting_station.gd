class_name CraftingStation
extends Node3D
## A workbench, a campfire, an anvil: walk up and the Action button reads [member prompt_label]; Action opens the
## [member crafting_screen] with this station's [member recipes]. [method craft] does the making, which the screen
## and a script share: the ingredients leave the bag, the result arrives, equipment goes straight on.

signal crafted(by: Player, recipe: Recipe)

@export var recipes: Array[Recipe] = []
@export var prompt_label: String = "Craft"
@export var station_name: String = "Workbench"
@export var crafting_screen: CraftingScreen ## The menu to open; the first in the "CraftingScreen" group when empty.

@onready var action_prompt: ActionPrompt = $ActionPrompt


func _ready() -> void:
	if crafting_screen == null:
		crafting_screen = get_tree().get_first_node_in_group(&"CraftingScreen") as CraftingScreen


## Opens the screen for [param who].
func open(who: Player) -> bool:
	if who == null or crafting_screen == null:
		return false
	crafting_screen.open_for(who, self)
	return true


## Makes [param recipe] for [param who]: false when the bag lacks something.
func craft(who: Player, recipe: Recipe) -> bool:
	if who == null or who.inventory == null or recipe == null or not recipe.can_craft(who.inventory):
		return false
	for item: Item in recipe.ingredients:
		who.inventory.remove_item(item, recipe.ingredients[item])
	if recipe.result.category == Item.Category.EQUIPMENT and recipe.result.equipment_scene:
		who.inventory.add_equipment_scene(recipe.result.equipment_scene)
	else:
		who.inventory.add_item(recipe.result, recipe.result_count)
	crafted.emit(who, recipe)
	return true


## Called by [Camera] when this is the one thing the action button would act on.
func display_menu(who: Player) -> void:
	action_prompt.show_for(who.controls, prompt_label)


## Called by [Camera] when it is not.
func hide_menu() -> void:
	for who: Node in get_tree().get_nodes_in_group(&"Player"):
		if who is Player and (who as Player).controls:
			action_prompt.hide_for((who as Player).controls)
	action_prompt.hide()


## The Camera's Action hook: open the screen for whoever pressed it.
func equip(who: Player) -> void:
	open(who)
