extends SceneTree

var failures := 0
var events: Array[String] = []

func _init() -> void:
	call_deferred("run_test")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run_test() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var a := AlkkagiPiece.new()
	var b := AlkkagiPiece.new()
	a.setup(1, 101)
	b.setup(2, 201)
	root.add_child(a)
	root.add_child(b)
	a.set_physics_process(false)
	b.set_physics_process(false)
	a.sound_requested.connect(func(kind: String, _db: float): events.append(kind))
	b.sound_requested.connect(func(kind: String, _db: float): events.append(kind))
	a._on_body_entered(b)
	b._on_body_entered(a)
	a._on_body_entered(b)
	check(events.count("collision") == 1, "one collision sound per contact, with cooldown")
	a.linear_velocity = Vector2(200, 0)
	a._physics_process(0.016)
	a._physics_process(0.016)
	check(events.count("move") == 1, "movement sound plays once while sliding")
	a.linear_velocity = Vector2.ZERO
	a._physics_process(0.016)
	a.linear_velocity = Vector2(200, 0)
	a._physics_process(0.016)
	check(events.count("move") == 2, "movement sound rearms after stopping")
	for kind in ["collision", "move"]:
		game.play_piece_sound(kind, -6.0)
	var players: Array[AudioStreamPlayer] = []
	for child in game.get_children():
		if child is AudioStreamPlayer:
			players.append(child)
	check(players.size() == 2, "both audio streams create players")
	for player in players:
		check(player.stream.get_length() > 0.0 and player.playing, "imported stream plays")
	await create_timer(4.0).timeout
	for player in players:
		check(not is_instance_valid(player), "finished audio players are freed")
	a.queue_free()
	b.queue_free()
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: collision, movement, playback and audio cleanup")
	quit(failures)