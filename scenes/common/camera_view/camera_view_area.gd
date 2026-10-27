# A viewpoint: while the player stands inside, the camera slowly pulls back and
# leans toward `view_offset`, `covers` fade away and `shows` fade in; all of it
# eases back when they leave. A cover hides a place until you get there; a shown
# layer appears only while you are here (the building's front, seen from outside).
extends Area2D

@export var zoom: float = 0.7          # below 1 shows more of the world
@export var view_offset: Vector2 = Vector2(-96, -24)
@export var seconds: float = 1.2
@export var covers: Array[NodePath] = []
@export var shows: Array[NodePath] = []
@export var cover_fade_seconds: float = 0.5

var _active: bool = false
var _tween: Tween

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# Set the starting state here, not in the scene, so the layers can stay fully
	# visible (and editable) in the editor whatever state they were saved in.
	_set_start_state(covers, 1.0)
	_set_start_state(shows, 0.0)

func _set_start_state(paths: Array[NodePath], alpha: float):
	for path in paths:
		var node = get_node_or_null(path)
		if node == null:
			continue
		node.visible = true
		node.modulate.a = alpha

func _on_body_entered(body: Node):
	if body == Global.controlled_char:
		_active = true
		_ease_camera(Vector2(zoom, zoom), view_offset)
		_fade(covers, 0.0)
		_fade(shows, 1.0)

func _on_body_exited(body: Node):
	if body == Global.controlled_char:
		_active = false
		_ease_camera(Vector2.ONE, Vector2.ZERO)
		_fade(covers, 1.0)
		_fade(shows, 0.0)

# Leaving the level while still inside must not leave the camera zoomed out.
func _exit_tree():
	if _active and Global.camera:
		Global.camera.zoom = Vector2.ONE
		Global.camera.offset = Vector2.ZERO

func is_active() -> bool:
	return _active

func _fade(paths: Array[NodePath], alpha: float):
	for path in paths:
		var node = get_node_or_null(path)
		if node == null:
			push_warning("%s: nothing at %s" % [name, path])
			continue
		var fade = create_tween()
		fade.tween_property(node, "modulate:a", alpha, cover_fade_seconds)

func _ease_camera(target_zoom: Vector2, target_offset: Vector2):
	if Global.camera == null:
		return
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(Global.camera, "zoom", target_zoom, seconds)
	_tween.tween_property(Global.camera, "offset", target_offset, seconds)
