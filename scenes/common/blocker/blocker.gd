@tool
extends StaticBody2D

@export var door_texture: Texture2D:
	set(v):
		door_texture = v
		if is_node_ready():
			$Sprite2D.texture = v

@export var collision_size: Vector2 = Vector2(16, 32):
	set(v):
		collision_size = v
		if is_node_ready():
			($CollisionShape2D.shape as RectangleShape2D).size = v

@export var start_open: bool = false

func _ready():
	$Sprite2D.texture = door_texture
	($CollisionShape2D.shape as RectangleShape2D).size = collision_size
	if Engine.is_editor_hint():
		return
	add_to_group("save")
	if start_open:
		Global.main.disable_node(self)

func _on_platform_running(_arg = ""):
	Global.main.disable_node(self)

func _on_platform_disabled(_arg = ""):
	Global.main.enable_node(self)
