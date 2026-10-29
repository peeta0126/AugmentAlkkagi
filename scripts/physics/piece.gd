class_name AlkkagiPiece
extends RigidBody2D

const SonicBoomScene := preload("res://scenes/effects/sonic_boom.tscn")
const StasisScene := preload("res://scenes/effects/stasis.tscn")
const TankBlackScene := preload("res://scenes/effects/tank.tscn")
const TankWhiteScene := preload("res://scenes/effects/tank_white.tscn")
const MergeScene := preload("res://scenes/effects/merge.tscn")
const JanggiScene := preload("res://scenes/effects/janggi.tscn")
const StealthScene := preload("res://scenes/effects/stealth.tscn")
const KingScene := preload("res://scenes/effects/king.tscn")
const BADGE_KNIGHT := preload("res://assets/effects/badge_greatsword.png")
const BADGE_WIZARD := preload("res://assets/effects/badge_wizard.png")

signal sound_requested(kind: String, volume_db: float)
signal selected(piece: AlkkagiPiece)
signal piece_collision(piece: AlkkagiPiece, other: AlkkagiPiece)

# 1mm = 1.2px. 흑돌 22.2mm, 백돌 21.9mm의 실제 지름을 그대로 환산한다.
const BLACK_DIAMETER := 26.64
const WHITE_DIAMETER := 26.28
const BLACK_RADIUS := BLACK_DIAMETER * 0.5
const WHITE_RADIUS := WHITE_DIAMETER * 0.5
const RADIUS := BLACK_RADIUS # 이전 테스트/확장 코드와의 호환용 기본값
const OWNER_COLORS := {1: Color("d2a85f"), 2: Color("eee9dc")}
const STONE_NAMES := {1: "흑돌", 2: "백돌"}
const TRANSFORM_NAMES := ["", "SOLDIER", "CHARIOT", "CANNON", "HORSE", "ELEPHANT", "GUARD", "KING", "WIZARD", "KNIGHT"]
const TRANSFORM_SIZES := {"SOLDIER": 0.90, "CHARIOT": 1.15, "CANNON": 1.08, "HORSE": 0.96, "ELEPHANT": 1.20, "GUARD": 1.05, "KING": 1.0, "WIZARD": 1.0}
const NETWORK_SNAP_DISTANCE := 100.0

var sound_was_moving := false
var collision_sound_cooldown := 0.0

var owner_id := 1
var piece_id := 0
var is_selected := false
var trail: Array[Vector2] = []
var base_radius := BLACK_RADIUS
var visual_radius := BLACK_RADIUS
var speed_cap := GameplayRules.BALANCE.max_speed
var sonic_trail := false
var is_tank := false
var collision_shape: CollisionShape2D
var tank_factor := 1.0
var fragment_factor := 1.0
var mass_factor := 1.0
var status_mass_factor := 1.0
var status_damp_bonus := 0.0
var invulnerable := false
var status_turns := 0
var status_kind := ""
var stasis_turns := 0
var stasis_cycle_based := false
var snow_turns := 0
var transformation := ""
var carried_count := 0
var merge_size_step := 0.22
var merge_size_cap := 1.8
var merge_mass_step := 0.9
var reached_enemy_end := false
var king_size_multiplier := 1.5
var king_mass_multiplier := 2.0
var king_shockwave_available := false
var field_damp_multiplier := 1.0
var field_speed_multiplier := 1.0
var hidden_from_player := 0
var stealth_turns := 0
var stealth_effect_time := 0.0
var network_interpolation_from := Vector2.ZERO
var network_interpolation_to := Vector2.ZERO
var network_interpolation_elapsed := 0.0
var network_interpolation_duration := 0.05
var network_interpolation_active := false
var sonic_boom_visual: SonicBoomVisual
var stasis_visual: StasisVisual
var tank_visual: TankVisual
var merge_visual: MergeVisual
var janggi_visual: JanggiVisual
var stealth_visual: StealthVisual
var king_visual: KingVisual

static func radius_for_owner(value: int) -> float:
	return BLACK_RADIUS if value == 1 else WHITE_RADIUS

func setup(new_owner_id: int, new_piece_id: int) -> void:
	owner_id = new_owner_id
	piece_id = new_piece_id
	base_radius = radius_for_owner(owner_id)
	visual_radius = base_radius
	mass = 1.0
	linear_damp = GameplayRules.BALANCE.linear_damp
	angular_damp = 9.0
	lock_rotation = true
	gravity_scale = 0.0
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	var material := PhysicsMaterial.new()
	material.bounce = GameplayRules.BALANCE.bounce
	material.friction = GameplayRules.BALANCE.friction
	physics_material_override = material
	contact_monitor = true
	max_contacts_reported = 8
	body_entered.connect(_on_body_entered)
	collision_layer = 1
	# Layer 1 contains stones; layer 2 contains host-authoritative temporary walls.
	collision_mask = 1 | GameplayRules.WALL_COLLISION_LAYER
	input_pickable = true
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = base_radius
	shape.shape = circle
	add_child(shape)
	collision_shape = shape
	queue_redraw()

func apply_tank(size_multiplier: float, mass_multiplier: float) -> void:
	# 흑돌/백돌의 고유 크기 차이를 보존한 채 각 기본값에서 계산한다.
	is_tank = true
	tank_factor = size_multiplier
	mass_factor = mass_multiplier
	refresh_physics()

func refresh_physics() -> void:
	var merge_size := minf(1.0 + sqrt(float(carried_count)) * merge_size_step, merge_size_cap)
	var merge_mass := 1.0 + float(carried_count) * merge_mass_step
	var king_size := king_size_multiplier if transformation == "KING" else 1.0
	visual_radius = base_radius * tank_factor * fragment_factor * float(TRANSFORM_SIZES.get(transformation, 1.0)) * merge_size * king_size
	mass = mass_factor * status_mass_factor * merge_mass
	linear_damp = (GameplayRules.BALANCE.linear_damp + status_damp_bonus) * field_damp_multiplier
	if collision_shape:
		(collision_shape.shape as CircleShape2D).radius = visual_radius
	_sync_transformation_visuals()
	queue_redraw()

func _sync_transformation_visuals() -> void:
	if is_tank and (not is_instance_valid(tank_visual) or tank_visual.visual_owner_id != owner_id):
		if is_instance_valid(tank_visual):
			remove_child(tank_visual)
			tank_visual.queue_free()
		tank_visual = (TankBlackScene if owner_id == 1 else TankWhiteScene).instantiate() as TankVisual
		add_child(tank_visual)
	elif not is_tank and is_instance_valid(tank_visual):
		tank_visual.queue_free()
		tank_visual = null
	if is_tank and is_instance_valid(tank_visual):
		tank_visual.configure(owner_id, visual_radius)
	if carried_count > 0 and not is_instance_valid(merge_visual):
		merge_visual = MergeScene.instantiate() as MergeVisual
		add_child(merge_visual)
	elif carried_count <= 0 and is_instance_valid(merge_visual):
		merge_visual.queue_free()
		merge_visual = null
	if transformation != "" and transformation not in ["WIZARD", "KING", "KNIGHT"]:
		if not is_instance_valid(janggi_visual):
			janggi_visual = JanggiScene.instantiate() as JanggiVisual
			add_child(janggi_visual)
		janggi_visual.configure(transformation)
	elif is_instance_valid(janggi_visual):
		janggi_visual.queue_free()
		janggi_visual = null
	if transformation == "KING":
		if not is_instance_valid(king_visual):
			king_visual = KingScene.instantiate() as KingVisual
			add_child(king_visual)
		king_visual.set_shockwave_available(king_shockwave_available)
	elif is_instance_valid(king_visual):
		king_visual.queue_free()
		king_visual = null

func set_fragment() -> void:
	fragment_factor = 0.62
	mass_factor *= 0.40
	refresh_physics()

func change_player_owner(new_owner: int) -> void:
	owner_id = new_owner
	base_radius = radius_for_owner(owner_id)
	refresh_physics()

func set_stasis(turns: int) -> void:
	stasis_turns = maxi(stasis_turns, turns)
	status_turns = maxi(status_turns, turns)
	invulnerable = true
	linear_velocity = Vector2.ZERO
	freeze = true
	_update_status_kind()
	queue_redraw()

func set_stealth(player_id: int, turns: int) -> void:
	hidden_from_player = player_id
	stealth_turns = maxi(turns, 1)
	stealth_effect_time = 0.8
	_sync_stealth_visual()
	queue_redraw()

func tick_stealth(completed_player: int) -> void:
	if hidden_from_player != completed_player or stealth_turns <= 0:
		return
	stealth_turns -= 1
	if stealth_turns <= 0:
		hidden_from_player = 0
		stealth_effect_time = 0.8
	_sync_stealth_visual()
	queue_redraw()

func apply_snow(turns: int) -> void:
	snow_turns = maxi(snow_turns, turns)
	status_turns = maxi(status_turns, turns)
	freeze = true
	_update_status_kind()
	refresh_physics()

func tick_status(for_owner: int) -> void:
	if owner_id != for_owner or status_turns <= 0:
		return
	if stasis_turns > 0 and not stasis_cycle_based:
		stasis_turns -= 1
		if stasis_turns == 0:
			freeze = snow_turns > 0
			invulnerable = false
	if snow_turns > 0:
		snow_turns -= 1
		if snow_turns == 0:
			freeze = stasis_turns > 0
	status_turns = maxi(stasis_turns, snow_turns)
	_update_status_kind()
	refresh_physics()

func clear_temporary_status() -> void:
	stasis_cycle_based = false
	freeze = false
	invulnerable = false
	stasis_turns = 0
	snow_turns = 0
	status_turns = 0
	status_kind = ""
	status_mass_factor = 1.0
	status_damp_bonus = 0.0
	refresh_physics()

func tick_stasis_cycle() -> void:
	if not stasis_cycle_based or stasis_turns <= 0:
		return
	stasis_turns -= 1
	if stasis_turns == 0:
		stasis_cycle_based = false
		invulnerable = false
		freeze = snow_turns > 0
	status_turns = maxi(stasis_turns, snow_turns)
	_update_status_kind()
	refresh_physics()

func _update_status_kind() -> void:
	if stasis_turns > 0 and snow_turns > 0:
		status_kind = "stasis+snow"
	elif stasis_turns > 0:
		status_kind = "stasis"
	elif snow_turns > 0:
		status_kind = "snow"
	else:
		status_kind = ""
	_sync_stasis_visual()

func _sync_stasis_visual() -> void:
	if stasis_turns > 0 and not is_instance_valid(stasis_visual):
		stasis_visual = StasisScene.instantiate() as StasisVisual
		add_child(stasis_visual)
	elif stasis_turns <= 0 and is_instance_valid(stasis_visual):
		stasis_visual.release()
		stasis_visual = null

func transform_as(kind: String, apply_physics_bonus: bool = true) -> void:
	transformation = kind
	if apply_physics_bonus:
		match kind:
			"SOLDIER": status_damp_bonus -= 0.35
			"CHARIOT": mass_factor *= 1.35
			"CANNON": mass_factor *= 1.20
			"HORSE": speed_cap = maxf(speed_cap, 1100.0)
			"ELEPHANT": mass_factor *= 1.25
			"GUARD": status_damp_bonus += 0.7
			"KING":
				mass_factor *= king_mass_multiplier
				king_shockwave_available = true
	refresh_physics()

func _on_body_entered(body: Node) -> void:
	# Both stones report the same contact; only one emits its sound.
	if not freeze and collision_sound_cooldown <= 0.0:
		if not body is AlkkagiPiece or piece_id < (body as AlkkagiPiece).piece_id:
			collision_sound_cooldown = 0.06
			sound_requested.emit("collision", -6.0)
	if body is AlkkagiPiece:
		piece_collision.emit(self, body as AlkkagiPiece)

func activate_sonic_trail(new_speed_cap: float) -> void:
	sonic_trail = true
	speed_cap = maxf(speed_cap, new_speed_cap)
	_sync_sonic_visual()
	queue_redraw()

func _sync_sonic_visual() -> void:
	if sonic_trail and not is_instance_valid(sonic_boom_visual):
		sonic_boom_visual = SonicBoomScene.instantiate() as SonicBoomVisual
		add_child(sonic_boom_visual)
	elif not sonic_trail and is_instance_valid(sonic_boom_visual):
		sonic_boom_visual.queue_free()
		sonic_boom_visual = null

func prepare_shot_speed_cap(new_speed_cap: float) -> void:
	speed_cap = maxf(GameplayRules.BALANCE.max_speed, new_speed_cap)

func apply_launch_impulse(reference_impulse: Vector2) -> void:
	apply_central_impulse(GameplayRules.mass_compensated_launch_impulse(reference_impulse, mass))

func set_selected(value: bool) -> void:
	is_selected = value
	queue_redraw()

func stop_motion() -> void:
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	sleeping = true

func network_state() -> Dictionary:
	return {
		"id": piece_id,
		"owner": owner_id,
		"position": position,
		"velocity": linear_velocity,
		"tank": is_tank,
		"tank_factor": tank_factor,
		"fragment_factor": fragment_factor,
		"mass_factor": mass_factor,
		"status_mass": status_mass_factor,
		"status_damp": status_damp_bonus,
		"invulnerable": invulnerable,
		"stasis": stasis_turns,
		"snow": snow_turns,
		"transformation": transformation,
		"carried": carried_count,
		"enemy_end": reached_enemy_end,
		"sonic": sonic_trail,
		"king_shockwave": king_shockwave_available,
		"speed_cap": speed_cap
	}

# 20Hz 온라인 스냅샷은 전송량을 줄이도록 필드명을 제외한 고정 배열로 전송한다.
func compact_network_state() -> PackedFloat32Array:
	var flags := (1 if is_tank else 0) | (2 if invulnerable else 0) | (4 if sonic_trail else 0) | (8 if reached_enemy_end else 0) | (16 if king_shockwave_available else 0)
	var transform_code := maxi(TRANSFORM_NAMES.find(transformation), 0)
	return PackedFloat32Array([piece_id, owner_id, position.x, position.y, linear_velocity.x, linear_velocity.y,
		tank_factor, fragment_factor, mass_factor, status_mass_factor, status_damp_bonus, flags,
		stasis_turns, snow_turns, transform_code, carried_count, speed_cap, hidden_from_player, stealth_turns])

func apply_compact_network_state(data: PackedFloat32Array, offset: int, interpolate: bool, interpolation_duration: float = 0.05) -> void:
	if data.size() < offset + 19:
		return
	apply_network_state({
		"id": int(data[offset]), "owner": int(data[offset + 1]),
		"position": Vector2(data[offset + 2], data[offset + 3]), "velocity": Vector2(data[offset + 4], data[offset + 5]),
		"tank": (int(data[offset + 11]) & 1) != 0, "tank_factor": data[offset + 6],
		"fragment_factor": data[offset + 7], "mass_factor": data[offset + 8],
		"status_mass": data[offset + 9], "status_damp": data[offset + 10],
		"invulnerable": (int(data[offset + 11]) & 2) != 0, "sonic": (int(data[offset + 11]) & 4) != 0,
		"enemy_end": (int(data[offset + 11]) & 8) != 0, "stasis": int(data[offset + 12]), "snow": int(data[offset + 13]),
		"king_shockwave": (int(data[offset + 11]) & 16) != 0,
		"transformation": TRANSFORM_NAMES[clampi(int(data[offset + 14]), 0, TRANSFORM_NAMES.size() - 1)],
		"carried": int(data[offset + 15]), "speed_cap": data[offset + 16],
		"hidden_from": int(data[offset + 17]), "stealth_turns": int(data[offset + 18])
	}, interpolate, interpolation_duration)

func apply_network_state(data: Dictionary, interpolate: bool, interpolation_duration: float = 0.05) -> void:
	var previous_hidden_from := hidden_from_player
	var new_owner := int(data.get("owner", owner_id))
	if new_owner != owner_id:
		change_player_owner(new_owner)
	var target_position: Vector2 = data.get("position", position)
	if interpolate and position.distance_to(target_position) < NETWORK_SNAP_DISTANCE:
		network_interpolation_from = position
		network_interpolation_to = target_position
		network_interpolation_elapsed = 0.0
		network_interpolation_duration = maxf(interpolation_duration, 0.001)
		network_interpolation_active = not position.is_equal_approx(target_position)
	else:
		position = target_position
		network_interpolation_active = false
	linear_velocity = data.get("velocity", Vector2.ZERO)
	is_tank = bool(data.get("tank", false))
	tank_factor = float(data.get("tank_factor", 1.0))
	fragment_factor = float(data.get("fragment_factor", 1.0))
	mass_factor = float(data.get("mass_factor", 1.0))
	status_mass_factor = float(data.get("status_mass", 1.0))
	status_damp_bonus = float(data.get("status_damp", 0.0))
	invulnerable = bool(data.get("invulnerable", false))
	stasis_turns = int(data.get("stasis", 0))
	snow_turns = int(data.get("snow", 0))
	status_turns = maxi(stasis_turns, snow_turns)
	transformation = str(data.get("transformation", ""))
	carried_count = int(data.get("carried", 0))
	reached_enemy_end = bool(data.get("enemy_end", false))
	king_shockwave_available = bool(data.get("king_shockwave", false))
	sonic_trail = bool(data.get("sonic", false))
	_sync_sonic_visual()
	speed_cap = float(data.get("speed_cap", GameplayRules.BALANCE.max_speed))
	hidden_from_player = int(data.get("hidden_from", 0))
	stealth_turns = int(data.get("stealth_turns", 0))
	if previous_hidden_from != hidden_from_player:
		stealth_effect_time = 0.8
	_sync_stealth_visual()
	_update_status_kind()
	refresh_physics()
	freeze = true

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# 작은 돌에서 눈에 띄는 미세 진동을 제거하고 고속 관통 범위를 제한한다.
	if state.linear_velocity.length() < GameplayRules.BALANCE.stop_threshold:
		state.linear_velocity = Vector2.ZERO
	elif state.linear_velocity.length() > speed_cap * field_speed_multiplier:
		state.linear_velocity = state.linear_velocity.limit_length(speed_cap * field_speed_multiplier)

func _physics_process(delta: float) -> void:
	collision_sound_cooldown = maxf(collision_sound_cooldown - delta, 0.0)
	# Clients render frozen snapshot bodies; the host sends their sound events.
	if not freeze:
		var moving := linear_velocity.length() > 38.0
		if moving and not sound_was_moving:
			sound_requested.emit("move", -10.0)
		if linear_velocity.length() < GameplayRules.BALANCE.stop_threshold:
			sound_was_moving = false
		elif moving:
			sound_was_moving = true
	stealth_effect_time = maxf(stealth_effect_time - delta, 0.0)
	_sync_stealth_visual()
	if freeze and network_interpolation_active:
		network_interpolation_elapsed = minf(network_interpolation_elapsed + delta, network_interpolation_duration)
		position = network_interpolation_from.lerp(network_interpolation_to, network_interpolation_elapsed / network_interpolation_duration)
		if network_interpolation_elapsed >= network_interpolation_duration:
			network_interpolation_active = false
	var trail_threshold := 38.0 if sonic_trail else 70.0
	if linear_velocity.length() > trail_threshold:
		trail.push_front(global_position)
		var trail_limit := 14 if sonic_trail else 6
		if trail.size() > trail_limit:
			trail.pop_back()
	else:
		trail.clear()
	queue_redraw()

func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		selected.emit(self)

func _draw() -> void:
	# 속도 잔상은 돌의 실제 반지름을 따라가며 음속 폭발만 금빛으로 강화한다.
	for index in range(trail.size() - 1, -1, -1):
		var local_point := to_local(trail[index])
		var alpha := (0.045 if sonic_trail else 0.025) + float(trail.size() - index) * 0.012
		var trail_color: Color = Color("ffe89a") if sonic_trail else OWNER_COLORS[owner_id]
		draw_circle(local_point, visual_radius * 0.78, Color(trail_color.r, trail_color.g, trail_color.b, alpha))

	# 접촉 그림자는 세로로 눌린 타원으로 그려 돌이 판 위에 놓인 느낌을 준다.
	draw_set_transform(Vector2(2.2, 4.0), 0.0, Vector2(1.08, 0.58))
	draw_circle(Vector2.ZERO, visual_radius + 2.4, Color(0.055, 0.035, 0.018, 0.38))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if is_selected:
		draw_circle(Vector2.ZERO, visual_radius + 5.0, Color(1.0, 0.72, 0.22, 0.92))
	if "stasis" in status_kind:
		draw_circle(Vector2.ZERO, visual_radius + 3.4, Color(0.95, 0.72, 0.22, 0.72))

	var outer: Color = Color("111110") if owner_id == 1 else Color("aaa79f")
	var center: Color = Color("343433") if owner_id == 1 else Color("fffdf3")
	draw_circle(Vector2.ZERO, visual_radius, outer)
	# 광원 쪽으로 조금씩 이동하는 동심원을 쌓아 양면 볼록 렌즈의 곡면을 표현한다.
	for layer in range(1, 12):
		var ratio := float(layer) / 11.0
		var radius := visual_radius * (1.0 - ratio * 0.075)
		var light_center := Vector2(-ratio * visual_radius * 0.10, -ratio * visual_radius * 0.13)
		draw_circle(light_center, radius, outer.lerp(center, ratio * 0.82))
	if owner_id == 2:
		# 조개 백돌의 결을 거의 보이지 않을 정도로 얇게 남긴다.
		draw_arc(Vector2(-1.0, 1.0), visual_radius * 0.66, -2.55, -0.45, 22, Color(0.68, 0.66, 0.61, 0.16), 0.7)
		draw_arc(Vector2(0.5, 2.0), visual_radius * 0.44, 0.55, 2.45, 18, Color(1, 1, 1, 0.28), 0.65)
	# 작고 부드러운 반사광은 플라스틱처럼 보이지 않도록 낮은 불투명도를 쓴다.
	draw_circle(Vector2(-visual_radius * 0.34, -visual_radius * 0.38), maxf(1.25, visual_radius * 0.15), Color(1, 1, 1, 0.22 if owner_id == 1 else 0.42))
	draw_arc(Vector2.ZERO, visual_radius - 0.8, 0.15, 2.75, 24, Color(1, 1, 1, 0.10 if owner_id == 1 else 0.20), 0.8)
	if "snow" in status_kind:
		for angle in [0.2, 2.25, 4.35]:
			draw_circle(Vector2.from_angle(angle) * visual_radius * 0.72, visual_radius * 0.28, Color(0.88, 0.96, 1.0, 0.9))
	if transformation != "":
		var mark_color := Color("ff784f") if transformation == "WIZARD" else Color("f4ce73")
		draw_arc(Vector2.ZERO, visual_radius + 3.0, 0.0, TAU, 28, Color("1c1512"), 4.6)
		draw_arc(Vector2.ZERO, visual_radius + 3.0, 0.0, TAU, 28, Color("c487ff") if transformation == "WIZARD" else Color("ff9a2e"), 2.2)
		if transformation in ["WIZARD", "KNIGHT"]:
			_draw_transformation_mark(mark_color)

func _sync_stealth_visual() -> void:
	var should_show := hidden_from_player != 0 or stealth_effect_time > 0.0
	if should_show and not is_instance_valid(stealth_visual):
		stealth_visual = StealthScene.instantiate() as StealthVisual
		add_child(stealth_visual)
	elif not should_show and is_instance_valid(stealth_visual):
		stealth_visual.queue_free()
		stealth_visual = null

func _draw_transformation_mark(_color: Color) -> void:
	# 기사는 대검, 마법사는 모자 그림을 돌 위에 올린다(증강 아이콘과 같은 잉크 그림).
	var icon: Texture2D = BADGE_KNIGHT if transformation == "KNIGHT" else BADGE_WIZARD
	var height := visual_radius * 2.3
	draw_texture_rect(icon, Rect2(Vector2(-height * 0.5, -visual_radius - height * 0.78), Vector2(height, height)), false)

