@tool
class_name ItemData
extends Resource

const CELL = 16

@export var id: String = ""
@export var item_name: String = ""
@export var description: String = ""
@export var icon: Texture2D = null:          # inventory grid icon
	set(v):
		icon = v
		if icon != null and auto_size_from_icon:
			var sz = icon.get_size()
			grid_size = Vector2i(max(1, int(sz.x / CELL)), max(1, int(sz.y / CELL)))
		notify_property_list_changed()
@export var world_texture: Texture2D = null: # sprite on ground (falls back to icon if null)
	set(v):
		world_texture = v
		if world_texture != null and icon == null and auto_size_from_icon:
			var sz = world_texture.get_size()
			grid_size = Vector2i(max(1, int(sz.x / CELL)), max(1, int(sz.y / CELL)))
@export var auto_size_from_icon: bool = true # set grid_size automatically from icon dimensions
@export var grid_size: Vector2i = Vector2i(1, 1)
@export var is_wearable: bool = false        # can be put in equipment slots
@export var item_type: String = ""           # used to prevent duplicate slot types (e.g. "weapon")
@export var combine_with: Dictionary = {}    # { other_item_id: String -> result: ItemData }

func get_icon() -> Texture2D:
	return icon if icon else world_texture

func get_world_texture() -> Texture2D:
	return world_texture if world_texture else icon
