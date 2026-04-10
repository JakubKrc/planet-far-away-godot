extends CanvasLayer

@onready var selector = $selector
@onready var timer = $Timer
@onready var musicPlayer = $MenuStreamPlayer
@onready var animationPlayer = $AnimationPlayer
@onready var colorRect = $ColorRect

@export_file("*.tscn") var start_level_path: String = "res://scenes/environment/castle_zone/rooms/room1.tscn"
@export var start_level_portal_name: String = 'game_start_portal'
@export var start_possessed_char: String = ""
@export var run_instantly : bool = false

var selection = 0

func _ready():
	Global.main_menu = self
	animationPlayer.play_backwards("fade_out") 

func _process(_delta):
	
	if Global.game_state!=Global.GameState.MAIN_MENU:
		return
	
	if Input.is_action_just_pressed("exit_now"):
		get_tree().quit();
	
	if Input.is_action_just_pressed("ui_down"):
		selection+=1
	if Input.is_action_just_pressed("ui_up"):
		selection-=1
		
	if selection<0: selection=1
	if selection>1: selection=0

	selector.position.y = 150 + (selection*40)
	
	if (Input.is_action_just_pressed("ui_accept") and selection == 0) || run_instantly:
		Global.game_state = Global.GameState.PLAYING
		Global.per_level_save.clear()
		Global.main.load_level(start_level_path, start_level_portal_name, 10000, 0.1, start_possessed_char)
		#Global.main.spawn2.spawn()
		get_tree().paused = false
		animationPlayer.play("fade_out")
		await animationPlayer.animation_finished
		musicPlayer.stop()
		colorRect.modulate = 1
		self.hide();
	
	if ((Input.is_action_just_pressed("ui_accept") and selection == 1) or
		(Input.is_key_pressed(KEY_ESCAPE) and OS.get_name() != "Web")):
		get_tree().quit();
