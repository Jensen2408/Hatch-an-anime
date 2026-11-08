// Deterministic hard-grid wake textures. No external artwork; all shapes are original.
const fs=require('fs'),path=require('path'),z=require('zlib'),http=require('http');
const out=path.resolve(__dirname,'../../assets/water/Wakes');fs.mkdirSync(out,{recursive:true});
function chunk(t,d){const n=Buffer.alloc(4),crc=Buffer.alloc(4),body=Buffer.concat([Buffer.from(t),d]);n.writeUInt32BE(d.length);crc.writeUInt32BE(z.crc32(body)>>>0);return Buffer.concat([n,body,crc])}
for(const kind of ['ring','stream','drop']){
 const data=Buffer.alloc(128*(128*4+1));
 for(let y=0;y<128;y++)for(let x=0;x<128;x++){
  const cx=x>>2,cy=y>>2,dx=cx-15.5,dy=cy-15.5,r=Math.hypot(dx,dy);let a=0,g=255;
  if(kind==='ring'){if(r>=12&&r<=14)a=255;else if(r>=11.2&&r<12||r>14&&r<=14.8){a=190;g=110}}
  else if(kind==='stream'){const u=(cx+(Math.floor(cy/4)%2)*3)%10;if(cy>=2&&cy<=29&&u<7&&cy%4<3){a=255;g=u===6||cy%4===2?170:255}}
  else if(Math.abs(dx)<=5&&Math.abs(dy)<=5)a=255;
  const i=y*(128*4+1)+1+x*4;data[i]=data[i+1]=data[i+2]=g;data[i+3]=a;
 }
 const h=Buffer.alloc(13);h.writeUInt32BE(128,0);h.writeUInt32BE(128,4);h[8]=8;h[9]=6;
 fs.writeFileSync(path.join(out,kind+'.png'),Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',h),chunk('IDAT',z.deflateSync(data)),chunk('IEND',Buffer.alloc(0))]));
}
console.log('Created ring, stream and drop textures in '+out);
if(process.argv.includes('--serve'))http.createServer((req,res)=>{
 const name=req.url.slice(1);if(req.method!=='GET'||!['ring.png','stream.png','drop.png'].includes(name)){res.writeHead(404);res.end();return}
 res.writeHead(200,{'Content-Type':'image/png'});res.end(fs.readFileSync(path.join(out,name)));
}).listen(8099,'127.0.0.1',()=>console.log('Wake textures served on 127.0.0.1:8099'));
