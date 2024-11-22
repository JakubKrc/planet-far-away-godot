extends Node2D

@onready var main2D = $main2D
@onready var spawn = $Spawn
@onready var testLabel = $CanvasLayerForTestLabel/TestLabel
@onready var backgroundMusicPlayer = $AudioManager/BackgroundMusicPlayer

var level_instance = null
# Called when the node enters the scene tree for the first time.
func _ready():
	Global.main = self
	testLabel.text = OS.get_name()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if Input.is_action_just_pressed("escape")  or Input.is_action_just_pressed("pause"):
		if Global.game_state == Global.GameState.MAIN_MENU:
			return;
		if Input.is_key_pressed(KEY_ESCAPE) and OS.get_name() == "Web":
			return;
		await get_tree().process_frame;
		Global.pause_menu.selection = 0;
		Global.pause_menu.show();
		Global.game_state = Global.GameState.PAUSE_MENU
		get_tree().paused = true;
	
func load_mainchar(where_to_set_character: Vector2):
	var character = get_tree().get_first_node_in_group("player")
	character.global_position = where_to_set_character;
	character.visible=true
	character.velocity = Vector2.ZERO
	character.get_node('Camera2D').position_smoothing_enabled = false
	character.get_node('Camera2D').global_position = where_to_set_character;
	await get_tree().process_frame
	character.get_node('Camera2D').position_smoothing_enabled = true
	
func load_level(level_path : String, door_name : String, fadeIn: float = 1, fadeOut: float = 1):
	
	if level_path=='':
		return
		
	if not ResourceLoader.exists(level_path):
		print("Level %s dont exist." % level_path);
		return
			
	var didFadeInTransitionHappened = TransitionScreen.transition(fadeIn, fadeOut)
	if didFadeInTransitionHappened:
		await TransitionScreen.on_transition_finished
		
	var level_resource := load(level_path)
	if (level_resource):
		unload_level()
		level_instance = level_resource.instantiate()
		main2D.call_deferred("add_child",level_instance)
		await get_tree().process_frame
				
	var doors = get_tree().get_nodes_in_group("door")
	var print_warning: bool = true
	for door in doors:
		if door.door_name == door_name:
			door.need_to_be_exited_before_activating = true;
			load_mainchar(door.global_position)
			print_warning = false
			break

	if  print_warning:
		print("Portal %s are not in the level %s" % [door_name, level_path])
		
	var levelMusic = get_tree().get_nodes_in_group('backgroundmusic')
	if levelMusic.size() == 0:
		#backgroundMusicPlayer.stop()
		#backgroundMusicPlayer.stream = null
		backgroundMusicPlayer.playMusic(null, 0)
	else:
		backgroundMusicPlayer.playMusic(levelMusic[0].song, 0)
			


func unload_level(): 
	for child in main2D.get_children():
		if not child.is_in_group("player"):
			main2D.call_deferred("remove_child",child)
			child.queue_free()
