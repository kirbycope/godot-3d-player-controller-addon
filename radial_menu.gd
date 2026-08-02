extends Control
class_name RadialMenu

@export var inner_radius: float = 64.0
@export var outer_radius: float = 200.0
@export var line_width: float = 4.0
@export var line_color: Color = Color.WHITE
@export var bg_color: Color = Color(0, 0, 0, 0.5)
@export var highlight_color: Color = Color(1, 1, 1, 0.3)
@export var equipped_color: Color = Color(1, 1, 1, 0.6)

@export var hold_threshold_ms: int = 200

var weapons: Array = []
var hovered_index: int = -1

@onready var inventory: Inventory = get_parent()
@onready var tooltip_label: Label = $TooltipLabel

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS

func is_keyboard_mouse() -> bool:
	if inventory and inventory.player and inventory.player.controls:
		return inventory.player.controls.current_input_type == inventory.player.controls.InputType.KEYBOARD_MOUSE
	return true

func is_menu_requested() -> bool:
	if inventory:
		var current_time = Time.get_ticks_msec()
		if inventory._last_weapon_press_pending and Input.is_action_pressed("last_weapon"):
			if current_time - inventory._last_weapon_press_time >= hold_threshold_ms:
				inventory._last_weapon_press_pending = false
				return true
		if inventory._next_weapon_press_pending and Input.is_action_pressed("next_weapon"):
			if current_time - inventory._next_weapon_press_time >= hold_threshold_ms:
				inventory._next_weapon_press_pending = false
				return true
	return false

func is_menu_held() -> bool:
	return Input.is_action_pressed("last_weapon") \
		or Input.is_action_pressed("next_weapon")

func _process(delta: float) -> void:
	if not visible:
		if is_menu_requested():
			show()
			if is_keyboard_mouse():
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
			if inventory and inventory.player and inventory.player.has_node("Crosshair"):
				inventory.player.get_node("Crosshair").hide()
			update_items()
	else:
		if is_menu_held():
			if is_keyboard_mouse():
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				# Calculate hovered index using mouse
				var mouse_pos = get_local_mouse_position()
				var center = size / 2.0
				var dist = mouse_pos.distance_to(center)
				var new_hovered = -1
				if dist >= inner_radius and dist <= outer_radius and weapons.size() > 0:
					var angle = rad_to_deg((mouse_pos - center).angle()) + 90.0
					if angle < 0:
						angle += 360.0
					var segment_angle = 360.0 / weapons.size()
					new_hovered = int(angle / segment_angle) % weapons.size()

				if new_hovered != hovered_index:
					hovered_index = new_hovered
					if tooltip_label:
						if hovered_index == -1 or hovered_index >= weapons.size():
							tooltip_label.text = ""
						else:
							var hovered_item = weapons[hovered_index]
							var text_name = "Unknown"
							if hovered_item is Dictionary:
								text_name = hovered_item.get("display_name", "Unarmed")
							else:
								if "display_name" in hovered_item and hovered_item.display_name != "":
									text_name = hovered_item.display_name
								elif "equipment_type" in hovered_item:
									text_name = Equipment.EquipmentType.keys()[hovered_item.equipment_type].capitalize()
							tooltip_label.text = text_name
					queue_redraw()
			else:
				Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
				# Calculate hovered index using R-stick
				var stick_vec = Input.get_vector("look_left", "look_right", "look_up", "look_down")
				if stick_vec.length() > 0.3 and weapons.size() > 0:
					var angle = rad_to_deg(stick_vec.angle()) + 90.0
					if angle < 0:
						angle += 360.0
					var segment_angle = 360.0 / weapons.size()
					var new_hovered = int(angle / segment_angle) % weapons.size()
					if new_hovered != hovered_index:
						hovered_index = new_hovered
						if tooltip_label:
							if hovered_index == -1 or hovered_index >= weapons.size():
								tooltip_label.text = ""
							else:
								var hovered_item = weapons[hovered_index]
								var text_name = "Unknown"
								if hovered_item is Dictionary:
									text_name = hovered_item.get("display_name", "Unarmed")
								else:
									if "display_name" in hovered_item and hovered_item.display_name != "":
										text_name = hovered_item.display_name
									elif "equipment_type" in hovered_item:
										text_name = Equipment.EquipmentType.keys()[hovered_item.equipment_type].capitalize()
								tooltip_label.text = text_name
						queue_redraw()
		else:
			hide()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			if inventory and inventory.player and inventory.player.has_node("Crosshair"):
				inventory.player.get_node("Crosshair").show()
			if hovered_index != -1 and weapons.size() > 0:
				equip_item(hovered_index)
			hovered_index = -1
			if tooltip_label:
				tooltip_label.text = ""
			weapons.clear()

func update_items() -> void:
	if not inventory:
		return
	
	var unarmed_dict = {
		"is_unarmed": true,
		"icon": load("res://addons/3d_player_controller/assets/game_icons/punch.svg"),
		"display_name": "Unarmed"
	}
	weapons = [unarmed_dict]
	weapons.append_array(inventory.get_all_weapons())
	queue_redraw()

func equip_item(index: int) -> void:
	var item = weapons[index]
	if item is Dictionary and item.get("is_unarmed"):
		inventory.unequip_all()
	else:
		inventory.equip_weapon(item)

func _draw() -> void:
	if weapons.size() == 0:
		return
	
	var center = size / 2.0
	var segment_angle = deg_to_rad(360.0 / weapons.size())
	var start_angle = - PI / 2.0
	
	for i in range(weapons.size()):
		var is_hovered = (i == hovered_index)
		var color = highlight_color if is_hovered else bg_color
		
		var points = PackedVector2Array()
		var num_points = max(16, int(64.0 / weapons.size()))
		
		# Draw inner arc
		for j in range(num_points + 1):
			var a = start_angle + i * segment_angle + j * segment_angle / num_points
			points.append(center + Vector2(cos(a), sin(a)) * inner_radius)
			
		# Draw outer arc
		for j in range(num_points, -1, -1):
			var a = start_angle + i * segment_angle + j * segment_angle / num_points
			points.append(center + Vector2(cos(a), sin(a)) * outer_radius)
			
		draw_polygon(points, PackedColorArray([color]))
		
		var is_equipped = false
		var item = weapons[i]
		if item is Dictionary and item.get("is_unarmed"):
			is_equipped = inventory.equipment.is_empty()
		elif item is Node3D:
			is_equipped = inventory.equipment.has(item)
			
		if is_equipped:
			var outer_points = PackedVector2Array()
			var split_radius = inner_radius + (outer_radius - inner_radius) * 0.9
			
			for j in range(num_points + 1):
				var a = start_angle + i * segment_angle + j * segment_angle / num_points
				outer_points.append(center + Vector2(cos(a), sin(a)) * split_radius)
				
			for j in range(num_points, -1, -1):
				var a = start_angle + i * segment_angle + j * segment_angle / num_points
				outer_points.append(center + Vector2(cos(a), sin(a)) * outer_radius)
				
			draw_polygon(outer_points, PackedColorArray([equipped_color]))
		
		
		# Draw separator line
		if weapons.size() > 1:
			var a1 = start_angle + i * segment_angle
			var p1_inner = center + Vector2(cos(a1), sin(a1)) * inner_radius
			var p1_outer = center + Vector2(cos(a1), sin(a1)) * outer_radius
			draw_line(p1_inner, p1_outer, line_color, line_width, true)
		
		# Draw Icon
		var item_icon = null
		if item is Dictionary:
			item_icon = item.get("icon")
		elif "icon" in item:
			item_icon = item.icon
			
		if item_icon:
			var mid_angle = start_angle + (i + 0.5) * segment_angle
			var icon_pos = center + Vector2(cos(mid_angle), sin(mid_angle)) * (inner_radius + outer_radius) / 2.0
			var icon_size = Vector2(64, 64)
			var rect = Rect2(icon_pos - icon_size / 2.0, icon_size)
			draw_texture_rect(item_icon, rect, false)
			
	# Draw outer circle
	draw_arc(center, outer_radius, 0, TAU, 64, line_color, line_width, true)
	# Draw inner circle
	draw_arc(center, inner_radius, 0, TAU, 32, line_color, line_width, true)
