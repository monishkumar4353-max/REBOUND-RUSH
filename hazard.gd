class_name Hazard
extends Area2D
## Reusable hazard. Layer 3 (hazards), mask 2 (player). Polls overlaps each physics frame.

enum Kind { SPIKE, SLIDER, ROTOR, LASER, ENEMY }

signal stomped(pos: Vector2)

var kind: Kind = Kind.SPIKE
var size := Vector2(70, 16)
var amp := 100.0
var speed := 1.5
var phase := 0.0
var length := 52.0

var _origin := Vector2.ZERO
var _t := 0.0
var _active := true
var _warn := false
var _dead := false


func _ready() -> void:
    collision_layer = 4
    collision_mask = 2
    monitorable = false
    _origin = position
    _t = phase
    match kind:
        Kind.SPIKE:
            _add_rect(Vector2(size.x - 8.0, size.y - 4.0), Vector2(0, -size.y * 0.5))
        Kind.SLIDER:
            _add_rect(Vector2(36, 26), Vector2(0, -13))
        Kind.ROTOR:
            _add_rect(Vector2(length * 2.0, 9.0), Vector2.ZERO)
            _add_rect(Vector2(9.0, length * 2.0), Vector2.ZERO)
        Kind.LASER:
            _add_rect(Vector2(8.0, size.y), Vector2(0, -size.y * 0.5))
        Kind.ENEMY:
            var cs := CollisionShape2D.new()
            var c := CircleShape2D.new()
            c.radius = 14.0
            cs.shape = c
            cs.position = Vector2(0, -14)
            add_child(cs)
    queue_redraw()


func _add_rect(s: Vector2, pos: Vector2) -> void:
    var cs := CollisionShape2D.new()
    var r := RectangleShape2D.new()
    r.size = s
    cs.shape = r
    cs.position = pos
    add_child(cs)


func _physics_process(delta: float) -> void:
    _t += delta
    match kind:
        Kind.SLIDER, Kind.ENEMY:
            position.x = _origin.x + sin(_t * speed) * amp
        Kind.ROTOR:
            rotation += speed * delta
        Kind.LASER:
            var c := fposmod(_t, 2.8)
            _active = c < 1.3
            _warn = c >= 2.5
    if kind != Kind.SPIKE:
        queue_redraw()
    if _dead or (kind == Kind.LASER and not _active):
        return
    for b in get_overlapping_bodies():
        if b is Player and b.alive:
            if kind == Kind.ENEMY and b.velocity.y > 0.0 and b.global_position.y < global_position.y - 16.0:
                _dead = true
                b.stomp_bounce()
                stomped.emit(global_position)
                Game.burst(get_parent(), global_position + Vector2(0, -14), Color(0.8, 0.4, 1.0), 24, 260.0)
                queue_free()
                return
            b.die()


func _draw() -> void:
    var pink := Color(1.0, 0.25, 0.55)
    match kind:
        Kind.SPIKE:
            var n := maxi(1, int(size.x / 16.0))
            var sw := size.x / n
            for i in n:
                var x0 := -size.x * 0.5 + i * sw
                var tri := PackedVector2Array([Vector2(x0, 0), Vector2(x0 + sw, 0), Vector2(x0 + sw * 0.5, -size.y)])
                draw_colored_polygon(tri, Color(0.15, 0.02, 0.1))
                var edge := PackedVector2Array([tri[0], tri[2], tri[1]])
                draw_polyline(edge, Color(pink.r, pink.g, pink.b, 0.3), 6.0)
                draw_polyline(edge, pink, 2.0)
        Kind.SLIDER:
            draw_rect(Rect2(-22, -30, 44, 34), Color(pink.r, pink.g, pink.b, 0.15))
            draw_rect(Rect2(-18, -26, 36, 26), Color(0.15, 0.02, 0.1))
            draw_rect(Rect2(-18, -26, 36, 26), pink, false, 2.0)
            for k in 3:
                var x0 := -18.0 + k * 12.0
                var tri := PackedVector2Array([Vector2(x0, -26), Vector2(x0 + 12, -26), Vector2(x0 + 6, -38)])
                draw_colored_polygon(tri, pink)
        Kind.ROTOR:
            for r in [Rect2(-length, -4.5, length * 2.0, 9.0), Rect2(-4.5, -length, 9.0, length * 2.0)]:
                draw_rect(r.grow(4.0), Color(pink.r, pink.g, pink.b, 0.2))
                draw_rect(r, Color(0.2, 0.02, 0.12))
                draw_rect(r, pink, false, 2.0)
            draw_circle(Vector2.ZERO, 9.0, Color(1.0, 0.8, 0.9))
        Kind.LASER:
            var post := Color(0.6, 0.6, 0.9)
            draw_rect(Rect2(-9, -4, 18, 8), post)
            draw_rect(Rect2(-9, -size.y - 4.0, 18, 8), post)
            if _active:
                draw_line(Vector2(0, 0), Vector2(0, -size.y), Color(1, 0.15, 0.3, 0.25), 16.0)
                draw_line(Vector2(0, 0), Vector2(0, -size.y), Color(1, 0.25, 0.4, 0.8), 6.0)
                draw_line(Vector2(0, 0), Vector2(0, -size.y), Color(1, 1, 1, 0.9), 2.0)
            elif _warn and int(_t * 20.0) % 2 == 0:
                draw_line(Vector2(0, 0), Vector2(0, -size.y), Color(1, 0.3, 0.4, 0.3), 2.0)
        Kind.ENEMY:
            var bob := sin(_t * 3.0) * 2.0
            var c := Color(0.75, 0.35, 1.0)
            var ctr := Vector2(0, -14.0 + bob)
            for i in range(4, 0, -1):
                draw_circle(ctr, 14.0 + i * 3.0, Color(c.r, c.g, c.b, 0.07))
            draw_circle(ctr, 14.0, Color(0.15, 0.05, 0.3))
            draw_arc(ctr, 14.0, 0.0, TAU, 28, c, 2.5, true)
            var look := signf(cos(_t * speed)) * 2.0
            draw_circle(ctr + Vector2(-5, -3), 4.0, Color.WHITE)
            draw_circle(ctr + Vector2(5, -3), 4.0, Color.WHITE)
            draw_circle(ctr + Vector2(-5 + look, -3), 2.0, Color(0.1, 0.0, 0.2))
            draw_circle(ctr + Vector2(5 + look, -3), 2.0, Color(0.1, 0.0, 0.2))
            draw_line(ctr + Vector2(-9, -9), ctr + Vector2(-2, -6), Color.WHITE, 2.0)
            draw_line(ctr + Vector2(9, -9), ctr + Vector2(2, -6), Color.WHITE, 2.0)
