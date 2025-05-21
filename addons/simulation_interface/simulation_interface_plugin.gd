@tool
extends EditorPlugin

const SIMULATION_INTERFACE = preload("res://addons/simulation_interface/simulation_interface.tscn")

var plugin_scene: SimulationInterface

func _enter_tree():
	# Initialization of the plugin goes here.
	plugin_scene = SIMULATION_INTERFACE.instantiate()
	EditorInterface.get_editor_main_screen().add_child(plugin_scene)
	plugin_scene.hide()

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool) -> void:
	if plugin_scene:
		plugin_scene.visible = visible



func _get_plugin_name() -> String:
	return "Simulation Interface"

func _exit_tree() -> void:
	if plugin_scene:
		plugin_scene.queue_free()
