@tool
extends EditorPlugin

const BuildHooks := preload("res://addons/build_hooks/build_hooks.gd")

var _export_plugin: EditorExportPlugin


func _enter_tree() -> void:
	_export_plugin = BuildHooks.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null
