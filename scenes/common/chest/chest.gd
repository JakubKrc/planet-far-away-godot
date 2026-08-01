@tool
class_name Chest
extends Area2D

@export var chest_texture: Texture2D:
	set(v):
		chest_texture = v
		if is_node_ready():
			$Sprite2D.texture = v

@export var collision_size: Vector2 = Vector2(16, 16):
	set(v):
		collision_size = v
		if is_node_ready():
			($CollisionShape2D.shape as RectangleShape2D).size = v

@export var cols: int = 8
@export var rows: int = 3
@export var starting_items: Array[ItemData] = []

var interact_priority: int = 20

func _ready():
	$Sprite2D.texture = chest_texture
	($CollisionShape2D.shape as RectangleShape2D).size = collision_size
	if Engine.is_editor_hint():
		return
	add_to_group("interactable")
	add_to_group("save")
	# The component built its grid at the default size during its own _ready(),
	# so it has to be rebuilt at the chest's size before anything is placed.
	var inv = $InventoryComponent as InventoryComponent
	inv.resize_grid(cols, rows)
	inv.add_starting_items(starting_items)

# Not openable mid-jump, so the icon stays hidden until the player lands.
func can_interact_with(player) -> bool:
	return player.is_on_floor()

func interact(player):
	var player_inv = player.get_node_or_null("InventoryComponent") as InventoryComponent
	if player_inv:
		Global.inventory_ui.open(player_inv, $InventoryComponent)
