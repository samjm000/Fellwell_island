extends CanvasLayer
## Full-screen fade to/from black, for sleeping now and room transitions later.

@onready var _overlay: ColorRect = %Overlay


func fade_out(duration: float = 0.8) -> void:
	await _fade_to(1.0, duration)


func fade_in(duration: float = 0.8) -> void:
	await _fade_to(0.0, duration)


func _fade_to(alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(_overlay, "color:a", alpha, duration)
	await tween.finished
