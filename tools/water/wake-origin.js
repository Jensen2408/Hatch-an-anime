// Original coarse-grid animated hull wakes and outline-free splash art.
const fs=require('fs'),path=require('path'),z=require('zlib'),http=require('http');
const out=path.resolve(__dirname,'../../assets/water/Wakes');
function chunk(t,d){const n=Buffer.alloc(4),c=Buffer.alloc(4),b=Buffer.concat([Buffer.from(t),d]);n.writeUInt32BE(d.length);c.writeUInt32BE(z.crc32(b)>>>0);return Buffer.concat([n,b,c])}
function png(name,w,h,p){const raw=Buffer.alloc(h*(w*4+1));for(let y=0;y<h;y++)p.copy(raw,y*(w*4+1)+1,y*w*4,(y+1)*w*4);const hd=Buffer.alloc(13);hd.writeUInt32BE(w);hd.writeUInt32BE(h,4);hd[8]=8;hd[9]=6;fs.writeFileSync(path.join(out,name),Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',hd),chunk('IDAT',z.deflateSync(raw)),chunk('IEND',Buffer.alloc(0))]))}
const hash=(x,y)=>{let v=Math.sin(x*127.1+y*311.7)*43758.5453;return v-Math.floor(v)};


// Original reference-inspired foam, static images; motion comes from world-space Trail history.

const W=32,S=8,p=Buffer.alloc(256*256*4);
for(let y=0;y<W;y++)for(let x=0;x<W;x++){
 const u=(x+.5-16)/16,t=(y+.5)/32,g=hash(Math.floor(x/2),Math.floor(y/2));
 // Rounded nose opens into parallel shoulders; no circular rear lobe.
 const wing=t<.32?.70*Math.sqrt(Math.max(0,1-Math.pow((t-.32)/.30,2))):.70;
 const d=Math.abs(Math.abs(u)-wing);let a=0;
 if(t>.025&&t<.67&&d<.10)a=255;
 if(t>.08&&t<.60&&d<.17&&g>.8)a=255;
 const c=g>.48?[238,253,255]:[170,226,244];
 for(let j=0;j<S;j++)for(let i=0;i<S;i++){const k=((y*S+j)*256+x*S+i)*4;p[k]=c[0];p[k+1]=c[1];p[k+2]=c[2];p[k+3]=a}
}
png('hull_shoulders.png',256,256,p);
http.createServer((req,res)=>{res.writeHead(200,{'Content-Type':'image/png'});res.end(fs.readFileSync(path.join(out,'hull_shoulders.png')))}).listen(8099,'127.0.0.1',()=>console.log('Shoulder origin ready'));
