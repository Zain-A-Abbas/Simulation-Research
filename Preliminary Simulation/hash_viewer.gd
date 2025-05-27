extends Node2D
class_name HashViewer

var h_hashes: int = 0
var v_hashes: int = 0

func _draw() -> void:
	if h_hashes == 0 || v_hashes == 0:
		return
	var screen_size: Vector2 = get_tree().root.size
	var rect_size: Vector2 = screen_size / Vector2(h_hashes, v_hashes)
	for h in h_hashes:
		for v in v_hashes:
			var hash_rect: Rect2 = Rect2(
				rect_size * Vector2(h, v),
				rect_size
			)
			draw_rect(hash_rect, Color(0.4, 0.8, 0.9), false, 1.0)
	
	#draw_rect()
