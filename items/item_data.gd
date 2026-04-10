class_name ItemData
extends Resource

@export var id: String = ""
@export var item_name: String = ""
@export var description: String = ""
@export var icon: Texture2D = null
@export var grid_size: Vector2i = Vector2i(1, 1)
@export var item_type: String = ""  # "" = not equippable; "weapon", "armor", etc.
@export var combine_with: Dictionary = {}  # { other_item_id: String -> result: ItemData }
