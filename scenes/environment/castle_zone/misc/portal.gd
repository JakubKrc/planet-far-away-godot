extends Area2D

@export var door_name: String = "default_door"
@export_file var level_to_load: String = ""
@export var door_to_spam: String = ""

var need_to_be_exited_before_activating = false
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

func _on_body_entered(body):
	if(body.is_in_group('player') && !need_to_be_exited_before_activating):
		Global.main.load_level(level_to_load, door_to_spam);

func _on_body_exited(body):
	if(body.is_in_group('player') && need_to_be_exited_before_activating):
		need_to_be_exited_before_activating = false
