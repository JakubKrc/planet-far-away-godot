extends Node

func die():
	Global.death_menu.visible = true
	Global.game_state = Global.GameState.GAME_OVER
	get_tree().paused = true
