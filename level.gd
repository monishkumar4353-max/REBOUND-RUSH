extends Node2D
## Level scene root (level.tscn). Builds the whole level at runtime from LevelGen data.
##
## Runtime tree:
##   Level (Node2D, this script)
##   ├─ CanvasLayer (layer -10) └─ NeonBackground
##   ├─ WorldEnvironment (neon glow)
##   ├─ World (Node2D)  ── NeonPlatform / Hazard / Pickup instances
##   ├─ Player (CharacterBody2D) └─ Camera2D
##   └─ Hud (CanvasLayer)

const CAM_BASE := Vector2(0, -60)

var level := 1
var data := {}
var player: Player
var cam: Camera2D
var hud: Hud
var world: Node2D
var coins := 0
var total_coins := 0
var stomps := 0
var deaths := 0
var time := 0.0
var spawn_pos := Vector2.ZERO
var goal_pos := Vector2.ZERO
var finished := false
var _shake := 0.0
var _kill_y := 900.0
var _final := 0
var _new_best := false


func _ready() -> void:
    get_tree().paused = false
    level = Game.current_level
    data = LevelGen.build(level)
    _kill_y = float(data["kill_y"])

    var bgl := CanvasLayer.new()
    bgl.layer = -10
    add_child(bgl)
    var bg := NeonBackground.new()
    bgl.add_child(bg)
    Game.add_glow(self)

    world = Node2D.new()
    world.name = "World"
    add_child(world)
    _build_world()

    player = Player.new()
    player.name = "Player"
    player.position = spawn_pos
    add_child(player)
    player.died.connect(_on_player_died)
    player.landed.connect(_on_landed)

    cam = Camera2D.new()
    cam.position_smoothing_enabled = true
    cam.position_smoothing_speed = 7.0
    cam.limit_left = -300
    cam.limit_right = int(data["end_x"]) + 500
    cam.limit_bottom = 760
    cam.offset = CAM_BASE
    player.add_child(cam)
    cam.make_current()
    bg.cam = cam

    hud = Hud.new()
    add_child(hud)
    hud.pause_toggled.connect(_toggle_pause)
    hud.restart_requested.connect(_restart)
    hud.levels_requested.connect(_to_levels)
    hud.menu_requested.connect(_to_menu)
    hud.next_requested.connect(_next)
    hud.flash("LEVEL %d  -  %s" % [level, data["name"]])
    if String(data["hint"]) != "":
        hud.set_hint(String(data["hint"]), 9.0)


func _build_world() -> void:
    var plats: Array = data["platforms"]
    for p in plats:
        var pl := NeonPlatform.new()
        pl.kind = p["kind"]
        pl.width = p["w"]
        pl.amp = p["amp"]
        pl.speed = p["speed"]
        pl.phase = p["phase"]
        pl.position = Vector2(p["x"], p["y"] + NeonPlatform.THICK * 0.5)
        world.add_child(pl)
    spawn_pos = Vector2(float(plats[0]["x"]) - 100.0, float(plats[0]["y"]) - 50.0)

    for h in data["hazards"]:
        var hz := Hazard.new()
        hz.kind = h["kind"]
        hz.position = Vector2(h["x"], h["y"])
        hz.size = h.get("size", Vector2(70, 16))
        hz.amp = h.get("amp", 100.0)
        hz.speed = h.get("speed", 1.5)
        hz.phase = h.get("phase", 0.0)
        hz.length = h.get("length", 52.0)
        hz.stomped.connect(_on_stomp)
        world.add_child(hz)

    for c in data["coins"]:
        var pk := Pickup.new()
        pk.kind = Pickup.Kind.COIN
        pk.position = c
        pk.collected.connect(_on_pickup)
        world.add_child(pk)
        total_coins += 1

    for c in data["checkpoints"]:
        var cp := Pickup.new()
        cp.kind = Pickup.Kind.CHECKPOINT
        cp.position = c
        cp.collected.connect(_on_pickup)
        world.add_child(cp)

    goal_pos = data["goal"]
    var goal := Pickup.new()
    goal.kind = Pickup.Kind.PORTAL
    goal.position = goal_pos
    goal.collected.connect(_on_pickup)
    world.add_child(goal)


func _process(delta: float) -> void:
    if not finished:
        time += delta
    _shake = move_toward(_shake, 0.0, 45.0 * delta)
    cam.offset = CAM_BASE + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
    hud.set_info(level, _score(), coins, total_coins, int(Game.best_scores.get(level, 0)))


func _physics_process(_delta: float) -> void:
    if not finished and player.alive and player.global_position.y > _kill_y:
        player.die()


func _score() -> int:
    return coins * 100 + stomps * 50


func _final_score() -> int:
    return maxi(0, _score() + maxi(0, int((90.0 - time) * 10.0)) - deaths * 25)


# ------------------------------------------------------------------ events
func _on_landed(fall_speed: float) -> void:
    if fall_speed > 1100.0:
        _shake = maxf(_shake, 3.0)


func _on_stomp(_pos: Vector2) -> void:
    stomps += 1
    _shake = maxf(_shake, 5.0)
    Game.play_sfx("stomp")


func _on_pickup(pk: Pickup) -> void:
    match pk.kind:
        Pickup.Kind.COIN:
            coins += 1
            Game.play_sfx("coin", 1.0 + float(coins % 8) * 0.05)
            Game.burst(world, pk.global_position, Color(1.0, 0.85, 0.3), 12, 160.0)
        Pickup.Kind.CHECKPOINT:
            spawn_pos = pk.global_position + Vector2(0, -40)
            Game.play_sfx("checkpoint")
            hud.flash("CHECKPOINT", Color(0.4, 1.0, 0.8))
        Pickup.Kind.PORTAL:
            _finish()


func _on_player_died() -> void:
    deaths += 1
    _shake = 14.0
    get_tree().create_timer(0.9).timeout.connect(_respawn)


func _respawn() -> void:
    if finished:
        return
    player.respawn(spawn_pos)
    cam.reset_smoothing()


func _finish() -> void:
    if finished:
        return
    finished = true
    player.set_physics_process(false)
    player.velocity = Vector2.ZERO
    Game.play_sfx("win")
    Game.burst(world, goal_pos, Color(1.0, 0.5, 1.0), 80, 420.0)
    _shake = 6.0
    _final = _final_score()
    _new_best = _final > int(Game.best_scores.get(level, 0))
    Game.complete_level(level, _final)
    get_tree().create_timer(0.9).timeout.connect(_show_complete)


func _show_complete() -> void:
    var stats := "Score  %d\nCoins  %d / %d\nTime  %.1f s\nDeaths  %d" % [_final, coins, total_coins, time, deaths]
    if _new_best:
        stats += "\nNEW BEST!"
    var last := level >= Game.LEVEL_COUNT
    hud.show_complete("YOU WIN!" if last else "LEVEL COMPLETE", stats, not last)


# ------------------------------------------------------------ navigation
func _toggle_pause() -> void:
    if finished:
        return
    var p := not get_tree().paused
    get_tree().paused = p
    hud.set_paused(p)


func _restart() -> void:
    Game.goto("res://level.tscn")


func _next() -> void:
    Game.current_level = mini(level + 1, Game.LEVEL_COUNT)
    Game.goto("res://level.tscn")


func _to_levels() -> void:
    Game.open_levels = true
    Game.goto("res://menu.tscn")


func _to_menu() -> void:
    Game.goto("res://menu.tscn")
