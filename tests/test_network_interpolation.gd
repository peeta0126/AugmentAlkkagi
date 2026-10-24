extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var piece := AlkkagiPiece.new()
	piece.setup(2, 2001)
	piece.position = Vector2.ZERO
	root.add_child(piece)
	await physics_frame

	piece.apply_network_state({"position": Vector2(60.0, 0.0), "velocity": Vector2(120.0, 0.0)}, true, 0.05)
	check(piece.freeze, "guest piece remains frozen so local physics cannot fight host snapshots")
	close_enough(piece.position.x, 0.0, 0.01, "snapshot is buffered instead of jumping on receipt")
	var previous_x := piece.position.x
	for frame in 5:
		piece._physics_process(0.01)
		check(piece.position.x > previous_x, "position advances on interpolation frame %d" % frame)
		previous_x = piece.position.x
	close_enough(piece.position.x, 60.0, 0.01, "piece reaches the host position over the 50ms receive interval")

	piece.apply_network_state({"position": Vector2(120.0, 0.0), "velocity": Vector2(120.0, 0.0)}, true, 0.10)
	piece._physics_process(0.05)
	close_enough(piece.position.x, 90.0, 0.01, "interpolation duration follows a longer receive interval")
	piece._physics_process(0.05)
	close_enough(piece.position.x, 120.0, 0.01, "longer interval interpolation reaches the next snapshot")

	piece.apply_network_state({"position": Vector2(250.0, 0.0)}, true, 0.05)
	close_enough(piece.position.x, 250.0, 0.01, "large authoritative correction snaps immediately")
	check(not piece.network_interpolation_active, "snap correction clears interpolation")

	piece.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: guest snapshots interpolate every physics frame without local simulation")
	quit(failures)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func close_enough(actual: float, expected: float, tolerance: float, message: String) -> void:
	check(absf(actual - expected) <= tolerance, "%s (actual=%.3f expected=%.3f)" % [message, actual, expected])
