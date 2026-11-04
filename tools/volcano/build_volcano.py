"""FarVolcano: a distant voxel volcano built with the SAME pipeline as the far voxel trees (voxel_far_trees/source):
coarse blocks (10 studs each), one solid shell, banded colours, shared stud texture pieces with bright rims, split into
parts by colour band when one 1024 px texture is not enough. Output: a .glb to import into Studio (1 unit = 1 stud).

Run (no system Python; the NVIDIA one has numpy, scipy and Pillow):
  "%LOCALAPPDATA%\\NVIDIA\\ChatWithRTX\\env_nvd_rag\\python.exe" tools/volcano/build_volcano.py [outDir]

Reads the far-tree modules and the stud textures from the Downloads folder (voxel_far_trees/source, StudPlastic_*.png).
Shape (blocks of 10 studs): a stratovolcano with a steep, ridged cone and a ragged caldera on top.
  base radius 50 blocks (500 studs), rim height 64 blocks (640 studs), caldera radius 11 blocks, bowl 7 blocks deep.
The model's origin is the centre of the base on the ground; the crater centre is the model's top-centre, the rim is the
highest point (bounding box max Y) and the lava lake sits LAKE_DEPTH studs below it. EventScripts use those numbers.
"""
import os, sys, json, math
DL = os.path.join(os.path.expanduser("~"), "Downloads")
SRC = os.path.join(DL, "voxel_far_trees", "source")
sys.path.insert(0, SRC)
os.environ.setdefault("STUDS_ONLY", "1"); os.environ.setdefault("FULLER", "1")
import numpy as np
from PIL import Image
import voxel_kit as vk
vk.TEX_DIR = DL; vk.STUDS_ONLY = True
import voxel_shared as VS
from obj_to_glb import convert
from voxel_kit import Mat, Model

BLOCK = 10.0                 # studs per block (the far trees: F * SCALE = 2 * 5)
BASE_R, RIM_H, CRATER_R, BOWL = 50, 64, 11.0, 7
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "Volcano")
NAME = "FarVolcano"
rng = np.random.default_rng(2611)

# ---- colours: banded, no per-block noise (like the far trees) ----
# Aerial perspective is baked in: cooler, lighter, lower-contrast colours so it reads as a far mountain next to the near trees.
MATS = {
    "forest0": Mat((46, 92, 60), "forest"), "forest1": Mat((62, 116, 72), "forest"),
    "dirt0": Mat((104, 78, 62), "dirt"), "dirt1": Mat((126, 96, 78), "dirt"),
    # warm basalt: dark brown-black low, red-brown mid, pale ash-grey at the top, each in two tones so the slopes are not flat
    "rock0": Mat((60, 48, 50), "rock"), "rock0b": Mat((46, 36, 40), "rock"),
    "rock1": Mat((92, 72, 66), "rock"), "rock1b": Mat((74, 58, 56), "rock"),
    "rock2": Mat((122, 100, 90), "rock"), "rock2b": Mat((100, 82, 76), "rock"),
    "ash": Mat((156, 143, 134), "ash"),
    "crust": Mat((150, 56, 26), "crust"),           # unused unless BAKED_FLOWS
    "inner": Mat((36, 28, 30), "inner"),            # caldera walls and the rock under the lake
    "lava": Mat((48, 38, 40), "lava"),             # the crater floor: plain dark basalt. NO lava is baked into this mesh (the event draws all of it)

}

# ---- height field ----
N = BASE_R * 2 + 3
cx = cz = N // 2
ang_ph = rng.uniform(0, 6.28, 7); ang_amp = [.16, .10, .08, .06, .045, .03, .02]
def ridge(a):  # angular ridges and gullies on the cone
    return sum(ang_amp[i] * math.sin((i + 2) * a + ang_ph[i]) for i in range(7))
H = np.zeros((N, N), int); BAND = [[None] * N for _ in range(N)]
flows = [(rng.uniform(0, 6.28), rng.uniform(0, 6.28), rng.uniform(0.25, 0.45)) for _ in range(3)]  # direction, wobble phase, wobble pace
# Glow strength per material (0..255) for the emissive mask: the lake blazes, the flows glow, everything else is dark.
EMISSIVE = {}  # no glowing parts: all masks come out black
NOTCH_ANGLE = 0.0   # model-space direction of the opening (after import the model is turned so this faces the map)
NOTCH_HALF = 2.6    # half-width of the opening in blocks (26 studs each side)
FLOOR_H = RIM_H - 1 - BOWL            # lake floor height in blocks
LIP_H = FLOOR_H + 3.5               # the opening's lip: lava rising past this spills out
NOTCH_CELLS = set()
BAKED_FLOWS = False  # the lava flows are drawn by the event (VolcanoEventClient); baked strips only read as a static brown stripe
for i in range(N):
    for k in range(N):
        dx, dz = i - cx, k - cz; r = math.hypot(dx, dz)
        if r > BASE_R: continue
        a = math.atan2(dz, dx)
        t = max(0.0, 1 - r / BASE_R)
        cone = RIM_H * (t ** 1.85) / ((1 - CRATER_R / BASE_R) ** 1.85)     # = RIM_H at the caldera rim
        cone *= 1 + ridge(a) * min(1, r / 18)
        if r <= CRATER_R:
            u = r / CRATER_R
            h = RIM_H - 1 - BOWL * (1 - u * u)                              # bowl
        else:
            h = cone
            # a solid shoulder just outside the rim: where a gully made the cone lower than the crater floor, the lake's column of
            # lava-coloured blocks used to show through the outside as a red strip
            w = min(1.0, max(0.0, (r - (CRATER_R + 4)) / 10.0))               # the shoulder fades into the cone over 10 blocks
            h = max(h, (RIM_H - 0.8 * (r - CRATER_R)) * (1 - w) + h * w)
            if r < CRATER_R + 2.5:                                          # ragged rim, never above RIM_H
                h = min(h, RIM_H - (1 if math.sin(a * 9 + ang_ph[0]) > 0.4 else 0))
        # the opening: a notch cut through the rim on the NOTCH_ANGLE side, down to just above the lake, so the rising lava is seen
        # and spills out through it (the event's main flow starts here)
        across = abs(math.sin(a - NOTCH_ANGLE)) * r                          # sideways distance from the notch's axis
        along = math.cos(a - NOTCH_ANGLE) > 0                                 # on the notch's side of the volcano
        if along and across <= NOTCH_HALF and r > CRATER_R * 0.8:
            lip = LIP_H - 0.3 * max(0.0, r - CRATER_R)                       # the lip slopes down outward
            if lip < h:
                h = lip
                NOTCH_CELLS.add((i, k))
        if h < 2.0 and r > CRATER_R + 3:
            continue                       # no flat apron: the foot ends where the slope is 2 blocks high (it is buried at placement)
        H[i, k] = max(2, int(round(h)))
        BAND[i][k] = (r, a)
# smooth single-column spikes and notches on the slopes (the rim and bowl keep their ragged edge)
from scipy import ndimage as _nd
_sm = np.rint(_nd.uniform_filter(H.astype(float), size=3)).astype(int)
for i in range(N):
    for k in range(N):
        if BAND[i][k] and BAND[i][k][0] > CRATER_R + 3.5:
            H[i, k] = max(2, _sm[i, k])
# the single highest rim cell sits exactly at RIM_H so the bounding box top is the rim
best = max(((H[i, k], i, k) for i in range(N) for k in range(N) if BAND[i][k] and CRATER_R < BAND[i][k][0] < CRATER_R + 2.6), key=lambda x: x[0])
H[best[1], best[2]] = RIM_H

def mat_for(i, k, y, top):
    r, a = BAND[i][k]
    if r <= CRATER_R + 0.2:
        return "lava" if y >= H[i, k] - 2 else "inner"
    if (i, k) in NOTCH_CELLS:
        return "rock2" if y >= H[i, k] - 1 else "inner"   # the lip of the opening is ordinary rock
    for f, phase, pace in (flows if BAKED_FLOWS else []):                   # lava flows: they wander, narrow and fade out
        wobble = 0.05 * math.sin(r * pace + phase) + 0.025 * math.sin(r * pace * 2.3 + phase * 1.7)
        d = abs(((a - f - wobble + math.pi) % (2 * math.pi)) - math.pi) * r
        reach = (r - CRATER_R) / (BASE_R * 0.8 - CRATER_R)                  # 0 at the rim ... 1 near the foot
        width = (1.0 + 2.0 * (1 - reach)) * (0.8 + 0.4 * math.sin(r * 0.9 + phase))
        if d < width and r > CRATER_R + 1 and reach < 1 and y > 8: return "crust"
    j = ((i * 7 + k * 13 + y * 5) % 7 - 3) * 0.012                    # ragged band edges, still no per-block noise
    f = y / RIM_H + j
    if f < .12: return "forest0" if (i + k) % 5 else "forest1"
    if f < .26: return "forest1" if (i * 3 + k) % 4 else "forest0"
    if f < .36: return "dirt0"
    if f < .48: return "dirt1"
    alt = (i * 5 + k * 3 + y) % 4 == 0                                  # a second tone on one block in four
    if f < .66: return "rock0b" if alt else "rock0"
    if f < .84: return "rock1b" if alt else "rock1"
    if f < .95: return "rock2b" if alt else "rock2"
    return "ash"

C = Model(NAME, MATS)
for i in range(N):
    for k in range(N):
        if not BAND[i][k]: continue
        for y in range(H[i, k]):
            C.grids[1.0][(i, y, k)] = mat_for(i, k, y, y == H[i, k] - 1)

# ---- same bake as far trees ----
import build_v3 as V3
faces = vk.build_faces(C); tiles = VS.plan(C, faces)
TARGET = 32; budget = 0.78 * 1024 * 1024
if V3.need_px(tiles, TARGET) <= budget: groups = [tiles]
else:
    by = {}
    for t in tiles: by.setdefault(t["key"][0], []).append(t)
    groups = []; cur = []
    for m, ts in sorted(by.items()):
        if cur and V3.need_px(cur + ts, TARGET) > budget: groups.append(cur); cur = []
        cur = cur + ts
    if cur: groups.append(cur)
d = os.path.abspath(OUT); os.makedirs(d, exist_ok=True)
off = np.array([-cx, 0, -cz], float)                       # origin = centre of the base, on the ground
parts = []; info = []
for gi, g in enumerate(groups):
    pn = NAME if len(groups) == 1 else f"{NAME}_S{gi+1}"
    q, col, nrm, D, nk = VS.bake_tiles(g, C.mats, Dmax=96)
    glow = {k: Mat((EMISSIVE.get(k, 0),) * 3, m.group, m.studs, m.shape_lines) for k, m in C.mats.items()}
    _, ecol, _, D2, _ = VS.bake_tiles(g, glow, Dmax=96)
    assert D2 == D, "emissive atlas must match the colour atlas layout"
    mask = ecol[..., 0]
    Image.fromarray(np.dstack([mask, mask, mask, mask]).astype(np.uint8), "RGBA").save(f"{d}/{pn}_emissive.png")
    Image.fromarray(col).save(f"{d}/{pn}_color.png"); Image.fromarray(nrm).save(f"{d}/{pn}_normal.png")
    parts.append((pn, q)); info.append((len(q) * 2, D, nk))
with open(f"{d}/{NAME}.obj", "w") as f, open(f"{d}/{NAME}.mtl", "w") as mt:
    f.write(f"mtllib {NAME}.mtl\n"); vo = 0
    for pn, q in parts:
        f.write(f"o {pn}\ng {pn}\nusemtl {pn}\n")
        mt.write(f"newmtl {pn}\nKd 1 1 1\nmap_Kd {pn}_color.png\nnorm {pn}_normal.png\nmap_Bump {pn}_normal.png\n\n")
        for pts, uvs, Nn in q:
            for p in pts: f.write("v %.3f %.3f %.3f\n" % tuple((np.array(p) + off) * BLOCK))
            for t in uvs: f.write("vt %.5f %.5f\n" % t)
            f.write("vn %d %d %d\n" % tuple(Nn))
        for i in range(len(q)):
            a = vo + 4 * i + 1; n = vo // 4 + i + 1
            f.write(f"f {a}/{a}/{n} {a+1}/{a+1}/{n} {a+2}/{a+2}/{n}\nf {a}/{a}/{n} {a+2}/{a+2}/{n} {a+3}/{a+3}/{n}\n")
        vo += 4 * len(q)
convert(f"{d}/{NAME}.obj", f"{d}/{NAME}.glb")
P = np.array([p for _, q in parts for pts, _, _ in q for p in pts]) + off
P = P * BLOCK
size = (P.max(0) - P.min(0))
meta = dict(name=NAME, parts=len(parts), tris=sum(i[0] for i in info), size=[round(float(x)) for x in size],
            top_y=round(float(P.max(0)[1])), centre_x=round(float((P.max(0)[0] + P.min(0)[0]) / 2), 1), centre_z=round(float((P.max(0)[2] + P.min(0)[2]) / 2), 1),
            crater_radius=CRATER_R * BLOCK, lake_depth=BOWL * BLOCK, block=BLOCK, lake_floor=FLOOR_H * BLOCK, notch_lip=LIP_H * BLOCK, notch_half=NOTCH_HALF * BLOCK, notch_angle=NOTCH_ANGLE, px=[min(i[1] for i in info), max(i[1] for i in info)])
json.dump(meta, open(f"{d}/{NAME}.json", "w"), indent=1)
print(json.dumps(meta))
