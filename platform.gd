class_name NeonPlatform
extends AnimatableBody2D
## Reusable platform. Layer 1 (world). One-way so the ball can bounce up through it.

enum Kind { STATIC, MOVING, DISAPPEARING, FALLING }
const THICK := 20.0

var kind: Kind = Kind.STATIC
var width := 240.0
var amp := 70.0
var speed := 1.2
var phase := 0.0

var _origin := Vector2.ZERO
var _t := 0.0
var _shape: CollisionShape2D
var _trigger: Area2D
var _state := 0
var _timer := 0.0
var _fall_v := 0.0
var _solid := true


func _ready() -> void:
    sync_to_physics = true
    collision_layer = 1
    collision_mask = 0
    _origin = position
    _t = phase
    _shape = CollisionShape2D.new()
    var r := RectangleShape2D.new()
    r.size = Vector2(width, THICK)
    _shape.shape = r
    _shape.one_way_collision = true
    add_child(_shape)
    if kind == Kind.FALLING:
        _trigger = Area2D.new()
        _trigger.collision_layer = 0
        _trigger.collision_mask = 2
        var tc := CollisionShape2D.new()
        var tr := RectangleShape2D.new()
        tr.size = Vector2(width - 8.0, 10.0)
        tc.shape = tr
        tc.position = Vector2(0, -THICK * 0.5 - 4.0)
        _trigger.add_child(tc)
        add_child(_trigger)


func _physics_process(delta: float) -> void:
    match kind:
        Kind.MOVING:
            _t += delta
            position.x = _origin.x + sin(_t * speed) * amp
        Kind.DISAPPEARING:
            _t += delta
            var c := fposmod(_t, 3.0)
            var solid := c < 2.0
            if solid != _solid:
                _solid = solid
                _shape.set_deferred("disabled", not solid)
            if not solid:
                modulate.a = 0.12
            elif c > 1.5:
                modulate.a = 0.4 + 0.6 * float(int(c * 12.0) % 2)
            else:
                modulate.a = 1.0
        Kind.FALLING:
            _update_falling(delta)


func _update_falling(delta: float) -> void:
    match _state:
        0:
            if _trigger.has_overlapping_bodies():
                _state = 1
                _timer = 0.45
        1:
            _timer -= delta
            position.x = _origin.x + randf_range(-1.5, 1.5)
            if _timer <= 0.0:
                _state = 2
                _fall_v = 0.0
                _timer = 1.3
        2:
            _fall_v += 1500.0 * delta
            position.y += _fall_v * delta
            _timer -= delta
            if _timer <= 0.0:
                _state = 3
                _timer = 1.0
                _shape.set_deferred("disabled", true)
                modulate.a = 0.0
        3:
            _timer -= delta
            if _timer <= 0.0:
                position = _origin
                _shape.set_deferred("disabled", false)
                modulate.a = 1.0
                _state = 0


func _draw() -> void:
    var c := Color(0.3, 0.6, 1.0)
    match kind:
        Kind.MOVING: c = Color(0.65, 0.4, 1.0)
        Kind.DISAPPEARING: c = Color(1.0, 0.35, 0.8)
        Kind.FALLING: c = Color(1.0, 0.6, 0.25)
    var rect := Rect2(-width * 0.5, -THICK * 0.5, width, THICK)
    for i in range(1, 5):
        draw_rect(rect.grow(i * 2.5), Color(c.r, c.g, c.b, 0.07))
    draw_rect(rect, Color(0.05, 0.02, 0.12))
    draw_rect(rect, c, false, 2.0)
    draw_line(Vector2(-width * 0.5 + 4.0, -THICK * 0.5 + 1.0), Vector2(width * 0.5 - 4.0, -THICK * 0.5 + 1.0), Color(1, 1, 1, 0.55), 1.5)
