// Original animated pixel wake. 8 frames: broken V foam, inner eddies, drifting foam flecks.
// No studs, rings, solid ribbon borders or external artwork. node tools/water/wake-atlas.js [--serve]
const fs=require('fs'),path=require('path'),z=require('zlib'),http=require('http');
const out=path.resolve(__dirname,'../../assets/water/Wakes');fs.mkdirSync(out,{recursive:true});
const S=4,W=64,H=96,COLS=4,ROWS=2,AW=W*S*COLS,AH=H*S*ROWS,data=Buffer.alloc(AW*AH*4);
const hash=(x,y)=>{let v=Math.sin(x*127.1+y*311.7)*43758.5453;return v-Math.floor(v)};
for(let f=0;f<8;f++)for(let y=0;y<H;y++)for(let x=0;x<W;x++){
 const t=(y+.5)/H,u=(x+.5-W/2)/(W/2),phase=f/8;
 const flowY=y-Math.floor(f*1.5),grain=hash(Math.floor(x/2),Math.floor(flowY/2));
 const wing=.10+.63*t+.025*Math.sin(y*.34+phase*6.283);
 const dist=Math.abs(Math.abs(u)-wing),edge=.038+.024*(1-t);
 const tail=Math.min(1,(1-t)*3.4),head=Math.min(1,t*14);
 let a=0,col=[225,252,255];
 // Broken irregular outer foam, with dark-blue thin shadow pixels rather than a solid outline.
 if(dist<edge && grain>.18){a=(.72+.28*grain)*tail*head;col=grain>.55?[248,255,255]:[174,233,249]}
 else if(dist<edge+.025 && grain>.55){a=.38*tail*head;col=[77,158,186]}
 // Several moving chevron eddies inside the widening wake.
 const bend=t-Math.abs(u)*.40;
 const band=((bend-phase*.14)% .18+.18)%.18;
 if(Math.abs(u)<wing-.055 && band<.026 && grain>.27){a=Math.max(a,.75*tail*head);col=grain>.65?[245,255,255]:[168,228,246]}
 // Foamy churn near the stern, thinning to sparse chunky islands along the centre.
 if(Math.abs(u)<.13+.1*t && grain>.70 && hash(Math.floor(x/3),Math.floor(flowY/3))>.3){a=Math.max(a,(.8-.48*t)*tail*head);col=[217,247,255]}
 // Loose broken cells just outside the edge connect the wake to the flowing river.
 if(dist>edge && dist<.16 && grain>.94 && hash(x,flowY)>.6){a=Math.max(a,.42*tail*head);col=[203,241,252]}
 // Never paint a bounding rectangle; every edge ends in transparent pixels.
 if(t<.015||t>.985||Math.abs(u)>.95)a=0;
 const ox=(f%COLS)*W*S+x*S,oy=Math.floor(f/COLS)*H*S+y*S;
 for(let dy=0;dy<S;dy++)for(let dx=0;dx<S;dx++){const i=((oy+dy)*AW+ox+dx)*4;data[i]=col[0];data[i+1]=col[1];data[i+2]=col[2];data[i+3]=Math.round(a*255)}
}
function chunk(t,d){const n=Buffer.alloc(4),crc=Buffer.alloc(4),body=Buffer.concat([Buffer.from(t),d]);n.writeUInt32BE(d.length);crc.writeUInt32BE(z.crc32(body)>>>0);return Buffer.concat([n,body,crc])}
function png(file,w,h,rgba){const raw=Buffer.alloc(h*(w*4+1));for(let y=0;y<h;y++)rgba.copy(raw,y*(w*4+1)+1,y*w*4,(y+1)*w*4);const hdr=Buffer.alloc(13);hdr.writeUInt32BE(w,0);hdr.writeUInt32BE(h,4);hdr[8]=8;hdr[9]=6;fs.writeFileSync(path.join(out,file),Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',hdr),chunk('IDAT',z.deflateSync(raw)),chunk('IEND',Buffer.alloc(0))]));}
png('wake_atlas.png',AW,AH,data);
const frame=Buffer.alloc(W*S*H*S*4);for(let y=0;y<H*S;y++)data.copy(frame,y*W*S*4,y*AW*4,y*AW*4+W*S*4);png('wake_preview.png',W*S,H*S,frame);
console.log('Saved 8-frame pixel foam atlas '+AW+'x'+AH);
if(process.argv.includes('--serve'))http.createServer((req,res)=>{if(req.url!=='/wake_atlas.png'){res.writeHead(404);res.end();return}res.writeHead(200,{'Content-Type':'image/png'});res.end(fs.readFileSync(path.join(out,'wake_atlas.png')))}).listen(8099,'127.0.0.1',()=>console.log('Pixel wake atlas server ready'));
