extends CanvasLayer


# Called when the node enters the scene tree for the first time.
func _ready():
	Global.death_menu = self

func _process(_delta):
	if Global.game_state == Global.GameState.GAME_OVER:
		if Input.is_action_just_pressed("escape"):
			self.hide()
			Global.game_state = Global.GameState.MAIN_MENU
			Global.pause_menu.go_to_main_menu()
