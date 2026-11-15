class_name Player
extends CharacterBody2D
## The glowing ball. Collision layer 2 (player), mask 1 (world/platforms).

signal died
signal landed(fall_speed: float)

const GRAVITY := 1800.0
const BOUNCE_SPEED := -880.0
const AIR_JUMP_SPEED := -820.0
const MOVE_SPEED := 330.0
const RADIUS := 14.0

var alive := true
var air_jump_ready := true
var _jump_buffer := 0.0
var _squash := Vector2.ONE
var _trail: CPUParticles2D


func _ready() -> void:
    collision_layer = 2
    collision_mask = 1
    floor_snap_length = 0.0
    var cs := CollisionShape2D.new()
    var sh := CircleShape2D.new()
    sh.radius = RADIUS
    cs.shape = sh
    add_child(cs)

    _trail = CPUParticles2D.new()
    _trail.show_behind_parent = true
    _trail.local_coords = false
    _trail.amount = 36
    _trail.lifetime = 0.45
    _trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
    _trail.emission_sphere_radius = 7.0
    _trail.gravity = Vector2.ZERO
    _trail.initial_velocity_min = 0.0
    _trail.initial_velocity_max = 25.0
    _trail.spread = 180.0
    _trail.scale_amount_min = 3.0
    _trail.scale_amount_max = 6.0
    _trail.color = Color(0.45, 0.85, 1.3, 0.8)
    var g := Gradient.new()
    g.set_color(0, Color(1, 1, 1, 0.9))
    g.set_color(1, Color(1, 0.4, 1, 0.0))
    _trail.color_ramp = g
    add_child(_trail)


func _physics_process(delta: float) -> void:
    if not alive:
        return
    var dir := Input.get_axis("move_left", "move_right")
    var accel := 3200.0 if is_on_floor() else 2000.0
    velocity.x = move_toward(velocity.x, dir * MOVE_SPEED, accel * delta)
    velocity.y += GRAVITY * delta

    if Input.is_action_just_pressed("jump"):
        _jump_buffer = 0.12
    _jump_buffer -= delta
    if _jump_buffer > 0.0 and air_jump_ready and not is_on_floor():
        velocity.y = AIR_JUMP_SPEED
        air_jump_ready = false
        _jump_buffer = 0.0
        _squash = Vector2(0.65, 1.45)
        Game.play_sfx("jump")
        Game.burst(get_parent(), global_position + Vector2(0, 10), Color(0.5, 0.9, 1.0), 10, 120.0)

    var fall_speed := velocity.y
    move_and_slide()

    if is_on_floor() and fall_speed > 0.0:
        velocity.y = BOUNCE_SPEED
        air_jump_ready = true
        _squash = Vector2(1.5, 0.55)
        Game.play_sfx("bounce", randf_range(0.95, 1.1))
        landed.emit(fall_speed)

    var vs := clampf(absf(velocity.y) / 2200.0, 0.0, 0.3)
    var target := Vector2(1.0 - vs * 0.5, 1.0 + vs)
    _squash = _squash.lerp(target, clampf(16.0 * delta, 0.0, 1.0))
    queue_redraw()


func _draw() -> void:
    if not alive:
        return
    draw_set_transform(Vector2.ZERO, 0.0, _squash)
    for i in range(8, 0, -1):
        draw_circle(Vector2.ZERO, RADIUS + i * 3.0, Color(0.35, 0.7, 1.0, 0.045))
    draw_circle(Vector2.ZERO, RADIUS, Color(0.55, 0.9, 1.0))
    draw_arc(Vector2.ZERO, RADIUS - 1.0, 0.0, TAU, 32, Color(1.0, 0.3, 0.9), 2.5, true)
    draw_circle(Vector2(-4, -5), 4.5, Color(1, 1, 1, 0.9))


func die() -> void:
    if not alive:
        return
    alive = false
    velocity = Vector2.ZERO
    visible = false
    _trail.emitting = false
    Game.burst(get_parent(), global_position, Color(1.0, 0.3, 0.8), 50, 380.0)
    Game.play_sfx("death")
    died.emit()


func respawn(pos: Vector2) -> void:
    global_position = pos
    velocity = Vector2.ZERO
    alive = true
    visible = true
    air_jump_ready = true
    _trail.restart()
    _trail.emitting = true


func stomp_bounce() -> void:
    velocity.y = BOUNCE_SPEED * 1.1
    air_jump_ready = true
