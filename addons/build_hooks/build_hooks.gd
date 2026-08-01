@tool
extends EditorExportPlugin

## Build steps that run around every export:
##
## Before  -- re-runs tools/production_graph.py and copies the freshly rendered
##            production_graph.png into res://assets/, so the in-game chain map
##            never ships stale.
## After   -- for Web only, zips the export output next to it, e.g.
##            "builds/12SS Web/index.html" -> "builds/12SS Web.zip".

const CHUNK_SIZE := 8 << 20  # 8 MiB, keeps big .pck/.wasm files out of memory.

const GRAPH_SCRIPT := "res://tools/production_graph.py"
const GRAPH_RENDERED := "res://tools/production_graph.png"
const GRAPH_IN_GAME := "res://assets/production_graph.png"

# Tried in order; the first interpreter that runs the script wins.
const PYTHONS: PackedStringArray = ["python", "py", "python3"]


func _get_name() -> String:
	return "Build Hooks"


# ---------------------------------------------------------------- pre-export
func _export_begin(_features: PackedStringArray, _is_debug: bool,
		_path: String, _flags: int) -> void:
	if not _run_graph_script():
		return
	_install_graph()


func _run_graph_script() -> bool:
	var script_path := ProjectSettings.globalize_path(GRAPH_SCRIPT)
	if not FileAccess.file_exists(GRAPH_SCRIPT):
		push_warning("Build Hooks: %s is missing, keeping the current graph." % GRAPH_SCRIPT)
		return false

	var output: Array = []
	for python in PYTHONS:
		output.clear()
		var exit_code := OS.execute(python, [script_path], output, true)
		if exit_code == 0:
			print("Build Hooks: production graph rebuilt.")
			return true
		if exit_code != -1:  # Ran, but the script itself failed.
			push_warning("Build Hooks: %s exited with %d, keeping the current graph.\n%s"
					% [GRAPH_SCRIPT.get_file(), exit_code, "\n".join(output)])
			return false

	push_warning("Build Hooks: no Python interpreter found on PATH, keeping the current graph.")
	return false


## Copies the rendered graph over the one the game ships, and reimports it so
## the export packs the new texture instead of the previously imported one.
func _install_graph() -> void:
	var fresh := FileAccess.get_file_as_bytes(GRAPH_RENDERED)
	if fresh.is_empty():
		push_warning("Build Hooks: %s was not rendered (is Graphviz on PATH?)." % GRAPH_RENDERED)
		return
	if fresh == FileAccess.get_file_as_bytes(GRAPH_IN_GAME):
		print("Build Hooks: %s is already up to date." % GRAPH_IN_GAME.get_file())
		return

	var err := DirAccess.copy_absolute(GRAPH_RENDERED, GRAPH_IN_GAME)
	if err != OK:
		push_warning("Build Hooks: could not update %s (error %d)." % [GRAPH_IN_GAME, err])
		return

	var fs := EditorInterface.get_resource_filesystem()
	fs.update_file(GRAPH_IN_GAME)
	fs.reimport_files(PackedStringArray([GRAPH_IN_GAME]))
	print("Build Hooks: updated and reimported %s." % GRAPH_IN_GAME)


# --------------------------------------------------------------- post-export
func _export_end() -> void:
	if not (get_export_platform() is EditorExportPlatformWeb):
		return

	var export_path := get_export_preset().get_export_path()
	var dir_path := export_path.get_base_dir()
	var zip_path := dir_path.trim_suffix("/") + ".zip"

	var names := DirAccess.get_files_at(dir_path)
	if names.is_empty():
		push_error("Build Hooks: nothing to pack in '%s'." % dir_path)
		return

	var packer := ZIPPacker.new()
	var err := packer.open(zip_path)
	if err != OK:
		push_error("Build Hooks: could not create '%s' (error %d)." % [zip_path, err])
		return

	for name in names:
		if name.get_extension().to_lower() == "zip":
			continue
		err = _pack_file(packer, dir_path.path_join(name), name)
		if err != OK:
			packer.close()
			push_error("Build Hooks: failed to add '%s' (error %d)." % [name, err])
			return

	packer.close()
	print("Build Hooks: wrote %s" % zip_path)


func _pack_file(packer: ZIPPacker, source_path: String, name: String) -> Error:
	var file := FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()

	var err := packer.start_file(name)
	if err != OK:
		return err

	while not file.eof_reached():
		var chunk := file.get_buffer(CHUNK_SIZE)
		if chunk.is_empty():
			break
		err = packer.write_file(chunk)
		if err != OK:
			return err

	return packer.close_file()
