@tool
extends EditorExportPlugin

## Zips the exported Web build so it can be uploaded to itch.io directly.
## The archive is written next to the export directory, e.g.
## "builds/12SS Web/index.html" -> "builds/12SS Web.zip".

const CHUNK_SIZE := 8 << 20  # 8 MiB, keeps big .pck/.wasm files out of memory.


func _get_name() -> String:
	return "Web Export Zip"


func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformWeb


func _export_end() -> void:
	if not (get_export_platform() is EditorExportPlatformWeb):
		return

	var export_path := get_export_preset().get_export_path()
	var dir_path := export_path.get_base_dir()
	var zip_path := dir_path.trim_suffix("/") + ".zip"

	var names := DirAccess.get_files_at(dir_path)
	if names.is_empty():
		push_error("Web Export Zip: nothing to pack in '%s'." % dir_path)
		return

	var packer := ZIPPacker.new()
	var err := packer.open(zip_path)
	if err != OK:
		push_error("Web Export Zip: could not create '%s' (error %d)." % [zip_path, err])
		return

	for name in names:
		if name.get_extension().to_lower() == "zip":
			continue
		err = _pack_file(packer, dir_path.path_join(name), name)
		if err != OK:
			packer.close()
			push_error("Web Export Zip: failed to add '%s' (error %d)." % [name, err])
			return

	packer.close()
	print("Web Export Zip: wrote %s" % ProjectSettings.globalize_path(zip_path))


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
