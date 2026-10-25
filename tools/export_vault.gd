# Exports the Obsidian vault into res://data (dialogues and encyclopedia).
#   godot --headless --path . -s res://tools/export_vault.gd [-- --vault=/path/to/vault]
# Without --vault it uses the vault folder next to the project.
extends SceneTree

const DEFAULT_VAULT = "../earth_echo_obs_vault"
const OUTPUT_DIR = "res://data"

func _initialize():
	var vault_dir = ProjectSettings.globalize_path("res://").path_join(DEFAULT_VAULT).simplify_path()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--vault="):
			vault_dir = arg.trim_prefix("--vault=")

	var exporter = VaultExporter.new()
	var succeeded = exporter.export_vault(vault_dir, OUTPUT_DIR)
	for warning in exporter.warnings:
		print("WARNING ", warning)
	for error in exporter.errors:
		print("ERROR ", error)
	if succeeded:
		print("Exported %d dialogues and %d encyclopedia entries from %s" % [exporter.dialogue_count, exporter.entry_count, vault_dir])
	else:
		print("Nothing exported: fix the errors above.")
	quit(0 if succeeded else 1)
