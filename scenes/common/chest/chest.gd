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

var _player_near: bool = false

func _ready():
	$Sprite2D.texture = chest_texture
	($CollisionShape2D.shape as RectangleShape2D).size = collision_size
	if Engine.is_editor_hint():
		return
	add_to_group("interactable")
	add_to_group("save")
	var inv = $InventoryComponent as InventoryComponent
	inv.cols = cols
	inv.rows = rows
	for item in starting_items:
		if item:
			var pos = inv.find_free_slot(item)
			if pos != Vector2i(-1, -1):
				inv.place(item, pos)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		_player_near = true

func _on_body_exited(body: Node2D):
	if body.is_in_group("player"):
		_player_near = false

func _input(event: InputEvent):
	if not _player_near or not event.is_action_pressed("use") or not Global.can_player_move:
		return
	var player = get_tree().get_first_node_in_group("player")
	if player and not player.is_on_floor():
		return
	var player_inv = player.get_node_or_null("InventoryComponent") as InventoryComponent
	if player_inv:
		get_viewport().set_input_as_handled()
		Global.inventory_ui.open(player_inv, $InventoryComponent)
