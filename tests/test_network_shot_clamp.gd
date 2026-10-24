extends SceneTree

const TEST_RATIOS := [1.0, 1.05, 1.5, 2.0]
var failures := 0

func _init() -> void:
	var base_max_drag := GameplayRules.BALANCE.drag_distance
	check_charge_levels(base_max_drag, "base")
	check_charge_levels(base_max_drag * 1.3, "scope")

	if failures == 0:
		print("PASS: host and guest shot charge limits at 100%, 105%, 150%, and 200%")
	quit(failures)

func check_charge_levels(max_drag: float, label: String) -> void:
	var origin := Vector2(500.0, 500.0)
	var expected_max_impulse := GameplayRules.BALANCE.max_launch_impulse * (max_drag / GameplayRules.BALANCE.drag_distance)
	for ratio: float in TEST_RATIOS:
		var raw_pull := Vector2.RIGHT * max_drag * ratio
		var guest_pull := GameplayRules.clamp_outgoing_pull_vector(raw_pull, max_drag)
		close_enough(guest_pull.length(), max_drag, 0.01, "%s guest %.0f%% request is clamped to maximum charge" % [label, ratio * 100.0])
		check(GameplayRules.is_network_pull_vector_valid(guest_pull, max_drag), "%s guest %.0f%% clamped request passes host validation" % [label, ratio * 100.0])

		var host_impulse := GameplayRules.shot_impulse(origin, origin - raw_pull, max_drag, 1.0)
		close_enough(host_impulse.length(), expected_max_impulse, 0.01, "%s host %.0f%% drag fires at maximum power" % [label, ratio * 100.0])

	var accepted_tolerance_pull := Vector2.RIGHT * max_drag * 1.05
	check(GameplayRules.is_network_pull_vector_valid(accepted_tolerance_pull, max_drag), "%s host accepts the existing 105%% network tolerance" % label)
	for invalid_ratio: float in [1.5, 2.0]:
		var invalid_pull := Vector2.RIGHT * max_drag * invalid_ratio
		check(not GameplayRules.is_network_pull_vector_valid(invalid_pull, max_drag), "%s host rejects abnormal external %.0f%% request" % [label, invalid_ratio * 100.0])

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func close_enough(actual: float, expected: float, tolerance: float, message: String) -> void:
	check(absf(actual - expected) <= tolerance, "%s (actual=%.3f expected=%.3f)" % [message, actual, expected])
