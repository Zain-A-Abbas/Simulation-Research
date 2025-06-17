class_name BoxRendering
extends Node2D

var boxes: Array[Vector4] = [
	Vector4(300, 800, 500, 100),
	Vector4(400, 200, 100, 300)
]

func _draw() -> void:
	for n in boxes.size():
		draw_rect(
			Rect2(boxes[n].x, boxes[n].y, boxes[n].z, boxes[n].w),
			Color.BLACK,
		)
