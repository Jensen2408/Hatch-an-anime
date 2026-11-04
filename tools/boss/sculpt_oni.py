# Smooth (non-blocky) Voxel Oni concept for Hunyuan3D input. Blender coords: Z up, the Oni faces +Y, feet at z = 0,
# proportions match the BossEvent rig (hips z 9, shoulders x +-10 z 19, neck z 20), so the cube step can split limbs.
# Every object carries OniGroup / OniColor, like build_oni.py, and lives in collection "OniSculpt".
import bpy, math
from mathutils import Vector

COLORS = {
    "stone": (128, 124, 116), "stoneDark": (98, 94, 90), "stoneLight": (150, 144, 134), "moss": (96, 142, 74),
    "mossDark": (70, 112, 58), "red": (186, 52, 44), "redDark": (146, 38, 34), "cream": (222, 198, 156),
    "gold": (196, 160, 86), "rope": (190, 160, 100), "paper": (240, 236, 224), "ink": (30, 26, 24),
    "eye": (255, 206, 90), "glow": (90, 240, 255), "crystal": (120, 210, 255),
}

coll = bpy.data.collections.get("OniSculpt") or bpy.data.collections.new("OniSculpt")
if coll.name not in bpy.context.scene.collection.children:
    bpy.context.scene.collection.children.link(coll)
for o in list(coll.objects):
    bpy.data.objects.remove(o, do_unlink=True)

def material(name):
    mat = bpy.data.materials.get("Oni_" + name) or bpy.data.materials.new("Oni_" + name)
    r, g, b = (c / 255 for c in COLORS[name])
    mat.diffuse_color = (r, g, b, 1)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (r ** 2.2, g ** 2.2, b ** 2.2, 1)
    bsdf.inputs["Roughness"].default_value = 0.7
    return mat

def tag(o, group, color):
    o["OniGroup"], o["OniColor"] = group, color
    o.data.materials.clear(); o.data.materials.append(material(color))
    for c in o.users_collection: c.objects.unlink(o)
    coll.objects.link(o)
    return o

def blob(name, group, color, elements, resolution=0.35, threshold=0.2):
    """Metaball object -> mesh. elements: ("ball", center, radius) | ("ellip", center, size xyz, rot?) |
    ("capsule", a, b, radius)"""
    mb = bpy.data.metaballs.new(name)
    mb.resolution, mb.render_resolution, mb.threshold = resolution, resolution, threshold
    # metaballs draw smaller than their nominal size; these factors bring them to the sizes written below
    for e in elements:
        if e[0] == "ball":
            el = mb.elements.new(); el.co = Vector(e[1]); el.radius = e[2] * 1.2
        elif e[0] == "ellip":
            el = mb.elements.new(type="ELLIPSOID"); el.co = Vector(e[1]); el.radius = 1
            el.size_x, el.size_y, el.size_z = (v * 1.35 for v in e[2])
            if len(e) > 3: el.rotation = e[3]
        elif e[0] == "capsule":
            a, b = Vector(e[1]), Vector(e[2])
            el = mb.elements.new(type="CAPSULE"); el.co = (a + b) / 2; el.radius = e[3] * 1.15
            el.size_x = (b - a).length / 2
            el.rotation = Vector((1, 0, 0)).rotation_difference((b - a).normalized())
    ob = bpy.data.objects.new(name, mb)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.update()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bpy.data.objects.remove(ob); bpy.data.metaballs.remove(mb)
    mo = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(mo)
    for p in me.polygons: p.use_smooth = True
    return tag(mo, group, color)

def cone(name, group, color, base, tip, r1, r2=0.0, verts=10):
    base, tip = Vector(base), Vector(tip)
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=(tip - base).length,
                                    location=(base + tip) / 2)
    o = bpy.context.active_object; o.name = name
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference((tip - base).normalized())
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    for p in o.data.polygons: p.use_smooth = True
    return tag(o, group, color)

def horn(name, group, color, root, out, up, segments=5, r=1.2):
    """Curved horn: chain of tapering cones bending outward then up."""
    p = Vector(root)
    for i in range(segments):
        t = (i + 1) / segments
        d = Vector(out) * (1 - t) + Vector(up) * t
        q = p + d.normalized() * 1.6
        cone(f"{name}{i}", group, color if i < segments - 1 else "gold", p, q, r * (1 - i / segments), r * (1 - (i + 1) / segments) + 0.05)
        p = q

def torus(name, group, color, center, major, minor, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=center, major_segments=40, minor_segments=10)
    o = bpy.context.active_object; o.name = name; o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    for p in o.data.polygons: p.use_smooth = True
    return tag(o, group, color)

# ---- body (hunched, heavy chest, round belly)
blob("Body_stone", "Body", "stone", [
    ("ellip", (0, 0.3, 15.5), (6.2, 4.6, 5.0)),
    ("ellip", (0, -0.4, 18.6), (7.4, 4.6, 3.6)),
    ("ellip", (0, 0.6, 12.6), (5.4, 4.4, 3.4)),
    ("ellip", (0, 0, 10.4), (4.8, 3.6, 2.2)),
    ("ellip", (0, -1.2, 20.4), (4.4, 3.4, 1.6)),  # trapezius hump
])
blob("Body_moss", "Body", "moss", [
    ("ellip", (0, -2.6, 20.6), (5.6, 2.2, 1.6)),
    ("ball", (-4.2, -2.8, 19.4), 1.6), ("ball", (4.0, -3.0, 19.0), 1.5), ("ball", (0, -3.6, 18.8), 1.4),
])
torus("Body_rope", "Body", "rope", (0, 0.4, 11.8), 5.6, 0.75, (1, 0.85, 1))
blob("Body_knot", "Body", "rope", [("ball", (0, 4.6, 11.8), 1.1), ("ball", (-0.9, 4.6, 11.0), 0.8), ("ball", (0.9, 4.6, 11.0), 0.8)])
for i, x in enumerate((-2.4, 0, 2.4)):
    blob(f"Body_paper{i}", "Body", "paper", [("ellip", (x, 4.9, 9.6), (0.6, 0.2, 1.4))])
blob("Body_core", "Body", "glow", [("ellip", (0, 4.9, 16.2), (1.5, 0.6, 1.5))])
blob("Body_coreRim", "Body", "gold", [("ellip", (0, 4.6, 16.2), (2.1, 0.5, 2.1))])
for i, (x, h) in enumerate(((-1.6, 3.2), (-0.4, 4.4), (0.9, 3.6), (2.0, 2.6))):
    cone(f"Body_crystal{i}", "Body", "crystal", (x, -4.0, 13.5), (x * 1.2, -5.4, 13.5 + h), 0.6, 0.05, 6)

# ---- head (oni mask face, heavy brow, tusks, curved horns, mossy mane)
blob("Head_stone", "Head", "stone", [
    ("ellip", (0, 0.6, 24.0), (3.7, 3.5, 3.6)),
    ("ellip", (0, 1.4, 21.6), (3.2, 2.8, 1.6)),  # jaw
])
blob("Head_mask", "Head", "red", [
    ("ellip", (0, 3.4, 23.6), (3.5, 1.2, 2.6)),
    ("ellip", (0, 3.3, 21.7), (3.0, 1.1, 1.3)),
])
# angry brows: tilted about the facing (Y) axis, inner ends low
blob("Head_brow", "Head", "redDark", [("ellip", (-1.6, 4.3, 25.1), (1.7, 0.7, 0.6), (0.95, 0, 0.31, 0)),
                                      ("ellip", (1.6, 4.3, 25.1), (1.7, 0.7, 0.6), (0.95, 0, -0.31, 0))])
blob("Head_nose", "Head", "redDark", [("ellip", (0, 4.7, 23.3), (0.9, 0.8, 0.8))])
blob("Head_eyes", "Head", "eye", [("ellip", (-1.5, 4.3, 24.3), (0.85, 0.4, 0.5), (0.97, 0, -0.24, 0)),
                                  ("ellip", (1.5, 4.3, 24.3), (0.85, 0.4, 0.5), (0.97, 0, 0.24, 0))])
blob("Head_mouth", "Head", "ink", [("ellip", (0, 4.25, 21.9), (2.1, 0.4, 0.55))])
for i, x in enumerate((-1.4, -0.5, 0.5, 1.4)):
    cone(f"Head_tooth{i}", "Head", "cream", (x, 4.5, 22.4), (x, 4.6, 21.7), 0.28, 0.02, 6)
for s in (-1, 1):
    cone(f"Head_tusk{s}", "Head", "cream", (1.9 * s, 4.3, 21.4), (2.4 * s, 5.2, 23.4), 0.45, 0.04, 8)
    horn(f"Head_horn{s}_", "Head", "cream", (2.2 * s, 0.6, 26.6), (1.0 * s, 0, 0.35), (0.25 * s, 0.1, 1.0), 6, 1.1)
blob("Head_mane", "Head", "mossDark", [
    ("ellip", (0, -1.8, 25.2), (3.6, 2.2, 2.6)), ("ball", (-2.4, -2.8, 23.4), 1.4), ("ball", (2.4, -2.8, 23.4), 1.4),
    ("ball", (0, -3.4, 22.8), 1.5), ("ball", (0, -0.6, 27.2), 1.3),
])

# ---- arms (separate from the torso so the rig can swing them), left = -x
for s, g in ((-1, "ArmL"), (1, "ArmR")):
    blob(f"{g}_stone", g, "stone", [
        ("capsule", (9.6 * s, -0.2, 18.2), (10.4 * s, 0.4, 12.8), 2.3),
        ("capsule", (10.4 * s, 0.4, 12.8), (10.8 * s, 1.6, 8.6), 2.5),
    ])
    blob(f"{g}_fist", g, "stoneDark", [("ellip", (10.9 * s, 2.0, 6.8), (2.9, 3.0, 2.5)),
                                       ("ball", (10.2 * s, 4.2, 7.4), 1.0), ("ball", (11.6 * s, 4.2, 7.4), 1.0)])
    blob(f"{g}_pauldron", g, "moss", [("ellip", (9.8 * s, -0.3, 20.0), (3.4, 3.4, 2.6)),
                                      ("ball", (10.6 * s, -1.0, 22.0), 1.3), ("ball", (9.0 * s, 0.8, 22.2), 1.1)])
    torus(f"{g}_bracer", g, "gold", (10.7 * s, 1.0, 10.6), 2.5, 0.5)
    for i, z in enumerate((20.6, 21.4)):
        cone(f"{g}_spike{i}", g, "cream", (10.0 * s + i * 1.2 * s, -0.4, z + 1.2), (10.6 * s + i * 1.6 * s, -0.8, z + 3.4), 0.55, 0.03, 8)

# ---- legs (short and thick, wading)
for s, g in ((-1, "LegL"), (1, "LegR")):
    blob(f"{g}_stone", g, "stone", [
        ("capsule", (3.2 * s, 0, 9.2), (3.5 * s, 0.6, 4.8), 2.5),
        ("capsule", (3.5 * s, 0.6, 4.8), (3.4 * s, 0.2, 1.6), 2.3),
    ])
    blob(f"{g}_foot", g, "stoneDark", [("ellip", (3.4 * s, 1.4, 0.9), (2.6, 3.6, 0.95))])
    for i, dx in enumerate((-1.4, 0, 1.4)):
        cone(f"{g}_claw{i}", g, "cream", (3.4 * s + dx, 3.4, 0.6), (3.4 * s + dx, 5.0, 0.3), 0.45, 0.03, 6)
    torus(f"{g}_band", g, "rope", (3.4 * s, 0.4, 2.6), 2.3, 0.4)

# fit the rope rings snugly around what they wrap: scale each ring to the wrapped mesh's cross-section at its height
def fit_ring(ring_name, body_name, slack=-0.2):
    ring, body = bpy.data.objects[ring_name], bpy.data.objects[body_name]
    z = sum(v.co.z for v in ring.data.vertices) / len(ring.data.vertices)
    cx = sum(v.co.x for v in ring.data.vertices) / len(ring.data.vertices)
    cy = sum(v.co.y for v in ring.data.vertices) / len(ring.data.vertices)
    near = [v.co for v in body.data.vertices if abs(v.co.z - z) < 0.25]
    rx = max(abs(p.x - cx) for p in near) + slack
    ry = max(abs(p.y - cy) for p in near) + slack
    inner_x = min(abs(v.co.x - cx) for v in ring.data.vertices if abs(v.co.y - cy) < 0.5)
    inner_y = min(abs(v.co.y - cy) for v in ring.data.vertices if abs(v.co.x - cx) < 0.5)
    for v in ring.data.vertices:
        v.co.x = cx + (v.co.x - cx) * rx / inner_x
        v.co.y = cy + (v.co.y - cy) * ry / inner_y
fit_ring("Body_rope", "Body_stone")
for g in ("ArmL", "ArmR"):
    fit_ring(f"{g}_bracer", f"{g}_stone")
for g in ("LegL", "LegR"):
    fit_ring(f"{g}_band", f"{g}_stone")

n = len(coll.objects)
print("sculpt objects", n, "tris", sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in coll.objects))
