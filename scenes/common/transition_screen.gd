extends CanvasLayer

signal on_transition_finished

@onready var color_rect = $ColorRect
@onready var animation_player = $AnimationPlayer

var stupidValueHolderForFadeOut: float = 1;

func _ready():
	color_rect.visible = false
	animation_player.animation_finished.connect(_on_animation_finished)
	
func _on_animation_finished(anim_name):
	if anim_name == 'fade_to_black':
		on_transition_finished.emit()
		animation_player.play('fade_to_normal', -1, stupidValueHolderForFadeOut)
		stupidValueHolderForFadeOut = 1
	elif anim_name == 'fade_to_normal':
		color_rect.visible = false
	
func transition(fadeIn: float = 1, fadeOut: float = 1):
	if(fadeIn == 10000):
		color_rect.visible = true
		stupidValueHolderForFadeOut = fadeOut
		_on_animation_finished('fade_to_black')
		return false
	color_rect.visible = true
	animation_player.play("fade_to_black", -1, fadeIn)
	return true
