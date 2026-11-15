class_name LevelGen
extends RefCounted
## Deterministic generator for the 10 levels. Same seed per level => same layout every run.
## Gaps/height steps are kept inside what the ball can physically reach
## (bounce apex ~225px, ~330px horizontal per bounce, plus an extra air jump).

const NAMES := ["First Bounce", "Moving On", "Spike Pit", "Danger Zone", "Now You See Me", "Laser Grid", "Razor Edge", "Chaos Theory", "Neon Nightmare", "The Portal"]
const HINTS := [
    "A / D or Arrow keys to move  -  SPACE for an extra jump  -  Reach the portal!",
    "Moving platforms carry you - time your landings.",
    "Spikes! Land beside them and hop over.",
    "Stomp the purple blobs from above. Dodge the spinners!",
    "Platforms flicker and vanish - keep bouncing!",
    "Lasers pulse on a timer. Cross when they are off, or clear them at your apex.",
    "", "", "", "",
]
const ALL := ["spike", "slider", "rotor", "laser", "enemy"]


static func params(lv: int) -> Dictionary:
    var p := {"seg": 10, "gmin": 90.0, "gmax": 140.0, "wmin": 240.0, "wmax": 340.0, "dy": 35.0,
        "moving": 0.0, "disap": 0.0, "fall": 0.0, "feat": [], "fchance": 0.0}
    match lv:
        1:
            p["seg"] = 9
        2:
            p["seg"] = 12; p["gmin"] = 100.0; p["gmax"] = 160.0; p["moving"] = 0.5
        3:
            p["seg"] = 14; p["gmin"] = 120.0; p["gmax"] = 200.0; p["wmin"] = 280.0; p["dy"] = 50.0
            p["feat"] = ["spike"]; p["fchance"] = 0.7
        4:
            p["seg"] = 16; p["gmin"] = 110.0; p["gmax"] = 180.0; p["wmin"] = 280.0; p["dy"] = 50.0; p["moving"] = 0.2
            p["feat"] = ["slider", "rotor", "enemy"]; p["fchance"] = 0.6
        5:
            p["seg"] = 16; p["gmin"] = 110.0; p["gmax"] = 190.0; p["dy"] = 50.0; p["disap"] = 0.5
            p["feat"] = ["spike", "enemy"]; p["fchance"] = 0.35
        6:
            p["seg"] = 18; p["gmin"] = 120.0; p["gmax"] = 190.0; p["wmin"] = 280.0; p["dy"] = 50.0; p["moving"] = 0.2; p["disap"] = 0.2
            p["feat"] = ["laser", "spike"]; p["fchance"] = 0.6
        7:
            p["seg"] = 20; p["gmin"] = 170.0; p["gmax"] = 250.0; p["wmin"] = 140.0; p["wmax"] = 300.0; p["dy"] = 70.0
            p["fall"] = 0.3; p["disap"] = 0.15
            p["feat"] = ["spike", "enemy"]; p["fchance"] = 0.4
        8:
            p["seg"] = 22; p["gmin"] = 150.0; p["gmax"] = 220.0; p["wmin"] = 200.0; p["wmax"] = 330.0; p["dy"] = 70.0
            p["moving"] = 0.15; p["disap"] = 0.15; p["fall"] = 0.15
            p["feat"] = ALL; p["fchance"] = 0.7
        9:
            p["seg"] = 26; p["gmin"] = 190.0; p["gmax"] = 270.0; p["wmin"] = 130.0; p["wmax"] = 280.0; p["dy"] = 90.0
            p["moving"] = 0.2; p["disap"] = 0.25; p["fall"] = 0.2
            p["feat"] = ALL; p["fchance"] = 0.8
        _:
            p["seg"] = 34; p["gmin"] = 170.0; p["gmax"] = 260.0; p["wmin"] = 150.0; p["wmax"] = 320.0; p["dy"] = 90.0
            p["moving"] = 0.2; p["disap"] = 0.2; p["fall"] = 0.2
            p["feat"] = ALL; p["fchance"] = 0.8
    return p


static func build(lv: int) -> Dictionary:
    var p := params(lv)
    var rng := RandomNumberGenerator.new()
    rng.seed = 4242 + lv * 7919
    var plats: Array = []
    var haz: Array = []
    var coins: Array = []
    var cps: Array = []
    var goal := Vector2.ZERO

    var y := 520.0
    var w := 420.0
    var cx := 100.0
    plats.append({"x": cx, "y": y, "w": w, "kind": NeonPlatform.Kind.STATIC, "amp": 0.0, "speed": 1.0, "phase": 0.0})
    var prev_right := cx + w * 0.5
    var end_x := prev_right
    var seg := int(p["seg"])

    for i in range(1, seg):
        var last := i == seg - 1
        var is_cp := (i % 5 == 0) and not last
        var gap := rng.randf_range(float(p["gmin"]), float(p["gmax"]))
        var pw := rng.randf_range(float(p["wmin"]), float(p["wmax"]))
        var kind := NeonPlatform.Kind.STATIC
        if not last and not is_cp and i >= 2:
            var r := rng.randf()
            var moving := float(p["moving"])
            var disap := float(p["disap"])
            var fall := float(p["fall"])
            if r < moving:
                kind = NeonPlatform.Kind.MOVING
            elif r < moving + disap:
                kind = NeonPlatform.Kind.DISAPPEARING
            elif r < moving + disap + fall:
                kind = NeonPlatform.Kind.FALLING
        var amp := 0.0
        if kind != NeonPlatform.Kind.STATIC:
            pw = clampf(pw, 150.0, 230.0)
        if kind == NeonPlatform.Kind.MOVING:
            gap = minf(gap, 150.0)
            amp = 70.0
        if last:
            pw = 360.0
        var pcx := prev_right + gap + pw * 0.5 + amp
        y = clampf(y + rng.randf_range(-float(p["dy"]), float(p["dy"])), 300.0, 560.0)
        plats.append({"x": pcx, "y": y, "w": pw, "kind": kind, "amp": amp,
            "speed": rng.randf_range(0.9, 1.5), "phase": rng.randf() * 3.0})

        var feats: Array = p["feat"]
        if kind == NeonPlatform.Kind.STATIC and not is_cp and not last and i >= 2 and pw >= 260.0 \
                and feats.size() > 0 and rng.randf() < float(p["fchance"]):
            var f: String = feats[rng.randi() % feats.size()]
            var off := rng.randf_range(-0.15, 0.15) * pw
            match f:
                "spike":
                    haz.append({"kind": Hazard.Kind.SPIKE, "x": pcx + off, "y": y, "size": Vector2(rng.randf_range(56.0, 84.0), 16.0)})
                "slider":
                    haz.append({"kind": Hazard.Kind.SLIDER, "x": pcx, "y": y, "amp": pw * 0.35, "speed": rng.randf_range(1.2, 1.9), "phase": rng.randf() * 6.0})
                "rotor":
                    var dirn := 1.0 if rng.randf() < 0.5 else -1.0
                    haz.append({"kind": Hazard.Kind.ROTOR, "x": pcx + off, "y": y - 150.0, "length": 52.0, "speed": rng.randf_range(1.8, 2.6) * dirn})
                "laser":
                    haz.append({"kind": Hazard.Kind.LASER, "x": pcx + off, "y": y, "size": Vector2(8.0, 190.0), "phase": rng.randf() * 2.8})
                "enemy":
                    haz.append({"kind": Hazard.Kind.ENEMY, "x": pcx, "y": y, "amp": pw * 0.5 - 28.0, "speed": rng.randf_range(1.0, 1.6), "phase": rng.randf() * 6.0})

        if not last and rng.randf() < 0.7:
            for k in range(-1, 2):
                coins.append(Vector2(pcx + k * 45.0, y - 70.0 - (20.0 if k == 0 else 0.0)))
        if rng.randf() < 0.6:
            coins.append(Vector2(prev_right + gap * 0.5, y - 130.0))
        if is_cp:
            cps.append(Vector2(pcx - pw * 0.5 + 36.0, y))
        if last:
            goal = Vector2(pcx, y - 46.0)
        prev_right = pcx + pw * 0.5
        end_x = prev_right

    return {
        "platforms": plats, "hazards": haz, "coins": coins, "checkpoints": cps,
        "goal": goal, "end_x": end_x, "kill_y": 900.0,
        "name": NAMES[lv - 1], "hint": HINTS[lv - 1],
    }
