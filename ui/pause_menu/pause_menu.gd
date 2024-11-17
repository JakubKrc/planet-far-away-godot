extends CanvasLayer

@onready var locator = $locator

var selection = 0;

# Called when the node enters the scene tree for the first time.
func _ready():
	Global.pause_menu = self

# Called every frame. 'delta' is the elapsed time since the previous frame.
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
	or Input.is_action_just_pressed("escape") ):
		go_back_to_game()
		
	if(Input.is_action_just_pressed("ui_accept") and selection==1):
		go_to_main_menu()
		
	if(Input.is_action_just_pressed("ui_accept") and selection==2):
		get_tree().quit()

func go_back_to_game():
	self.hide()
	get_tree().paused = false
	
func go_to_main_menu():
	get_tree().get_first_node_in_group('player').queue_free()
	Global.main.unload_level()
	Global.main_menu.selection=0
	Global.main_menu.show()
	Global.game_state=Global.GameState.MAIN_MENU
	get_tree().paused = false
	self.hide()

func _on_return_to_mm_pressed():
	go_to_main_menu()

func _on_resume_pressed():
	go_back_to_game()

func _on_exit_pressed():
	get_tree().quit()
