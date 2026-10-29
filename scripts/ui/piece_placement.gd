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
	_apply_ink_style()

func configure(player_name: String, player_color: Color, modes_text: String) -> void:
	title_label.text = "%s 배치 단계" % player_name
	title_label.add_theme_color_override("font_color", player_color.lightened(0.2))
	mode_label.text = modes_text

func update_state(my_done: bool, opponent_done: bool, editable: bool) -> void:
	my_status_label.text = "내 배치: 완료" if my_done else "내 배치: 조정 중"
	opponent_status_label.text = "상대 배치: 완료" if opponent_done else "상대 배치: 대기 중"
	confirm_button.disabled = my_done or not editable
	confirm_button.text = "배치 완료" if not my_done else "배치 확정됨"
	InkStyle.set_wrapped(
		instruction_label,
		(
			"양쪽 배치가 끝났습니다. 증강 선택을 준비합니다."
			if my_done and opponent_done
			else "자기 진영 안에서 돌을 드래그하세요. 겹치거나 경계를 벗어난 위치는 확정되지 않습니다."
		),
		296.0
	)


func _apply_ink_style() -> void:
	var panel := $TopPanel as PanelContainer
	panel.add_theme_stylebox_override("panel", InkStyle.panel(30.0, 0.0))
	var margin := panel.get_node("Margin") as MarginContainer
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 4)
	InkStyle.outline_label(title_label, 28, InkStyle.CREAM, 8)
	InkStyle.outline_label(instruction_label, 15, InkStyle.CREAM_SOFT, 4)
	InkStyle.outline_label(my_status_label, 17, InkStyle.CREAM, 5)
	InkStyle.outline_label(opponent_status_label, 17, InkStyle.CREAM, 5)
	InkStyle.outline_label(mode_label, 15, InkStyle.ORANGE, 4)
	InkStyle.style_button(confirm_button, 22)
	InkStyle.style_button(%MenuButton, 22)
	confirm_button.custom_minimum_size = Vector2(190, 58)
	%MenuButton.custom_minimum_size = Vector2(150, 58)
	var actions := $Actions as HBoxContainer
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.offset_top = 618.0
	actions.offset_bottom = 680.0
	actions.add_theme_constant_override("separation", 14)
