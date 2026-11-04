# Builds the Voxel Oni in Blender from boxes.txt (same boxes as VoxelBossBuilder.luau) plus extra detail.
# Coordinates in the box lists are Roblox model space (studs, Y up, -Z forward). Blender = (x, -z, y), so after
# the glTF export (Blender (x,y,z) -> glTF (x,z,-y)) the file is in Roblox model space again.
# One object per (group, colour): "<Group>__<colour>", so every colour region of every limb is its own MeshPart.
import bpy, bmesh, random, os
from mathutils import Vector

# Run from Blender: exec(compile(open(path).read(), path, "exec"), {"__file__": path}); boxes.txt sits beside it.
# Export: assets/Boss/VoxelOni.glb (selected VoxelOni collection, materials off), then Studio's 3D Importer.
HERE = os.path.dirname(os.path.abspath(__file__))
BOXES = eval("[" + open(os.path.join(HERE, "boxes.txt"), encoding="utf-8").read() + "]")

COLORS = {
    "stone": (128, 124, 116), "stoneLight": (150, 144, 134), "stoneDark": (98, 94, 90),
    "moss": (96, 142, 74), "mossDark": (70, 112, 58), "red": (186, 52, 44), "redDark": (146, 38, 34),
    "cream": (222, 198, 156), "gold": (196, 160, 86), "rope": (190, 160, 100), "ropeDark": (150, 122, 74),
    "paper": (240, 236, 224), "ink": (30, 26, 24), "wood": (86, 60, 46), "woodDark": (74, 54, 44),
    "glow": (90, 240, 255), "eye": (255, 206, 90), "lantern": (226, 88, 52), "crystal": (120, 210, 255),
}

rng = random.Random(7)
EXTRA = []
def box(g, a, b, c, m=False):
    EXTRA.append((g, a, b, c, m))

# --- extra detail (Roblox coords) ---
# moss clumps on the pauldrons, head and shoulders (seeded, 0.25 grid)
for _ in range(10):
    x = -9.5 + rng.randint(0, 12) * 0.25
    z = -2.5 + rng.randint(0, 20) * 0.25
    s = rng.choice([0.5, 0.75, 1.0])
    box("ArmL", (x, 23, z), (x + s, 23 + rng.choice([0.25, 0.5, 0.75]), z + s), rng.choice(["moss", "mossDark"]))
for _ in range(8):
    x = -3.5 + rng.randint(0, 24) * 0.25
    z = -3.5 + rng.randint(0, 24) * 0.25
    s = rng.choice([0.5, 0.75])
    box("Head", (x, 27, z), (x + s, 27.25 + rng.choice([0, 0.25, 0.5]), z + s), rng.choice(["moss", "mossDark"]))
for _ in range(8):
    x = -5.75 + rng.randint(0, 10) * 0.25
    z = -3.75 + rng.randint(0, 28) * 0.25
    box("Body", (x, 20, z), (x + 0.75, 20.25 + rng.choice([0, 0.25, 0.5]), z + 0.75), rng.choice(["moss", "mossDark"]), True)
# crystal shards growing out of the back
for x0, h in ((-2.5, 3.5), (-1.25, 4.75), (0.25, 4.0), (1.5, 3.0)):
    box("Body", (x0, 13.5, 4.75), (x0 + 1, 13.5 + h, 5.75), "crystal")
    box("Body", (x0 + 0.25, 13.5 + h, 5), (x0 + 0.75, 13.5 + h + 0.75, 5.5), "crystal")
# stepped (rounded) torso corners
box("Body", (-6.5, 12, -3.5), (-6, 19, 3.5), "stone", True)
box("Body", (-5.5, 20, -3.5), (5.5, 20.5, 3.5), "stoneDark")
box("Body", (-5.5, 10.5, -4.5), (5.5, 11, 4.5), "stoneDark")
# fists: thumbs, finger splits, wrist studs
box("ArmL", (-5, 8, -2.5), (-4.25, 10.25, -0.75), "stoneDark")
for x0 in (-9.5, -8, -6.5):
    box("ArmL", (x0, 6, -3.25), (x0 + 0.25, 8.5, -3), "ink")
for z0 in (-2, 0, 2):
    box("ArmL", (-11.25, 11.25, z0 - 0.25), (-11, 11.75, z0 + 0.25), "cream")
# shoulder joint bridging the arm to the torso (before the ARM_OUT shift)
box("ArmL", (-6.5, 16.5, -2), (-4.5, 20, 2), "stoneDark")
box("ArmL", (-6.25, 17.5, -2.25), (-4.75, 19, 2.25), "rope")
# pauldron layered plates
box("ArmL", (-10.5, 18.5, -3.5), (-6, 19.5, 3.5), "mossDark")
box("ArmL", (-10.25, 20.5, -3.25), (-6.25, 21, 3.25), "moss")
# leg armour bands and toe knuckles
box("LegL", (-5.25, 8, -2.25), (-0.75, 8.5, 2.25), "stoneDark")
box("LegL", (-6.25, 0, -4.25), (0.25, 0.5, 2.25), "stoneDark")
for x0 in (-5.75, -3.25, -0.75):
    box("LegL", (x0, 1, -4.5), (x0 + 0.5, 1.5, -4), "stoneLight")
# head: jaw, nose bridge, layered horns, mask outline
box("Head", (-3.5, 20, -5.5), (3.5, 21, -4), "stoneDark")
box("Head", (-4.25, 20.75, -5.25), (4.25, 21, -4), "redDark")
box("Head", (-4.25, 21, -5.25), (-4, 25, -4), "redDark", True)
box("Head", (-2.75, 27.25, -1.75), (-2.25, 28.5, -0.25), "gold", True)
box("Head", (-6.25, 32.5, -1.75), (-5.75, 33.5, -1.25), "cream", True)
box("Head", (-3.75, 26, -4.25), (3.75, 27, -4), "stoneLight")
# shrine: back panel lattice, lantern glow, tassels on the rope knot
for y0 in (29.5, 31, 32.5):
    box("Body", (-3, y0, 9.25), (3, y0 + 0.25, 9.75), "gold")
box("Body", (-6, 33.75, 1.75), (-5, 34.75, 2.25), "eye", True)
for x0 in (-1.25, 0.75):
    box("Body", (x0, 8.5, -6.25), (x0 + 0.5, 11.25, -6), "ropeDark")
    box("Body", (x0 - 0.25, 8, -6.5), (x0 + 0.75, 8.5, -5.75), "red")

MIRROR = {"LegL": "LegR", "ArmL": "ArmR"}
ARM_OUT = 2

def expand(entries):
    out = []
    for g, a, b, c, m in entries:
        if g == "ArmL":  # arms stand ARM_OUT studs clear of the torso (VoxelBossBuilder does the same)
            a, b = (a[0] - ARM_OUT, a[1], a[2]), (b[0] - ARM_OUT, b[1], b[2])
        out.append((g, a, b, c))
        target = MIRROR.get(g) or (g if m else None)
        if target:
            out.append((target, (-b[0], a[1], a[2]), (-a[0], b[1], b[2]), c))
    return out

def to_blender(v):
    return Vector((v[0], -v[2], v[1]))

# --- clear the old build ---
for o in list(bpy.data.objects):
    if o.name.startswith(("Oni__", "Body__", "Head__", "ArmL__", "ArmR__", "LegL__", "LegR__")) or o.name in ("Cube",):
        bpy.data.objects.remove(o, do_unlink=True)
coll = bpy.data.collections.get("VoxelOni") or bpy.data.collections.new("VoxelOni")
if coll.name not in bpy.context.scene.collection.children:
    bpy.context.scene.collection.children.link(coll)

def material(name):
    mat = bpy.data.materials.get("Oni_" + name) or bpy.data.materials.new("Oni_" + name)
    r, g, b = (c / 255 for c in COLORS[name])
    mat.diffuse_color = (r, g, b, 1)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (r ** 2.2, g ** 2.2, b ** 2.2, 1)
    bsdf.inputs["Roughness"].default_value = 0.8
    return mat

groups = {}
for g, a, b, c in expand(BOXES) + expand(EXTRA):
    groups.setdefault((g, c), []).append((a, b))

BEVEL = 0  # flat Roblox-part look (Jacob rejected bevels 2026-11-02)
made = 0
for (g, c), boxes in sorted(groups.items()):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    for a, b in boxes:
        lo, hi = to_blender(a), to_blender(b)
        lo, hi = Vector(map(min, lo, hi)), Vector(map(max, lo, hi))
        geom = bmesh.ops.create_cube(bm, size=1.0)
        verts = geom["verts"]
        size, center = hi - lo, (hi + lo) / 2
        for v in verts:
            v.co = Vector((v.co.x * size.x, v.co.y * size.y, v.co.z * size.z)) + center
        bevel = min(BEVEL, min(size) * 0.2)
        edges = list({e for v in verts for e in v.link_edges})
        if bevel > 0:
            bmesh.ops.bevel(bm, geom=edges, offset=bevel, segments=1, affect="EDGES", clamp_overlap=True)
    bm.normal_update()
    # box-projected UVs, 1 UV unit = 1 stud
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for loop in f.loops:
            p = loop.vert.co
            loop[uv].uv = (p.y, p.z) if ax == 0 else (p.x, p.z) if ax == 1 else (p.x, p.y)
    name = f"{g}__{c}"
    mesh = bpy.data.meshes.get(name) or bpy.data.meshes.new(name)
    mesh.clear_geometry()
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.clear()
    mesh.materials.append(material(c))
    obj = bpy.data.objects.new(name, mesh)
    obj["OniGroup"] = g
    obj["OniColor"] = c
    coll.objects.link(obj)
    made += 1

total_boxes = sum(len(v) for v in groups.values())
print("objects", made, "boxes", total_boxes, "tris", sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in coll.objects))
