// Original coarse-grid animated hull wakes and outline-free splash art.
const fs=require('fs'),path=require('path'),z=require('zlib'),http=require('http');
const out=path.resolve(__dirname,'../../assets/water/Wakes');
function chunk(t,d){const n=Buffer.alloc(4),c=Buffer.alloc(4),b=Buffer.concat([Buffer.from(t),d]);n.writeUInt32BE(d.length);c.writeUInt32BE(z.crc32(b)>>>0);return Buffer.concat([n,b,c])}
function png(name,w,h,p){const raw=Buffer.alloc(h*(w*4+1));for(let y=0;y<h;y++)p.copy(raw,y*(w*4+1)+1,y*w*4,(y+1)*w*4);const hd=Buffer.alloc(13);hd.writeUInt32BE(w);hd.writeUInt32BE(h,4);hd[8]=8;hd[9]=6;fs.writeFileSync(path.join(out,name),Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',hd),chunk('IDAT',z.deflateSync(raw)),chunk('IEND',Buffer.alloc(0))]))}
const hash=(x,y)=>{let v=Math.sin(x*127.1+y*311.7)*43758.5453;return v-Math.floor(v)};


const W=32,S=8,p=Buffer.alloc(W*S*W*S*4);
for(let y=0;y<W;y++)for(let x=0;x<W;x++){
 const dx=x-15.5,dy=y-15.5,r=Math.hypot(dx,dy);let a=0;
 if(r>=11&&r<=13)a=255;
 // Sparse detached impact flecks, not a second outline.
 if(r>14&&r<15.5&&hash(x,y)>.93)a=255;
 const c=(x+y)%5===0?[193,238,252]:[244,254,255];
 for(let j=0;j<S;j++)for(let i=0;i<S;i++){const k=((y*S+j)*W*S+x*S+i)*4;p[k]=c[0];p[k+1]=c[1];p[k+2]=c[2];p[k+3]=a}
}
png('splash_round_coarse.png',256,256,p);
http.createServer((req,res)=>{res.writeHead(200,{'Content-Type':'image/png'});res.end(fs.readFileSync(path.join(out,'splash_round_coarse.png')))}).listen(8099,'127.0.0.1',()=>console.log('Round splash ready'));
