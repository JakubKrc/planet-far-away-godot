# Compiles every project script with the autoloads loaded and lists any that fail.
#   godot --headless --path . -s res://tests/compile_all.gd
extends SceneTree

func _initialize():
	var script_paths = []
	_collect_scripts("res://", script_paths)
	var failed = 0
	for path in script_paths:
		# Reloading the script that is running right now hangs the engine.
		if path == get_script().resource_path:
			continue
		var script = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if script == null or not script.can_instantiate():
			print("FAIL ", path)
			failed += 1
	print("RESULT: %d scripts, %d failed" % [script_paths.size(), failed])
	quit(1 if failed > 0 else 0)

func _collect_scripts(dir_path: String, script_paths: Array):
	var dir = DirAccess.open(dir_path)
	for name in dir.get_directories():
		if name == ".godot" or name == "addons":
			continue
		_collect_scripts(dir_path.path_join(name), script_paths)
	for name in dir.get_files():
		if name.ends_with(".gd"):
			script_paths.append(dir_path.path_join(name))
