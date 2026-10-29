extends SceneTree

var sibling_contacts := 0
var obstacle_contacts := 0
var obstacle: Node
var fragments: Array[AlkkagiPiece] = []

func _init() -> void:
	call_deferred("run_test")

func contact(body: Node) -> void:
	if body is AlkkagiPiece and body in fragments:
		sibling_contacts += 1
	elif body == obstacle:
		obstacle_contacts += 1

func setup_case(game: Node, kind: String) -> bool:
	game.clear_world()
	game.augment_manager.reset_match()
	game.reset_runtime_effects()
	game.start_game_world()
	await process_frame
	var shooter: AlkkagiPiece = game.get_pieces()[0]
	for piece: AlkkagiPiece in game.get_pieces():
		if piece != shooter:
			piece.queue_free()
	await process_frame
	var origin := AlkkagiBoard.BOARD_RECT.get_center()
	shooter.position = origin
	shooter.transform_as("SOLDIER")
	obstacle = null
	if kind in ["ally", "enemy"]:
		game.spawn_piece(1 if kind == "ally" else 2, 76543, origin + Vector2(40, 0))
		obstacle = game.find_piece(76543)
	elif kind == "wall":
		var wall := StaticBody2D.new()
		wall.collision_layer = GameplayRules.WALL_COLLISION_LAYER
		wall.collision_mask = 1
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(10, 100)
		shape.shape = rectangle
		wall.add_child(shape)
		game.world.add_child(wall)
		wall.position = origin + Vector2(45, 0)
		obstacle = wall
	game.split_piece_and_launch(shooter, 1, Vector2(400, 0), 12.0)
	fragments.clear()
	for piece: AlkkagiPiece in game.get_pieces():
		if piece.fragment_factor < 1.0:
			fragments.append(piece)
	sibling_contacts = 0
	obstacle_contacts = 0
	for piece in fragments:
		piece.body_entered.connect(contact)
	var overlap := false
	var starts: Array[Vector2] = []
	var exceptions_ok := true
	for piece in fragments:
		starts.append(piece.position)
		exceptions_ok = exceptions_ok and piece.get_collision_exceptions().size() == 2 and (obstacle == null or not piece.get_collision_exceptions().has(obstacle))
	for i in fragments.size():
		for j in range(i + 1, fragments.size()):
			var a := fragments[i]
			var b := fragments[j]
			var ra: float = (a.collision_shape.shape as CircleShape2D).radius
			var rb: float = (b.collision_shape.shape as CircleShape2D).radius
			overlap = overlap or a.position.distance_to(b.position) < ra + rb
	await physics_frame
	await physics_frame
	var initial_sibling_contacts := sibling_contacts
	var speed_ok := true
	if kind == "empty":
		for piece in fragments:
			speed_ok = speed_ok and absf(piece.linear_velocity.length() - fragments[0].linear_velocity.length()) < 0.1
	for frame in 38:
		await physics_frame
	var distance_ok := true
	if kind == "empty":
		for i in fragments.size():
			distance_ok = distance_ok and absf(fragments[i].position.distance_to(starts[i]) - fragments[0].position.distance_to(starts[0])) < 0.1
	print("CONTACT CASE ", kind, " overlap=", overlap, " initial_sibling=", initial_sibling_contacts, " sibling=", sibling_contacts, " obstacle=", obstacle_contacts)
	return not overlap and exceptions_ok and speed_ok and distance_ok and sibling_contacts == 0 and (kind == "empty" or obstacle_contacts > 0)

func run_test() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var ok := true
	for kind in ["empty", "ally", "enemy", "wall"]:
		if not await setup_case(game, kind):
			ok = false
	if ok:
		print("PASS: triple contact scenarios")
	else:
		push_error("FAIL: triple contact scenarios")
	game.queue_free()
	quit(0 if ok else 1)
