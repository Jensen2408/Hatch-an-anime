// Particle textures for the Volcano Eruption. node smoke-textures.js <outDir>
//   volcano_smoke.png  1024 x 1024, a 2 x 2 flipbook (FlipbookLayout Grid2x2, mode Random) of four anime-cartoon cloud puffs: a union of
//                      round lobes, flat cel shading in three bands lit from the upper left (highlight / body / shadow) and a thin darker
//                      outline, like the game's sky clouds. Grey-scale RGBA: the emitter's colour tints it, so one sheet makes dark smoke,
//                      lava-lit brown smoke and pale high cloud.
//   volcano_ember.png  128 x 128, a pixel-art ember: a diamond of 8 px cells, white-hot core fading to orange, for lava embers.
const fs = require('fs'), zlib = require('zlib'), path = require('path');
const out = process.argv[2] || path.join(__dirname, '..', '..', 'assets', 'ArenaLava');
fs.mkdirSync(out, { recursive: true });
function crc32(b) { let c, t = crc32.t; if (!t) { t = crc32.t = []; for (let n = 0; n < 256; n++) { c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0; } } let crc = -1; for (const x of b) crc = t[(crc ^ x) & 255] ^ (crc >>> 8); return (crc ^ -1) >>> 0; }
function chunk(type, data) { const l = Buffer.alloc(4); l.writeUInt32BE(data.length); const td = Buffer.concat([Buffer.from(type), data]); const c = Buffer.alloc(4); c.writeUInt32BE(crc32(td)); return Buffer.concat([l, td, c]); }
function writePNG(file, w, h, data) {
  const raw = Buffer.alloc(h * (w * 4 + 1));
  for (let y = 0; y < h; y++) { raw[y * (w * 4 + 1)] = 0; data.copy(raw, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4); }
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6;
  fs.writeFileSync(path.join(out, file), Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]));
}
let seed = 20261104; const rnd = () => (seed = (seed * 1664525 + 1013904223) >>> 0) / 4294967296;

// ---- cloud sheet ----
const CELL = 512, W = CELL * 2;
const sheet = Buffer.alloc(W * W * 4);
const LIGHT = (() => { const l = [-0.45, -0.85]; const n = Math.hypot(l[0], l[1]); return [l[0] / n, l[1] / n]; })();
for (let v = 0; v < 4; v++) {
  const ox = (v % 2) * CELL, oy = Math.floor(v / 2) * CELL;
  // a main puff and 6 to 8 lobes around it; lobes sit lower and wider, so the cloud has a heavy, billowing belly
  const circles = [{ x: 256, y: 232, r: 118 + rnd() * 20 }];
  const lobes = 6 + (v % 3);
  for (let i = 0; i < lobes; i++) {
    const a = (i / lobes) * Math.PI * 2 + rnd() * 0.5;
    const d = 92 + rnd() * 44;
    circles.push({ x: 256 + Math.cos(a) * d * 1.12, y: 240 + Math.sin(a) * d * 0.9 + 12, r: 60 + rnd() * 44 });
  }
  circles.push({ x: 256 + (rnd() - 0.5) * 70, y: 150 + rnd() * 30, r: 70 + rnd() * 24 }); // a crown on top
  const depthAt = (x, y) => { let d = -1e9; for (const c of circles) d = Math.max(d, c.r - Math.hypot(x - c.x, y - c.y)); return d; };
  for (let py = 0; py < CELL; py++) for (let px = 0; px < CELL; px++) {
    const best = depthAt(px, py);
    if (best < -1) continue;
    const alpha = Math.max(0, Math.min(1, best + 1));
    let g;
    if (best < 5) g = 176;                                              // the outline
    else if (depthAt(px + LIGHT[0] * 26, py + LIGHT[1] * 26) < 6) g = 255; // highlight: near the edge facing the light
    else if (depthAt(px - LIGHT[0] * 46, py - LIGHT[1] * 46) < 6) g = 150; // shadow: near the edge away from the light
    else g = 208;                                                       // body
    const o = ((oy + py) * W + ox + px) * 4;
    sheet[o] = sheet[o + 1] = sheet[o + 2] = g; sheet[o + 3] = Math.round(alpha * 255);
  }
}
writePNG('volcano_smoke.png', W, W, sheet);

// ---- ember sprite ----
const E = 128, CP = 8, N = E / CP;
const ember = Buffer.alloc(E * E * 4);
for (let cy = 0; cy < N; cy++) for (let cx = 0; cx < N; cx++) {
  const dx = Math.abs(cx - (N / 2 - 0.5)), dy = Math.abs(cy - (N / 2 - 0.5));
  const f = 1 - (dx + dy) / 6.2;
  if (f <= 0) continue;
  const q = Math.ceil(f * 4) / 4;
  const rgb = q > 0.9 ? [255, 250, 200] : q > 0.6 ? [255, 190, 70] : q > 0.4 ? [255, 120, 30] : [210, 60, 20];
  for (let y = 0; y < CP; y++) for (let x = 0; x < CP; x++) { const o = ((cy * CP + y) * E + cx * CP + x) * 4; ember[o] = rgb[0]; ember[o + 1] = rgb[1]; ember[o + 2] = rgb[2]; ember[o + 3] = Math.round(Math.min(1, q + 0.15) * 255); }
}
writePNG('volcano_ember.png', E, E, ember);
console.log('ok', out);
