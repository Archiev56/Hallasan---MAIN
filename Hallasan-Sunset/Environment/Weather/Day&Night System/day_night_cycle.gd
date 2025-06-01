extends CanvasModulate

func _process(delta):
	var time = Time.get_datetime_dict_from_system()
	var time_in_seconds = time.hour * 3600 + time.minute * 60 + time.second
	var current_frame = remap(time_in_seconds, 0.0, 86400.0, 0.0, 24.0)

	$AnimationPlayer.play("day&night")
	$AnimationPlayer.seek(current_frame, true)
