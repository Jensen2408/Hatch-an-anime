# Voxel Oni, step 2 (run in Blender after build_oni.py): turn the Hunyuan3D shape into flat grid cubes.
#   exec(compile(open(path).read(), path, "exec"), {"__file__": path, "HY_GLB": r"...\oni_hunyuan.glb", "V": 0.5})
# - the Hunyuan mesh is fitted to the block Oni's bounding box (shrine excluded), already turned to face +Y
# - solid = cells near the surface + everything the outside can't reach (same fill as RosterBuild voxel_rebuild.py)
# - each cube takes colour AND limb group from the nearest piece of the coloured block Oni (VoxelOni collection),
#   so the result still splits into Body / Head / ArmL / ArmR / LegL / LegR for the walk animation
# - output: collection "VoxelOniCubes", one flat-shaded object per "<Group>__<colour>" (no bevel, coplanar faces
#   greedily merged, UVs in studs), plus the block shrine copied over unchanged
import bpy, bmesh, os, numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

V = globals().get("V", 0.5)
HY_GLB = globals()["HY_GLB"]
SHRINE = lambda c: c.z >= 20 and c.y <= -1.0  # Blender coords of the shrine (Roblox y >= 20, z >= 1)

# REF: collection whose tagged pieces give colour + limb (block "VoxelOni" or smooth "OniSculpt").
# The shrine always comes from the block Oni.
REF = globals().get("REF", "VoxelOni")
ref = bpy.data.collections[REF]
block = bpy.data.collections["VoxelOni"]
FILTER_SHRINE = REF == "VoxelOni"
out_coll = bpy.data.collections.get("VoxelOniCubes") or bpy.data.collections.new("VoxelOniCubes")
if out_coll.name not in bpy.context.scene.collection.children:
    bpy.context.scene.collection.children.link(out_coll)
for o in list(out_coll.objects):
    bpy.data.objects.remove(o, do_unlink=True)

# ---- reference: one BVH per block piece (shrine faces left out), with its group and colour
pieces, lo, hi = [], Vector((1e9,) * 3), Vector((-1e9,) * 3)
for o in ref.objects:
    bm = bmesh.new(); bm.from_mesh(o.data); bm.transform(o.matrix_world)
    if FILTER_SHRINE:
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if o["OniGroup"] == "Body" and SHRINE(f.calc_center_median())], context="FACES")
    if not bm.faces:
        bm.free(); continue
    for v in bm.verts:
        lo = Vector(map(min, lo, v.co)); hi = Vector(map(max, hi, v.co))
    pieces.append((BVHTree.FromBMesh(bm), o["OniGroup"], o["OniColor"]))
    bm.free()

# ---- Hunyuan shape, fitted to the reference box
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=HY_GLB)
imported = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
bm = bmesh.new()
for o in imported:
    me = o.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
    me.transform(o.matrix_world)
    bm.from_mesh(me)
for o in [o for o in bpy.data.objects if o not in before]:
    bpy.data.objects.remove(o, do_unlink=True)
if globals().get("FLIP", True):  # Hunyuan returns the Oni facing -Y; the block Oni faces +Y
    for v in bm.verts:
        v.co.x, v.co.y = -v.co.x, -v.co.y
co = np.array([v.co[:] for v in bm.verts])
hlo, hhi = co.min(0), co.max(0)
scale = (hi.z - lo.z) / (hhi[2] - hlo[2])  # match height
offset = np.array([(lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z]) - np.array([(hlo[0] + hhi[0]) / 2, (hlo[1] + hhi[1]) / 2, hlo[2]]) * scale
for v in bm.verts:
    v.co = Vector(np.array(v.co) * scale + offset)
bvh = BVHTree.FromBMesh(bm)
co = np.array([v.co[:] for v in bm.verts])
bm.free()

# ---- solid grid
g0 = co.min(0) - 2 * V
dims = np.ceil((co.max(0) + 2 * V - g0) / V).astype(int)
solid = np.zeros(dims, bool)
R = V * 0.6
for ix in range(dims[0]):
    for iy in range(dims[1]):
        for iz in range(dims[2]):
            if bvh.find_nearest(Vector(g0 + (np.array([ix, iy, iz]) + 0.5) * V), R)[0] is not None:
                solid[ix, iy, iz] = True
outside = np.zeros_like(solid)
outside[0] = outside[-1] = True; outside[:, 0] = outside[:, -1] = True; outside[:, :, 0] = outside[:, :, -1] = True
outside &= ~solid
while True:
    g = np.pad(outside, 1)
    grow = (g[2:, 1:-1, 1:-1] | g[:-2, 1:-1, 1:-1] | g[1:-1, 2:, 1:-1] | g[1:-1, :-2, 1:-1] | g[1:-1, 1:-1, 2:] | g[1:-1, 1:-1, :-2]) & ~solid & ~outside
    if not grow.any():
        break
    outside |= grow
solid = ~outside

# ---- colour + group per surface cube (nearest reference piece)
keys = {}
label = np.full(dims, -1, np.int32)
cells = np.argwhere(solid)
for ix, iy, iz in cells:
    # only cubes with an open neighbour need a label
    if all(0 <= ix + dx < dims[0] and 0 <= iy + dy < dims[1] and 0 <= iz + dz < dims[2] and solid[ix + dx, iy + dy, iz + dz]
           for dx, dy, dz in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))):
        continue
    p = Vector(g0 + (np.array([ix, iy, iz]) + 0.5) * V)
    best, bd = None, 1e9
    for tree, grp, col in pieces:
        hit = tree.find_nearest(p, 6.0)
        if hit[0] is not None and hit[3] < bd:
            best, bd = (grp, col), hit[3]
    best = best or ("Body", "stone")
    label[ix, iy, iz] = keys.setdefault(best, len(keys))
names = {i: k for k, i in keys.items()}

# ---- exterior faces, greedy-merged per (direction, slice, label)
meshes = {}  # (group, colour) -> bmesh
def bm_for(k):
    if k not in meshes:
        b = bmesh.new(); b.loops.layers.uv.new("UVMap"); meshes[k] = b
    return meshes[k]
for axis in range(3):
    u, w = [a for a in range(3) if a != axis]
    for sign in (1, -1):
        for s in range(dims[axis]):
            idx = [slice(None)] * 3; idx[axis] = s
            here = label[tuple(idx)]
            nidx = s + sign
            if 0 <= nidx < dims[axis]:
                idx2 = [slice(None)] * 3; idx2[axis] = nidx
                open_ = ~solid[tuple(idx2)]
            else:
                open_ = np.ones_like(here, bool)
            mask = np.where(open_ & (here >= 0), here, -1)
            done = np.zeros_like(mask, bool)
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
                    plane = g0[axis] + (s + (1 if sign > 0 else 0)) * V
                    corners = []
                    for da, db in ((0, 0), (ht, 0), (ht, wd), (0, wd)):
                        c = [0.0, 0.0, 0.0]
                        c[axis] = plane; c[u] = g0[u] + (a + da) * V; c[w] = g0[w] + (b + db) * V
                        corners.append(Vector(c))
                    # winding: normal must point along +axis*sign
                    n = (corners[1] - corners[0]).cross(corners[3] - corners[0])
                    if n[axis] * sign < 0:
                        corners.reverse()
                    b_ = bm_for(names[k])
                    f = b_.faces.new([b_.verts.new(c) for c in corners])
                    uvl = b_.loops.layers.uv["UVMap"]
                    for loop in f.loops:
                        q = loop.vert.co
                        loop[uvl].uv = (q[u], q[w])

# ---- shrine: copy the block shrine faces over unchanged
for o in block.objects:
    if o["OniGroup"] != "Body":
        continue
    src = bmesh.new(); src.from_mesh(o.data)
    bmesh.ops.delete(src, geom=[f for f in src.faces if not SHRINE(f.calc_center_median())], context="FACES")
    if src.faces:
        tmp = bpy.data.meshes.new("tmp"); src.to_mesh(tmp)
        bm_for(("Body", o["OniColor"])).from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
    src.free()

tris = 0
for (grp, col), b in sorted(meshes.items()):
    bmesh.ops.remove_doubles(b, verts=b.verts, dist=1e-4)
    name = f"{grp}__{col}"
    me = bpy.data.meshes.new(name + "_vox"); b.to_mesh(me); b.free()
    mat = bpy.data.materials.get("Oni_" + col)
    if mat:
        me.materials.append(mat)
    ob = bpy.data.objects.new(name, me) if name not in bpy.data.objects else None
    if ob is None:  # block piece of the same name exists: name the cube one with a suffix, fixed on export
        ob = bpy.data.objects.new(name + ".vox", me)
    ob["OniGroup"], ob["OniColor"] = grp, col
    out_coll.objects.link(ob)
    tris += sum(len(p.vertices) - 2 for p in me.polygons)
print("cubes", int(solid.sum()), "objects", len(out_coll.objects), "tris", tris, "grid", tuple(dims))
