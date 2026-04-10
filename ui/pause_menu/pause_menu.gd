extends CanvasLayer

@onready var locator = $locator
@onready var fullscreen_label = $fullscreen_label

var selection = 0;

var _cx: float = 0.0

func _ready():
	Global.pause_menu = self
	_cx = floor((get_viewport().get_visible_rect().size.x - 320.0) / 2.0)
	$bg.position.x = _cx
	locator.position.x = 132 + _cx
	# Align buttons to locator y positions (98, 120, 142) + center offset
	for pair in [[$resume, 98], [$return_to_mm, 120], [$exit, 142]]:
		var btn = pair[0] as Button
		var ly  = pair[1] as int
		btn.position = Vector2(_cx + 120, ly - 9)
		btn.size     = Vector2(80, 20)

func _process(_delta):

	if Global.game_state != Global.GameState.PAUSE_MENU:
		return

	if(Input.is_action_just_pressed("ui_down")):
		selection += 1
	if(Input.is_action_just_pressed("ui_up")):
		selection -= 1

	if(selection<0): selection=2
	if(selection>2): selection=0

	locator.position.y = 98 + (selection*22)

	if((Input.is_action_just_pressed("ui_accept") and selection==0)
	or Input.is_action_just_pressed("escape") or Input.is_action_just_pressed('pause') ):
		if Input.is_key_pressed(KEY_ESCAPE) and OS.get_name() == "Web":
			return;
		go_back_to_game()

	if(Input.is_action_just_pressed("ui_accept") and selection==1):
		go_to_main_menu()

	if(Input.is_action_just_pressed("ui_accept") and selection==2):
		get_tree().quit()

func go_back_to_game():
	self.hide()
	Global.game_state=Global.GameState.PLAYING
	get_tree().paused = false
	
func go_to_main_menu():
	get_tree().get_first_node_in_group('player').queue_free()
	get_tree().get_first_node_in_group('main_char').queue_free()
	Global.main.unload_level()
	Global.main_menu.selection=0
	Global.main_menu.show()
	Global.game_state=Global.GameState.MAIN_MENU
	get_tree().paused = false
	self.hide()
	Global.main_menu.musicPlayer.play()
	Global.main.backgroundMusicPlayer.playMusic(null, 0)

func _on_return_to_mm_pressed():
	go_to_main_menu()

func _on_resume_pressed():
	go_back_to_game()

func _on_exit_pressed():
	get_tree().quit()
