# Runs the Obsidian vault export each time the game is started from the editor
# (F5, F6, F7), so dialogue edits in Obsidian show up without a separate step.
@tool
extends EditorPlugin

const DEFAULT_VAULT = "../earth_echo_obs_vault"
const OUTPUT_DIR = "res://data"

# Called by the editor right before it runs the project. Returning true lets the
# run go ahead; a failed export never blocks it, the game uses the last good data.
func _build() -> bool:
	var vault_dir = ProjectSettings.globalize_path("res://").path_join(DEFAULT_VAULT).simplify_path()
	if not DirAccess.dir_exists_absolute(vault_dir):
		print("Vault export skipped: no vault at %s" % vault_dir)
		return true

	var exporter = VaultExporter.new()
	var succeeded = exporter.export_vault(vault_dir, OUTPUT_DIR)
	for warning in exporter.warnings:
		print_rich("[color=yellow]Vault: %s[/color]" % warning)
	if not succeeded:
		for error in exporter.errors:
			push_error("Vault: " + error)
		_toast("Vault export failed, the game uses the last good data. See Output.", EditorToaster.SEVERITY_ERROR)
		return true

	print("Vault exported: %d dialogues, %d encyclopedia entries" % [exporter.dialogue_count, exporter.entry_count])
	EditorInterface.get_resource_filesystem().scan()
	return true

func _toast(message: String, severity: int):
	EditorInterface.get_editor_toaster().push_toast(message, severity)
