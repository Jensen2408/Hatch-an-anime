// Original coarse-grid animated hull wakes and outline-free splash art.
const fs=require('fs'),path=require('path'),z=require('zlib'),http=require('http');
const out=path.resolve(__dirname,'../../assets/water/Wakes');
function chunk(t,d){const n=Buffer.alloc(4),c=Buffer.alloc(4),b=Buffer.concat([Buffer.from(t),d]);n.writeUInt32BE(d.length);c.writeUInt32BE(z.crc32(b)>>>0);return Buffer.concat([n,b,c])}
function png(name,w,h,p){const raw=Buffer.alloc(h*(w*4+1));for(let y=0;y<h;y++)p.copy(raw,y*(w*4+1)+1,y*w*4,(y+1)*w*4);const hd=Buffer.alloc(13);hd.writeUInt32BE(w);hd.writeUInt32BE(h,4);hd[8]=8;hd[9]=6;fs.writeFileSync(path.join(out,name),Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',hd),chunk('IDAT',z.deflateSync(raw)),chunk('IEND',Buffer.alloc(0))]))}
const hash=(x,y)=>{let v=Math.sin(x*127.1+y*311.7)*43758.5453;return v-Math.floor(v)};
for(const kind of ['egg','player']){
 const p=Buffer.alloc(1024*768*4);
 for(let f=0;f<8;f++)for(let y=0;y<48;y++)for(let x=0;x<32;x++){
  const t=(y+.5)/48,u=(x+.5-16)/16,g=hash(x,y-Math.floor(f/2)),phase=f/8;
  let a=0,c=[238,253,255];const tail=Math.min(1,(1-t)*3.2);
  if(kind==='egg'){
   // Open hull shoulders curve around the front third, then separate into a broad foamy wake.
   const wing=t<.30?.46*Math.sqrt(Math.max(0,1-Math.pow((t-.30)/.24,2))):.46+(t-.30)*.50;
   const d=Math.abs(Math.abs(u)-wing);
   if(t>.065&&d<.075+(g*.035)&&g>.13){a=.96*tail;c=g>.45?[248,255,255]:[184,236,250]}
   const band=((t-Math.abs(u)*.23-phase*.15)% .20+.20)%.20;
   if(t>.43&&Math.abs(u)<wing-.10&&band<.045&&g>.26){a=.83*tail;c=[213,247,255]}
   if(t>.33&&d<.21&&g>.85){a=.68*tail;c=[228,251,255]}
  }else{
   // Broad paired foot churn, short scalloped wash, open centre rather than a boat-shaped V.
   const wing=.30+.30*t+.06*Math.sin(t*14+phase*6.283),d=Math.abs(Math.abs(u)-wing);
   if(t>.14&&d<.12&&g>.20){a=.94*tail;c=g>.5?[249,255,255]:[188,239,252]}
   const band=((t+Math.abs(u)*.22-phase*.18)%.23+.23)%.23;
   if(t>.32&&Math.abs(u)<.65&&band<.065&&g>.30){a=.80*tail;c=[222,249,255]}
   if(t>.18&&Math.abs(u)<.85&&g>.90){a=.6*tail}
  }
  if(t>.96||Math.abs(u)>.94)a=0;
  for(let j=0;j<8;j++)for(let i=0;i<8;i++){const k=(((f>>2)*384+y*8+j)*1024+(f%4)*256+x*8+i)*4;p[k]=c[0];p[k+1]=c[1];p[k+2]=c[2];p[k+3]=Math.round(a*255)}
 }
 png(kind+'_wake_atlas.png',1024,768,p);
 const preview=Buffer.alloc(256*384*4);for(let y=0;y<384;y++)p.copy(preview,y*256*4,y*1024*4,y*1024*4+256*4);png(kind+'_wake_preview.png',256,384,preview);
}
for(const kind of ['splash','cube']){
 const p=Buffer.alloc(128*128*4);
 for(let y=0;y<32;y++)for(let x=0;x<32;x++){
  const dx=x-15.5,dy=y-15.5,r=Math.hypot(dx,dy),a=Math.atan2(dy,dx),g=hash(x,y);let alpha=0,c=[245,255,255];
  if(kind==='splash'){
   const edge=12.2+.7*Math.sin(a*9)+.4*Math.sin(a*15);
   if(Math.abs(r-edge)<1.35&&g>.10){alpha=255;c=g>.4?[250,255,255]:[195,241,255]}
   else if(r>9&&r<15&&g>.87){alpha=210;c=[223,250,255]}
  }else if(Math.abs(dx)<10&&Math.abs(dy)<10){alpha=255;c=dy<-4?[251,255,255]:dx>3?[151,220,245]:[208,245,255]}
  for(let j=0;j<4;j++)for(let i=0;i<4;i++){const k=((y*4+j)*128+x*4+i)*4;p[k]=c[0];p[k+1]=c[1];p[k+2]=c[2];p[k+3]=alpha}
 }
 png(kind+'.png',128,128,p);
}
console.log('Saved egg/player atlases, splash and cube sprites');
if(process.argv.includes('--serve'))http.createServer((req,res)=>{const n=req.url.slice(1);if(!['egg_wake_atlas.png','player_wake_atlas.png','splash.png','cube.png'].includes(n)){res.writeHead(404);return res.end()}res.writeHead(200,{'Content-Type':'image/png'});res.end(fs.readFileSync(path.join(out,n)))}).listen(8099,'127.0.0.1',()=>console.log('Serving wake revision'));