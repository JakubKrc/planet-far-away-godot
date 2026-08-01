extends Area2D

@export var damage: int = 10
@export var damage_interval: float = 0.5
@export var show_animation: String = "fire_damage"
@export var collison_shape: CollisionShape2D
# Limits who this area hurts. Empty means anything that has health.
@export var damage_group: String = ""

#@onready var visual_template = $Visual
@export var visual_scene: PackedScene

#@onready var anim = $AnimationPlayer
#@onready var sprite = $Sprite2D

var damage_timer: Timer = null
var players_in_area := []
var visuals := {}

func _ready():
	self.body_entered.connect(_on_body_entered)
	self.body_exited.connect(_on_body_exited)
	
	damage_timer = Timer.new()
	damage_timer.wait_time = damage_interval
	damage_timer.one_shot = false
	damage_timer.timeout.connect(_on_damage_tick)
	add_child(damage_timer)
	
func _physics_process(_delta):
	for body in visuals.keys():
		if not is_instance_valid(body):
			_forget_body(body)
			continue
		visuals[body].global_position = _feet_position(body)

# Bottom-centre of the body's collider, falling back to its own origin for
# bodies with no collider or a non-rectangular one.
func _feet_position(body) -> Vector2:
	var col = body.get_node_or_null("CollisionShape2D")
	if col == null or not (col.shape is RectangleShape2D):
		return body.global_position
	return col.global_position + Vector2(0, (col.shape as RectangleShape2D).size.y / 2.0)
	
# Only bodies that actually carry health can be hurt, so scenery and projectiles
# passing through a hazard are ignored instead of erroring on a missing field.
func _can_be_damaged(body) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	if damage_group != "" and not body.is_in_group(damage_group):
		return false
	return "health" in body

func _on_damage_tick():
	# Iterate a copy: a body can die and be removed from the list mid-tick.
	for body in players_in_area.duplicate():
		if not is_instance_valid(body):
			players_in_area.erase(body)
			continue
		body.health -= damage
	if players_in_area.is_empty():
		damage_timer.stop()

func _on_body_entered(body):

	if not _can_be_damaged(body):
		return

	if body in players_in_area:
		return

	players_in_area.append(body)

	#var visual = visual_template.duplicate()
	#add_child(visual)
#
	#visuals[body] = visual
	#visuals[body].visible = true
	#var anim: AnimationPlayer = visuals[body].get_node("AnimationPlayer")
	#anim.play(show_animation)
	
	if visual_scene:
		var visual = visual_scene.instantiate()
		add_child(visual)
		visual.visible = true
		visual.name = "Visual_" + str(body.get_instance_id())
		visuals[body] = visual
		var anim_sprite = visual.get_node_or_null("AnimatedSprite2D")
		if anim_sprite:
			anim_sprite.play(show_animation)

	if players_in_area.size() == 1:
		damage_timer.start()

func _on_body_exited(body):
	_forget_body(body)

# Drops all tracking for a body, whether it walked out or was freed while inside.
func _forget_body(body):
	players_in_area.erase(body)

	if visuals.has(body):
		if is_instance_valid(visuals[body]):
			visuals[body].queue_free()
		visuals.erase(body)

	if players_in_area.is_empty():
		damage_timer.stop()
