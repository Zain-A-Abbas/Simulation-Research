@tool
class_name WallInformation
extends HBoxContainer

@onready var x_spinbox: SpinBox = $XSpinbox
@onready var y_spinbox: SpinBox = $YSpinbox
@onready var width_spinbox: SpinBox = $WidthSpinbox
@onready var height_spinbox: SpinBox = $HeightSpinbox
@onready var delete_button: Button = $DeleteButton

func _ready() -> void:
	delete_button.pressed.connect(_on_delete_button_pressed)

func _on_delete_button_pressed() -> void:
	print("Woah")
	self.queue_free()
