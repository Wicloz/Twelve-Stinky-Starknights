@tool
extends EditorPlugin

const WebExportZip := preload("res://addons/web_export_zip/web_export_zip.gd")

var _export_plugin: EditorExportPlugin


func _enter_tree() -> void:
	_export_plugin = WebExportZip.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null
