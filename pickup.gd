class_name Pickup
extends Area2D
## Coin (layer 4), Checkpoint and Portal (layer 5). Mask 2 (player).

enum Kind { COIN, CHECKPOINT, PORTAL }

signal collected(pickup: Pickup)

var kind: Kind = Kind.COIN
var active := false
var _t := 0.0
var _taken := false


func _ready() -> void:
    collision_mask = 2
    monitorable = false
    var cs := CollisionShape2D.new()
    match kind:
        Kind.COIN:
            collision_layer = 8
            var c := CircleShape2D.new()
            c.radius = 14.0
            cs.shape = c
        Kind.CHECKPOINT:
            collision_layer = 16
            var r := RectangleShape2D.new()
            r.size = Vector2(36, 70)
            cs.shape = r
            cs.position = Vector2(0, -35)
        Kind.PORTAL:
            collision_layer = 16
            var c2 := CircleShape2D.new()
            c2.radius = 34.0
            cs.shape = c2
    add_child(cs)
    body_entered.connect(_on_body)
    _t = randf() * TAU


func _on_body(b: Node2D) -> void:
    var pl := b as Player
    if _taken or pl == null or not pl.alive:
        return
    if kind == Kind.CHECKPOINT and active:
        return
    if kind == Kind.COIN:
        _taken = true
    if kind == Kind.CHECKPOINT:
        active = true
    collected.emit(self)
    if kind == Kind.COIN:
        queue_free()


func _process(delta: float) -> void:
    _t += delta
    queue_redraw()


func _draw() -> void:
    match kind:
        Kind.COIN:
            var sx := maxf(0.2, absf(cos(_t * 3.0)))
            draw_set_transform(Vector2.ZERO, 0.0, Vector2(sx, 1.0))
            for i in range(3, 0, -1):
                draw_circle(Vector2.ZERO, 12.0 + i * 3.0, Color(1.0, 0.8, 0.2, 0.08))
            draw_circle(Vector2.ZERO, 11.0, Color(1.0, 0.85, 0.25))
            draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 20, Color(0.8, 0.5, 0.1), 2.0, true)
        Kind.CHECKPOINT:
            var col := Color(0.3, 1.0, 0.8) if active else Color(0.5, 0.4, 0.8)
            draw_line(Vector2(0, 0), Vector2(0, -56), col, 3.0)
            var flag := PackedVector2Array([Vector2(0, -56), Vector2(26, -46 + sin(_t * 4.0) * 2.0), Vector2(0, -36)])
            draw_colored_polygon(flag, col)
            if active:
                for i in range(3, 0, -1):
                    draw_circle(Vector2(0, -46), 10.0 + i * 5.0, Color(col.r, col.g, col.b, 0.06))
        Kind.PORTAL:
            for i in range(5, 0, -1):
                draw_circle(Vector2.ZERO, 14.0 + i * 8.0, Color(0.8, 0.3, 1.0, 0.05))
            for i in 5:
                var dirn := 1.0 if i % 2 == 0 else -1.0
                var a := _t * (1.0 + i * 0.35) * dirn
                var col2 := Color(0.4, 0.7, 1.0).lerp(Color(1.0, 0.3, 0.9), i / 4.0)
                draw_arc(Vector2.ZERO, 10.0 + i * 6.5, a, a + TAU * 0.72, 28, col2, 3.0, true)
