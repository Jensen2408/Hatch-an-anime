// Bat texture tinting helper (localhost only). node bat_texture_server.js [outDir]
//   POST /save/<name>?w=<px>&h=<px>   body = raw RGBA bytes (Studio EditableImage ReadPixelsBuffer) -> <outDir>/<name>.png
//   POST /tint/<tier>?src=<name>      builds <outDir>/<tier>_color.png from <src>.png: luminance of the wood colour map
//                                     mapped through the tier's shadow/mid/highlight gradient (grain and detail kept)
//   GET  /<file>.png                  serves a PNG from <outDir> (the Studio MCP upload_image tool fetches from here)
const http = require("http"), fs = require("fs"), path = require("path"), zlib = require("zlib");
const outDir = process.argv[2] || path.join(__dirname, "out");
fs.mkdirSync(outDir, { recursive: true });

function crcChunk(type, data) {
  const t = Buffer.from(type), len = Buffer.alloc(4), crc = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  crc.writeUInt32BE(zlib.crc32(Buffer.concat([t, data])) >>> 0);
  return Buffer.concat([len, t, data, crc]);
}
function encodePng(w, h, rgba) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) { raw[y * (w * 4 + 1)] = 0; rgba.copy(raw, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4); }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6; // 8-bit RGBA
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), crcChunk("IHDR", ihdr),
    crcChunk("IDAT", zlib.deflateSync(raw, { level: 9 })), crcChunk("IEND", Buffer.alloc(0))]);
}

// shadow / mid / highlight per tier
const TIERS = {
  iron:    [[58, 64, 78], [150, 158, 172], [225, 231, 240]],
  gold:    [[128, 74, 6], [236, 172, 28], [255, 236, 130]],
  diamond: [[22, 104, 138], [96, 212, 240], [232, 254, 255]],
  oni:     [[70, 6, 12], [186, 26, 38], [250, 112, 100]],
};

http.createServer((req, res) => {
  const url = new URL(req.url, "http://localhost");
  const parts = url.pathname.split("/").filter(Boolean);
  if (req.method === "POST" && parts[0] === "save") {
    const chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => {
      const w = +url.searchParams.get("w"), h = +url.searchParams.get("h"), body = Buffer.concat(chunks);
      if (body.length !== w * h * 4) { res.writeHead(400); return res.end("bad size " + body.length + " vs " + w * h * 4); }
      fs.writeFileSync(path.join(outDir, parts[1] + ".rgba"), body);
      fs.writeFileSync(path.join(outDir, parts[1] + ".png"), encodePng(w, h, body));
      res.writeHead(200); res.end("saved " + w + "x" + h);
    });
    return;
  }
  if (req.method === "POST" && parts[0] === "tint") {
    const tier = parts[1], src = url.searchParams.get("src");
    const px = fs.readFileSync(path.join(outDir, src + ".rgba"));
    const meta = JSON.parse(fs.readFileSync(path.join(outDir, src + ".json"), "utf8"));
    const n = meta.w * meta.h, lum = new Float32Array(n);
    for (let i = 0; i < n; i++) lum[i] = (0.299 * px[i * 4] + 0.587 * px[i * 4 + 1] + 0.114 * px[i * 4 + 2]) / 255;
    const sorted = Float32Array.from(lum).sort();
    const lo = sorted[Math.floor(n * 0.03)], hi = sorted[Math.floor(n * 0.97)];
    const [sh, mid, hl] = TIERS[tier];
    const out = Buffer.alloc(n * 4);
    for (let i = 0; i < n; i++) {
      const t = Math.min(1, Math.max(0, (lum[i] - lo) / Math.max(hi - lo, 1e-3)));
      const a = t < 0.5 ? sh : mid, b = t < 0.5 ? mid : hl, k = t < 0.5 ? t * 2 : (t - 0.5) * 2;
      for (let c = 0; c < 3; c++) out[i * 4 + c] = Math.round(a[c] + (b[c] - a[c]) * k);
      out[i * 4 + 3] = px[i * 4 + 3]; // keep the original alpha
    }
    fs.writeFileSync(path.join(outDir, tier + "_color.png"), encodePng(meta.w, meta.h, out));
    res.writeHead(200); return res.end(`tinted ${tier}: lum range ${lo.toFixed(2)}..${hi.toFixed(2)}`);
  }
  if (req.method === "POST" && parts[0] === "join") { // POST /join/<name>?a=<top half>&b=<bottom half>&w=&h=  (full size)
    const w = +url.searchParams.get("w"), h = +url.searchParams.get("h");
    const full = Buffer.concat([fs.readFileSync(path.join(outDir, url.searchParams.get("a") + ".rgba")), fs.readFileSync(path.join(outDir, url.searchParams.get("b") + ".rgba"))]);
    if (full.length !== w * h * 4) { res.writeHead(400); return res.end("bad join size"); }
    fs.writeFileSync(path.join(outDir, parts[1] + ".rgba"), full);
    fs.writeFileSync(path.join(outDir, parts[1] + ".png"), encodePng(w, h, full));
    fs.writeFileSync(path.join(outDir, parts[1] + ".json"), JSON.stringify({ w, h }));
    res.writeHead(200); return res.end("joined " + w + "x" + h);
  }
  if (req.method === "POST" && parts[0] === "meta") { // POST /meta/<name>?w=&h= : remember the size of a saved map
    fs.writeFileSync(path.join(outDir, parts[1] + ".json"), JSON.stringify({ w: +url.searchParams.get("w"), h: +url.searchParams.get("h") }));
    res.writeHead(200); return res.end("ok");
  }
  if (req.method === "GET" && /^[\w.-]+\.png$/.test(parts[0] || "") && fs.existsSync(path.join(outDir, parts[0]))) {
    res.writeHead(200, { "Content-Type": "image/png" });
    return res.end(fs.readFileSync(path.join(outDir, parts[0])));
  }
  res.writeHead(404); res.end("no");
}).listen(8098, "127.0.0.1", () => console.log("bat texture server on 8098, out:", outDir));
