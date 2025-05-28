@tool
extends MarginContainer
class_name SimulationInterface

@onready var agent_count_spin_box: SpinBox = %AgentCountSpinBox
@onready var scenario_option: OptionButton = %ScenarioOption
@onready var max_velocity_spinbox: SpinBox = %MaxVelocitySpinbox
@onready var radius_spin_box: SpinBox = %RadiusSpinBox
@onready var rendering_check_box: CheckBox = %RenderingCheckBox
@onready var save_check_box: CheckBox = %SaveCheckBox
@onready var start_button: Button = %StartButton
@onready var window_x_spin_box: SpinBox = %WindowXSpinBox
@onready var window_y_spin_box: SpinBox = %WindowYSpinBox
@onready var world_width_spin_box: SpinBox = %WorldWidthSpinBox
@onready var world_height_spin_box: SpinBox = %WorldHeightSpinBox
@onready var hashes_spin_box: SpinBox = %HashesSpinBox
@onready var spatial_hashes_toggle: CheckButton = %SpatialHashesToggle
@onready var hash_settings_hbox: HBoxContainer = %HashSettingsHbox

@onready var error_label: Label = %ErrorLabel

var config_file_location: String = RedBlackAgents.RED_BLACK_AGENTS_CONFIG_FILE
const RED_BLACK_AGENTS_PATH: String = "res://Preliminary Simulation/red_black_agents.tscn"

func _ready() -> void:
	start_button.pressed.connect(start_simulation)
	spatial_hashes_toggle.toggled.connect(hash_settings_hbox.set_visible.bind())
	scenario_option.clear()
	for scenario in RedBlackAgents.Scenarios.keys():
		scenario_option.add_item(scenario)

func start_simulation():
	if (step_decimals(window_x_spin_box.value / hashes_spin_box.value) > 0.0 || step_decimals(window_y_spin_box.value / hashes_spin_box.value) > 0.0):
		set_error_text("Hash count must be divisible by window width and height")
		return
	
	
	var param_dict: Dictionary[String, Variant] = {
		"agent_count": agent_count_spin_box.value,
		"max_velocity": max_velocity_spinbox.value,
		"radius": radius_spin_box.value,
		"scenario": scenario_option.get_item_text(scenario_option.selected),
		"disable_rendering": rendering_check_box.button_pressed,
		"save": save_check_box.button_pressed,
		"window_width": window_x_spin_box.value,
		"window_height": window_y_spin_box.value,
		"world_width": world_width_spin_box.value,
		"world_height": world_height_spin_box.value,
		"use_hashes": spatial_hashes_toggle.button_pressed,
		"hash_size": hashes_spin_box.value,
	}
	
	var config_file: FileAccess = FileAccess.open(config_file_location, FileAccess.WRITE)
	config_file.store_line(JSON.stringify(param_dict))
	config_file.close()
	EditorInterface.play_custom_scene(RED_BLACK_AGENTS_PATH)

func set_error_text(text: String):
	error_label.text = text
	await get_tree().create_timer(2.0).timeout
	error_label.text = ""
