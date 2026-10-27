class_name PiecePlacementUI
extends Control

signal placement_confirmed
signal menu_requested

@onready var title_label: Label = %TitleLabel
@onready var instruction_label: Label = %InstructionLabel
@onready var my_status_label: Label = %MyStatusLabel
@onready var opponent_status_label: Label = %OpponentStatusLabel
@onready var confirm_button: Button = %ConfirmButton
@onready var mode_label: Label = %ModeLabel

func _ready() -> void:
	confirm_button.pressed.connect(func(): placement_confirmed.emit())
	%MenuButton.pressed.connect(func(): menu_requested.emit())

func configure(player_name: String, player_color: Color, modes_text: String) -> void:
	title_label.text = "%s 배치 단계" % player_name
	title_label.add_theme_color_override("font_color", player_color.lightened(0.2))
	mode_label.text = modes_text

func update_state(my_done: bool, opponent_done: bool, editable: bool) -> void:
	my_status_label.text = "내 배치: 완료" if my_done else "내 배치: 조정 중"
	opponent_status_label.text = "상대 배치: 완료" if opponent_done else "상대 배치: 대기 중"
	confirm_button.disabled = my_done or not editable
	confirm_button.text = "배치 완료" if not my_done else "배치 확정됨"
	instruction_label.text = (
		"양쪽 배치가 끝났습니다. 증강 선택을 준비합니다."
		if my_done and opponent_done
		else "자기 진영 안에서 돌을 드래그하세요. 겹치거나 경계를 벗어난 위치는 확정되지 않습니다."
	)
