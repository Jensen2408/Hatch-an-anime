# Sends a 4-view strip (front|back|left|right, RGBA) to the local Hunyuan3D-2mv server (G:\AI\shape_server.py)
# and saves the untextured GLB.   G:\AI\hy3d-env\Scripts\python.exe hunyuan_send.py strip.png out.glb
import base64, json, sys, time, urllib.request

strip, out = sys.argv[1], sys.argv[2]
body = json.dumps({
    "image": base64.b64encode(open(strip, "rb").read()).decode(),
    "num_inference_steps": 50,
    "octree_resolution": 384,
}).encode()
t = time.time()
req = urllib.request.Request("http://localhost:8081/generate", body, {"Content-Type": "application/json"})
with urllib.request.urlopen(req, timeout=900) as r:
    data = r.read()
open(out, "wb").write(data)
print("saved", out, len(data), "bytes in", round(time.time() - t), "s")
