class_name TemporaryWall
extends StaticBody2D

const WallMariaScene := preload("res://scenes/effects/wall_maria.tscn")
const DUST_SHEET: Texture2D = preload("res://assets/effects/dodge_sheet.png")

var wall_id := 0
var wall_size := GameplayRules.WALL_SIZE
var turns_left := 3
var cycle_based := false
var faces_flipped := false

func setup(center: Vector2, wall_rotation: float, duration: int, id: int = 0) -> void:
	wall_id = id
	position = center
	rotation = wall_rotation
	wall_size = GameplayRules.WALL_SIZE
	turns_left = duration
	var collision := CollisionShape2D.new()
	collision.name = "WallCollision"
	var rectangle := RectangleShape2D.new()
	rectangle.size = wall_size
	collision.shape = rectangle
	add_child(collision)
	var material := PhysicsMaterial.new()
	material.bounce = GameplayRules.WALL_BOUNCE
	material.friction = GameplayRules.WALL_FRICTION
	physics_material_override = material
	collision_layer = GameplayRules.WALL_COLLISION_LAYER
	collision_mask = 1
	var wall_visual := WallMariaScene.instantiate()
	wall_visual.name = "WallVisual"
	# 벽 앞면이 항상 화면 아래·오른쪽을 보도록 그림만 뒤집는다(충돌은 그대로).
	faces_flipped = WallMariaVisual.needs_flip(wall_rotation)
	if faces_flipped:
		wall_visual.rotation = PI
	add_child(wall_visual)

## 설치되는 순간 벽 아래쪽에서 흙먼지가 인다.
func play_dust() -> void:
	var half_length := wall_size.x * 0.5
	var bottom := wall_size.y * 0.5
	for index in 5:
		var x := lerpf(-half_length * 0.85, half_length * 0.85, float(index) / 4.0)
		var base_y := (bottom + 2.0) * (-1.0 if faces_flipped else 1.0)  # 앞면이 놓인 쪽의 바닥
		SheetPopVisual.spawn(self, Vector2(x, base_y), DUST_SHEET, 2, 1, 0.28, 0.0, 0.07, 0.03 * float(index))

func tick() -> bool:
	if cycle_based:
		return false
	turns_left -= 1
	return turns_left <= 0

