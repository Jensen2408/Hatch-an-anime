// River water maps for Hatch an Anime, adapted from the MIC SIDEWAYS! ocean generator (FFT spectrum + foam noise).
// Usage: node river-water-textures.js <outDir>
// Writes:
//   river_flow_normal.png / river_flow_roughness.png  fast current ripples (V = downstream), tile both ways
//   river_detail_normal.png                            finer chop for the second ripple layer
//   river_foam.png        RGBA, U across the river (bank foam at both edges), V downstream (tiles in V only)
//   river_foam_tide.png   RGBA, the same layout with wide churned bands for the high tide event
//   tide_crest_foam.png   RGBA beam texture for the surge crests: X across the crest (front at the right), Y along it
//   preview_*.png         the maps lit/composited roughly like in game
const fs = require('fs'), zlib = require('zlib'), path = require('path');
const out = process.argv[2] || path.join(__dirname, '..', '..', 'assets', 'water');
fs.mkdirSync(out, { recursive: true });

// ---------- PNG ----------
function crc32(b) { let c, t = crc32.t; if (!t) { t = crc32.t = []; for (let n = 0; n < 256; n++) { c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0; } } let crc = -1; for (const x of b) crc = t[(crc ^ x) & 255] ^ (crc >>> 8); return (crc ^ -1) >>> 0; }
function chunk(type, data) { const l = Buffer.alloc(4); l.writeUInt32BE(data.length); const td = Buffer.concat([Buffer.from(type), data]); const c = Buffer.alloc(4); c.writeUInt32BE(crc32(td)); return Buffer.concat([l, td, c]); }
function writePNG(file, w, h, channels, data) {
  const raw = Buffer.alloc(h * (w * channels + 1));
  for (let y = 0; y < h; y++) { raw[y * (w * channels + 1)] = 0; data.copy(raw, y * (w * channels + 1) + 1, y * w * channels, (y + 1) * w * channels); }
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = channels === 4 ? 6 : 2;
  fs.writeFileSync(path.join(out, file), Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]));
}

// ---------- Pixel-art pass ----------
// The game is built from whole-stud blocks, so every map is block-averaged into cells of `block` pixels, quantized,
// and written back at full size with nearest-neighbour cells. With the in-game repeat sizes one cell is ~1 stud.
//   kind 'normal': average the normals per cell and snap their tilt to a few steps (flat voxel facets)
//   kind 'gray'  : snap to 1/16 steps
//   kind 'rgba'  : alpha-weighted colour per cell, alpha snapped to 0 / .5 / .85 / 1 (below .3 is clear), colour to 16 levels
//   kind 'rgb'   : colour snapped to 16 levels
const PIXEL = true;
function pixelate(w, h, ch, data, block, kind) {
  const out = Buffer.alloc(data.length);
  for (let cy = 0; cy < h; cy += block) for (let cx = 0; cx < w; cx += block) {
    const sum = [0, 0, 0, 0]; let n = 0, wsum = 0;
    for (let y = cy; y < Math.min(h, cy + block); y++) for (let x = cx; x < Math.min(w, cx + block); x++) {
      const i = (y * w + x) * ch, a = ch === 4 ? data[i + 3] / 255 : 1;
      for (let c = 0; c < 3; c++) sum[c] += (kind === 'normal' ? data[i + c] / 127.5 - 1 : data[i + c]) * (kind === 'rgba' ? a : 1);
      if (ch === 4) sum[3] += a;
      wsum += kind === 'rgba' ? a : 1; n++;
    }
    let px;
    if (kind === 'normal') {
      const step = .12, snap = v => Math.max(-.36, Math.min(.36, Math.round(v / step) * step));
      const nx = snap(sum[0] / n), ny = snap(sum[1] / n), nz = Math.sqrt(Math.max(0, 1 - nx * nx - ny * ny));
      px = [nx, ny, nz].map(v => Math.round((v * .5 + .5) * 255));
    } else if (kind === 'gray') {
      const v = Math.round(sum[0] / n / 255 * 16) / 16; px = [v * 255, v * 255, v * 255].map(Math.round);
    } else {
      const q = v => Math.min(255, Math.round(v / 17) * 17);
      px = [0, 1, 2].map(c => q(wsum > 0 ? sum[c] / wsum : 255));
      if (ch === 4) { const a = sum[3] / n; px.push(Math.round((a < .3 ? 0 : a < .55 ? .5 : a < .78 ? .85 : 1) * 255)); }
    }
    for (let y = cy; y < Math.min(h, cy + block); y++) for (let x = cx; x < Math.min(w, cx + block); x++) {
      const i = (y * w + x) * ch; for (let c = 0; c < ch; c++) out[i + c] = px[c];
    }
  }
  return out;
}
function writeMap(file, w, h, ch, data, block, kind) {
  writePNG(file, w, h, ch, PIXEL ? pixelate(w, h, ch, data, block, kind) : data);
}

// ---------- Stud tiles ----------
// Every pixel cell becomes one ground tile: 2 x 2 studs with a stud cavity in it, taken from the game's own stud maps
// (assets/water/source/stud_normal.png and stud_shade.png, 4 x 4 studs per 1024 px image, the "Incubator One Stud
// Cavity" look). The scripts map textures so one cell = 2 studs, the ground's tile size.
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
const studNormalSrc = readPNG(path.join(out, 'source', 'stud_normal.png'));
const studShadeSrc = readPNG(path.join(out, 'source', 'stud_shade.png'));
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
// Averages `data` (w x h, ch channels) into cellsX x cellsY cells, then draws each cell as a cellPx stud tile.
//   'normal'  cell facet tilt (snapped) plus the stud relief
//   'stud'    stud relief only (flat cells), for layers whose colour comes from another map
//   'overlay' (from a normal map) Overlay-mode colour: light/dark teal cells from the facet tilt, dark stud rims
//   'gray'    roughness per cell, rougher stud rims
//   'rgba'    colour + snapped alpha per cell, shaded by the stud rims
function studTiles(file, w, h, ch, data, cellsX, cellsY, kind, cellPx) {
  const W = cellsX * cellPx, H = cellsY * cellPx, outCh = kind === 'normal' || kind === 'stud' || kind === 'gray' ? 3 : 4;
  const img = Buffer.alloc(W * H * outCh);
  for (let cy = 0; cy < cellsY; cy++) for (let cx = 0; cx < cellsX; cx++) {
    const x0 = Math.floor(cx * w / cellsX), x1 = Math.floor((cx + 1) * w / cellsX), y0 = Math.floor(cy * h / cellsY), y1 = Math.floor((cy + 1) * h / cellsY);
    const sum = [0, 0, 0, 0]; let n = 0, wsum = 0;
    for (let y = y0; y < y1; y++) for (let x = x0; x < x1; x++) {
      const i = (y * w + x) * ch, a = ch === 4 ? data[i + 3] / 255 : 1;
      const asNormal = kind === 'normal' || kind === 'overlay' || kind === 'stud';
      for (let c = 0; c < 3; c++) sum[c] += (asNormal ? data[i + c] / 127.5 - 1 : data[i + c]) * (kind === 'rgba' ? a : 1);
      sum[3] += a; wsum += kind === 'rgba' ? a : 1; n++;
    }
    const snap = v => Math.max(-.3, Math.min(.3, Math.round(v / .1) * .1));
    // Ripple slopes mostly cancel over a whole 2-stud cell, so the cell tilt is amplified before snapping.
    const tx = kind === 'stud' ? 0 : snap(sum[0] / n * 5), ty = kind === 'stud' ? 0 : snap(sum[1] / n * 5);
    const q = v => Math.min(255, Math.round(v / 17) * 17);
    const cellRGB = [0, 1, 2].map(c => q(wsum > 0 ? sum[c] / wsum : 255));
    const am = sum[3] / n, cellA = am < .3 ? 0 : am < .55 ? .5 : am < .78 ? .85 : 1;
    const lit = -tx * .7 + ty * .7; // facing the light (up-left) or away from it
    for (let py = 0; py < cellPx; py++) for (let px = 0; px < cellPx; px++) {
      const s = studAt((px + .5) / cellPx, (py + .5) / cellPx), o = ((cy * cellPx + py) * W + cx * cellPx + px) * outCh;
      if (kind === 'normal' || kind === 'stud') {
        let nx = tx + s.nx * .9, ny = ty + s.ny * .9, nz = 1; const l = Math.hypot(nx, ny, nz);
        img[o] = Math.round((nx / l * .5 + .5) * 255); img[o + 1] = Math.round((ny / l * .5 + .5) * 255); img[o + 2] = Math.round((nz / l * .5 + .5) * 255);
      } else if (kind === 'gray') {
        const v = Math.min(1, Math.round(sum[0] / n / 255 * 16) / 16 + s.rim * .3) * 255; img[o] = img[o + 1] = img[o + 2] = Math.round(v);
      } else if (kind === 'overlay') {
        // Light or dark cells shimmer as the ripples pass; every cell carries a dark stud rim like the ground.
        const cell = lit > .1 ? [150, 238, 245, .4] : lit < -.1 ? [24, 128, 160, .35] : [0, 0, 0, 0];
        const rim = s.rim * .55, a = Math.max(cell[3], rim), k = a > 0 ? rim / a : 0;
        img[o] = Math.round(cell[0] + (12 - cell[0]) * k); img[o + 1] = Math.round(cell[1] + (70 - cell[1]) * k); img[o + 2] = Math.round(cell[2] + (92 - cell[2]) * k);
        img[o + 3] = Math.round(a * 255);
      } else {
        const shadeK = 1 - s.rim * .28;
        img[o] = Math.round(cellRGB[0] * shadeK); img[o + 1] = Math.round(cellRGB[1] * shadeK); img[o + 2] = Math.round(cellRGB[2] * (1 - s.rim * .12));
        img[o + 3] = Math.round(cellA * 255);
      }
    }
  }
  writePNG(file, W, H, outCh, img);
  return { W, H, img, ch: outCh };
}

// ---------- RNG / noise ----------
function rng(seed) { let s = seed >>> 0; return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296); }
function gauss(r) { let u = 0; while (u === 0) u = r(); return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * r()); }
// Tileable gradient noise with px cells across U and py cells along V (fewer cells = longer features).
function perlin(px, py, r) {
  const g = []; for (let i = 0; i < px * py; i++) { const a = r() * 2 * Math.PI; g.push([Math.cos(a), Math.sin(a)]); }
  const f = t => t * t * t * (t * (t * 6 - 15) + 10);
  return (u, v) => {
    const x = u * px, y = v * py, x0 = Math.floor(x), y0 = Math.floor(y), fx = x - x0, fy = y - y0;
    const G = (i, j) => g[((j % py + py) % py) * px + ((i % px + px) % px)];
    const d = (i, j, dx, dy) => { const q = G(i, j); return q[0] * dx + q[1] * dy; };
    const sx = f(fx), sy = f(fy);
    return (d(x0, y0, fx, fy) * (1 - sx) + d(x0 + 1, y0, fx - 1, fy) * sx) * (1 - sy) + (d(x0, y0 + 1, fx, fy - 1) * (1 - sx) + d(x0 + 1, y0 + 1, fx - 1, fy - 1) * sx) * sy;
  };
}
function worleyF1(cu, cv, r) {
  const pts = []; for (let j = 0; j < cv; j++) for (let i = 0; i < cu; i++) pts.push([(i + r()) / cu, (j + r()) / cv]);
  return (u, v) => {
    u -= Math.floor(u); v -= Math.floor(v);
    const ci = Math.floor(u * cu), cj = Math.floor(v * cv); let f1 = 9;
    for (let dj = -1; dj <= 1; dj++) for (let di = -1; di <= 1; di++) {
      const p = pts[((cj + dj + cv) % cv) * cu + (ci + di + cu) % cu];
      const dx = (p[0] - u - Math.round(p[0] - u)) * cu, dy = (p[1] - v - Math.round(p[1] - v)) * cv;
      f1 = Math.min(f1, Math.hypot(dx, dy));
    }
    return f1;
  };
}
const sm = (a, b, x) => { const t = Math.min(1, Math.max(0, (x - a) / (b - a))); return t * t * (3 - 2 * t); };
const ridge = (n, k = 2.1) => Math.pow(Math.max(0, 1 - Math.abs(n) * k), 4);

// ---------- FFT ----------
function fft1d(re, im, n, inverse) {
  for (let i = 1, j = 0; i < n; i++) {
    let bit = n >> 1;
    for (; j & bit; bit >>= 1) j ^= bit;
    j ^= bit;
    if (i < j) { let t = re[i]; re[i] = re[j]; re[j] = t; t = im[i]; im[i] = im[j]; im[j] = t; }
  }
  for (let len = 2; len <= n; len <<= 1) {
    const ang = 2 * Math.PI / len * (inverse ? 1 : -1), wr = Math.cos(ang), wi = Math.sin(ang), half = len >> 1;
    for (let i = 0; i < n; i += len) {
      let cr = 1, ci = 0;
      for (let k = 0; k < half; k++) {
        const a = i + k, b = a + half;
        const br = re[b] * cr - im[b] * ci, bi = re[b] * ci + im[b] * cr;
        re[b] = re[a] - br; im[b] = im[a] - bi; re[a] += br; im[a] += bi;
        const nr = cr * wr - ci * wi; ci = cr * wi + ci * wr; cr = nr;
      }
    }
  }
}
function fft2d(re, im, n, inverse) {
  const tr = new Float64Array(n), ti = new Float64Array(n);
  for (let y = 0; y < n; y++) { const o = y * n; for (let x = 0; x < n; x++) { tr[x] = re[o + x]; ti[x] = im[o + x]; } fft1d(tr, ti, n, inverse); for (let x = 0; x < n; x++) { re[o + x] = tr[x]; im[o + x] = ti[x]; } }
  for (let x = 0; x < n; x++) { for (let y = 0; y < n; y++) { tr[y] = re[y * n + x]; ti[y] = im[y * n + x]; } fft1d(tr, ti, n, inverse); for (let y = 0; y < n; y++) { re[y * n + x] = tr[y]; im[y * n + x] = ti[y]; } }
}

// Choppy spectrum height field like the ocean maps, but the wave vectors lean along V (the current), so crests lie
// across the river, and two lobes at +-angle give the crossing V-shaped ripples seen in fast shallow water.
function riverHeight(N, o, seed) {
  const r = rng(seed), NN = N * N;
  const hr = new Float64Array(NN), hi = new Float64Array(NN), xr = new Float64Array(NN), xi = new Float64Array(NN), yr = new Float64Array(NN), yi = new Float64Array(NN);
  const ca = Math.cos(o.lobe), sa = Math.sin(o.lobe);
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const fx = x <= N / 2 ? x : x - N, fy = y <= N / 2 ? y : y - N, k = Math.hypot(fx, fy), i = y * N + x;
    if (k < 1e-9) continue;
    const lobeA = Math.abs((fx * sa + fy * ca) / k), lobeB = Math.abs((-fx * sa + fy * ca) / k);
    const dir = Math.max(Math.pow(lobeA, o.spread), Math.pow(lobeB, o.spread)) * (1 - o.floor) + o.floor;
    const P = Math.pow(k, -o.power) * Math.exp(-1.25 * Math.pow(o.kPeak / k, 2)) * Math.exp(-Math.pow(k / o.kHigh, 2)) * dir;
    const a = Math.sqrt(P), gr = a * gauss(r), gi = a * gauss(r);
    hr[i] = gr; hi[i] = gi;
    xr[i] = -gi * fx / k; xi[i] = gr * fx / k; yr[i] = -gi * fy / k; yi[i] = gr * fy / k;
  }
  fft2d(hr, hi, N, true); fft2d(xr, xi, N, true); fft2d(yr, yi, N, true);
  let v = 0; for (let i = 0; i < NN; i++) v += hr[i] * hr[i]; const sd = Math.sqrt(v / NN);
  for (let i = 0; i < NN; i++) { hr[i] /= sd; xr[i] /= sd; yr[i] /= sd; }
  let dv = 0; for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) { const d = (xr[y * N + (x + 1) % N] - xr[y * N + (x + N - 1) % N] + yr[((y + 1) % N) * N + x] - yr[((y + N - 1) % N) * N + x]) / 2; dv += d * d; }
  const lambda = o.chop / Math.sqrt(dv / NN);
  const samp = (f, px, py) => { px = ((px % N) + N) % N; py = ((py % N) + N) % N; const x0 = Math.floor(px), y0 = Math.floor(py), fx = px - x0, fy = py - y0, x1 = (x0 + 1) % N, y1 = (y0 + 1) % N; return (f[y0 * N + x0] * (1 - fx) + f[y0 * N + x1] * fx) * (1 - fy) + (f[y1 * N + x0] * (1 - fx) + f[y1 * N + x1] * fx) * fy; };
  // Long streaks along the current (few cells along V) ride on top, so the surface reads as flowing water, not sea.
  const streak = perlin(o.streakCells, 2, r), streak2 = perlin(o.streakCells * 2, 3, r);
  const h = new Float64Array(NN);
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    let qx = x, qy = y;
    for (let it = 0; it < 6; it++) { qx = x - lambda * samp(xr, qx, qy); qy = y - lambda * samp(yr, qx, qy); }
    h[y * N + x] = samp(hr, qx, qy) + o.streak * (streak(x / N, y / N) * 2.2 + streak2(x / N, y / N) * 1.1);
  }
  return h;
}

function normalMaps(name, N, o, seed, withRoughness) {
  const h = riverHeight(N, o, seed);
  const gx = new Float64Array(N * N), gy = new Float64Array(N * N);
  let ss = 0;
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const i = y * N + x;
    gx[i] = (h[y * N + (x + 1) % N] - h[y * N + (x + N - 1) % N]) / 2;
    gy[i] = (h[((y + 1) % N) * N + x] - h[((y + N - 1) % N) * N + x]) / 2;
    ss += gx[i] * gx[i] + gy[i] * gy[i];
  }
  const rms = Math.sqrt(ss / (N * N)), s = o.slope / rms;
  const nrm = Buffer.alloc(N * N * 3), pv = Buffer.alloc(N * N * 3);
  const D = [0, Math.cos(.5), -Math.sin(.5)], S = [.2, .8, .56], T = [70 / 255, 214 / 255, 214 / 255];
  for (let i = 0; i < N * N; i++) {
    // OpenGL convention (green up): image rows grow downward, so n.y = +dh/drow.
    let nx = -gx[i] * s, ny = gy[i] * s, nz = 1; const l = Math.hypot(nx, ny, nz); nx /= l; ny /= l; nz /= l;
    nrm[i * 3] = Math.round((nx * .5 + .5) * 255); nrm[i * 3 + 1] = Math.round((ny * .5 + .5) * 255); nrm[i * 3 + 2] = Math.round((nz * .5 + .5) * 255);
    const dn = D[0] * nx + D[1] * ny + D[2] * nz, rx = D[0] - 2 * dn * nx, ry = D[1] - 2 * dn * ny, rz = Math.max(0, D[2] - 2 * dn * nz);
    const up = Math.sqrt(rz), spec = Math.pow(Math.max(0, rx * S[0] + ry * S[1] + rz * S[2]), 160) * 2.4;
    for (let c = 0; c < 3; c++) { const sky = [.9, .95, .98][c] * (1 - up) + [.5, .74, .9][c] * up; pv[i * 3 + c] = Math.min(255, (sky * T[c] * 1.15 + spec) * 255); }
  }
  if (o.raw) return nrm;
  // One cell per ground tile (2 studs): o.cells cells across the texture's repeat, each drawn as a stud tile.
  studTiles(name + '_normal.png', N, N, 3, nrm, o.cells, o.cells, 'normal', 64);
  studTiles(name + '_color.png', N, N, 3, nrm, o.cells, o.cells, 'overlay', 64);
  writeMap('preview_' + name + '.png', N, N, 3, pv, N / o.cells, 'rgb');
  if (withRoughness) {
    // Glossy stream water: smooth on the long glides, a little rougher on steep ripple faces.
    const R = N / 2, rough = Buffer.alloc(R * R * 3), patch = perlin(5, 3, rng(seed + 7));
    for (let y = 0; y < R; y++) for (let x = 0; x < R; x++) {
      let m = 0; for (let dy = 0; dy < 2; dy++) for (let dx = 0; dx < 2; dx++) { const i = (y * 2 + dy) * N + x * 2 + dx; m += Math.hypot(gx[i], gy[i]) / rms; } m /= 4;
      const v = Math.min(.48, Math.max(.06, .2 + .08 * (m - 1) + .08 * patch(x / R, y / R)));
      const b = Math.round(v * 255), i = (y * R + x) * 3; rough[i] = rough[i + 1] = rough[i + 2] = b;
    }
    studTiles(name + '_roughness.png', R, R, 3, rough, o.cells, o.cells, 'gray', 32);
  }
  console.log(name, 'done');
}

// ---------- Foam: U across the river (0 = left bank, 1 = right bank), V downstream ----------
// band = how far the bank foam reaches in from each edge, streaks = midstream filament strength, churn = extra
// whitewater patches (the tide version).
function riverFoam(file, W, H, o, seed) { // W, H: source size; reassigned to the stud tile output size
  const r = rng(seed);
  const edgeA = perlin(3, 6, r), edgeB = perlin(6, 14, r), edgeC = perlin(12, 30, r);
  const fil1 = perlin(14, 3, r), fil2 = perlin(28, 5, r), fil3 = perlin(40, 9, r);
  const warpU = perlin(4, 6, r), warpV = perlin(4, 6, r), patch = perlin(3, 4, r), patch2 = perlin(7, 9, r);
  const holes = worleyF1(14, 28, r), churnN = perlin(5, 8, r), churnFine = perlin(16, 26, r);
  const img = Buffer.alloc(W * H * 4); let pv;
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const u = x / (W - 1), v = y / H;
    const wu = u + .04 * warpU(u, v), wv = v + .05 * warpV(u, v);
    // Ragged bank foam: a band from each edge whose reach wanders, broken by bubble holes near its inner edge.
    const reachL = o.band * (1 + .55 * edgeA(0, v) + .3 * edgeB(.1, wv) + .15 * edgeC(.2, wv));
    const reachR = o.band * (1 + .55 * edgeA(.5, v) + .3 * edgeB(.6, wv) + .15 * edgeC(.7, wv));
    const bubbles = sm(.18, .55, holes(wu, wv));
    const bankL = 1 - sm(reachL * .45, reachL, u), bankR = 1 - sm(reachR * .45, reachR, 1 - u);
    let bank = Math.max(bankL, bankR);
    bank *= .55 + .45 * bubbles;
    bank = Math.max(bank, Math.max(1 - sm(0, .035, u), 1 - sm(0, .035, 1 - u)) * .9); // solid lip against the banks
    // Midstream filaments stretched along the current, gathered in drifting patches.
    const fil = .6 * ridge(fil1(wu, wv)) + .35 * ridge(fil2(wu, wv)) + .2 * ridge(fil3(wu, wv), 2.6);
    const gather = sm(-.1, .35, .7 * patch(u, v) + .3 * patch2(u, v) + o.patchBias);
    const centre = sm(0, .16, u) * sm(0, .16, 1 - u);
    let mid = fil * o.streaks * (.25 + .75 * gather) * (.5 + .5 * bubbles) * centre;
    // Churned whitewater blobs (tide only).
    const churn = o.churn * sm(.05, .45, churnN(wu, wv) + .35 * churnFine(wu, wv)) * (.45 + .55 * bubbles);
    const a = Math.min(1, Math.max(bank, mid + churn));
    const i = (y * W + x) * 4, shade = 236 + 19 * Math.min(1, a * 1.2);
    img[i] = Math.min(255, shade - 4); img[i + 1] = Math.min(255, shade + 2); img[i + 2] = 255; img[i + 3] = Math.round(Math.pow(a, .9) * 255);
  }
  if (o.raw) return img;
  const tiles = studTiles(file + '.png', W, H, 4, img, o.cellsX, o.cellsY, 'rgba', 32), px = tiles.img;
  W = tiles.W; H = tiles.H; pv = Buffer.alloc(W * H * 3);
  for (let k = 0; k < W * H; k++) { const al = px[k * 4 + 3] / 255; pv[k * 3] = 70 + (px[k * 4] - 70) * al; pv[k * 3 + 1] = 214 + (px[k * 4 + 1] - 214) * al; pv[k * 3 + 2] = 214 + (255 - 214) * al; }
  writePNG('preview_' + file + '.png', W, H, 3, pv);
  console.log(file, 'done');
}

// Surge crest foam for beams laid across the river. A Beam maps the image's right edge across its width, so here
// image X runs across the crest (0 = back of the wave, 1 = its breaking front) and image Y runs along the crest
// (tiles). A bright rolling lip at the front with a lacy trail behind it.
function crestFoam(file, W, H, seed, raw) {
  const r = rng(seed);
  const lip = perlin(10, 1, r), lip2 = perlin(24, 1, r), lace = perlin(18, 4, r), lace2 = perlin(36, 7, r), holes = worleyF1(30, 6, r);
  const img = Buffer.alloc(W * H * 4);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const u = y / H, v = x / (W - 1);
    const front = .72 + .08 * lip(u, 0) + .04 * lip2(u, 0);
    const bubbles = sm(.15, .5, holes(u, v * .999));
    const crest = sm(front - .3, front - .04, v) * (1 - sm(front, front + .1, v));
    const trail = sm(.05, .45, v) * (1 - sm(front - .25, front, v)) * (.5 * ridge(lace(u, v), 1.6) + .35 * ridge(lace2(u, v), 2)) ;
    const a = Math.min(1, crest * (.75 + .25 * bubbles) + trail * (.4 + .6 * bubbles));
    const i = (y * W + x) * 4;
    img[i] = 244; img[i + 1] = 252; img[i + 2] = 255; img[i + 3] = Math.round(a * 255);
  }
  if (raw) return img;
  studTiles(file + '.png', W, H, 4, img, 4, 8, 'rgba', 32); // ~1.75-stud cells on a 7-stud crest
  console.log(file, 'done');
}

// Waterfall sheet, U across the fall (16 cells), V down it (32 cells, tiles; the script scrolls it downward).
// body: opaque-ish blue water with long light streaks; veil: sparse white streaks in front, broken into dashes.
function waterfall(file, W, H, seed, veil, raw) {
  const r = rng(seed);
  const s1 = perlin(10, 2, r), s2 = perlin(20, 3, r), s3 = perlin(6, 1, r), dash = perlin(14, 10, r), patch = perlin(4, 5, r);
  const img = Buffer.alloc(W * H * 4);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const u = x / W, v = y / H, i = (y * W + x) * 4;
    const streak = .65 * ridge(s1(u, v), 1.8) + .45 * ridge(s2(u, v), 2.2);
    if (veil) {
      const a = Math.min(1, streak * sm(-.05, .3, dash(u, v)) * 1.6) * (.6 + .4 * sm(-.2, .3, patch(u, v)));
      img[i] = 238; img[i + 1] = 252; img[i + 2] = 255; img[i + 3] = Math.round(a * 255);
    } else {
      const shade = s3(u, v) * .5 + .5, light = Math.min(1, streak * 1.3);
      const base = [34 + 30 * shade, 150 + 40 * shade, 186 + 24 * shade], hi = [150, 236, 245], white = [240, 252, 255];
      const mix = (a, b, t) => a.map((c, k) => c + (b[k] - c) * t);
      const col = light > .75 ? mix(hi, white, (light - .75) * 4) : mix(base, hi, light / .75);
      img[i] = col[0]; img[i + 1] = col[1]; img[i + 2] = col[2]; img[i + 3] = Math.round((.86 + .14 * light) * 255);
    }
  }
  if (raw) return img;
  studTiles(file + '.png', W, H, 4, img, 8, 16, 'rgba', 32); // 2-stud cells on a 16 x 32 stud tile
  console.log(file, 'done');
}

// ---------- Current version: static stud layer + smooth 1-stud pixel flow layer ----------
// The ground's studs are 1 stud apart in 4-stud panels (the stud maps in source/ are exactly one panel), so:
//   - the stud layer is the stud maps themselves (tools/water/stud-water-maps.js), mapped by the scripts to the
//     ground's world grid and never moved, so water studs line up with the ground's;
//   - everything that moves is a 1-stud pixel layer with no studs in it (pixels slide smoothly without dragging studs
//     around), drawn from the first, smooth textures: the crossing V ripples of the FFT ripple map, the bank foam and
//     streaks, the tide churn, the waterfall streaks.
const SHADES = { // pixel palette: [r, g, b, alpha]
  foam: [242, 252, 255], highlight: [214, 250, 255, .6], light: [140, 232, 242, .38],
  dark: [32, 142, 172, .26], deep: [14, 104, 146, .4],
};
const snapAlpha = a => a < .3 ? 0 : a < .55 ? .5 : a < .78 ? .85 : 1;
function cellsToPNG(file, cellsX, cellsY, cellPx, cellAt) { // cellAt(cx, cy) -> [r, g, b, a] (a 0..1)
  const W = cellsX * cellPx, H = cellsY * cellPx, img = Buffer.alloc(W * H * 4);
  for (let cy = 0; cy < cellsY; cy++) for (let cx = 0; cx < cellsX; cx++) {
    const c = cellAt(cx, cy);
    for (let y = 0; y < cellPx; y++) for (let x = 0; x < cellPx; x++) {
      const o = ((cy * cellPx + y) * W + cx * cellPx + x) * 4;
      img[o] = c[0]; img[o + 1] = c[1]; img[o + 2] = c[2]; img[o + 3] = Math.round(c[3] * 255);
    }
  }
  writePNG(file, W, H, 4, img);
  return { W, H, img };
}
// Average of an RGBA buffer's alpha (or of a normal map's light-facing tilt) over a rectangle, wrapping.
function avgAlpha(buf, W, x0, y0, x1, y1) {
  let s = 0, n = 0; for (let y = y0; y < y1; y++) for (let x = x0; x < x1; x++) { s += buf[(y * W + x) * 4 + 3] / 255; n++; } return s / n;
}
function avgLit(nrm, N, u0, v0, u1, v1) { // u, v in pixels of the N x N tileable ripple normal map
  let s = 0, n = 0;
  for (let v = Math.floor(v0); v < v1; v += 2) for (let u = Math.floor(u0); u < u1; u += 2) {
    const i = ((((v % N) + N) % N) * N + (((u % N) + N) % N)) * 3;
    s += -(nrm[i] / 127.5 - 1) * .7 + (nrm[i + 1] / 127.5 - 1) * .7; n++;
  }
  return s / n;
}
// Light/dark ripple pixel for a cell from its light-facing tilt.
function rippleShade(lit) {
  return lit > .2 ? SHADES.highlight : lit > .07 ? SHADES.light : lit < -.2 ? SHADES.deep : lit < -.08 ? SHADES.dark : null;
}

// River flow layer: U wall to wall (14 cells = the 14-stud river), V downstream (36 cells = 36 studs, tiles).
// The ripple map repeats every 16 studs, so 1 stud = N / 16 of its pixels.
const FLOW_N = 512, RIPPLE_STUDS = 16;
const rippleNormal = normalMaps('river_flow', FLOW_N, { raw: true, power: 4.2, kPeak: 6, kHigh: 70, spread: 6, floor: .08, lobe: .5, chop: .32, slope: .22, streak: .35, streakCells: 7 }, 3141, true);
function flowLayer(file, foamOptions, seed) {
  const cellsX = 14, cellsY = 36, FW = 224, FH = 576; // smooth foam field at 16 px per stud
  const foam = riverFoam(null, FW, FH, { ...foamOptions, raw: true }, seed);
  const px = FLOW_N / RIPPLE_STUDS;
  return cellsToPNG(file, cellsX, cellsY, 16, (cx, cy) => {
    const a = snapAlpha(avgAlpha(foam, FW, cx * 16, cy * 16, cx * 16 + 16, cy * 16 + 16));
    if (a > 0) return [...SHADES.foam, a];
    const shade = rippleShade(avgLit(rippleNormal, FLOW_N, cx * px, cy * px, (cx + 1) * px, (cy + 1) * px) * 2.2);
    return shade || [0, 0, 0, 0];
  });
}
flowLayer('river_flow_px.png', { band: .13, streaks: 1.2, churn: 0, patchBias: 0 }, 77);
flowLayer('river_flow_px_tide.png', { band: .24, streaks: 1.9, churn: .55, patchBias: .12 }, 78);

// Surge crest beam: 7 cells across the crest (front at the right) x 14 along it, plain pixels.
{
  const crest = crestFoam(null, 112, 224, 99, true);
  cellsToPNG('tide_crest_px.png', 7, 14, 16, (cx, cy) => {
    const a = snapAlpha(avgAlpha(crest, 112, cx * 16, cy * 16, cx * 16 + 16, cy * 16 + 16));
    return a > 0 ? [...SHADES.foam, a] : [0, 0, 0, 0];
  });
}

// Waterfall flow layer (in front of the static stud sheet): 16 x 32 cells = 16 x 32 studs, scrolling down. White
// streak pixels where the veil streaks are, light and deep blue pixels from the body's streak brightness.
{
  const veil = waterfall(null, 256, 512, 502, true, true), body = waterfall(null, 256, 512, 501, false, true);
  cellsToPNG('waterfall_flow_px.png', 16, 32, 16, (cx, cy) => {
    const a = snapAlpha(avgAlpha(veil, 256, cx * 16, cy * 16, cx * 16 + 16, cy * 16 + 16) * 1.15);
    if (a > 0) return [...SHADES.foam, a];
    let b = 0; for (let y = cy * 16; y < cy * 16 + 16; y++) for (let x = cx * 16; x < cx * 16 + 16; x++) b += body[(y * 256 + x) * 4 + 1]; b /= 256 * 255;
    return b > .82 ? SHADES.highlight : b > .72 ? SHADES.light : b < .62 ? SHADES.deep : [0, 0, 0, 0];
  });
}
// Waterfall stud sheet colour: water blue with the stud rims shaded, one 4 x 4 stud panel (static, like the river's).
{
  const P = 512, img = Buffer.alloc(P * P * 4), sw = studShadeSrc.w;
  for (let y = 0; y < P; y++) for (let x = 0; x < P; x++) {
    const i = (Math.floor(y * sw / P) * sw + Math.floor(x * sw / P)) * studShadeSrc.ch, rim = Math.min(1, (1 - studShadeSrc.data[i] / 255) * 2.2);
    const o = (y * P + x) * 4, k = 1 - rim * .35;
    img[o] = Math.round(56 * k); img[o + 1] = Math.round(176 * k); img[o + 2] = Math.round(208 * (1 - rim * .2)); img[o + 3] = Math.round(.9 * 255);
  }
  writePNG('waterfall_stud_color.png', P, P, 4, img);
}
console.log('stud layer + pixel flow layers done');

// ---------- Current version: studded pieces over realistic waves ----------
// The water and foam are made of studded pieces: every 1-stud cell that holds water or foam is a crisp square piece
// with the game's stud (from source/stud_*.png) in the middle, so studs belong to the pieces
// themselves. Gaps between pieces (including the foam's bubbles, which come out as stud-sized square holes) show the
// realistic layer underneath: the first, smooth river ripple map (rbxassetid://130231786534226) on the river and a
// smooth streaked sheet on the waterfall. Patterns come from the first textures: the bank lace and streaks of the
// first foam, the crossing V ripples of the FFT ripple map, the waterfall streaks.
const PIECE_PX = 32, BEVEL = 0; // no outline around pieces: neighbouring pieces read as one studded surface
const studCell = [];
for (let y = 0; y < PIECE_PX; y++) for (let x = 0; x < PIECE_PX; x++) studCell.push(studAt((x + .5) / PIECE_PX, (y + .5) / PIECE_PX));
// Every piece is fully opaque; cells with no ripple or foam get a solid light-blue fill piece (no see-through holes).
const PIECES = {
  foam: [244, 252, 255, 1], highlight: [196, 246, 252, 1], light: [120, 222, 236, 1],
  mid: [158, 234, 246, 1], deep: [22, 112, 150, 1],
};
// Pixel animation: each texture has FRAMES frames that the scripts cycle like a flipbook. Frame k samples the ripple
// and foam fields at a small offset (in cells), looping round so the last frame flows back into the first.
const FRAMES = 4;
const FRAME_OFFSETS = [[0, 0], [1, 2], [2, 1], [1, -1]];
// cellAt(cx, cy) -> a PIECES entry or null. Writes <name>.png (colour, alpha = piece) and, unless colourOnly,
// <name>_normal.png (stud relief + bevels). Beams have no normal map, so their shading is baked into the colour.
function studPieces(name, cellsX, cellsY, cellAt, colourOnly) {
  const W = cellsX * PIECE_PX, H = cellsY * PIECE_PX, col = Buffer.alloc(W * H * 4), nrm = Buffer.alloc(W * H * 3);
  for (let cy = 0; cy < cellsY; cy++) for (let cx = 0; cx < cellsX; cx++) {
    const piece = cellAt(cx, cy);
    for (let y = 0; y < PIECE_PX; y++) for (let x = 0; x < PIECE_PX; x++) {
      const px = cx * PIECE_PX + x, py = cy * PIECE_PX + y, o = py * W + px;
      if (!piece) { nrm[o * 3] = 128; nrm[o * 3 + 1] = 128; nrm[o * 3 + 2] = 255; continue; }
      const s = studCell[y * PIECE_PX + x];
      const lightEdge = x < BEVEL || y < BEVEL, darkEdge = x >= PIECE_PX - BEVEL || y >= PIECE_PX - BEVEL;
      let shade = (darkEdge ? .74 : lightEdge ? 1.12 : 1) * (1 - s.rim * .22);
      for (let c = 0; c < 3; c++) col[o * 4 + c] = Math.min(255, Math.round(piece[c] * shade));
      col[o * 4 + 3] = Math.round(piece[3] * 255);
      // OpenGL normals (green = up the image): bevels tilt each piece's edges away from its middle.
      let nx = s.nx * .9 + (x < BEVEL ? -.55 : x >= PIECE_PX - BEVEL ? .55 : 0);
      let ny = s.ny * .9 + (y < BEVEL ? .55 : y >= PIECE_PX - BEVEL ? -.55 : 0), nz = 1;
      const l = Math.hypot(nx, ny, nz);
      nrm[o * 3] = Math.round((nx / l * .5 + .5) * 255); nrm[o * 3 + 1] = Math.round((ny / l * .5 + .5) * 255); nrm[o * 3 + 2] = Math.round((nz / l * .5 + .5) * 255);
    }
  }
  writePNG(name + '.png', W, H, 4, col);
  if (!colourOnly) writePNG(name + '_normal.png', W, H, 3, nrm);
  return { W, H, col };
}

// River pieces: 14 cells wall to wall x 32 cells (32 studs) downstream, tiling along the river.
// foamCut: how much foam a cell needs to become a foam piece (higher = less foam); rippleCut: how strong a ripple must
// be to become a water piece (lower = more water pieces).
// Writes <name>_f1..f4.png (one per animation frame) and <name>_normal.png (shared: every cell holds a stud).
function riverPieces(name, foamOptions, seed, rippleCut, foamCut) {
  // The ripple map spans the whole 32-stud tile here (half its smooth-layer scale), so pieces never repeat in a tile.
  const FW = 14 * 16, FH = 32 * 16, foam = riverFoam(null, FW, FH, { ...foamOptions, raw: true }, seed), px = FLOW_N / 32;
  let first;
  for (let k = 0; k < FRAMES; k++) {
    const [ox, oy] = FRAME_OFFSETS[k];
    const frame = studPieces(name + '_f' + (k + 1), 14, 32, (cx, cy) => {
      // Foam flickers by one cell along the river between frames; ripples shift a couple of cells.
      const fy = ((cy + Math.sign(oy)) % 32 + 32) % 32;
      if (avgAlpha(foam, FW, cx * 16, fy * 16, cx * 16 + 16, fy * 16 + 16) > foamCut) return PIECES.foam;
      const sx = cx + ox, sy = cy + oy;
      const lit = avgLit(rippleNormal, FLOW_N, sx * px, sy * px, (sx + 1) * px, (sy + 1) * px) * 2.2;
      return lit > rippleCut * 1.8 ? PIECES.highlight : lit > rippleCut ? PIECES.light
        : lit < -rippleCut * 1.4 ? PIECES.deep : PIECES.mid;
    }, k > 0);
    if (k === 0) first = frame;
  }
  fs.renameSync(path.join(out, name + '_f1_normal.png'), path.join(out, name + '_normal.png'));
  return first;
}
const rivers = [
  // Mostly flowing water pieces; foam only as a thin broken line along the banks and the odd fleck.
  riverPieces('river_pieces', { band: .08, streaks: .5, churn: 0, patchBias: 0 }, 77, .07, .58),
  riverPieces('river_pieces_tide', { band: .15, streaks: 1, churn: .3, patchBias: .12 }, 78, .06, .52),
];
// Surge crest beam: 7 cells across (front at the right) x 14 along, foam pieces with baked stud shading.
{
  const crest = crestFoam(null, 112, 224, 99, true);
  studPieces('tide_crest_pieces', 7, 14, (cx, cy) => avgAlpha(crest, 112, cx * 16, cy * 16, cx * 16 + 16, cy * 16 + 16) > .4 ? PIECES.foam : null, true);
}
// Waterfall: studded pieces sliding down in front (16 x 32 cells = studs), over a smooth realistic sheet.
{
  const veil = waterfall(null, 256, 512, 502, true, true), body = waterfall(null, 256, 512, 501, false, true);
  for (let k = 0; k < FRAMES; k++) {
    const [ox, oy] = FRAME_OFFSETS[k];
    studPieces('waterfall_pieces_f' + (k + 1), 16, 32, (cx, cy) => {
      const sx = ((cx + ox) % 16 + 16) % 16, sy = ((cy + oy * 2) % 32 + 32) % 32;
      // Few foam pieces (the brightest veil streaks only), mostly blue water pieces falling.
      if (avgAlpha(veil, 256, sx * 16, sy * 16, sx * 16 + 16, sy * 16 + 16) * 1.15 > .62) return PIECES.foam;
      let b = 0; for (let y = sy * 16; y < sy * 16 + 16; y++) for (let x = sx * 16; x < sx * 16 + 16; x++) b += body[(y * 256 + x) * 4 + 1]; b /= 256 * 255;
      return b > .86 ? PIECES.highlight : b > .74 ? PIECES.light : b < .66 ? PIECES.deep : PIECES.mid;
    }, k > 0);
  }
  fs.renameSync(path.join(out, 'waterfall_pieces_f1_normal.png'), path.join(out, 'waterfall_pieces_normal.png'));
}
// Pixel roughness for the pixel-water look: half-stud cells (32 x 32 per 16-stud tile) of varied roughness, so some
// pixels catch a sharp glint while their neighbours stay satin, which is what makes the pixels read as water. Mostly
// 0.18-0.42, with about one cell in five near-mirror (0.04).
{
  const G = 256, CELL = 8, img = Buffer.alloc(G * G * 3), r = rng(933), patch = perlin(4, 4, rng(934));
  const cells = G / CELL, values = [];
  for (let cy = 0; cy < cells; cy++) for (let cx = 0; cx < cells; cx++) {
    const shiny = r() < .2 + .1 * patch(cx / cells, cy / cells);
    values.push(shiny ? .04 : .18 + .24 * r());
  }
  for (let y = 0; y < G; y++) for (let x = 0; x < G; x++) {
    const v = values[Math.floor(y / CELL) * cells + Math.floor(x / CELL)], i = (y * G + x) * 3;
    img[i] = img[i + 1] = img[i + 2] = Math.round(v * 255);
  }
  writePNG('water_pixel_roughness.png', G, G, 3, img);
}
// Shine for the studded pieces: near-mirror smooth plastic (roughness ~0.02-0.05). Reflectance stays 0 on the parts.
{
  const G = 128, img = Buffer.alloc(G * G * 3), n1 = perlin(3, 3, rng(911));
  for (let y = 0; y < G; y++) for (let x = 0; x < G; x++) {
    const v = .035 + .015 * n1(x / G, y / G), i = (y * G + x) * 3;
    img[i] = img[i + 1] = img[i + 2] = Math.round(v * 255);
  }
  writePNG('piece_shine_roughness.png', G, G, 3, img);
}
// Gloss: low, gently varying roughness for every water layer (shiny highlights; parts keep Reflectance 0, so no
// mirror reflections).
{
  const G = 256, img = Buffer.alloc(G * G * 3), n1 = perlin(4, 4, rng(901)), n2 = perlin(11, 11, rng(902));
  for (let y = 0; y < G; y++) for (let x = 0; x < G; x++) {
    const v = Math.min(.2, Math.max(.04, .1 + .04 * n1(x / G, y / G) + .02 * n2(x / G, y / G)));
    const i = (y * G + x) * 3; img[i] = img[i + 1] = img[i + 2] = Math.round(v * 255);
  }
  writePNG('water_gloss_roughness.png', G, G, 3, img);
}
// Previews over the water colour.
for (const [file, r] of [['river_pieces', rivers[0]], ['river_pieces_tide', rivers[1]]]) {
  const pv = Buffer.alloc(r.W * r.H * 3);
  for (let k = 0; k < r.W * r.H; k++) { const a = r.col[k * 4 + 3] / 255; pv[k * 3] = 58 + (r.col[k * 4] - 58) * a; pv[k * 3 + 1] = 190 + (r.col[k * 4 + 1] - 190) * a; pv[k * 3 + 2] = 200 + (r.col[k * 4 + 2] - 200) * a; }
  writePNG('preview_' + file + '.png', r.W, r.H, 3, pv);
}
console.log('studded pieces done');

// ---------- Current version: studded pixel water ----------
// The pixel-waterfall look (translucent pixel water, pixel foam with clear gaps, mixed shine, smooth sliding), with
// every pixel one stud across like the ground's tiles and a stud in each pixel. Mappings in the scripts:
//   river base   16 x 16 pixels per 16-stud tile (ripple shades + stud rims as an Overlay colour, stud + facet normals)
//   river foam   14 pixels wall to wall x 32 pixels per 32-stud tile
//   waterfall    16 x 32 pixels per 16 x 32-stud tile (body and front streaks)
//   crest beam   7 x 14 pixels
// Roughness is per pixel: most pixels satin (0.18-0.42), about one in five near-mirror (0.04), stud rims rougher.
function pixelRoughness(file, cellsX, cellsY, cellPx, seed) {
  const r = rng(seed), W = cellsX * cellPx, H = cellsY * cellPx, img = Buffer.alloc(W * H * 3);
  for (let cy = 0; cy < cellsY; cy++) for (let cx = 0; cx < cellsX; cx++) {
    const v = r() < .22 ? .04 : .18 + .24 * r();
    for (let py = 0; py < cellPx; py++) for (let px = 0; px < cellPx; px++) {
      const s = studAt((px + .5) / cellPx, (py + .5) / cellPx), o = ((cy * cellPx + py) * W + cx * cellPx + px) * 3;
      img[o] = img[o + 1] = img[o + 2] = Math.round(Math.min(1, v + s.rim * .3) * 255);
    }
  }
  writePNG(file, W, H, 3, img);
}
const flatNormal = (w, h) => Buffer.alloc(w * h * 3).fill(Buffer.from([128, 128, 255]));
{
  // River base: the first ripple map, one pixel per stud.
  studTiles('river_px_normal.png', FLOW_N, FLOW_N, 3, rippleNormal, 16, 16, 'normal', 64);
  studTiles('river_px_color.png', FLOW_N, FLOW_N, 3, rippleNormal, 16, 16, 'overlay', 64);
  pixelRoughness('river_px_roughness.png', 16, 16, 32, 941);
  // River foam (the first foam's bank lace and streaks), normal and tide.
  studTiles('river_foam_px_normal.png', 14, 32, 3, flatNormal(14, 32), 14, 32, 'stud', 32);
  pixelRoughness('river_foam_px_roughness.png', 14, 32, 32, 942);
  for (const [file, options, seed] of [
    ['river_foam_px', { band: .12, streaks: 1.2, churn: 0, patchBias: 0 }, 77],
    ['river_foam_px_tide', { band: .22, streaks: 1.9, churn: .5, patchBias: .12 }, 78],
  ]) {
    const foam = riverFoam(null, 224, 512, { ...options, raw: true }, seed);
    const t = studTiles(file + '.png', 224, 512, 4, foam, 14, 32, 'rgba', 32);
    const pv = Buffer.alloc(t.W * t.H * 3);
    for (let k = 0; k < t.W * t.H; k++) { const a = t.img[k * 4 + 3] / 255; pv[k * 3] = 58 + (t.img[k * 4] - 58) * a; pv[k * 3 + 1] = 190 + (t.img[k * 4 + 1] - 190) * a; pv[k * 3 + 2] = 200 + (t.img[k * 4 + 2] - 200) * a; }
    writePNG('preview_' + file + '.png', t.W, t.H, 3, pv);
  }
  // Surge crest beam.
  studTiles('tide_crest_px_studs.png', 112, 224, 4, crestFoam(null, 112, 224, 99, true), 7, 14, 'rgba', 32);
  // Waterfall: blue streaked body and white front streaks.
  studTiles('waterfall_body_px.png', 256, 512, 4, waterfall(null, 256, 512, 501, false, true), 16, 32, 'rgba', 32);
  studTiles('waterfall_veil_px.png', 256, 512, 4, waterfall(null, 256, 512, 502, true, true), 16, 32, 'rgba', 32);
  studTiles('waterfall_px_normal.png', 16, 32, 3, flatNormal(16, 32), 16, 32, 'stud', 32);
  pixelRoughness('waterfall_px_roughness.png', 16, 32, 32, 943);
}
console.log('studded pixel water done');
