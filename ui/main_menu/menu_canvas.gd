extends CanvasLayer

@onready var selector = $selector
@onready var timer = $Timer
@onready var musicPlayer = $MenuStreamPlayer

var selection = 0
# Called when the node enters the scene tree for the first time.
func _ready():
	Global.main_menu = self

# Called every frame. 'delta' is the elapsed time since the previous frame.
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
	
	if Input.is_action_just_pressed("ui_accept") and selection == 0:
		Global.game_state = Global.GameState.PLAYING
		Global.main.load_level("res://scenes/environment/castle_zone/rooms/room1.tscn",'game_start_portal', 10000, 0.1)
		#await get_tree().create_timer(5).timeout
		Global.main.spawn.spawn()
		get_tree().paused = false
		musicPlayer.stop()
		self.hide();
	
	if ((Input.is_action_just_pressed("ui_accept") and selection == 1) or
		(Input.is_key_pressed(KEY_ESCAPE) and OS.get_name() != "Web")):
		get_tree().quit();
