class_name Die
extends Node

@onready var parent = get_parent()

func die():
	if Global.controlled_char != parent:
		parent.components.get("State").state = Global.States.DEATH
		parent.velocity.x = 0
		parent.z_index = 1
		parent.collision_layer = 0
		parent.collision_mask = 0
		if parent.has_node("DamageArea"):
			parent.get_node("DamageArea").collision_layer = 0
			parent.get_node("DamageArea").collision_mask = 0
		parent.animation_player.play("death")
		return

	$/root/main/CanvasLayerForUi/HealthBar.value = 0
	$/root/main/CanvasLayerForUi/HealthBar.get_node("DamageBar").value = 0
	Global.death_menu.visible = true
	Global.game_state = Global.GameState.GAME_OVER
	get_tree().paused = true
