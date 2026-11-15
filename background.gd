class_name NeonBackground
extends Node2D
## Dark purple gradient, parallax stars and drifting neon shapes. Put it in a CanvasLayer.

var cam: Camera2D
var _stars: Array = []
var _shapes: Array = []
var _t := 0.0
const VP := Vector2(1280, 720)


func _ready() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    for i in 140:
        _stars.append([Vector2(rng.randf() * VP.x, rng.randf() * VP.y), rng.randf_range(0.02, 0.25), rng.randf_range(1.0, 2.8), rng.randf() * TAU])
    for i in 14:
        _shapes.append([Vector2(rng.randf() * VP.x, rng.randf() * VP.y), rng.randf_range(0.1, 0.35), rng.randf_range(18.0, 55.0), rng.randf() * TAU, rng.randf_range(-0.5, 0.5), i % 3])


func _process(delta: float) -> void:
    _t += delta
    queue_redraw()


func _draw() -> void:
    var top := Color(0.02, 0.0, 0.06)
    var bot := Color(0.2, 0.04, 0.3)
    draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(VP.x, 0), VP, Vector2(0, VP.y)]), PackedColorArray([top, top, bot, bot]))
    var off := Vector2(_t * 30.0, 0.0)
    if cam != null and is_instance_valid(cam):
        off = cam.get_screen_center_position()
    for i in range(5, 0, -1):
        draw_circle(Vector2(fposmod(900.0 - off.x * 0.04, VP.x + 200.0) - 100.0, 170.0), 40.0 + i * 14.0, Color(1.0, 0.3, 0.8, 0.035))
    for s in _stars:
        var sp: Vector2 = s[0]
        var p := Vector2(fposmod(sp.x - off.x * float(s[1]), VP.x), fposmod(sp.y - off.y * float(s[1]) * 0.5, VP.y))
        var tw := 0.5 + 0.5 * sin(_t * 2.0 + float(s[3]))
        draw_circle(p, float(s[2]), Color(0.8, 0.85, 1.0, 0.3 + 0.5 * tw))
    var cols := [Color(0.3, 0.6, 1.0, 0.22), Color(0.65, 0.4, 1.0, 0.22), Color(1.0, 0.3, 0.8, 0.22)]
    for sh in _shapes:
        var sp2: Vector2 = sh[0]
        var d := float(sh[1])
        var p2 := Vector2(fposmod(sp2.x - off.x * d - _t * 12.0 * d * 10.0, VP.x + 120.0) - 60.0, fposmod(sp2.y - off.y * d * 0.5 + sin(_t * 0.5 + sp2.x) * 10.0, VP.y + 120.0) - 60.0)
        var r := float(sh[2])
        var col: Color = cols[int(sh[5])]
        draw_set_transform(p2, float(sh[3]) + _t * float(sh[4]), Vector2.ONE)
        match int(sh[5]):
            0: draw_polyline(PackedVector2Array([Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0), Vector2(0, -r)]), col, 2.0)
            1: draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, col, 2.0, true)
            _: draw_rect(Rect2(-r * 0.7, -r * 0.7, r * 1.4, r * 1.4), col, false, 2.0)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
