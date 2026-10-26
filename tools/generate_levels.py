#!/usr/bin/env python3
"""Generates data/levels/level_XX.json (30 levels, 5 worlds x 6).
Run:  python tools/generate_levels.py
Levels are plain JSON, so you can also edit them by hand or add new files
(level_31.json, ...). Coordinates: platform top is y=0, structure centre z=-14."""
import json
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "data", "levels")


def r3(x):
    return round(float(x), 3)


class B:
    def __init__(self):
        self.blocks = []
        self.movers = []

    def add(self, mat, x, y, z, w=1.0, h=1.0, d=1.0, protected=False):
        e = {"material": mat, "pos": [r3(x), r3(y), r3(z)], "size": [r3(w), r3(h), r3(d)]}
        if mat == "crystal":
            e["target"] = True
        if protected:
            e["protected"] = True
        self.blocks.append(e)

    def mover(self, x, y, z, w, h, d, axis=(1, 0, 0), amp=3.0, speed=1.0):
        self.movers.append({"pos": [r3(x), r3(y), r3(z)], "size": [r3(w), r3(h), r3(d)],
                            "axis": list(axis), "amplitude": amp, "speed": speed})


def const(m):
    return lambda *a: m


def alt(a, b):
    return lambda r, *rest: a if r % 2 == 0 else b


def rows(*ms):
    return lambda r, *rest: ms[min(r, len(ms) - 1)]


def wall(b, zc, cols, nrows, mat, depth=1, bw=1.0, bh=0.7, bd=1.0, cx=0.0, crystals=(), prot=()):
    for l in range(depth):
        z = zc + (l - (depth - 1) / 2.0) * bd
        for r in range(nrows):
            for c in range(cols):
                x = cx + (c - (cols - 1) / 2.0) * bw
                y = (r + 0.5) * bh
                key = (r, c, l)
                m = "crystal" if key in crystals else mat(r, c, l)
                b.add(m, x, y, z, bw, bh, bd, protected=(key in prot))


def pyramid(b, zc, base, mat, depth=1, bw=1.0, bh=0.7, bd=1.0, crystals=(), top=True):
    for l in range(depth):
        z = zc + (l - (depth - 1) / 2.0) * bd
        for r in range(base):
            n = base - r
            for c in range(n):
                x = (c - (n - 1) / 2.0) * bw
                y = (r + 0.5) * bh
                key = (r, c, l)
                m = "crystal" if (key in crystals or (top and r == base - 1)) else mat(r, c, l)
                b.add(m, x, y, z, bw, bh, bd)


def tower(b, x, z, height, mat, w=1.0, bh=1.0, d=1.0, crystal_top=True, prot=False):
    for i in range(height):
        m = "crystal" if (crystal_top and i == height - 1) else mat(i)
        b.add(m, x, (i + 0.5) * bh, z, w, bh, d, protected=prot and m != "crystal")


def jenga(b, zc, layers, mat, cx=0.0, crystal=True, lh=0.6):
    for i in range(layers):
        y = (i + 0.5) * lh
        for k in (-1, 0, 1):
            m = mat(i, k)
            if i % 2 == 0:
                b.add(m, cx + k * 1.0, y, zc, 1.0, lh, 3.0)
            else:
                b.add(m, cx, y, zc + k * 1.0, 3.0, lh, 1.0)
    if crystal:
        b.add("crystal", cx, layers * lh + 0.4, zc, 0.8, 0.8, 0.8)


def arch(b, zc, span, ph, pmat, beam, crystals=2, depth=1.0):
    for sx in (-1, 1):
        for i in range(ph):
            b.add(pmat(i), sx * span / 2.0, i + 0.5, zc, 1.0, 1.0, depth)
    b.add(beam, 0.0, ph + 0.3, zc, span + 1.0, 0.6, depth)
    for k in range(crystals):
        x = 0.0 if crystals == 1 else -span / 2.0 + 0.8 + k * (span - 1.6) / (crystals - 1)
        b.add("crystal", x, ph + 0.6 + 0.4, zc, 0.8, 0.8, 0.8)


def fort(b, zc, w, h, wmat, inner_x, bh=0.8, roof=None):
    xs = [c - (w - 1) / 2.0 for c in range(w)]
    for r in range(h):
        y = (r + 0.5) * bh
        for x in xs:
            b.add(wmat(r), x, y, zc + 1.0, 1.0, bh, 1.0)
            b.add(wmat(r), x, y, zc - 1.0, 1.0, bh, 1.0)
        for sx in (-1, 1):
            b.add(wmat(r), sx * (w - 1) / 2.0, y, zc, 1.0, bh, 1.0)
    for x in inner_x:
        b.add("crystal", x, 0.4, zc, 0.8, 0.8, 0.8)


def stairs(b, zc, steps, mat, crystal_steps=()):
    for i in range(steps):
        x = i - (steps - 1) / 2.0
        for j in range(i + 1):
            m = "crystal" if (i in crystal_steps and j == i) else mat(i, j)
            b.add(m, x, j + 0.5, zc, 1.0, 1.0, 1.5)


def towers(b, zc, specs, crystal_top=True):
    for (x, h, mat) in specs:
        tower(b, x, zc, h, mat, crystal_top=crystal_top)


WOOD_GLASS = lambda r, c=0, l=0: "wood" if (r + c) % 2 == 0 else "glass"
WG = lambda r, c=0, l=0: "wood" if (r + c) % 2 == 0 else "glass"

CAM_DEFAULT = {"position": [0, 6, 8], "look_at": [0, 4, -14], "fov": 44}
CAM_TALL = {"position": [0, 8, 9], "look_at": [0, 6.5, -14], "fov": 48}
ZC = -14.0
P_STD = {"size": [12, 8], "center_z": -14}
P_SMALL = {"size": [10, 6], "center_z": -14}


def L(world, fa, en, diff, balls, win, build, platform=P_STD, cam=CAM_DEFAULT, zc=ZC):
    return dict(world=world, fa=fa, en=en, diff=diff, balls=balls, win=win,
                build=build, platform=platform, cam=cam, zc=zc)


D = {"type": "destroy_targets"}


def jm(a, b):
    return lambda i, k: a if k != 0 else b


LEVELS = []

# ---------------- World 1: Rainbow Island ----------------
LEVELS.append(L(1, "اولین ضربه", "First Strike", 1, {"standard": 5}, D,
    lambda b, z: wall(b, z, 5, 4, const("wood"), crystals={(3, 1, 0), (3, 3, 0)})))
LEVELS.append(L(1, "سه برج", "Three Towers", 1, {"standard": 5}, D,
    lambda b, z: towers(b, z, [(-3, 3, const("wood")), (0, 4, const("wood")), (3, 3, alt("glass", "wood"))])))
LEVELS.append(L(1, "هرم رنگین", "Rainbow Pyramid", 2, {"standard": 3, "heavy": 2}, D,
    lambda b, z: pyramid(b, z, 6, WG)))
LEVELS.append(L(1, "دیوار دوگانه", "Double Wall", 2, {"standard": 4, "heavy": 2}, D,
    lambda b, z: wall(b, z, 6, 5, rows("stone", "stone", "wood", "glass", "wood"), depth=2,
                      crystals={(4, 1, 0), (4, 4, 1), (4, 2, 1)})))
LEVELS.append(L(1, "برج چیده‌شده", "Stacked Tower", 2, {"standard": 4, "heavy": 2},
    {"type": "topple", "height": 1.8},
    lambda b, z: jenga(b, z, 9, jm("wood", "stone")), cam=CAM_TALL))
LEVELS.append(L(1, "لبه جزیره", "Island Edge", 3, {"standard": 5, "heavy": 2},
    {"type": "knock_off", "count": 10},
    lambda b, z: wall(b, z, 6, 4, WG, depth=2, crystals=()), platform=P_SMALL, zc=-15.5))

# ---------------- World 2: Neon City ----------------
LEVELS.append(L(2, "دژ فلزی", "Metal Keep", 3, {"standard": 4, "heavy": 1, "bouncy": 2}, D,
    lambda b, z: fort(b, z, 5, 4, rows("metal", "metal", "wood", "wood"), [-0.5, 1.0])))
LEVELS.append(L(2, "برج‌های لاستیکی", "Rubber Towers", 3, {"standard": 4, "bouncy": 2}, D,
    lambda b, z: towers(b, z, [(-3.5, 5, const("wood")), (0, 6, alt("rubber", "wood")), (3.5, 5, const("wood"))]),
    cam=CAM_TALL))
LEVELS.append(L(2, "برج بلند", "Skyline Tower", 3, {"standard": 4, "bouncy": 1},
    {"type": "topple", "height": 1.6},
    lambda b, z: (tower(b, 0, z, 9, alt("glass", "wood")), tower(b, 3, z, 4, const("wood"), crystal_top=False)),
    cam=CAM_TALL))
LEVELS.append(L(2, "نگهبان متحرک", "Moving Guard", 4, {"standard": 5, "bouncy": 1}, D,
    lambda b, z: (wall(b, z, 5, 4, WG, crystals={(3, 0, 0), (3, 2, 0), (3, 4, 0)}),
                  b.mover(0, 1.5, -11.0, 2.6, 3.0, 0.6, (1, 0, 0), 3.2, 1.2))))
LEVELS.append(L(2, "پله‌های سنگی", "Stone Stairs", 4, {"standard": 4, "heavy": 2, "bouncy": 1}, D,
    lambda b, z: stairs(b, z, 6, const("stone"), crystal_steps={1, 3, 5}), cam=CAM_TALL))
LEVELS.append(L(2, "ستون سرخ", "Red Column", 4, {"standard": 5, "bouncy": 1}, D,
    lambda b, z: wall(b, z, 7, 4, const("wood"), crystals={(0, 1, 0), (0, 5, 0), (2, 1, 0), (2, 5, 0)},
                      prot={(r, 3, 0) for r in range(4)}) or None))

# ---------------- World 3: Ancient Temple ----------------
LEVELS.append(L(3, "طاق باستانی", "Ancient Arch", 4, {"standard": 3, "blast": 2}, D,
    lambda b, z: arch(b, z, 6, 5, const("stone"), "wood", 2), cam=CAM_TALL))
LEVELS.append(L(3, "هرم سنگی", "Stone Pyramid", 4, {"standard": 3, "heavy": 2, "blast": 1}, D,
    lambda b, z: pyramid(b, z, 7, rows("stone", "stone", "stone", "wood", "wood", "wood", "wood"),
                         crystals={(1, 2, 0), (1, 4, 0)}, top=True)))
LEVELS.append(L(3, "برج معبد", "Temple Tower", 5, {"standard": 3, "heavy": 2, "blast": 1},
    {"type": "topple", "height": 1.8},
    lambda b, z: jenga(b, z, 11, const("stone")), cam=CAM_TALL))
LEVELS.append(L(3, "قلعه گنج", "Treasure Fort", 5, {"standard": 2, "heavy": 1, "blast": 3}, D,
    lambda b, z: fort(b, z, 6, 5, const("stone"), [-1.0, 0.0, 1.0]), cam=CAM_TALL))
LEVELS.append(L(3, "پل باستانی", "Ancient Bridge", 5, {"standard": 3, "heavy": 1, "blast": 2}, D,
    lambda b, z: (arch(b, z, 8, 4, const("stone"), "stone", 3), b.mover(0, 1.0, -11.0, 2.0, 2.0, 0.6, (1, 0, 0), 3.0, 1.0))))
LEVELS.append(L(3, "سه نگهبان", "Three Guardians", 5, {"standard": 4, "heavy": 1, "blast": 1}, D,
    lambda b, z: (tower(b, -3.5, z, 5, const("wood")),
                  tower(b, 0, z, 5, const("stone"), crystal_top=False, prot=True),
                  tower(b, 3.5, z, 5, const("wood"))), cam=CAM_TALL))

# ---------------- World 4: Ice Land ----------------
P_ICE = {"size": [10, 6], "center_z": -14}
LEVELS.append(L(4, "نیزه‌های یخی", "Ice Spikes", 5, {"standard": 3, "precision": 3}, D,
    lambda b, z: towers(b, z, [(-3, 4, const("glass")), (-1, 6, alt("glass", "wood")), (1, 5, const("glass")), (3, 7, alt("wood", "glass"))]),
    platform=P_ICE, cam=CAM_TALL))
LEVELS.append(L(4, "دیوار لایه‌ای", "Layered Wall", 5, {"standard": 2, "precision": 3, "blast": 1}, D,
    lambda b, z: wall(b, z, 5, 4, lambda r, c, l: ("metal" if (l == 2 and r < 2) else "glass"), depth=3,
                      crystals={(0, 1, 0), (0, 3, 0), (1, 2, 0)}), platform=P_ICE))
LEVELS.append(L(4, "قلعه یخی", "Ice Castle", 5, {"standard": 3, "heavy": 1, "precision": 2}, D,
    lambda b, z: (tower(b, -3, z - 0.0, 5, alt("glass", "wood")), tower(b, 3, z, 5, alt("glass", "wood")),
                  fort(b, z, 3, 3, const("glass"), [0.0])), platform=P_ICE, cam=CAM_TALL))
LEVELS.append(L(4, "نگهبانان یخی", "Frozen Guards", 6, {"standard": 3, "bouncy": 2, "precision": 1}, D,
    lambda b, z: (wall(b, z, 6, 5, WG, crystals={(4, 0, 0), (4, 3, 0), (4, 5, 0)}),
                  b.mover(-1.5, 1.2, -11.0, 2.0, 2.4, 0.6, (1, 0, 0), 2.0, 1.4),
                  b.mover(1.5, 3.2, -11.0, 2.0, 1.4, 0.6, (1, 0, 0), 2.0, 1.0)), platform=P_ICE))
LEVELS.append(L(4, "برج هسته‌دار", "Core Tower", 6, {"standard": 2, "heavy": 2, "blast": 1},
    {"type": "topple", "height": 1.8},
    lambda b, z: jenga(b, z, 12, lambda i, k: "metal" if k == 0 else "glass"), platform=P_ICE, cam=CAM_TALL))
LEVELS.append(L(4, "قلب محافظت‌شده", "Guarded Heart", 6, {"standard": 3, "precision": 3, "bouncy": 1}, D,
    lambda b, z: wall(b, z, 7, 4, const("glass"), crystals={(2, 0, 0), (2, 6, 0), (0, 2, 0), (0, 4, 0)},
                      prot={(r, 3, 0) for r in range(2)}) or None, platform=P_ICE))

# ---------------- World 5: Cosmic Space ----------------
P_SPACE = {"size": [11, 7], "center_z": -14}
LEVELS.append(L(5, "پنج ستاره", "Five Stars", 6, {"standard": 4, "blast": 2, "precision": 1}, D,
    lambda b, z: towers(b, z, [(-4, 3, const("wood")), (-2, 5, alt("glass", "stone")), (0, 4, const("wood")),
                               (2, 6, alt("stone", "glass")), (4, 3, const("glass"))]),
    platform=P_SPACE, cam=CAM_TALL))
LEVELS.append(L(5, "دژ مداری", "Orbital Fortress", 6, {"standard": 2, "heavy": 1, "blast": 3, "precision": 1}, D,
    lambda b, z: (fort(b, z, 6, 5, const("stone"), [-1.0, 0.0, 1.0]),
                  b.mover(0, 1.5, -11.0, 3.0, 2.8, 0.6, (1, 0, 0), 3.0, 1.1)), platform=P_SPACE, cam=CAM_TALL))
LEVELS.append(L(5, "هرم زره‌دار", "Armored Pyramid", 6, {"standard": 3, "blast": 3, "heavy": 2}, D,
    lambda b, z: pyramid(b, z, 8, lambda r, c, l: "metal" if (c == 0 or c == 7 - r) else ("stone" if r < 3 else "wood"),
                         crystals={(2, 2, 0), (2, 4, 0), (3, 1, 0)}, top=True), platform=P_SPACE, cam=CAM_TALL))
LEVELS.append(L(5, "دو برج", "Twin Towers", 6, {"standard": 2, "heavy": 2, "blast": 2},
    {"type": "topple", "height": 1.8},
    lambda b, z: (jenga(b, z, 8, const("stone"), cx=-3.5), jenga(b, z, 8, jm("wood", "stone"), cx=3.5)),
    platform=P_SPACE, cam=CAM_TALL))
LEVELS.append(L(5, "ستاره‌باران", "Meteor Shower", 6, {"standard": 2, "heavy": 2, "blast": 2},
    {"type": "knock_off", "count": 20},
    lambda b, z: wall(b, z, 5, 6, WG, depth=2, bh=0.7), platform={"size": [7, 5], "center_z": -14}, zc=-15.0))
LEVELS.append(L(5, "نبرد نهایی", "Final Smash", 6, {"standard": 2, "heavy": 1, "blast": 2, "precision": 2}, D,
    lambda b, z: (arch(b, z + 1.5, 7, 5, const("stone"), "metal", 2),
                  fort(b, z - 2.0, 5, 3, const("wood"), [0.0]),
                  b.mover(0, 1.3, -11.0, 2.4, 2.6, 0.6, (1, 0, 0), 3.4, 1.3)),
    platform={"size": [12, 8], "center_z": -14}, cam=CAM_TALL))


def main():
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.startswith("level_") and f.endswith(".json"):
            os.remove(os.path.join(OUT, f))
    for i, s in enumerate(LEVELS, start=1):
        b = B()
        s["build"](b, s["zc"])
        total = sum(s["balls"].values())
        data = {
            "id": i,
            "world": s["world"],
            "name_fa": s["fa"],
            "name_en": s["en"],
            "difficulty": s["diff"],
            "balls": s["balls"],
            "win": s["win"],
            "reward": {"coins": 20 + 6 * s["diff"]},
            "stars": {"three": max(1, total // 2), "two": max(2, total - 1)},
            "platform": s["platform"],
            "camera": s["cam"],
            "blocks": b.blocks,
            "movers": b.movers,
        }
        with open(os.path.join(OUT, "level_%02d.json" % i), "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=1)
    print("generated %d levels" % len(LEVELS))


if __name__ == "__main__":
    main()
