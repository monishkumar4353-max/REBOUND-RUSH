class_name Hud
extends CanvasLayer
## In-game UI: score/coins/level/best bar, pause button, pause menu, level-complete screen.

signal pause_toggled
signal restart_requested
signal levels_requested
signal menu_requested
signal next_requested

var _root: Control
var _lbl_level: Label
var _lbl_score: Label
var _lbl_coins: Label
var _lbl_best: Label
var _flash: Label
var _hint: Label
var _pause_ui: Control
var _done_ui: Control
var _done_box: VBoxContainer
var _flash_tw: Tween
var _done_open := false


func _ready() -> void:
    layer = 10
    process_mode = Node.PROCESS_MODE_ALWAYS
    _root = Control.new()
    Game.full_rect(_root)
    _root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_root)
    _build_bar()
    _build_flash_and_hint()
    var p := _make_overlay()
    _pause_ui = p[0]
    var pbox: VBoxContainer = p[1]
    _build_pause_menu(pbox)
    var d := _make_overlay()
    _done_ui = d[0]
    _done_box = d[1]


func _build_bar() -> void:
    var bar := PanelContainer.new()
    bar.add_theme_stylebox_override("panel", Game.make_box(Color(0.06, 0.02, 0.14, 0.8), Color(0.55, 0.3, 1.0)))
    bar.anchor_right = 1.0
    bar.offset_left = 16.0
    bar.offset_right = -16.0
    bar.offset_top = 12.0
    _root.add_child(bar)
    var h := HBoxContainer.new()
    h.add_theme_constant_override("separation", 36)
    bar.add_child(h)
    _lbl_level = Game.make_label("LEVEL 1", 24, Color(0.6, 0.85, 1.0))
    _lbl_score = Game.make_label("SCORE 00000", 24, Color(1.0, 0.4, 0.8))
    _lbl_coins = Game.make_label("COINS 0/0", 24, Color(1.0, 0.85, 0.3))
    _lbl_best = Game.make_label("BEST 00000", 24, Color(0.75, 0.55, 1.0))
    for l in [_lbl_level, _lbl_score, _lbl_coins, _lbl_best]:
        h.add_child(l)
    var sp := Control.new()
    sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    h.add_child(sp)
    var pb := Game.make_button("II  PAUSE", Vector2(150, 40), Color(0.6, 0.4, 1.0), 20)
    pb.pressed.connect(func(): pause_toggled.emit())
    h.add_child(pb)


func _build_flash_and_hint() -> void:
    var fc := CenterContainer.new()
    fc.anchor_right = 1.0
    fc.offset_top = 100.0
    fc.offset_bottom = 190.0
    fc.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.add_child(fc)
    _flash = Game.make_label("", 54, Color(0.5, 0.9, 1.0))
    _flash.add_theme_color_override("font_outline_color", Color(0.8, 0.2, 0.9))
    _flash.add_theme_constant_override("outline_size", 8)
    _flash.modulate.a = 0.0
    fc.add_child(_flash)

    var hc := CenterContainer.new()
    hc.anchor_right = 1.0
    hc.anchor_top = 1.0
    hc.anchor_bottom = 1.0
    hc.offset_top = -100.0
    hc.offset_bottom = -50.0
    hc.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.add_child(hc)
    _hint = Game.make_label("", 24, Color(0.85, 0.8, 1.0))
    _hint.modulate.a = 0.0
    hc.add_child(_hint)


func _make_overlay() -> Array:
    var o := Control.new()
    Game.full_rect(o)
    o.visible = false
    _root.add_child(o)
    var dim := ColorRect.new()
    dim.color = Color(0.02, 0.0, 0.08, 0.75)
    Game.full_rect(dim)
    o.add_child(dim)
    var cc := CenterContainer.new()
    Game.full_rect(cc)
    o.add_child(cc)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 14)
    cc.add_child(v)
    return [o, v]


func _title(text: String, color: Color) -> Label:
    var l := Game.make_label(text, 64, color)
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.add_theme_color_override("font_outline_color", Color(0.8, 0.2, 0.9))
    l.add_theme_constant_override("outline_size", 8)
    return l


func _build_pause_menu(box: VBoxContainer) -> void:
    box.add_child(_title("PAUSED", Color(0.6, 0.9, 1.0)))
    var items := [
        ["RESUME", func(): pause_toggled.emit()],
        ["RESTART", func(): restart_requested.emit()],
        ["LEVEL SELECT", func(): levels_requested.emit()],
        ["MAIN MENU", func(): menu_requested.emit()],
    ]
    for it in items:
        var b := Game.make_button(it[0], Vector2(300, 54))
        b.pressed.connect(it[1])
        box.add_child(b)


# ---------------------------------------------------------------- public API
func set_info(level: int, score: int, coins: int, total: int, best: int) -> void:
    _lbl_level.text = "LEVEL %d" % level
    _lbl_score.text = "SCORE %05d" % score
    _lbl_coins.text = "COINS %d/%d" % [coins, total]
    _lbl_best.text = "BEST %05d" % best


func set_paused(p: bool) -> void:
    _pause_ui.visible = p


func flash(text: String, color: Color = Color(0.5, 0.9, 1.0)) -> void:
    _flash.text = text
    _flash.add_theme_color_override("font_color", color)
    _flash.modulate.a = 1.0
    if _flash_tw != null and _flash_tw.is_valid():
        _flash_tw.kill()
    _flash_tw = create_tween()
    _flash_tw.tween_interval(1.0)
    _flash_tw.tween_property(_flash, "modulate:a", 0.0, 0.7)


func set_hint(text: String, seconds: float = 8.0) -> void:
    _hint.text = text
    _hint.modulate.a = 1.0
    var tw := create_tween()
    tw.tween_interval(seconds)
    tw.tween_property(_hint, "modulate:a", 0.0, 1.0)


func show_complete(title: String, stats: String, has_next: bool) -> void:
    _done_open = true
    _pause_ui.visible = false
    for c in _done_box.get_children():
        c.queue_free()
    _done_box.add_child(_title(title, Color(1.0, 0.85, 0.4)))
    var s := Game.make_label(stats, 28, Color(0.9, 0.9, 1.0))
    s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _done_box.add_child(s)
    if has_next:
        var n := Game.make_button("NEXT LEVEL", Vector2(300, 54), Color(0.4, 1.0, 0.8))
        n.pressed.connect(func(): next_requested.emit())
        _done_box.add_child(n)
    var r := Game.make_button("REPLAY", Vector2(300, 54))
    r.pressed.connect(func(): restart_requested.emit())
    _done_box.add_child(r)
    var l := Game.make_button("LEVEL SELECT", Vector2(300, 54), Color(0.7, 0.45, 1.0))
    l.pressed.connect(func(): levels_requested.emit())
    _done_box.add_child(l)
    _done_ui.visible = true


func _unhandled_input(event: InputEvent) -> void:
    if _done_open:
        return
    if event.is_action_pressed("pause"):
        pause_toggled.emit()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("restart"):
        restart_requested.emit()
