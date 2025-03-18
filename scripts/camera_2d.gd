extends Camera2D

func _ready():
	Global.camera = self

func _process(_delta):
	if (Global.controlled_char != null):
		global_position = Global.controlled_char.global_position
