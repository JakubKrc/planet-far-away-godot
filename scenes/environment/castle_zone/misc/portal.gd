extends Area2D

@export var door_name: String = "portal_1"
@export_file var level_to_load: String = ""
@export var door_to_spam: String = ""
@export var need_to_interact: bool = true
@export var direction_vector: Vector2 = Vector2.RIGHT

var need_to_be_exited_before_activating = false
var player_inside: bool = false
# Called when the node enters the scene tree for the first time. test22
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass
	
func _input(event):
	if need_to_interact and event.is_action_pressed("use") and Global.can_player_move and player_inside:
		Global.main.load_level(level_to_load, door_to_spam);

func _on_body_entered(body):
	player_inside = true
	
	if need_to_interact:
		return
		
	if(body.is_in_group('player') && !need_to_be_exited_before_activating):
		Global.main.load_level(level_to_load, door_to_spam);
		

func _on_body_exited(body):
	player_inside = false

	if need_to_interact:
		return
		
	if(body.is_in_group('player') && need_to_be_exited_before_activating):
		need_to_be_exited_before_activating = false
	
