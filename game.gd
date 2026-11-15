extends Node
## Autoload "Game": save data, settings, procedural audio, UI helpers, transitions.

const RATE := 22050
const MUSIC_RATE := 16000
const SAVE_PATH := "user://bounce_back.cfg"
const LEVEL_COUNT := 10

var current_level := 1
var unlocked := 1
var best_scores := {}
var music_vol := 0.7
var sfx_vol := 0.8
var open_levels := false

var _sfx := {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _fade: ColorRect
var _busy := false


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _register_inputs()
    load_game()
    _setup_audio()
    _setup_fade()
    apply_volumes()
    _music_player.play()


# ---------------------------------------------------------------- input map
func _register_inputs() -> void:
    var map := {
        "move_left": [KEY_A, KEY_LEFT],
        "move_right": [KEY_D, KEY_RIGHT],
        "jump": [KEY_SPACE, KEY_W, KEY_UP],
        "pause": [KEY_ESCAPE, KEY_P],
        "restart": [KEY_R],
    }
    for action in map:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
        for k in map[action]:
            var e := InputEventKey.new()
            e.physical_keycode = k
            InputMap.action_add_event(action, e)


# --------------------------------------------------------------- save / load
func load_game() -> void:
    var cf := ConfigFile.new()
    if cf.load(SAVE_PATH) != OK:
        return
    unlocked = int(cf.get_value("progress", "unlocked", 1))
    music_vol = float(cf.get_value("audio", "music", 0.7))
    sfx_vol = float(cf.get_value("audio", "sfx", 0.8))
    for i in range(1, LEVEL_COUNT + 1):
        best_scores[i] = int(cf.get_value("scores", "l%d" % i, 0))


func save_game() -> void:
    var cf := ConfigFile.new()
    cf.set_value("progress", "unlocked", unlocked)
    cf.set_value("audio", "music", music_vol)
    cf.set_value("audio", "sfx", sfx_vol)
    for i in range(1, LEVEL_COUNT + 1):
        cf.set_value("scores", "l%d" % i, int(best_scores.get(i, 0)))
    cf.save(SAVE_PATH)


func total_best() -> int:
    var t := 0
    for i in range(1, LEVEL_COUNT + 1):
        t += int(best_scores.get(i, 0))
    return t


func complete_level(lv: int, score: int) -> void:
    if score > int(best_scores.get(lv, 0)):
        best_scores[lv] = score
    unlocked = maxi(unlocked, mini(lv + 1, LEVEL_COUNT))
    save_game()


func reset_progress() -> void:
    unlocked = 1
    best_scores.clear()
    save_game()


# ------------------------------------------------------------------- audio
func _setup_audio() -> void:
    for n in ["Music", "SFX"]:
        if AudioServer.get_bus_index(n) == -1:
            AudioServer.add_bus()
            var idx := AudioServer.bus_count - 1
            AudioServer.set_bus_name(idx, n)
            AudioServer.set_bus_send(idx, "Master")
    _sfx["bounce"] = _synth([260.0], 0.12, 0, 0.5, 6.0, 1.2)
    _sfx["jump"] = _synth([400.0], 0.18, 0, 0.45, 4.0, 1.5)
    _sfx["coin"] = _synth([988.0, 1319.0], 0.09, 1, 0.28, 4.0, 0.0)
    _sfx["death"] = _synth([220.0, 196.0, 165.0, 110.0], 0.14, 2, 0.4, 3.0, -0.2)
    _sfx["win"] = _synth([523.0, 659.0, 784.0, 1047.0, 784.0, 1047.0], 0.14, 1, 0.3, 3.0, 0.0)
    _sfx["checkpoint"] = _synth([660.0, 880.0], 0.12, 0, 0.45, 3.0, 0.0)
    _sfx["click"] = _synth([700.0], 0.05, 1, 0.22, 6.0, 0.0)
    _sfx["stomp"] = _synth([200.0], 0.12, 2, 0.45, 5.0, -0.6)
    for i in 8:
        var p := AudioStreamPlayer.new()
        p.bus = "SFX"
        add_child(p)
        _sfx_players.append(p)
    _music_player = AudioStreamPlayer.new()
    _music_player.bus = "Music"
    _music_player.stream = _make_music()
    _music_player.volume_db = -3.0
    add_child(_music_player)


func _synth(freqs: Array, note_dur: float, wave: int, vol: float, decay: float, slide: float) -> AudioStreamWAV:
    var per := int(RATE * note_dur)
    var data := PackedByteArray()
    data.resize(per * freqs.size() * 2)
    var idx := 0
    for f in freqs:
        var ph := 0.0
        for i in per:
            var t := float(i) / RATE
            ph += (float(f) * (1.0 + slide * t / note_dur)) / RATE
            var v := 0.0
            match wave:
                0: v = sin(TAU * ph)
                1: v = signf(sin(TAU * ph))
                2: v = fposmod(ph, 1.0) * 2.0 - 1.0
                _: v = randf() * 2.0 - 1.0
            v *= vol * exp(-decay * t / note_dur)
            data.encode_s16(idx * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
            idx += 1
    var st := AudioStreamWAV.new()
    st.format = AudioStreamWAV.FORMAT_16_BITS
    st.mix_rate = RATE
    st.stereo = false
    st.data = data
    return st


func _mtof(m: int) -> float:
    return 440.0 * pow(2.0, (m - 69) / 12.0)


func _make_music() -> AudioStreamWAV:
    var rate := MUSIC_RATE
    var step_len := 0.22
    var steps := 32
    var per := int(rate * step_len)
    var data := PackedByteArray()
    data.resize(per * steps * 2)
    var roots := [45, 41, 48, 43]
    var arp := [0, 7, 12, 15, 12, 7, 3, 7]
    for s in steps:
        var root: int = roots[s >> 3]
        var bf := _mtof(root)
        var af := _mtof(root + 24 + int(arp[s % 8]))
        for i in per:
            var t := float(i) / rate
            var v := 0.0
            v += (fposmod(t * bf, 1.0) * 2.0 - 1.0) * 0.2 * exp(-t * 4.0)
            v += signf(sin(TAU * af * t)) * 0.07 * exp(-t * 9.0)
            if s % 2 == 0:
                v += sin(TAU * (55.0 * t + 6.0 * (1.0 - exp(-t * 30.0)))) * 0.45 * exp(-t * 14.0)
            else:
                v += (randf() * 2.0 - 1.0) * 0.05 * exp(-t * 40.0)
            data.encode_s16((s * per + i) * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
    var st := AudioStreamWAV.new()
    st.format = AudioStreamWAV.FORMAT_16_BITS
    st.mix_rate = rate
    st.stereo = false
    st.data = data
    st.loop_mode = AudioStreamWAV.LOOP_FORWARD
    st.loop_begin = 0
    st.loop_end = per * steps
    return st


func play_sfx(sfx_name: String, pitch: float = 1.0) -> void:
    if not _sfx.has(sfx_name):
        return
    var target: AudioStreamPlayer = _sfx_players[0]
    for p in _sfx_players:
        if not p.playing:
            target = p
            break
    target.stream = _sfx[sfx_name]
    target.pitch_scale = pitch
    target.play()


func apply_volumes() -> void:
    _set_bus("Music", music_vol)
    _set_bus("SFX", sfx_vol)


func _set_bus(bus_name: String, v: float) -> void:
    var i := AudioServer.get_bus_index(bus_name)
    AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
    AudioServer.set_bus_mute(i, v <= 0.001)


func set_music_vol(v: float) -> void:
    music_vol = v
    apply_volumes()
    save_game()


func set_sfx_vol(v: float) -> void:
    sfx_vol = v
    apply_volumes()
    save_game()


# -------------------------------------------------------------- transitions
func _setup_fade() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 100
    add_child(layer)
    _fade = ColorRect.new()
    _fade.color = Color(0, 0, 0, 0)
    _fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    full_rect(_fade)
    layer.add_child(_fade)


func goto(path: String) -> void:
    if _busy:
        return
    _busy = true
    get_tree().paused = false
    var tw := create_tween()
    tw.tween_property(_fade, "color:a", 1.0, 0.3)
    await tw.finished
    get_tree().change_scene_to_file(path)
    await get_tree().process_frame
    var tw2 := create_tween()
    tw2.tween_property(_fade, "color:a", 0.0, 0.35)
    await tw2.finished
    _busy = false


# ------------------------------------------------------------------ helpers
func burst(parent: Node, pos: Vector2, color: Color, amount: int = 30, speed: float = 260.0) -> void:
    var p := CPUParticles2D.new()
    p.position = pos
    p.one_shot = true
    p.amount = amount
    p.lifetime = 0.7
    p.explosiveness = 1.0
    p.direction = Vector2.UP
    p.spread = 180.0
    p.initial_velocity_min = speed * 0.4
    p.initial_velocity_max = speed
    p.gravity = Vector2(0, 500)
    p.scale_amount_min = 2.0
    p.scale_amount_max = 4.5
    p.color = color
    var g := Gradient.new()
    g.set_color(0, Color(1, 1, 1, 1))
    g.set_color(1, Color(1, 1, 1, 0))
    p.color_ramp = g
    parent.add_child(p)
    p.emitting = true
    get_tree().create_timer(1.2).timeout.connect(p.queue_free)


func add_glow(parent: Node) -> void:
    var we := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_CANVAS
    env.glow_enabled = true
    env.glow_intensity = 0.8
    env.glow_strength = 1.0
    env.glow_bloom = 0.08
    env.glow_hdr_threshold = 0.8
    env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
    we.environment = env
    parent.add_child(we)


func full_rect(c: Control) -> void:
    c.anchor_left = 0.0
    c.anchor_top = 0.0
    c.anchor_right = 1.0
    c.anchor_bottom = 1.0
    c.offset_left = 0.0
    c.offset_top = 0.0
    c.offset_right = 0.0
    c.offset_bottom = 0.0


func make_label(text: String, size: int = 24, color: Color = Color.WHITE) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    return l


func make_box(bg: Color, border: Color, radius: int = 12) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(2)
    s.set_corner_radius_all(radius)
    s.shadow_color = Color(border.r, border.g, border.b, 0.4)
    s.shadow_size = 8
    s.content_margin_left = 16.0
    s.content_margin_right = 16.0
    s.content_margin_top = 8.0
    s.content_margin_bottom = 8.0
    return s


func make_button(text: String, min_size: Vector2 = Vector2(260, 56), accent: Color = Color(0.35, 0.8, 1.0), font_size: int = 24) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = min_size
    b.focus_mode = Control.FOCUS_NONE
    b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    b.add_theme_font_size_override("font_size", font_size)
    b.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
    b.add_theme_color_override("font_hover_color", Color.WHITE)
    b.add_theme_color_override("font_disabled_color", Color(0.45, 0.4, 0.55))
    b.add_theme_stylebox_override("normal", make_box(Color(0.08, 0.03, 0.18, 0.92), accent))
    b.add_theme_stylebox_override("hover", make_box(Color(accent.r * 0.35, accent.g * 0.35, accent.b * 0.35, 0.95), accent))
    b.add_theme_stylebox_override("pressed", make_box(Color(accent.r * 0.55, accent.g * 0.55, accent.b * 0.55, 1.0), Color.WHITE))
    b.add_theme_stylebox_override("disabled", make_box(Color(0.05, 0.03, 0.1, 0.8), Color(0.3, 0.25, 0.4)))
    b.pressed.connect(func(): play_sfx("click"))
    return b
