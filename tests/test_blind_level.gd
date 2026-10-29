extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("run_test")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func run_test() -> void:
	var visual := (load("res://scenes/effects/blind.tscn") as PackedScene).instantiate() as BlindVisual
	root.add_child(visual)
	await process_frame
	for level in BlindVisual.LEVELS.size():
		visual.apply_level(level)
		var settings: Dictionary = BlindVisual.LEVELS[level]
		check(is_equal_approx(float(visual.veil_material.get_shader_parameter("sight_radius")), float(settings.radius)), "blind level %d sets sight radius" % level)
		check(is_equal_approx((visual.veil_material.get_shader_parameter("veil_color") as Color).a, float(settings.alpha)), "blind level %d sets veil opacity" % level)
	check(float(BlindVisual.LEVELS[0].radius) > float(BlindVisual.LEVELS[2].radius), "weakest level shows a wider circle than the strongest")
	if failures == 0:
		print("PASS test_blind_level")
	quit()
