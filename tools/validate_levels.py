#!/usr/bin/env python3
"""Validates data/levels/*.json (same rules as scripts/levels/level_validator.gd,
plus an AABB overlap check). Exit code 1 on any error."""
import glob
import json
import math
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
MATS = {"wood", "glass", "stone", "metal", "rubber", "crystal"}
BALLS = {"standard", "heavy", "bouncy", "blast", "precision"}
WINS = {"destroy_targets", "knock_off", "topple"}


def vec3(v):
    return isinstance(v, list) and len(v) == 3 and all(isinstance(x, (int, float)) and math.isfinite(x) for x in v)


def validate(lv, name):
    errs = []
    for k in ("id", "world", "name_fa", "name_en", "difficulty", "balls", "win", "reward", "stars", "platform", "camera", "blocks"):
        if k not in lv:
            errs.append("missing key " + k)
    if errs:
        return errs
    if not 1 <= lv["world"] <= 5:
        errs.append("bad world")
    if not lv["balls"] or any(k not in BALLS or int(v) <= 0 for k, v in lv["balls"].items()):
        errs.append("bad balls")
    w = lv["win"]
    if w.get("type") not in WINS:
        errs.append("bad win type")
    if w.get("type") == "knock_off" and int(w.get("count", 0)) <= 0:
        errs.append("knock_off needs count")
    pw, pd = lv["platform"]["size"]
    pz = lv["platform"]["center_z"]
    targets = 0
    bl = lv["blocks"]
    if not bl:
        errs.append("no blocks")
    for i, b in enumerate(bl):
        if b.get("material") not in MATS:
            errs.append("block %d bad material" % i)
            continue
        if not (vec3(b.get("pos")) and vec3(b.get("size"))):
            errs.append("block %d bad vectors" % i)
            continue
        x, y, z = b["pos"]
        sx, sy, sz = b["size"]
        if min(b["size"]) < 0.05:
            errs.append("block %d too small" % i)
        if abs(x) + sx / 2 > pw / 2 + 0.01 or z - sz / 2 < pz - pd / 2 - 0.01 or z + sz / 2 > pz + pd / 2 + 0.01:
            errs.append("block %d outside platform (%s)" % (i, b["pos"]))
        if y - sy / 2 < -0.01:
            errs.append("block %d below platform" % i)
        if b["material"] == "crystal" or b.get("target"):
            targets += 1
    if w.get("type") in ("destroy_targets", "topple") and targets == 0:
        errs.append("win type needs targets")
    if w.get("type") == "knock_off" and len(bl) < int(w.get("count", 0)) + 3:
        errs.append("knock_off count too high for block count")
    # overlap
    eps = 0.03
    for i in range(len(bl)):
        for j in range(i + 1, len(bl)):
            a, c = bl[i], bl[j]
            ok = False
            for ax in range(3):
                if abs(a["pos"][ax] - c["pos"][ax]) >= (a["size"][ax] + c["size"][ax]) / 2 - eps:
                    ok = True
                    break
            if not ok:
                errs.append("blocks %d and %d overlap" % (i, j))
    if len(bl) > 110:
        errs.append("too many blocks (%d)" % len(bl))
    for m in lv.get("movers", []):
        if not (vec3(m.get("pos")) and vec3(m.get("size")) and vec3(m.get("axis"))):
            errs.append("bad mover")
    return errs


def main():
    files = sorted(glob.glob(os.path.join(ROOT, "data", "levels", "level_*.json")))
    bad = 0
    ids = []
    for f in files:
        lv = json.load(open(f, encoding="utf-8"))
        errs = validate(lv, f)
        ids.append(lv.get("id"))
        if errs:
            bad += 1
            print("FAIL", os.path.basename(f))
            for e in errs[:8]:
                print("   -", e)
    if ids != list(range(1, len(files) + 1)):
        print("FAIL: level ids are not contiguous 1..N")
        bad += 1
    if len(files) < 30:
        print("FAIL: need at least 30 levels, found", len(files))
        bad += 1
    print("checked %d levels, %d with problems" % (len(files), bad))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
