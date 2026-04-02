extends Area2D

@export var damage: int = 10
@export var damage_interval: float = 0.5 
@export var show_animation: String = "fire_damage"
@export var collison_shape: CollisionShape2D

#@onready var visual_template = $Visual
@export var visual_scene: PackedScene

#@onready var anim = $AnimationPlayer
#@onready var sprite = $Sprite2D

var damage_timer = Timer.new()
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
		if is_instance_valid(body):
			visuals[body].global_position = body.get_node("CollisionShape2D").global_position + Vector2(0, body.get_node("CollisionShape2D").shape.size.y/2)
	
func _on_damage_tick():
	for player in players_in_area:
		player.health-=damage

func _on_body_entered(body):

	#if body.is_in_group("player"):
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
	
	var visual = visual_scene.instantiate()
	add_child(visual)
	visual.visible = true
	visual.name = "Visual_" + str(body.get_instance_id())

	visuals[body] = visual

	#var anim: AnimationPlayer = visuals[body].get_node("AnimationPlayer")
	#anim.call_deferred("play", show_animation)
	
	var anim_sprite: AnimatedSprite2D = visual.get_node("AnimatedSprite2D")
	anim_sprite.play(show_animation)
	
	if players_in_area.size() == 1:
		damage_timer.start()

func _on_body_exited(body):
	if body in players_in_area:
		players_in_area.erase(body)

	if visuals.has(body):
		visuals[body].queue_free()
		visuals.erase(body)

	if players_in_area.is_empty():
		damage_timer.stop()
