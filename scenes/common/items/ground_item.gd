@tool
class_name GroundItem
extends Area2D

@export var item: ItemData:
	set(v):
		item = v
		if is_node_ready():
			_update_sprite()

@export var pickup_radius: float = 8.0:
	set(v):
		pickup_radius = v
		if is_node_ready():
			_update_collision()

var _player_near: bool = false

func _ready():
	# Duplicate the shape so each instance gets its own copy
	if has_node("CollisionShape2D") and $CollisionShape2D.shape != null:
		$CollisionShape2D.shape = $CollisionShape2D.shape.duplicate()
	_update_sprite()
	_update_collision()
	if Engine.is_editor_hint():
		return
	add_to_group("interactable")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _update_sprite():
	if not has_node("Sprite2D"):
		return
	$Sprite2D.texture = item.get_world_texture() if item else null

func _update_collision():
	if not has_node("CollisionShape2D"):
		return
	var shape = $CollisionShape2D.shape
	if not (shape is CircleShape2D):
		return
	var own_shape = shape.duplicate() as CircleShape2D
	own_shape.radius = pickup_radius
	$CollisionShape2D.shape = own_shape

func _input(event: InputEvent):
	if Engine.is_editor_hint():
		return
	if _player_near and event.is_action_pressed("use") and Global.can_player_move:
		if Global.inventory_ui and Global.inventory_ui.pick_up(item):
			get_viewport().set_input_as_handled()
			queue_free()

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		_player_near = true

func _on_body_exited(body: Node2D):
	if body.is_in_group("player"):
		_player_near = false
