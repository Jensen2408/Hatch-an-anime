// Original coarse-grid animated hull wakes and outline-free splash art.
const fs=require('fs'),path=require('path'),z=require('zlib'),http=require('http');
const out=path.resolve(__dirname,'../../assets/water/Wakes');
function chunk(t,d){const n=Buffer.alloc(4),c=Buffer.alloc(4),b=Buffer.concat([Buffer.from(t),d]);n.writeUInt32BE(d.length);c.writeUInt32BE(z.crc32(b)>>>0);return Buffer.concat([n,b,c])}
function png(name,w,h,p){const raw=Buffer.alloc(h*(w*4+1));for(let y=0;y<h;y++)p.copy(raw,y*(w*4+1)+1,y*w*4,(y+1)*w*4);const hd=Buffer.alloc(13);hd.writeUInt32BE(w);hd.writeUInt32BE(h,4);hd[8]=8;hd[9]=6;fs.writeFileSync(path.join(out,name),Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',hd),chunk('IDAT',z.deflateSync(raw)),chunk('IEND',Buffer.alloc(0))]))}
const hash=(x,y)=>{let v=Math.sin(x*127.1+y*311.7)*43758.5453;return v-Math.floor(v)};


// Original reference-inspired foam, static images; motion comes from world-space Trail history.
for(const kind of ['hull_foam','wake_track']){
 const W=64,H=64,S=4,p=Buffer.alloc(W*S*H*S*4);
 for(let y=0;y<H;y++)for(let x=0;x<W;x++){
 const u=(x+.5-32)/32,t=(y+.5)/64,g=hash(Math.floor(x/2),Math.floor(y/2));let a=0,c=[238,253,255];
 if(kind==='hull_foam'){
 const rr=Math.sqrt(u*u+Math.pow((t-.43)*1.9,2));
 const edge=.70+.025*Math.sin(y*.7);
 if(t<.68&&Math.abs(rr-edge)<.085&&g>.12)a=.94;
 if(t<.67&&Math.abs(rr-edge)<.18&&g>.70)a=.66;
 if(t>.48&&t<.88&&Math.abs(Math.abs(u)-.65)<.12&&g>.45)a=.55*(1-t);
 }else{
 const jag=.67+.04*Math.sin(y*.55)+.035*Math.sin(y*1.5);
 const d=Math.abs(Math.abs(u)-jag);
 if(d<.065&&g>.12)a=.94;
 if(d<.15&&g>.61)a=.72;
 const eddy=(t+Math.abs(u)*.32)% .42;
 if(Math.abs(u)<.57&&eddy<.045&&g>.3)a=.52;
 if(Math.abs(u)>.3&&g>.93)a=.6;
 }
 if(g<.48)c=[170,226,244];
 for(let j=0;j<S;j++)for(let i=0;i<S;i++){const k=((y*S+j)*W*S+x*S+i)*4;p[k]=c[0];p[k+1]=c[1];p[k+2]=c[2];p[k+3]=Math.round(a*255)}
 }
 png(kind+'.png',W*S,H*S,p);
}
http.createServer((req,res)=>{const n=req.url.slice(1);if(!['hull_foam.png','wake_track.png'].includes(n)){res.writeHead(404);return res.end()}res.writeHead(200,{'Content-Type':'image/png'});res.end(fs.readFileSync(path.join(out,n)))}).listen(8099,'127.0.0.1',()=>console.log('Foam history textures ready'));
