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

var config_file_location: String = RedBlackAgents.RED_BLACK_AGENTS_CONFIG_FILE
const RED_BLACK_AGENTS_PATH: String = "res://Preliminary Simulation/red_black_agents.tscn"

func _ready() -> void:
	start_button.pressed.connect(start_simulation)
	scenario_option.clear()
	for scenario in RedBlackAgents.Scenarios.keys():
		scenario_option.add_item(scenario)

func start_simulation():
	var param_dict: Dictionary[String, Variant] = {
		"agent_count": agent_count_spin_box.value,
		"max_velocity": max_velocity_spinbox.value,
		"radius": radius_spin_box.value,
		"scenario": scenario_option.get_item_text(scenario_option.selected),
		"disable_rendering": rendering_check_box.button_pressed,
		"save": save_check_box.button_pressed,
		"window_x": window_x_spin_box.value,
		"window_y": window_y_spin_box.value,
	}
	
	var config_file: FileAccess = FileAccess.open(config_file_location, FileAccess.WRITE)
	config_file.store_line(JSON.stringify(param_dict))
	config_file.close()
	EditorInterface.play_custom_scene(RED_BLACK_AGENTS_PATH)
