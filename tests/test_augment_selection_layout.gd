extends SceneTree

var failures := 0
var refresh_count := 0
var selected: StringName

func _init() -> void:
	call_deferred("run_test")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func settle() -> void:
	for i in 5:
		await process_frame

func run_test() -> void:
	var choices: Array[AugmentDefinition] = []
	for path in ["res://resources/augments/blizzard.tres", "res://resources/augments/wizard.tres", "res://resources/augments/coup.tres"]:
		choices.append(load(path) as AugmentDefinition)
	var ui := load("res://scenes/ui/augment_selection.tscn").instantiate() as AugmentSelection
	ui.setup("Player", Color.WHITE, choices, true, 0, 1, 1, true, true)
	root.add_child(ui)
	ui.refresh_requested.connect(func(): refresh_count += 1)
	ui.augment_selected.connect(func(id: StringName): selected = id)
	await settle()
	ui.refresh_button.pressed.emit()
	check(refresh_count == 1, "refresh button forwards request")
	for dimensions in [Vector2(1280, 720), Vector2(1920, 1080), Vector2(800, 600), Vector2(720, 1280), Vector2(2560, 1080)]:
		# Override the root control size to exercise the same resized path as a window.
		ui.set_anchors_preset(Control.PRESET_TOP_LEFT)
		ui.size = dimensions
		await settle()
		check(ui.card_area.get_child_count() == 3, "three cards")
		var buttons: Array[Rect2] = []
		for card in ui.card_area.get_children():
			buttons.append(card.select_button.get_global_rect())
		check(buttons[0].size.is_equal_approx(buttons[1].size) and buttons[1].size.is_equal_approx(buttons[2].size), "equal selection sizes")
		check(is_equal_approx(buttons[0].position.y, buttons[1].position.y) and is_equal_approx(buttons[1].position.y, buttons[2].position.y), "aligned selection buttons")
		var center := (ui.card_area.get_child(1) as Control).get_global_rect()
		for card in ui.card_area.get_children():
			check(card.get_global_rect().size.is_equal_approx(center.size), "equal card sizes")
			check(card.background.get_global_rect().size.is_equal_approx((ui.card_area.get_child(1) as AugmentCard).background.get_global_rect().size), "equal panel borders")
			check(card.panel_size == Vector2(326, 454), "original card dimensions")
			check(not card.is_ancestor_of(ui.refresh_button), "refresh is independent of cards")
		for text in ["\uc0c8\ub85c\uace0\uce68 1\ud68c \ub0a8\uc74c", "\uc0c8\ub85c\uace0\uce68 \uc0ac\uc6a9 \uc644\ub8cc", "Long refresh status ".repeat(12)]:
			ui.refresh_status_label.text = text
			await settle()
			var status := ui.refresh_status_label.get_global_rect()
			var refresh := ui.refresh_button.get_global_rect()
			for card in ui.card_area.get_children():
				var panel := card.background.get_global_rect() as Rect2
				check(panel.end.y <= status.position.y and not panel.intersects(refresh), "refresh controls below all card borders")
			var footer := ui.get_node("Layout/BodyMargin/Body/FooterLabel") as Label
			check(refresh.end.y <= footer.get_global_rect().position.y, "footer below refresh")
			check(Rect2(Vector2.ZERO, dimensions).grow(0.1).encloses(footer.get_global_rect()), "footer inside screen")
			check(status.end.y <= refresh.position.y, "status above refresh")
			for button in buttons:
				check(not button.intersects(refresh) and not button.intersects(status), "no control overlap")
	ui.setup("Player", Color.WHITE, choices, true, 0, 1, 1, true, false)
	await settle()
	check(ui.refresh_button.disabled and ui.refresh_status_label.text == "\uc0c8\ub85c\uace0\uce68 \uc0ac\uc6a9 \uc644\ub8cc", "consumed refresh status")
	(ui.card_area.get_child(2) as AugmentCard).select_button.pressed.emit()
	check(selected == choices[2].id, "selection forwards augment id after rebuilding")
	ui.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: augment selection layout at five sizes, long status, refresh and selection signals")
	quit(failures)
