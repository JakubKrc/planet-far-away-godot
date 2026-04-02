extends Node2D

@onready var main2D = $main2D
@onready var spawn = $Spawn
@onready var OStestLabel = $CanvasLayerForTestLabel/OSTestLabel
@onready var backgroundMusicPlayer = $AudioManager/BackgroundMusicPlayer
@onready var interact_icon = $InteractIcon

var level_instance = null
# Called when the node enters the scene tree for the first time.
func _ready():
	Global.main = self
	if Global.isTest==true:
		OStestLabel.visible = true
		OStestLabel.text = OS.get_name()
		Global.G_STAT_TestLabel = $CanvasLayerForTestLabel/G_STAT_TestLabel
		Global.G_STAT_TestLabel.visible = true
		Global.G_STAT_TestLabel.text = Global.game_state_names[Global.game_state]

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
	
func load_mainchar(where_to_set_character: Vector2, direction_vector: Vector2):
	
	var character = get_tree().get_first_node_in_group("player")
	Global.controlled_char = character
	character.global_position = where_to_set_character;
	character.visible=true
	character.velocity = direction_vector
	Global.camera.position_smoothing_enabled = false
	Global.camera.global_position = where_to_set_character;
	await get_tree().process_frame
	Global.camera.position_smoothing_enabled = true
	
func load_level(level_path : String, door_name : String, fadeIn: float = 1, fadeOut: float = 1):
	
	if level_path=='':
		return
		
	if not ResourceLoader.exists(level_path):
		print("Level %s dont exist." % level_path);
		return
		
	save_current_level()
						
	Global.level_transition_started.emit()
	
	var didFadeInTransitionHappened = TransitionScreen.transition(fadeIn, fadeOut)
	if didFadeInTransitionHappened:
		await TransitionScreen.on_transition_finished
		
	Global.level_transition_finished.emit()
		
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
			load_mainchar(door.global_position, door.direction_vector)
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
			
	Global.current_level = str(level_instance.name)
	restore_current_level()
	
func save_current_level():
	var level_path = Global.current_level
	if level_path=="":
		return
	
	if not Global.per_level_save.has(level_path):
		Global.per_level_save[level_path] = {}
	
	for node in get_tree().get_nodes_in_group("save"):
		Global.per_level_save[level_path][node.name] = {
			"node_adress": node.get_path(),
			"position": node.global_position,
			"health": node.health,
			"disabled": !node.visible,
		}
		
	print(Global.per_level_save)
	
func restore_current_level():
	var level_path = Global.current_level
	
	if not Global.per_level_save.has(level_path):
		var all_save_nodes = get_tree().get_nodes_in_group("save")
		for node in all_save_nodes:
			if !str(node.get_path()).contains("main2D"):
				if(!(node.is_in_group("player"))):
					disable_node(node)
		return
	
	var level_data = Global.per_level_save[level_path]
	
	for node in get_tree().get_nodes_in_group("save"):
		var data
		if level_data.has(node.name):
			data = level_data[node.name]
			#if str(data.node_adress).contains("main2D"):
			print("loadujem: ", node.name)
			node.global_position = data["position"]
			node.health = data["health"]
			if node.name == get_tree().get_first_node_in_group("player").name:
				if !node.is_in_group("player"):
					node.queue_free()
		#	if !str(data.node_adress).contains("main2D") && !data.disabled:      #ak je to co loadujem na root
		#		if !get_node("/root/main/main2D/"+str(Global.current_level)).has_node(NodePath(node.name)):    #a ak neni na leveli ten isty node
			if data.disabled == true:
				disable_node(node)
			else:
				enable_node(node)

func unload_level(): 
	for child in main2D.get_children():
		if not child.is_in_group("player"):
			main2D.call_deferred("remove_child",child)
			child.queue_free()

func disable_node(node: Node):
	node.visible = false
	node.set_process(false)
	node.set_physics_process(false)
	node.set_process_input(false)
	node.set_process_unhandled_input(false)

	for child in node.get_children():
		if child is CollisionShape2D:
			child.disabled = true


func enable_node(node: Node):
	node.visible = true
	node.set_process(true)
	node.set_physics_process(true)
	node.set_process_input(true)
	node.set_process_unhandled_input(true)

	for child in node.get_children():
		if child is CollisionShape2D:
			child.disabled = false
