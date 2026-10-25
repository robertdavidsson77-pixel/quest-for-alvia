## On-screen interface: party list, dice tray, card hand, combat log, buttons,
## the seat setup screen and the end screen.
class_name Hud
extends CanvasLayer

signal roll_pressed
signal end_turn_pressed
signal restart_pressed
signal card_pressed(index: int)
signal seats_chosen(ai_flags: Array)

const BONE := Color(0.86, 0.82, 0.72)
const INK := Color(0.12, 0.1, 0.09)
const GOLD := Color(0.95, 0.75, 0.25)
const BLOOD := Color(0.75, 0.12, 0.1)
const CARD_BG := Color(0.16, 0.13, 0.11)

var _root: Control
var _turn_label: Label
var _party: RichTextLabel
var _status_label: Label
var _log: RichTextLabel
var _dice_caption: Label
var _dice_row: HBoxContainer
var _hand: HBoxContainer
var _roll_button: Button
var _end_button: Button
var _end_screen: Control
var _end_title: Label
var _end_subtitle: Label
var _seat_screen: Control


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Top left: whose turn, and the party.
	var info := VBoxContainer.new()
	info.position = Vector2(24, 16)
	_root.add_child(info)
	info.add_child(_make_label("THE QUEST FOR ALVIA", 18, GOLD))
	_turn_label = _make_label("", 28, BONE)
	info.add_child(_turn_label)
	_party = RichTextLabel.new()
	_party.bbcode_enabled = true
	_party.fit_content = true
	_party.custom_minimum_size = Vector2(520, 0)
	_party.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_party.add_theme_font_size_override("normal_font_size", 18)
	_party.add_theme_font_size_override("bold_font_size", 18)
	_party.add_theme_color_override("default_color", BONE)
	info.add_child(_party)

	# Left side: what happened.
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log.add_theme_font_size_override("normal_font_size", 16)
	_log.add_theme_font_size_override("bold_font_size", 16)
	_log.add_theme_color_override("default_color", BONE)
	_place(_log, Control.PRESET_BOTTOM_LEFT, Rect2(24, -330, 430, 300))
	_root.add_child(_log)

	# Bottom centre: card hand, with the dice tray above it.
	_hand = HBoxContainer.new()
	_hand.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand.add_theme_constant_override("separation", 12)
	_place(_hand, Control.PRESET_CENTER_BOTTOM, Rect2(-330, -176, 660, 160))
	_root.add_child(_hand)

	var tray := VBoxContainer.new()
	tray.alignment = BoxContainer.ALIGNMENT_END
	_place(tray, Control.PRESET_CENTER_BOTTOM, Rect2(-250, -310, 500, 125))
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(tray)
	_dice_caption = _make_label("", 20, BONE)
	_dice_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tray.add_child(_dice_caption)
	_dice_row = HBoxContainer.new()
	_dice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_dice_row.add_theme_constant_override("separation", 12)
	tray.add_child(_dice_row)

	# Bottom right: what the active hero has left, and buttons.
	var buttons := VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	_place(buttons, Control.PRESET_BOTTOM_RIGHT, Rect2(-300, -190, 276, 170))
	_root.add_child(buttons)
	_status_label = _make_label("", 18, BONE)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	buttons.add_child(_status_label)
	_roll_button = _make_button("Roll movement  [Space]")
	_roll_button.pressed.connect(func(): roll_pressed.emit())
	buttons.add_child(_roll_button)
	_end_button = _make_button("End turn  [Enter]")
	_end_button.pressed.connect(func(): end_turn_pressed.emit())
	buttons.add_child(_end_button)

	var help := _make_label("Click a lit square to move. Click a red square to fight.\nSpells: click a card, then a target. Right-click or Esc cancels.\nRight-drag or Q / E rotate  ·  R / F tilt  ·  W A S D pan  ·  wheel zoom\nT top-down view  ·  C reset camera", 15, Color(BONE, 0.6))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(help, Control.PRESET_TOP_RIGHT, Rect2(-640, 16, 616, 110))
	_root.add_child(help)

	_build_end_screen()


func set_turn(text: String) -> void:
	_turn_label.text = text


func set_party(bbcode: String) -> void:
	_party.text = bbcode


func set_status(text: String) -> void:
	_status_label.text = text


func set_buttons(can_roll: bool, can_end: bool) -> void:
	_roll_button.disabled = not can_roll
	_end_button.disabled = not can_end


func log_line(bbcode: String) -> void:
	_log.append_text(bbcode + "\n")


## Shows the active hero's cards. `playable[i]` says if card i can be clicked now,
## `selected` is the index of the card waiting for a target, or -1.
func show_hand(fig: Figure, playable: Array, selected: int) -> void:
	for child in _hand.get_children():
		child.queue_free()
	if fig == null:
		return
	for i in fig.stats.cards.size():
		var card: CardData = fig.stats.cards[i]
		var used_up := not fig.can_play(card)
		_hand.add_child(_make_card(card, fig.card_uses.get(card, 0), used_up, playable[i], i == selected, i))


## Shows dice tumbling, then settling on `results`.
func show_dice(caption: String, sides: int, results: Array) -> void:
	_dice_caption.text = caption
	for child in _dice_row.get_children():
		child.queue_free()
	var faces: Array[Label] = []
	var panels: Array[PanelContainer] = []
	for r in results:
		var panel := _make_die(sides)
		_dice_row.add_child(panel)
		panels.append(panel)
		faces.append(panel.get_child(0).get_child(0) as Label)

	for i in 9:
		for face in faces:
			face.text = str(randi_range(1, sides if sides > 0 else 6))
		await get_tree().create_timer(0.05).timeout

	for i in results.size():
		faces[i].text = str(results[i])
		if sides == 20 and results[i] == 20:
			_tint_die(panels[i], GOLD)
		elif sides == 20 and results[i] == 1:
			_tint_die(panels[i], BLOOD)
	await get_tree().create_timer(0.4).timeout


## Before the quest: choose Player or AI for each hero.
func show_seat_setup(hero_names: Array) -> void:
	_seat_screen = ColorRect.new()
	(_seat_screen as ColorRect).color = Color(0, 0, 0, 0.75)
	_seat_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_seat_screen)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_place(box, Control.PRESET_CENTER, Rect2(-260, -220, 520, 440))
	_seat_screen.add_child(box)
	var title := _make_label("WHO LEADS THE PARTY?", 36, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := _make_label("Click to switch each hero between Player and AI.", 17, BONE)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var ai_flags: Array = []
	for i in hero_names.size():
		ai_flags.append(false)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		box.add_child(row)
		var name_label := _make_label(hero_names[i], 24, BONE)
		name_label.custom_minimum_size = Vector2(240, 0)
		row.add_child(name_label)
		var toggle := _make_button("Player")
		toggle.custom_minimum_size = Vector2(200, 44)
		toggle.pressed.connect(func():
			ai_flags[i] = not ai_flags[i]
			toggle.text = "AI" if ai_flags[i] else "Player")
		row.add_child(toggle)

	var begin := _make_button("Enter the dungeon")
	begin.custom_minimum_size = Vector2(300, 52)
	begin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	begin.pressed.connect(func():
		_seat_screen.queue_free()
		seats_chosen.emit(ai_flags))
	box.add_child(begin)


func show_end(title: String, subtitle: String, won: bool) -> void:
	_end_title.text = title
	_end_title.add_theme_color_override("font_color", GOLD if won else BLOOD)
	_end_subtitle.text = subtitle
	_end_screen.visible = true
	set_buttons(false, false)
	show_hand(null, [], -1)


func _build_end_screen() -> void:
	_end_screen = ColorRect.new()
	(_end_screen as ColorRect).color = Color(0, 0, 0, 0.7)
	_end_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_screen.visible = false
	_root.add_child(_end_screen)

	var box := VBoxContainer.new()
	_place(box, Control.PRESET_CENTER, Rect2(-300, -110, 600, 220))
	box.add_theme_constant_override("separation", 18)
	_end_screen.add_child(box)
	_end_title = _make_label("", 64, GOLD)
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_end_title)
	_end_subtitle = _make_label("", 22, BONE)
	_end_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_end_subtitle)
	var again := _make_button("Play again")
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	again.custom_minimum_size = Vector2(240, 48)
	again.pressed.connect(func(): restart_pressed.emit())
	box.add_child(again)


func _make_card(card: CardData, _uses_left: int, used_up: bool, playable: bool, selected: bool, index: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(150, 160)
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not playable
	button.pressed.connect(func(): card_pressed.emit(index))

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.05) if used_up else CARD_BG
	style.set_corner_radius_all(8)
	style.set_border_width_all(3 if selected else 2)
	style.border_color = GOLD if selected else Color(0.45, 0.36, 0.25)
	style.set_content_margin_all(8)
	var hover := style.duplicate() as StyleBoxFlat
	hover.border_color = GOLD
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", style)
	if not playable and not selected:
		button.modulate = Color(1, 1, 1, 0.5)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 8
	column.offset_top = 8
	column.offset_right = -8
	column.offset_bottom = -8
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(column)
	if used_up:
		var used := _make_label("%s\n\nused" % card.title, 16, Color(BONE, 0.5))
		used.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(used)
		return button
	column.add_child(_make_label(card.title, 17, GOLD))
	column.add_child(_make_label("Once per quest", 12, Color(BONE, 0.7)))
	var text := _make_label(card.description, 13, BONE)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_constant_override("outline_size", 0)
	column.add_child(text)
	return button


## Anchors `control` to a corner or edge of the screen, then offsets it by `rect`.
func _place(control: Control, preset: Control.LayoutPreset, rect: Rect2) -> void:
	control.set_anchors_preset(preset)
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.position.x + rect.size.x
	control.offset_bottom = rect.position.y + rect.size.y


func _make_die(sides: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(64, 64)
	var style := StyleBoxFlat.new()
	style.bg_color = BONE
	style.set_corner_radius_all(12)
	style.set_border_width_all(3)
	style.border_color = INK
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 0)
	panel.add_child(column)
	var face := _make_label("?", 28, INK)
	face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	face.add_theme_constant_override("outline_size", 0)
	column.add_child(face)
	var kind := _make_label("d%d" % sides if sides > 0 else "", 12, Color(INK, 0.6))
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kind.add_theme_constant_override("outline_size", 0)
	column.add_child(kind)
	return panel


func _tint_die(panel: PanelContainer, color: Color) -> void:
	var style := panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.bg_color = color
	panel.add_theme_stylebox_override("panel", style)


func _make_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 44)
	button.add_theme_font_size_override("font_size", 18)
	return button
