// Lava maps for the Arena Brawl volcano. node lava-textures.js <outDir>
// Writes (256 x 256, tiles both ways, one pixel cell = 1 stud when mapped at 64 studs per tile):
//   (512 x 512: 64 cells of 8 px, every cell carries a stud)
//   lava_color.png      dark basalt plates split by glowing orange-yellow seams, hot spots
//   lava_normal.png     plates stand proud of the seams (flat voxel facets)
//   lava_roughness.png  crust rough, seams glossy
//   lava_emissive.png   RGB = A = how hot a pixel is (seams bright, crust a dim red glow)
//   lava_flow.png       second layer: translucent bright veins only (alpha = heat), crosses the first
const fs = require('fs'), zlib = require('zlib'), path = require('path');
const out = process.argv[2] || path.join(__dirname, '..', '..', 'assets', 'ArenaLava');
fs.mkdirSync(out, { recursive: true });
function crc32(b) { let c, t = crc32.t; if (!t) { t = crc32.t = []; for (let n = 0; n < 256; n++) { c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0; } } let crc = -1; for (const x of b) crc = t[(crc ^ x) & 255] ^ (crc >>> 8); return (crc ^ -1) >>> 0; }
function chunk(type, data) { const l = Buffer.alloc(4); l.writeUInt32BE(data.length); const td = Buffer.concat([Buffer.from(type), data]); const c = Buffer.alloc(4); c.writeUInt32BE(crc32(td)); return Buffer.concat([l, td, c]); }
function writePNG(file, w, h, channels, data) {
  const raw = Buffer.alloc(h * (w * channels + 1));
  for (let y = 0; y < h; y++) { raw[y * (w * channels + 1)] = 0; data.copy(raw, y * (w * channels + 1) + 1, y * w * channels, (y + 1) * w * channels); }
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = channels === 4 ? 6 : channels === 3 ? 2 : 0;
  fs.writeFileSync(path.join(out, file), Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]));
}
// The game's own HD stud (the 'Incubator One Stud Cavity' look, measured from the ground; the river water uses the same
// maps): every 1-stud cell below is stamped with it, exactly like the river's studTiles pass.
function readPNG(file) {
  const b = fs.readFileSync(file);
  let p = 8, w, h, type; const idat = [];
  while (p < b.length) {
    const len = b.readUInt32BE(p), kind = b.toString('ascii', p + 4, p + 8), data = b.subarray(p + 8, p + 8 + len);
    if (kind === 'IHDR') { w = data.readUInt32BE(0); h = data.readUInt32BE(4); type = data[9]; }
    else if (kind === 'IDAT') idat.push(data);
    else if (kind === 'IEND') break;
    p += 12 + len;
  }
  const ch = type === 6 ? 4 : 3, raw = zlib.inflateSync(Buffer.concat(idat)), stride = w * ch, img = Buffer.alloc(h * stride);
  for (let y = 0; y < h; y++) {
    const f = raw[y * (stride + 1)], src = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    for (let x = 0; x < stride; x++) {
      const a = x >= ch ? img[y * stride + x - ch] : 0, up = y > 0 ? img[(y - 1) * stride + x] : 0, c = x >= ch && y > 0 ? img[(y - 1) * stride + x - ch] : 0;
      let v = src[x];
      if (f === 1) v += a; else if (f === 2) v += up; else if (f === 3) v += (a + up) >> 1;
      else if (f === 4) { const pa = Math.abs(up - c), pb = Math.abs(a - c), pc = Math.abs(a + up - 2 * c); v += pa <= pb && pa <= pc ? a : pb <= pc ? up : c; }
      img[y * stride + x] = v & 255;
    }
  }
  return { w, h, ch, data: img };
}
const studNormalSrc = readPNG(path.join(__dirname, '..', '..', 'assets', 'water', 'source', 'stud_normal.png'));
const studShadeSrc = readPNG(path.join(__dirname, '..', '..', 'assets', 'water', 'source', 'stud_shade.png'));
const STUD_PERIOD = studNormalSrc.w / 4; // one stud tile in the source images
// Stud tile sample at fx, fy in 0..1 across one cell: { nx, ny } normal tilt and `rim` (0 open, 1 cavity rim/shadow).
function studAt(fx, fy) {
  const sx = Math.min(STUD_PERIOD - 1, Math.floor(fx * STUD_PERIOD)), sy = Math.min(STUD_PERIOD - 1, Math.floor(fy * STUD_PERIOD));
  const i = sy * studNormalSrc.w + sx, n = studNormalSrc.data, s = studShadeSrc.data;
  return {
    nx: n[i * studNormalSrc.ch] / 127.5 - 1,
    ny: n[i * studNormalSrc.ch + 1] / 127.5 - 1,
    rim: Math.min(1, (1 - s[i * studShadeSrc.ch] / 255) * 2.2),
  };
}

// argv[3] = cells per tile (64 for the arena sea, 16 for the river, which tiles every 16 studs), argv[4] = file prefix.
const N = Number(process.argv[3] || 64), PREFIX = process.argv[4] || 'lava_', K = N / 64; // cells per tile (pixel art)
const PX = 16, SIZE = N * PX; // 16 px per cell (1 stud): a 1024 px tile of 64 studs, the largest Roblox keeps
let seed = 7; const rnd = () => (seed = (seed * 1664525 + 1013904223) >>> 0) / 4294967296;
// tileable value noise
function makeNoise(period) { const g = []; for (let i = 0; i < period * period; i++) g.push(rnd()); const sm = t => t * t * (3 - 2 * t);
  return (x, y) => { x = ((x % period) + period) % period; y = ((y % period) + period) % period; const x0 = Math.floor(x), y0 = Math.floor(y), fx = sm(x - x0), fy = sm(y - y0), x1 = (x0 + 1) % period, y1 = (y0 + 1) % period;
    const a = g[y0 * period + x0], b = g[y0 * period + x1], c = g[y1 * period + x0], d = g[y1 * period + x1]; return (a + (b - a) * fx) * (1 - fy) + (c + (d - c) * fx) * fy; }; }
const coolN = makeNoise(4), warpA = makeNoise(4), warpB = makeNoise(4), heatN = makeNoise(8), fine = makeNoise(16);
function worley(period, count) { const pts = []; for (let j = 0; j < count; j++) for (let i = 0; i < count; i++) pts.push([(i + 0.15 + rnd() * 0.7) * period / count, (j + 0.15 + rnd() * 0.7) * period / count]);
  return (x, y) => { let f1 = 1e9, f2 = 1e9; for (const [px, py] of pts) for (let oy = -1; oy <= 1; oy++) for (let ox = -1; ox <= 1; ox++) { const dx = x - (px + ox * period), dy = y - (py + oy * period), d = Math.sqrt(dx * dx + dy * dy); if (d < f1) { f2 = f1; f1 = d; } else if (d < f2) f2 = d; } return [f1, f2]; }; }
const CT = N === 64 ? 0 : 0.16; // fewer dark crust floes on the narrow river tile
const plates = worley(N, N === 64 ? 7 : 5), veins = worley(N, N === 64 ? 11 : 7);
// per cell: seam closeness 0..1 (1 = in the seam) and a heat value
const seam = new Float32Array(N * N), heat = new Float32Array(N * N), vein = new Float32Array(N * N);
for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
  const u = x / N * 4, v = y / N * 4;
  const wx = x + (warpA(u, v) - .5) * 9 * K, wy = y + (warpB(u, v) - .5) * 9 * K;
  const [f1, f2] = plates(wx, wy); const edge = f2 - f1;
  seam[y * N + x] = Math.max(0, Math.min(1, 1 - edge / (8 * K)));
  const [g1, g2] = veins(x + (warpB(u * 1.3, v * 1.3) - .5) * 12 * K, y + (warpA(u * 1.3, v * 1.3) - .5) * 12 * K); const e2 = g2 - g1;
  vein[y * N + x] = Math.max(0, Math.min(1, 1 - e2 / (2.2 * K)));
  heat[y * N + x] = Math.max(0, Math.min(1, heatN(x / N * 8, y / N * 8) * 1.3 - .1));
}
const q = v => Math.round(v * 6) / 6; // posterise to hard bands (pixel art)
function lerp(a, b, t) { return a + (b - a) * t; }
function lavaColor(s, h, jitter, cool) {
  const sq = q(s);
  if (sq <= 0.62 && cool > 0.46 + CT) { const c = 26 + Math.round(jitter * 22); return [c + 12, c * .42, c * .36, 0.14 + jitter * .08]; } // dark crust floe, faint red glow
  if (sq <= 0.4 || (sq < 0.72 && cool > 0.38 + CT)) return [190 + jitter * 40, 44 + jitter * 30, 8, 0.6]; // glowing rim / deep red lava
  const t = Math.max(0, Math.min(1, (sq - .8) * 1.6 + (h - .55) * 1.1));
  return [255, lerp(78, 205, t), lerp(10, 55, t * t * t), 0.8 + t * .2];
}
const color = Buffer.alloc(SIZE * SIZE * 3), emis = Buffer.alloc(SIZE * SIZE * 4), rough = Buffer.alloc(SIZE * SIZE * 3), normal = Buffer.alloc(SIZE * SIZE * 3), flow = Buffer.alloc(SIZE * SIZE * 4);
const height = new Float32Array(N * N);
for (let i = 0; i < N * N; i++) height[i] = 1 - q(seam[i]);
for (let cy = 0; cy < N; cy++) for (let cx = 0; cx < N; cx++) {
  const i = cy * N + cx, jit = fine(cx / N * 16, cy / N * 16);
  const [r, g, b, e] = lavaColor(seam[i], heat[i], jit, coolN(cx / N * 4, cy / N * 4));
  // normals from the neighbouring heights
  const hx = height[cy * N + (cx + 1) % N] - height[cy * N + (cx + N - 1) % N], hy = height[((cy + 1) % N) * N + cx] - height[((cy + N - 1) % N) * N + cx];
  let nx = -hx * .9, ny = -hy * .9, nz = 1; const nl = Math.hypot(nx, ny, nz); nx /= nl; ny /= nl; nz /= nl;
  const rv = seam[i] > .45 ? 90 : 235;
  const vv = q(vein[i]); const va = vv > .5 ? Math.round(255 * Math.min(1, .35 + vv * .65)) : 0;
  const vr = 255, vg = Math.round(lerp(110, 235, heat[i])), vb = Math.round(lerp(20, 90, heat[i]));
  for (let py = 0; py < PX; py++) for (let px = 0; px < PX; px++) {
    const o = ((cy * PX + py) * SIZE + cx * PX + px);
    // the game's stud: normal tilt and rim (0 open ... 1 cavity rim / shadow) from the real stud maps
    const st = studAt((px + .5) / PX, (py + .5) / PX);
    let sx = nx + st.nx * .9, sy = ny + st.ny * .9; const sl = Math.hypot(sx, sy, nz);
    const shadeK = 1 - st.rim * .3;
    color[o * 3] = Math.round(r * shadeK); color[o * 3 + 1] = Math.round(g * shadeK); color[o * 3 + 2] = Math.round(b * (1 - st.rim * .12));
    const ev = Math.round(Math.min(1, e * (1 - st.rim * .55)) * 255); emis[o * 4] = emis[o * 4 + 1] = emis[o * 4 + 2] = emis[o * 4 + 3] = ev;
    rough[o * 3] = rough[o * 3 + 1] = rough[o * 3 + 2] = Math.min(255, Math.round(rv + st.rim * 70));
    normal[o * 3] = Math.round((sx / sl * .5 + .5) * 255); normal[o * 3 + 1] = Math.round((sy / sl * .5 + .5) * 255); normal[o * 3 + 2] = Math.round((nz / sl * .5 + .5) * 255);
    flow[o * 4] = vr; flow[o * 4 + 1] = vg; flow[o * 4 + 2] = vb; flow[o * 4 + 3] = va;
  }
}
if (N === 64) // lava_crest.png: one full wavelength of the two biggest wave trains on its two axes (U = train 1, V = train 2). The script
// feeds each vertex the wave's own phase as UV, so the bright bands sit exactly on the wave crests and travel with them.
// A crest is at 0.25 of a wavelength (the top of the sine); RGBA, alpha = glow, also used as the emissive mask.
{
  const CS = 128, CP = 2; const crest = Buffer.alloc(CS * CS * 4);
  const wrap = d => { d = Math.abs(d % 1); return d > .5 ? 1 - d : d; };
  const cell = new Float32Array((CS / CP) * (CS / CP)); let sd = 99; const r2 = () => (sd = (sd * 1664525 + 1013904223) >>> 0) / 4294967296;
  for (let i = 0; i < cell.length; i++) cell[i] = r2();
  for (let y = 0; y < CS; y++) for (let x = 0; x < CS; x++) {
    const u = (Math.floor(x / CP) + .5) / (CS / CP), v = (Math.floor(y / CP) + .5) / (CS / CP);
    const a1 = Math.exp(-Math.pow(wrap(u - .25) / .075, 2)), a2 = .8 * Math.exp(-Math.pow(wrap(v - .25) / .075, 2));
    let a = Math.max(a1, a2) + .25 * Math.min(a1, a2);
    const n = cell[(Math.floor(y / CP)) * (CS / CP) + Math.floor(x / CP)]; a *= .55 + .6 * n; // ragged, broken glow
    a = Math.min(1, a); const q = Math.round(a * 4) / 4; const al = q < .3 ? 0 : q;
    const o = (y * CS + x) * 4, hot = Math.min(1, q * 1.1);
    crest[o] = 255; crest[o + 1] = Math.round(120 + 110 * hot); crest[o + 2] = Math.round(30 + 90 * hot * hot); crest[o + 3] = Math.round(al * 255);
  }
  writePNG('lava_crest.png', CS, CS, 4, crest);
}
// argv[5] = 'tall': the tile repeated twice downward (16 x 32 cells for the waterfall sheet, which tiles every 32 studs)
const TALL = process.argv[5] === 'tall';
const out2 = (name, ch, buf) => TALL ? writePNG(name, SIZE, SIZE * 2, ch, Buffer.concat([buf, buf])) : writePNG(name, SIZE, SIZE, ch, buf);
out2(PREFIX + 'color.png', 3, color);
out2(PREFIX + 'normal.png', 3, normal);
out2(PREFIX + 'roughness.png', 3, rough);
out2(PREFIX + 'emissive.png', 4, emis);
writePNG(PREFIX + 'flow.png', SIZE, SIZE, 4, flow);
// preview: colour tiled 2x2 with emissive added
const P = Buffer.alloc(SIZE * 2 * SIZE * 2 * 3);
for (let y = 0; y < SIZE * 2; y++) for (let x = 0; x < SIZE * 2; x++) { const s = ((y % SIZE) * SIZE + (x % SIZE)); const e = emis[s * 4] / 255; const o = (y * SIZE * 2 + x) * 3; for (let c = 0; c < 3; c++) P[o + c] = Math.min(255, color[s * 3 + c]); }
writePNG(PREFIX + 'preview.png', SIZE * 2, SIZE * 2, 3, P);
console.log('ok', out);
