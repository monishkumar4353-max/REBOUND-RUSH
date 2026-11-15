extends Control
## BOUNCE BACK - CYBER NEON MAIN MENU (DUAL AUDIO TRACKS & ADVANCED GRAPHICS)

var _holder: Control
var _title: Label
var _t := 0.0

const CYAN := Color(0.0, 0.95, 1.0)
const PURPLE := Color(0.7, 0.25, 1.0)
const PINK := Color(1.0, 0.15, 0.65)
const GOLD := Color(1.0, 0.8, 0.2)
const BLUE_NEON := Color(0.1, 0.5, 1.0)


func _ready() -> void:
	Game.full_rect(self)

	var bgl := CanvasLayer.new()
	bgl.layer = -10
	add_child(bgl)
	bgl.add_child(NeonBackground.new())

	Game.add_glow(self)

	if Game.open_levels:
		Game.open_levels = false
		_show_levels()
	else:
		_show_main()


func _process(delta: float) -> void:
	_t += delta

	if _title != null and is_instance_valid(_title):
		var pulse := 0.5 + 0.5 * sin(_t * 2.5)
		_title.modulate = Color.WHITE.lerp(
			Color(0.4, 0.9, 1.0),
			pulse * 0.45
		)


func _clear() -> VBoxContainer:
	if _holder != null and is_instance_valid(_holder):
		_holder.queue_free()

	_title = null
	_holder = CenterContainer.new()
	Game.full_rect(_holder)
	add_child(_holder)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	_holder.add_child(v)

	return v


func _center(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _make_title(text: String, size: int) -> Label:
	var l := Game.make_label(text, size, CYAN)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", PURPLE)
	l.add_theme_constant_override("outline_size", 8)
	return l


func _make_menu_button(text: String, color: Color = CYAN) -> Button:
	var b := Game.make_button(
		text,
		Vector2(340, 48),
		color,
		22
	)

	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", color)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)

	return b


func _show_main() -> void:
	var v := _clear()

	_title = _make_title("BOUNCE BACK", 72)
	v.add_child(_title)

	v.add_child(_center(Game.make_label(
		"CYBER NEON ARCADE PLATFORMER",
		16,
		Color(0.75, 0.55, 1.0)
	)))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	v.add_child(spacer)

	var play := _make_menu_button("▶ PLAY", CYAN)
	play.pressed.connect(_on_play)
	v.add_child(play)

	var levels := _make_menu_button("▦ LEVEL SELECT", PURPLE)
	levels.pressed.connect(_show_levels)
	v.add_child(levels)

	var leaderboard := _make_menu_button("🏆 LEADERBOARD", GOLD)
	leaderboard.pressed.connect(_show_leaderboard)
	v.add_child(leaderboard)

	var settings := _make_menu_button("⚙ SETTINGS", PINK)
	settings.pressed.connect(_show_settings)
	v.add_child(settings)

	var help := _make_menu_button("★ HOW TO PLAY", BLUE_NEON)
	help.pressed.connect(_show_help)
	v.add_child(help)

	var exit := _make_menu_button("✕ EXIT", Color(1.0, 0.3, 0.3))
	exit.pressed.connect(func() -> void: get_tree().quit())
	v.add_child(exit)

	v.add_child(_center(Game.make_label(
		"★ TOTAL BEST SCORE: %d" % Game.total_best(),
		16,
		GOLD
	)))


func _on_play() -> void:
	Game.current_level = 1
	Game.goto("res://level.tscn")


func _start(i: int) -> void:
	Game.current_level = i
	Game.goto("res://level.tscn")


func _show_levels() -> void:
	var v := _clear()

	_title = _make_title("LEVEL SELECT", 46)
	v.add_child(_title)

	v.add_child(_center(Game.make_label(
		"CHOOSE YOUR CHALLENGE",
		16,
		PURPLE
	)))

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)

	for i in range(1, Game.LEVEL_COUNT + 1):
		var best := int(Game.best_scores.get(i, 0))
		var label := "%02d\n%s" % [
			i,
			str(best) if best > 0 else "READY"
		]

		var color := CYAN if i % 2 == 0 else PURPLE

		var b := Game.make_button(
			label,
			Vector2(110, 70),
			color,
			19
		)

		b.disabled = i > Game.unlocked
		b.pressed.connect(_start.bind(i))
		grid.add_child(b)

	var back := _make_menu_button("← BACK", PINK)
	back.pressed.connect(_show_main)
	v.add_child(back)


func _show_leaderboard() -> void:
	var v := _clear()

	_title = _make_title("TOP RANKINGS", 46)
	v.add_child(_title)

	v.add_child(_center(Game.make_label(
		"HIGH SCORES ACROSS ALL LEVELS",
		16,
		GOLD
	)))

	var scores_box := VBoxContainer.new()
	scores_box.add_theme_constant_override("separation", 6)
	v.add_child(scores_box)

	var top_records = []
	for i in range(1, Game.LEVEL_COUNT + 1):
		var score := int(Game.best_scores.get(i, 0))
		top_records.append({"level": i, "score": score})
	
	top_records.sort_custom(func(a, b): return a["score"] > b["score"])

	for idx in range(min(4, top_records.size())):
		var rec = top_records[idx]
		var rank_text := "RANK #%d  -  Level %02d  :  %d PTS" % [idx + 1, rec["level"], rec["score"]]
		var rank_lbl := Game.make_label(rank_text, 16, CYAN if idx % 2 == 0 else PURPLE)
		scores_box.add_child(_center(rank_lbl))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	v.add_child(spacer)

	var back := _make_menu_button("← BACK", PINK)
	back.pressed.connect(_show_main)
	v.add_child(back)


func _show_help() -> void:
	var v := _clear()

	_title = _make_title("HOW TO PLAY", 46)
	v.add_child(_title)

	var instructions := [
		["LEFT ARROW", "Move backward"],
		["RIGHT ARROW", "Move forward"],
		["SPACE", "Jump / Double jump"],
		["E", "Activate shield"],
		["Q", "Speed boost"]
	]

	for item in instructions:
		var label := Game.make_label(
			item[0] + "  -  " + item[1],
			16,
			CYAN
		)
		v.add_child(label)

	var note := Game.make_label(
		"LEVEL 2 ONWARDS: WATCH OUT FOR VILLAINS!",
		15,
		PINK
	)
	v.add_child(_center(note))

	var back := _make_menu_button("← BACK", PURPLE)
	back.pressed.connect(_show_main)
	v.add_child(back)


func _show_settings() -> void:
	var v := _clear()

	_title = _make_title("SETTINGS", 44)
	v.add_child(_title)

	# --- AUDIO SECTION ---
	v.add_child(Game.make_label("♫ MASTER VOLUME", 16, CYAN))
	var ms := _slider(Game.music_vol)
	ms.value_changed.connect(func(x: float) -> void: Game.set_music_vol(x))
	v.add_child(ms)

	# Dual Audio Track Switcher Buttons
	var track1_btn := _make_menu_button("♬ PLAY TRACK 1: CYBER SYNTH", BLUE_NEON)
	track1_btn.pressed.connect(func() -> void:
		if Game.has_method("play_music_track"):
			Game.play_music_track(1)
		else:
			Game.play_sfx("coin")
	)
	v.add_child(track1_btn)

	var track2_btn := _make_menu_button("♬ PLAY TRACK 2: NEON PULSE", PURPLE)
	track2_btn.pressed.connect(func() -> void:
		if Game.has_method("play_music_track"):
			Game.play_music_track(2)
		else:
			Game.play_sfx("powerup")
	)
	v.add_child(track2_btn)

	v.add_child(Game.make_label("♪ SOUND EFFECTS", 16, PINK))
	var ss := _slider(Game.sfx_vol)
	ss.value_changed.connect(func(x: float) -> void: Game.set_sfx_vol(x))
	ss.drag_ended.connect(func(_c: bool) -> void: Game.play_sfx("coin"))
	v.add_child(ss)

	# --- GRAPHICS SECTION ---
	var fs_label := "🖥 FULLSCREEN: %s" % ("ON" if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else "OFF")
	var fullscreen_btn := _make_menu_button(fs_label, CYAN)
	fullscreen_btn.pressed.connect(func() -> void:
		var current_mode := DisplayServer.window_get_mode()
		if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			fullscreen_btn.text = "🖥 FULLSCREEN: OFF"
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			fullscreen_btn.text = "🖥 FULLSCREEN: ON"
		Game.play_sfx("powerup")
	)
	v.add_child(fullscreen_btn)

	var vsync_label := "⚡ VSYNC: %s" % ("ON" if DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED else "OFF")
	var vsync_btn := _make_menu_button(vsync_label, GOLD)
	vsync_btn.pressed.connect(func() -> void:
		var current_vsync := DisplayServer.window_get_vsync_mode()
		if current_vsync == DisplayServer.VSYNC_DISABLED:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
			vsync_btn.text = "⚡ VSYNC: ON"
		else:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			vsync_btn.text = "⚡ VSYNC: OFF"
		Game.play_sfx("powerup")
	)
	v.add_child(vsync_btn)

	# Neon Glow/Bloom Toggle
	var glow_active := true # Replace with Game.glow_enabled if tracked in Game singleton
	var glow_btn := _make_menu_button("✨ NEON GLOW EFFECT: ON", PINK)
	glow_btn.pressed.connect(func() -> void:
		if Game.has_method("toggle_glow"):
			Game.toggle_glow()
			glow_btn.text = "✨ NEON GLOW EFFECT: " + ("ON" if Game.glow_enabled else "OFF")
		else:
			Game.play_sfx("coin")
		Game.play_sfx("powerup")
	)
	v.add_child(glow_btn)

	# --- PROGRESS & NAVIGATION ---
	var reset := _make_menu_button("RESET PROGRESS", Color(1.0, 0.35, 0.25))
	reset.pressed.connect(func() -> void: Game.reset_progress())
	v.add_child(reset)

	var back := _make_menu_button("← BACK", BLUE_NEON)
	back.pressed.connect(_show_main)
	v.add_child(back)


func _slider(val: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = val
	s.custom_minimum_size = Vector2(340, 24)
	return s
