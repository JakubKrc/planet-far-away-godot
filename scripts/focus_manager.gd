extends Node2D

var has_focus := false
@onready var overlay := $CanvasLayer/ColorRect

func _ready():
	if OS.has_feature("web"):
		queue_free()
		return
	overlay.visible = true

func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		has_focus = false
		overlay.visible = true
		get_tree().paused = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		overlay.visible = false

func _input(event):
	if not has_focus and event is InputEventMouseButton and event.pressed:
		has_focus = true
		if Global.game_state not in [Global.GameState.PAUSE_MENU, Global.GameState.GAME_OVER]:
			get_tree().paused = false
		overlay.visible = false
