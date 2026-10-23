class_name PhysicsBalance
extends Resource

# 마우스 드래그 1px을 실제 충격량으로 바꾸는 기본 계수입니다.
@export var base_launch_impulse := 9.36
# 증강이 없는 돌을 최대 드래그했을 때 적용되는 충격량 상한입니다.
@export var max_launch_impulse := 1123.2
# 기본 발사가 최대 파워에 도달하는 마우스 드래그 거리입니다.
@export var drag_distance := 120.0
# 돌이 보드 위를 미끄러질 때 매초 줄어드는 속도의 정도입니다.
@export var linear_damp := 2.68
# 증강이 없는 일반 돌의 안전한 최대 이동 속도입니다.
@export var max_speed := 1250.0
# 이 속도 아래에서는 미세 진동을 제거하고 정지한 것으로 처리합니다.
@export var stop_threshold := 4.0
# 돌끼리 충돌했을 때 유지되는 반발 정도입니다.
@export_range(0.0, 1.0) var bounce := 0.48
# 접촉 중 속도 방향 변화와 미끄러짐에 영향을 주는 마찰값입니다.
@export_range(0.0, 1.0) var friction := 0.24
