// Stud-look maps for the river's base water layer, built from the game's stud cavity maps (4 x 4 studs per tile,
// the same look as the "Incubator One Stud Cavity" ground at 8 studs per tile).
// Usage: node stud-water-maps.js [assetsDir]   (reads <assetsDir>/source/stud_normal.png and stud_shade.png)
// Writes:
//   water_stud_normal.png     the stud normal map, flattened a little so water reads glassier than plastic
//   water_stud_color.png      RGBA overlay for SurfaceAppearance Overlay mode: clear on the flat water, a dark teal
//                             rim around each stud (alpha from the shade map), so the studs read on any water colour
//   water_stud_roughness.png  glossy water, slightly rougher in the stud rims
const fs = require('fs'), zlib = require('zlib'), path = require('path');
const dir = process.argv[2] || path.join(__dirname, '..', '..', 'assets', 'water');

// ---------- PNG read (8-bit RGB/RGBA, non-interlaced) / write ----------
function readPNG(file) {
  const b = fs.readFileSync(file);
  let p = 8, w, h, type, idat = [];
  while (p < b.length) {
    const len = b.readUInt32BE(p), kind = b.toString('ascii', p + 4, p + 8), data = b.subarray(p + 8, p + 8 + len);
    if (kind === 'IHDR') { w = data.readUInt32BE(0); h = data.readUInt32BE(4); type = data[9]; if (data[8] !== 8 || data[12] !== 0) throw new Error('unsupported PNG'); }
    else if (kind === 'IDAT') idat.push(data);
    else if (kind === 'IEND') break;
    p += 12 + len;
  }
  const ch = type === 6 ? 4 : type === 2 ? 3 : (() => { throw new Error('unsupported colour type ' + type); })();
  const raw = zlib.inflateSync(Buffer.concat(idat)), stride = w * ch, out = Buffer.alloc(h * stride);
  for (let y = 0; y < h; y++) {
    const f = raw[y * (stride + 1)], src = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    for (let x = 0; x < stride; x++) {
      const a = x >= ch ? out[y * stride + x - ch] : 0, up = y > 0 ? out[(y - 1) * stride + x] : 0;
      const c = x >= ch && y > 0 ? out[(y - 1) * stride + x - ch] : 0;
      let v = src[x];
      if (f === 1) v += a; else if (f === 2) v += up; else if (f === 3) v += (a + up) >> 1;
      else if (f === 4) { const pa = Math.abs(up - c), pb = Math.abs(a - c), pc = Math.abs(a + up - 2 * c); v += pa <= pb && pa <= pc ? a : pb <= pc ? up : c; }
      out[y * stride + x] = v & 255;
    }
  }
  return { w, h, ch, data: out };
}
function crc32(b) { let c, t = crc32.t; if (!t) { t = crc32.t = []; for (let n = 0; n < 256; n++) { c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0; } } let crc = -1; for (const x of b) crc = t[(crc ^ x) & 255] ^ (crc >>> 8); return (crc ^ -1) >>> 0; }
function chunk(type, data) { const l = Buffer.alloc(4); l.writeUInt32BE(data.length); const td = Buffer.concat([Buffer.from(type), data]); const c = Buffer.alloc(4); c.writeUInt32BE(crc32(td)); return Buffer.concat([l, td, c]); }
function writePNG(file, w, h, ch, data) {
  const raw = Buffer.alloc(h * (w * ch + 1));
  for (let y = 0; y < h; y++) data.copy(raw, y * (w * ch + 1) + 1, y * w * ch, (y + 1) * w * ch);
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = ch === 4 ? 6 : 2;
  fs.writeFileSync(path.join(dir, file), Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]));
}

const normal = readPNG(path.join(dir, 'source', 'stud_normal.png'));
const shade = readPNG(path.join(dir, 'source', 'stud_shade.png'));
const { w, h } = normal, N = w * h;
const FLATTEN = 0.8; // stud relief kept on the water (1 = as strong as the plastic ground)
const RIM = [12, 70, 92], RIM_ALPHA = 0.6;

const nrm = Buffer.alloc(N * 3), col = Buffer.alloc(N * 4), rough = Buffer.alloc(N * 3);
for (let i = 0; i < N; i++) {
  let nx = (normal.data[i * normal.ch] / 127.5 - 1) * FLATTEN, ny = (normal.data[i * normal.ch + 1] / 127.5 - 1) * FLATTEN;
  const nz = Math.sqrt(Math.max(0.05, 1 - nx * nx - ny * ny)), l = Math.hypot(nx, ny, nz);
  nrm[i * 3] = Math.round((nx / l * .5 + .5) * 255); nrm[i * 3 + 1] = Math.round((ny / l * .5 + .5) * 255); nrm[i * 3 + 2] = Math.round((nz / l * .5 + .5) * 255);
  // Shade map: white = open surface, grey = the cavity rim and its soft shadow.
  const dark = 1 - shade.data[i * shade.ch] / 255;
  const a = Math.min(1, dark * 2.2) * RIM_ALPHA;
  col[i * 4] = RIM[0]; col[i * 4 + 1] = RIM[1]; col[i * 4 + 2] = RIM[2]; col[i * 4 + 3] = Math.round(a * 255);
  const r = Math.round((0.1 + Math.min(1, dark * 2.2) * 0.35) * 255);
  rough[i * 3] = rough[i * 3 + 1] = rough[i * 3 + 2] = r;
}
writePNG('water_stud_normal.png', w, h, 3, nrm);
writePNG('water_stud_color.png', w, h, 4, col);
writePNG('water_stud_roughness.png', w, h, 3, rough);
console.log('stud water maps done', w, 'x', h);
