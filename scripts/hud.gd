## On-screen interface: turn info, dice tray, combat log, buttons and the end screen.
class_name Hud
extends CanvasLayer

signal roll_pressed
signal end_turn_pressed
signal restart_pressed
signal volume_changed(value: float)
signal mute_pressed

const BONE := Color(0.86, 0.82, 0.72)
const INK := Color(0.12, 0.1, 0.09)
const GOLD := Color(0.95, 0.75, 0.25)
const BLOOD := Color(0.75, 0.12, 0.1)

var _turn_label: Label
var _stats_label: Label
var _log: RichTextLabel
var _dice_caption: Label
var _dice_row: HBoxContainer
var _roll_button: Button
var _end_button: Button
var _mute_button: Button
var _volume_slider: HSlider
var _end_screen: Control
var _end_title: Label
var _end_subtitle: Label
var _banner: Label
var _banner_sub: Label


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Top left: whose turn, and the hero's numbers.
	var info := VBoxContainer.new()
	info.position = Vector2(24, 16)
	root.add_child(info)
	var title := _make_label("THE QUEST FOR ALVIA", 18, GOLD)
	info.add_child(title)
	_turn_label = _make_label("", 28, BONE)
	info.add_child(_turn_label)
	_stats_label = _make_label("", 20, BONE)
	info.add_child(_stats_label)

	# Left side: what happened.
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log.add_theme_font_size_override("normal_font_size", 17)
	_log.add_theme_color_override("default_color", BONE)
	_place(_log, Control.PRESET_BOTTOM_LEFT, Rect2(24, -330, 460, 260))
	root.add_child(_log)

	# Bottom centre: the dice tray.
	var tray := VBoxContainer.new()
	_place(tray, Control.PRESET_CENTER_BOTTOM, Rect2(-200, -150, 400, 130))
	tray.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(tray)
	_dice_caption = _make_label("", 20, BONE)
	_dice_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tray.add_child(_dice_caption)
	_dice_row = HBoxContainer.new()
	_dice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_dice_row.add_theme_constant_override("separation", 12)
	tray.add_child(_dice_row)

	# Bottom right: buttons.
	var buttons := VBoxContainer.new()
	_place(buttons, Control.PRESET_BOTTOM_RIGHT, Rect2(-284, -150, 260, 110))
	buttons.add_theme_constant_override("separation", 10)
	root.add_child(buttons)
	_roll_button = _make_button("Roll movement  [Space]")
	_roll_button.pressed.connect(func(): roll_pressed.emit())
	buttons.add_child(_roll_button)
	_end_button = _make_button("End turn  [Enter]")
	_end_button.pressed.connect(func(): end_turn_pressed.emit())
	buttons.add_child(_end_button)

	# Bottom left, under the log: sound on/off and volume.
	var sound_row := HBoxContainer.new()
	_place(sound_row, Control.PRESET_BOTTOM_LEFT, Rect2(24, -58, 400, 36))
	sound_row.add_theme_constant_override("separation", 12)
	root.add_child(sound_row)
	_mute_button = _make_button("")
	_mute_button.custom_minimum_size = Vector2(150, 36)
	_mute_button.add_theme_font_size_override("font_size", 16)
	_mute_button.pressed.connect(func(): mute_pressed.emit())
	sound_row.add_child(_mute_button)
	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step = 0.05
	_volume_slider.focus_mode = Control.FOCUS_NONE
	_volume_slider.custom_minimum_size = Vector2(200, 36)
	_volume_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_volume_slider.value_changed.connect(func(v: float): volume_changed.emit(v))
	sound_row.add_child(_volume_slider)

	var help := _make_label("Click a lit square to move. Click a gold door next to you to open it.\nClick a monster next to you to attack.\nRight-drag or Q / E rotate   ·   R / F tilt   ·   W A S D pan   ·   wheel zoom\nT top-down view   ·   C reset camera   ·   M mute sound", 15, Color(BONE, 0.6))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(help, Control.PRESET_TOP_RIGHT, Rect2(-640, 16, 616, 100))
	root.add_child(help)

	_build_banner(root)
	_build_end_screen(root)


func set_turn(text: String) -> void:
	_turn_label.text = text


func set_stats(text: String) -> void:
	_stats_label.text = text


func set_buttons(can_roll: bool, can_end: bool) -> void:
	_roll_button.disabled = not can_roll
	_end_button.disabled = not can_end


## Shows the current volume (0..1) and whether sound is muted.
func set_volume(value: float, muted: bool) -> void:
	_volume_slider.set_value_no_signal(value)
	_volume_slider.modulate.a = 0.4 if muted else 1.0
	_mute_button.text = "Sound off  [M]" if muted else "Sound on  [M]"


func log_line(bbcode: String) -> void:
	_log.append_text(bbcode + "\n")


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

	Sound.play("dice_shake")
	# Tumble fast at first, then slow down as the dice run out of steam.
	for i in 16:
		for face in faces:
			face.text = str(randi_range(1, sides))
		for panel in panels:
			panel.pivot_offset = panel.size / 2.0
			panel.rotation = randf_range(-0.35, 0.35) * (1.0 - i / 16.0)
		await get_tree().create_timer(0.035 + 0.006 * i * i / 4.0).timeout

	Sound.play("die_land" if results.size() == 1 else "dice_land")
	for i in results.size():
		faces[i].text = str(results[i])
		panels[i].rotation = 0.0
		if sides == 20 and results[i] == 20:
			_tint_die(panels[i], GOLD)
		elif sides == 20 and results[i] == 1:
			_tint_die(panels[i], BLOOD)
		# Thud: the die punches up in size and settles.
		var punch := panels[i].create_tween()
		punch.tween_property(panels[i], "scale", Vector2(1.25, 1.25), 0.06)
		punch.tween_property(panels[i], "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Hold the result so the player can read it.
	await get_tree().create_timer(0.9).timeout


## Big words across the middle of the screen, such as "YOUR TURN". They fade
## in, hold, and fade out; awaiting this waits for the whole thing.
func show_banner(text: String, subtitle: String, color: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner_sub.text = subtitle
	var tween := create_tween()
	tween.tween_property(_banner, "modulate:a", 1.0, 0.35)
	tween.parallel().tween_property(_banner_sub, "modulate:a", 1.0, 0.35)
	tween.parallel().tween_property(_banner, "scale", Vector2.ONE, 0.5).from(Vector2(1.15, 1.15)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.7)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.45)
	tween.parallel().tween_property(_banner_sub, "modulate:a", 0.0, 0.45)
	await tween.finished


func show_end(title: String, subtitle: String, won: bool) -> void:
	_end_title.text = title
	_end_title.add_theme_color_override("font_color", GOLD if won else BLOOD)
	_end_subtitle.text = subtitle
	_end_screen.visible = true
	set_buttons(false, false)


func _build_banner(root: Control) -> void:
	_banner = _make_label("", 72, BONE)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_constant_override("outline_size", 16)
	_place(_banner, Control.PRESET_CENTER, Rect2(-500, -320, 1000, 100))
	_banner.pivot_offset = Vector2(500, 50)
	_banner.modulate.a = 0.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_banner)
	_banner_sub = _make_label("", 24, Color(BONE, 0.8))
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_banner_sub, Control.PRESET_CENTER, Rect2(-500, -225, 1000, 40))
	_banner_sub.modulate.a = 0.0
	_banner_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_banner_sub)


func _build_end_screen(root: Control) -> void:
	_end_screen = ColorRect.new()
	(_end_screen as ColorRect).color = Color(0, 0, 0, 0.7)
	_end_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_screen.visible = false
	root.add_child(_end_screen)

	var box := VBoxContainer.new()
	_place(box, Control.PRESET_CENTER, Rect2(-300, -110, 600, 220))
	box.add_theme_constant_override("separation", 18)
	_end_screen.add_child(box)
	_end_title = _make_label("", 64, GOLD)
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_end_title)
	_end_subtitle = _make_label("", 22, BONE)
	_end_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_end_subtitle)
	var again := _make_button("Play again")
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	again.custom_minimum_size = Vector2(240, 48)
	again.pressed.connect(func(): restart_pressed.emit())
	box.add_child(again)


## Anchors `control` to a corner or edge of the screen, then offsets it by `rect`.
func _place(control: Control, preset: Control.LayoutPreset, rect: Rect2) -> void:
	control.set_anchors_preset(preset)
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.position.x + rect.size.x
	control.offset_bottom = rect.position.y + rect.size.y


func _make_die(sides: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(72, 72)
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
	var face := _make_label("?", 30, INK)
	face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(face)
	var kind := _make_label("d%d" % sides, 12, Color(INK, 0.6))
	kind.add_theme_constant_override("outline_size", 0)
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
