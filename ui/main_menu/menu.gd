extends CanvasLayer

@onready var selector = $selector
@onready var timer = $Timer
@onready var musicPlayer = $MenuStreamPlayer
@onready var animationPlayer = $AnimationPlayer
@onready var colorRect = $ColorRect
@onready var label_continue = $bg/Label2

@export_file("*.tscn") var start_level_path: String = "res://scenes/environment/castle_zone/rooms/room1.tscn"
@export var start_level_portal_name: String = 'game_start_portal'
@export var start_possessed_char: String = ""
@export var run_instantly : bool = false

var selection = 0  # 0=Continue, 1=New Game, 2=Quit
var has_save: bool = false

var _cx: float = 0.0  # x offset to center 320px content

func _ready():
	Global.main_menu = self
	var vp_w = get_viewport().get_visible_rect().size.x
	_cx = floor((vp_w - 320.0) / 2.0)
	$bg.scale.x = vp_w / 320.0
	selector.position.x = 108 + _cx
	animationPlayer.play_backwards("fade_out")
	has_save = Global.has_save()
	if not has_save:
		label_continue.modulate = Color(0.5, 0.5, 0.5, 1.0)
		selection = 1

func _process(_delta):

	if Global.game_state != Global.GameState.MAIN_MENU:
		return

	if Input.is_action_just_pressed("exit_now"):
		get_tree().quit()

	if Input.is_action_just_pressed("ui_down"):
		selection += 1
	if Input.is_action_just_pressed("ui_up"):
		selection -= 1

	if selection < 0: selection = 2
	if selection > 2: selection = 0

	selector.position.y = 120 + (selection * 40)

	if Input.is_action_just_pressed("ui_accept") and selection == 0:
		if has_save:
			_continue_game()

	if (Input.is_action_just_pressed("ui_accept") and selection == 1) or run_instantly:
		_start_new_game()

	if (Input.is_action_just_pressed("ui_accept") and selection == 2) or \
		(Input.is_key_pressed(KEY_ESCAPE) and OS.get_name() != "Web"):
		get_tree().quit()

func _start_new_game():
	Global.game_state = Global.GameState.PLAYING
	Global.per_level_save.clear()
	Global.main.load_level(start_level_path, start_level_portal_name, 10000, 0.1, start_possessed_char)
	get_tree().paused = false
	animationPlayer.play("fade_out")
	await animationPlayer.animation_finished
	musicPlayer.stop()
	colorRect.modulate = 1
	self.hide()

func _continue_game():
	var save = Global.load_game()
	if save.is_empty():
		return
	Global.game_state = Global.GameState.PLAYING
	get_tree().paused = false
	var possessed = save.get("possessed_char_name", start_possessed_char)
	var sp = save.get("spawn_position", [0.0, 0.0])
	var spawn_pos = Vector2(sp[0], sp[1])
	var target_level: String = save["current_level"]
	var home_level: String = save.get("possessed_char_home_level", "")
	# Load the char's home level first (silently) so the char exists in the tree,
	# then jump to the actual saved level if it's a different one.
	if home_level != "" and home_level != target_level:
		await Global.main.load_level(home_level, "", 10000, 10000, possessed)
		await Global.main.load_level(target_level, "", 10000, 0.1, "", spawn_pos)
	else:
		await Global.main.load_level(target_level, "", 10000, 0.1, possessed, spawn_pos)
	animationPlayer.play("fade_out")
	await animationPlayer.animation_finished
	musicPlayer.stop()
	colorRect.modulate = 1
	self.hide()
