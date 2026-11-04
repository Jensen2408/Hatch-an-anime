# Voxel-art Oni: the boss designed straight on a V-stud cube grid (default 0.5), flat cubes, no bevels.
# Rounded primitives (ellipsoids, capsules, cones) are rasterised into the grid; later primitives paint over earlier
# ones, so the face, brows, tusks and trims sit exactly on the grid. Stone and moss get a light/dark speckle.
# Blender coords: Z up, the Oni faces +Y, feet on z = 0. Joints match the BossEvent rig (VoxelBossBuilder PIVOTS in
# Roblox space): hips z 9, legs x +-3, shoulders x +-10 z 19, neck z 20.
# Output: collection "VoxelArtOni", one object per "<Group>__<colour>" (greedy-merged faces, UVs in studs).
#   exec(compile(open(p).read(), p, "exec"), {"__file__": p, "V": 0.5})
import bpy, bmesh, os, numpy as np

V = globals().get("V", 0.5)
HERE = os.path.dirname(os.path.abspath(__file__))
COLORS = {
    "stone": (128, 124, 116), "stoneLight": (150, 144, 134), "stoneDark": (98, 94, 90),
    "moss": (96, 142, 74), "mossDark": (70, 112, 58), "red": (186, 52, 44), "redDark": (146, 38, 34),
    "cream": (222, 198, 156), "gold": (196, 160, 86), "rope": (190, 160, 100), "ropeDark": (150, 122, 74),
    "paper": (240, 236, 224), "ink": (30, 26, 24), "wood": (86, 60, 46), "woodDark": (74, 54, 44),
    "glow": (90, 240, 255), "eye": (255, 206, 90), "lantern": (226, 88, 52), "crystal": (120, 210, 255),
}
GROUPS = ["Body", "Head", "ArmL", "ArmR", "LegL", "LegR"]
NAMES = list(COLORS)

# ---- grid
lo = np.array([-16.0, -12.0, 0.0]); hi = np.array([16.0, 13.0, 40.0])
dims = np.ceil((hi - lo) / V).astype(int)
ax = [lo[i] + (np.arange(dims[i]) + 0.5) * V for i in range(3)]
X, Y, Z = np.meshgrid(*ax, indexing="ij")
col = np.full(dims, -1, np.int16)   # colour index
grp = np.full(dims, -1, np.int8)    # group index

def paint(mask, group, color):
    col[mask] = NAMES.index(color); grp[mask] = GROUPS.index(group)

def ellip(c, r):
    return ((X - c[0]) / r[0]) ** 2 + ((Y - c[1]) / r[1]) ** 2 + ((Z - c[2]) / r[2]) ** 2 <= 1

def capsule(a, b, r0, r1=None):
    a, b = np.array(a, float), np.array(b, float); r1 = r0 if r1 is None else r1
    ab = b - a; t = ((X - a[0]) * ab[0] + (Y - a[1]) * ab[1] + (Z - a[2]) * ab[2]) / ab.dot(ab)
    t = np.clip(t, 0, 1)
    d2 = (X - a[0] - t * ab[0]) ** 2 + (Y - a[1] - t * ab[1]) ** 2 + (Z - a[2] - t * ab[2]) ** 2
    return d2 <= (r0 + (r1 - r0) * t) ** 2

def box(a, b):
    return (X >= a[0]) & (X <= b[0]) & (Y >= a[1]) & (Y <= b[1]) & (Z >= a[2]) & (Z <= b[2])

def both(fn, group_l, color, *args, groups=None):
    """Paint fn(*args) for the left side (x < 0 as written) and its x-mirror (group L -> R)."""
    paint(fn(*args), group_l, color)
    if fn is box:  # mirrored corners swap min/max in x
        a, b = args
        m = box((-b[0], a[1], a[2]), (-a[0], b[1], b[2]))
    else:
        m = fn(*[mirror_arg(a) for a in args])
    paint(m, {"ArmL": "ArmR", "LegL": "LegR"}.get(group_l, group_l), color)

def mirror_arg(a):
    if isinstance(a, (tuple, list)) and len(a) == 3 and all(isinstance(v, (int, float)) for v in a):
        return (-a[0], a[1], a[2])
    return a

def hash01(salt, cell=1):
    """Deterministic noise 0..1, constant over cell x cell x cell voxel blocks."""
    i, j, k = (a // cell for a in np.indices(dims))
    h = (i * 73856093) ^ (j * 19349663) ^ (k * 83492791) ^ salt
    return ((h * 2654435761) % 4294967296) / 4294967296.0

# ===== legs (short, thick, wading)
both(capsule, "LegL", "stone", (-3.2, 0.0, 9.4), (-3.5, 0.6, 4.8), 2.6, 2.4)
both(capsule, "LegL", "stone", (-3.5, 0.6, 4.8), (-3.4, 0.3, 1.8), 2.4, 2.2)
both(ellip, "LegL", "stoneDark", (-3.4, 1.3, 0.9), (2.8, 3.7, 1.1))
both(box, "LegL", "rope", (-5.9, -2.6, 2.4), (-0.9, 3.2, 3.2))  # ankle wrap (clipped to the leg below)
both(capsule, "LegL", "stoneLight", (-3.6, 2.6, 5.6), (-3.6, 2.8, 4.6), 1.1)  # kneecap
for dx in (-1.6, 0.0, 1.6):
    both(capsule, "LegL", "cream", (-3.4 + dx, 4.2, 0.6), (-3.4 + dx, 5.2, 0.4), 0.5, 0.25)
leg_shape = np.isin(grp, [GROUPS.index("LegL"), GROUPS.index("LegR")])
# ankle wrap only where it hugs the shin
wrap = (col == NAMES.index("rope")) & leg_shape
near_leg = capsule((-3.4, 0.3, 1.8), (-3.5, 0.6, 4.8), 2.75) | capsule((3.4, 0.3, 1.8), (3.5, 0.6, 4.8), 2.75)
col[wrap & ~near_leg] = -1; grp[wrap & ~near_leg] = -1

# ===== body (hunched, heavy chest, belly)
paint(ellip((0, 0.4, 13.0), (5.3, 4.3, 3.4)), "Body", "stone")
paint(ellip((0, 0.2, 15.6), (6.6, 4.7, 5.4)), "Body", "stone")
paint(ellip((0, -0.4, 18.6), (7.3, 4.6, 3.4)), "Body", "stone")
paint(ellip((0, -1.4, 20.4), (4.6, 3.2, 1.6)), "Body", "stone")
paint(ellip((0, 0.0, 10.4), (5.0, 3.8, 2.2)), "Body", "stoneDark")
body = grp == GROUPS.index("Body")
# chest plates and belly, painted onto the front surface
paint(body & ellip((-3.0, 3.6, 17.2), (2.8, 1.6, 1.8)), "Body", "stoneLight")
paint(body & ellip((3.0, 3.6, 17.2), (2.8, 1.6, 1.8)), "Body", "stoneLight")
paint(body & (Y > 3.0) & (np.abs(X) <= 0.25) & (Z > 12.6) & (Z < 15.2), "Body", "ink")  # ab line
paint(body & (Y > 2.6) & (Z > 14.0) & (Z < 14.5) & (np.abs(X) < 4.5), "Body", "ink")
# glowing core with a gold rim
paint(ellip((0, 4.2, 16.4), (2.1, 1.0, 2.1)), "Body", "gold")
paint(ellip((0, 4.6, 16.4), (1.4, 0.8, 1.4)), "Body", "glow")
# shimenawa rope belt with twists, knot and zig-zag paper charms
belt = (((X / 6.1) ** 2 + ((Y - 0.4) / 5.0) ** 2) <= 1) & (Z >= 11.0) & (Z <= 12.75)
paint(belt, "Body", "rope")
twist = belt & ((np.floor(X / V) + np.floor(Y / V) + np.floor(Z / V)) % 3 == 0)
paint(twist, "Body", "ropeDark")
paint(ellip((0, 5.0, 11.9), (1.5, 0.9, 1.2)), "Body", "rope")
for x0 in (-2.75, 2.75):  # zig-zag shide charms hanging off the belt, one voxel wide
    for k, z0 in enumerate((10.25, 9.75, 9.25, 8.75, 8.25)):
        dx = 0.5 if k in (1, 2) else 0.0
        paint(box((x0 - 0.2 + dx, 3.6, z0 - 0.2), (x0 + 0.2 + dx, 3.9, z0 + 0.2)), "Body", "paper")
# moss mantle over the back and shoulders, with drips
mantle = body & (Z > 18.0) & (Y < 0.5) & ~ellip((0, -0.4, 18.6), (6.7, 4.0, 3.0))
paint(mantle, "Body", "moss")
for x0 in (-5.0, -3.0, -0.5, 1.5, 4.0):
    h = 1.5 + abs(x0) * 0.25
    paint(body & capsule((x0, -4.4, 18.5), (x0, -4.4, 18.5 - h), 0.6), "Body", "moss")
# crystal shards out of the back
for x0, h in ((-2.0, 3.5), (-0.5, 5.0), (1.0, 4.0), (2.4, 3.0)):
    paint(capsule((x0, -4.2, 13.0), (x0 * 1.15, -5.8, 13.0 + h), 0.75, 0.2), "Body", "crystal")

# ===== head (oni mask face, heavy brows, tusks, curved horns, moss mane)
paint(ellip((0, 0.7, 24.2), (3.9, 3.6, 3.8)), "Head", "stone")
paint(ellip((0, 1.6, 21.8), (3.4, 2.9, 1.8)), "Head", "stone")
head = grp == GROUPS.index("Head")
paint(head & (Y > 2.3) & (Z > 20.5) & (Z < 26.2), "Head", "red")  # mask plate on the face
paint(head & (Y > 2.0) & (Z >= 26.2) & (Z < 26.7) & (np.abs(X) < 3.4), "Head", "redDark")
# The face is pixel art: FACE is drawn onto the front-most head voxel of each (x, z) column, top row first,
# 16 columns from x = -4 to +4. Capital letters protrude one voxel (brows, nose, tusks).
#   . mask red   d dark red   B brow (protrudes)   e eye (solid glowing yellow, no pupils)   N nose (protrudes)
#   k mouth   t tooth   U tusk (protrudes, plus one more above)   g gold mark
FACE = [
    "ddBB........BBdd",
    "dddBBB....BBBddd",
    "..eeeBB..BBeee..",
    "..eeeee..eeeee..",
    "...ee..NN..ee...",
    ".g....NNNN....g.",
    ".g..U.kNNk.U..g.",
    "...UkkkkkkkkU...",
    "...UktkttktkU...",
    "....kkkkkkkk....",
    "................",
]
CODES = {".": "red", "d": "redDark", "B": "redDark", "e": "eye", "p": "ink", "N": "redDark", "k": "ink",
         "t": "cream", "U": "cream", "u": "cream", "g": "gold"}
for row in FACE:  # the face must mirror left/right (teeth and tusks matching on both sides)
    assert len(row) == 16 and row == row[::-1], "FACE row not symmetric: " + row
xi0 = int(round((-4.0 - lo[0]) / V))
head_i = GROUPS.index("Head")
for r, row in enumerate(FACE):
    zc = 25.75 - r * 0.5
    kz = int((zc - lo[2]) / V)
    for c, ch in enumerate(row):
        kx = xi0 + c
        column = np.where(grp[kx, :, kz] == head_i)[0]
        if not len(column):
            continue
        ky = column.max()
        col[kx, ky, kz] = NAMES.index(CODES[ch]); grp[kx, ky, kz] = head_i
        if ch.isupper() or ch == "u":
            col[kx, ky + 1, kz] = NAMES.index(CODES[ch]); grp[kx, ky + 1, kz] = head_i
            if ch in "Uu" and r > 0:  # tusks curve up past the lip
                col[kx, ky + 1, kz + 1] = NAMES.index("cream"); grp[kx, ky + 1, kz + 1] = head_i
both(ellip, "Head", "stone", (-4.1, 0.6, 23.4), (0.8, 1.0, 1.4))  # ears
both(ellip, "Head", "redDark", (-4.6, 0.6, 23.4), (0.4, 0.6, 0.9))
horn = [(-2.4, 0.4, 26.4), (-3.7, 0.4, 27.9), (-4.5, 0.2, 29.8), (-4.7, 0.0, 31.7), (-4.3, -0.2, 33.4)]
radii = [1.15, 0.95, 0.75, 0.55, 0.35, 0.2]
for i in range(len(horn) - 1):
    both(capsule, "Head", "gold" if i == len(horn) - 2 else "cream", horn[i], horn[i + 1], radii[i], radii[i + 1])
both(capsule, "Head", "gold", (-2.6, 0.4, 26.6), (-3.2, 0.4, 27.3), 1.3)  # horn rings
paint(ellip((0, -1.9, 25.0), (3.8, 2.3, 2.9)), "Head", "mossDark")  # mane
for p in ((-2.6, -2.9, 23.3), (2.6, -2.9, 23.3), (0, -3.5, 22.6), (0, -0.4, 27.6), (-1.6, -1.6, 27.2), (1.6, -1.6, 27.2)):
    paint(ellip(p, (1.5, 1.5, 1.5)), "Head", "mossDark")

# ===== arms (joined to the torso at the shoulder; the rig swings each from its shoulder pivot)
# shoulders: the body's trapezius/lats swell out to meet the arm, and the arm's deltoid fills the rest of the gap,
# so the joint reads as one mass at rest but the arm (with its deltoid) still swings from the rig's shoulder pivot
both(ellip, "Body", "stone", (-6.4, -0.4, 19.4), (2.4, 3.4, 2.2))
both(ellip, "Body", "stone", (-6.0, -0.6, 16.6), (1.8, 3.4, 2.6))
both(ellip, "ArmL", "stone", (-8.4, -0.3, 18.6), (2.6, 3.0, 2.6))
both(capsule, "ArmL", "stone", (-9.4, -0.2, 18.2), (-10.0, 0.4, 13.0), 2.4, 2.3)
both(capsule, "ArmL", "stone", (-10.0, 0.4, 13.0), (-10.4, 1.3, 9.2), 2.5, 2.7)
arm_l = grp == GROUPS.index("ArmL"); arm_r = grp == GROUPS.index("ArmR")
for g, m, s in (("ArmL", arm_l, -1), ("ArmR", arm_r, 1)):
    paint(m & (Z > 10.0) & (Z < 11.75), g, "gold")  # bracer
    paint(m & (Z >= 10.75) & (Z < 11.25), g, "ink")
    paint(m & (Z > 14.0) & (Z < 16.5) & (X * s > 9.6) & (Y > 0.0) & (Y < 0.5), g, "ink")  # crack
both(ellip, "ArmL", "stoneDark", (-10.5, 1.8, 7.0), (2.9, 3.1, 2.5))  # fist
for dx in (-1.5, -0.5, 0.5, 1.5):
    both(ellip, "ArmL", "stoneLight", (-10.5 + dx, 4.4, 7.6), (0.55, 0.6, 0.75))  # knuckles
both(ellip, "ArmL", "stoneDark", (-8.3, 2.6, 7.6), (0.9, 1.4, 0.9))  # thumb
both(ellip, "ArmL", "moss", (-9.4, -0.2, 20.2), (3.5, 3.5, 2.7))  # pauldron
both(ellip, "ArmL", "mossDark", (-9.4, -0.2, 18.9), (3.7, 3.7, 0.7))
both(box, "ArmL", "gold", (-13.25, -3.75, 17.75), (-5.5, 3.25, 18.25))
pauldron_gold = (col == NAMES.index("gold")) & (Z > 17.7) & (Z < 18.3) & (np.abs(X) > 5.4)  # not the chest gem rim
keep = ellip((-9.4, -0.2, 18.0), (3.9, 3.9, 2.0)) | ellip((9.4, -0.2, 18.0), (3.9, 3.9, 2.0))
col[pauldron_gold & ~keep] = -1; grp[pauldron_gold & ~keep] = -1
for i, (dx, h) in enumerate(((0.0, 2.6), (1.6, 1.8), (-1.6, 1.8))):
    both(capsule, "ArmL", "cream", (-9.4 + dx, -0.6, 22.4), (-9.8 + dx * 1.3, -0.9, 22.4 + h), 0.6, 0.2)

# ===== shrine on the back (the block shrine from build_oni.py's boxes, on the same grid)
BOXES = eval("[" + open(os.path.join(HERE, "boxes.txt"), encoding="utf-8").read() + "]")
for g, a, b, c, m in BOXES:
    if g != "Body" or a[1] < 20 or b[2] < 2 or c not in COLORS:
        continue
    # Roblox (x, y, z) -> Blender (x, -z, y)
    lo_b = (min(a[0], b[0]), min(-a[2], -b[2]), a[1]); hi_b = (max(a[0], b[0]), max(-a[2], -b[2]), b[1])
    paint(box((lo_b[0] + 0.01, lo_b[1] + 0.01, lo_b[2] + 0.01), (hi_b[0] - 0.01, hi_b[1] - 0.01, hi_b[2] - 0.01)), "Body", c)
    if m:
        paint(box((-hi_b[0] + 0.01, lo_b[1] + 0.01, lo_b[2] + 0.01), (-lo_b[0] - 0.01, hi_b[1] - 0.01, hi_b[2] - 0.01)), "Body", c)

# ===== voxel-art speckle on stone and moss
n = hash01(1234, cell=2)  # 1-stud patches read calmer than per-voxel noise
for base, light, dark in (("stone", "stoneLight", "stoneDark"), ("moss", "moss", "mossDark")):
    m = col == NAMES.index(base)
    col[m & (n < 0.10)] = NAMES.index(light); col[m & (n > 0.91)] = NAMES.index(dark)
col[(col >= 0) & (Z < 0)] = -1

# ===== mesh: exterior faces only, greedy-merged per (group, colour)
solid = col >= 0
key = np.where(solid, grp.astype(np.int32) * 64 + col, -1)
coll = bpy.data.collections.get("VoxelArtOni") or bpy.data.collections.new("VoxelArtOni")
if coll.name not in bpy.context.scene.collection.children:
    bpy.context.scene.collection.children.link(coll)
for o in list(coll.objects):
    bpy.data.objects.remove(o, do_unlink=True)
meshes = {}
def bm_for(k):
    if k not in meshes:
        b = bmesh.new(); b.loops.layers.uv.new("UVMap"); meshes[k] = b
    return meshes[k]
for axis in range(3):
    u, w = [a for a in range(3) if a != axis]
    for sign in (1, -1):
        for s in range(dims[axis]):
            here = np.take(key, s, axis=axis)
            nb = s + sign
            # a face is drawn where the neighbour is empty OR belongs to another rig group, so every limb is a
            # closed shell: when an arm or leg swings away from the body you see a cap, not the hollow inside
            if 0 <= nb < dims[axis]:
                g_here, g_nb = np.take(grp, s, axis=axis), np.take(grp, nb, axis=axis)
                open_ = ~np.take(solid, nb, axis=axis) | (g_nb != g_here)
            else:
                open_ = np.ones_like(here, bool)
            mask = np.where(open_, here, -1)
            done = np.zeros(mask.shape, bool)
            H, W = mask.shape
            for a in range(H):
                for b in range(W):
                    k = mask[a, b]
                    if k < 0 or done[a, b]:
                        continue
                    wd = 1
                    while b + wd < W and mask[a, b + wd] == k and not done[a, b + wd]:
                        wd += 1
                    ht = 1
                    while a + ht < H and (mask[a + ht, b:b + wd] == k).all() and not done[a + ht, b:b + wd].any():
                        ht += 1
                    done[a:a + ht, b:b + wd] = True
                    plane = lo[axis] + (s + (1 if sign > 0 else 0)) * V
                    corners = []
                    for da, db in ((0, 0), (ht, 0), (ht, wd), (0, wd)):
                        c = [0.0, 0.0, 0.0]
                        c[axis] = plane; c[u] = lo[u] + (a + da) * V; c[w] = lo[w] + (b + db) * V
                        corners.append(c)
                    e1 = np.subtract(corners[1], corners[0]); e2 = np.subtract(corners[3], corners[0])
                    if np.cross(e1, e2)[axis] * sign < 0:
                        corners.reverse()
                    bmx = bm_for(int(k))
                    f = bmx.faces.new([bmx.verts.new(c) for c in corners])
                    uvl = bmx.loops.layers.uv["UVMap"]
                    for loop in f.loops:
                        loop[uvl].uv = (loop.vert.co[u], loop.vert.co[w])

def material(name):
    mat = bpy.data.materials.get("Oni_" + name) or bpy.data.materials.new("Oni_" + name)
    r, g, b = (c / 255 for c in COLORS[name])
    mat.diffuse_color = (r, g, b, 1)
    return mat

tris = 0
for k, b in sorted(meshes.items()):
    g, c = GROUPS[k // 64], NAMES[k % 64]
    bmesh.ops.remove_doubles(b, verts=b.verts, dist=1e-4)
    name = f"{g}__{c}"
    me = bpy.data.meshes.new(name + "_art"); b.to_mesh(me); b.free()
    me.materials.append(material(c))
    ob = bpy.data.objects.new(name + "_art", me)
    ob["OniGroup"], ob["OniColor"] = g, c
    coll.objects.link(ob)
    tris += 2 * len(me.polygons)
print("voxels", int(solid.sum()), "objects", len(coll.objects), "tris", tris, "grid", tuple(dims))
