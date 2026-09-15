class_name Recipe
extends Resource
## What a [CraftingStation] makes: [member ingredients] out of the bag, [member result] into it. A result that
## is [constant Item.Category.EQUIPMENT] with an [member Item.equipment_scene] goes on the skeleton the way a
## picked-up weapon does.

@export var title: String = ""
@export var ingredients: Dictionary[Item, int] = {}
@export var result: Item
@export var result_count: int = 1
@export var icon: Texture2D ## The station's list shows it; empty takes the result's.


## Whether [param inventory] holds every ingredient.
func can_craft(inventory: Inventory) -> bool:
	if inventory == null or result == null:
		return false
	for item: Item in ingredients:
		if inventory.count_of(item) < ingredients[item]:
			return false
	return true


## The ingredients as one line: "3 Wood, 2 Stone".
func describe_ingredients() -> String:
	var parts: PackedStringArray = []
	for item: Item in ingredients:
		parts.append("%d %s" % [ingredients[item], item.get_display_name()])
	return ", ".join(parts)
