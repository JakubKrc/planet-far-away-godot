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

# Picked up before anything it happens to be lying on top of.
var interact_priority: int = 30

func _ready():
	_update_sprite()
	_update_collision()
	if Engine.is_editor_hint():
		return
	add_to_group("interactable")
	add_to_group("ground_item")

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
	# Own copy per instance: every ground item loaded from the scene shares one
	# shape resource, so setting the radius on one would resize all of them.
	var own_shape = shape.duplicate() as CircleShape2D
	own_shape.radius = pickup_radius
	$CollisionShape2D.shape = own_shape

func interact(_player):
	if Global.inventory_ui and Global.inventory_ui.pick_up(item):
		queue_free()
